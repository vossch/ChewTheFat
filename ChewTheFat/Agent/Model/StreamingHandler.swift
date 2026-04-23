import Foundation

/// Tag-based parser for streamed model output. The model's raw stream may
/// interleave text with `<tool_call>{...}</tool_call>` and `<widget>{...}</widget>`
/// blocks. This actor accumulates a sliding buffer, emits text outside tags,
/// and assembles complete tag bodies before emitting structured events.
actor StreamingHandler {
    private enum State {
        case text
        case insideTag(name: TagName, depth: Int)
    }

    private enum TagName: String, CaseIterable {
        case toolCall = "tool_call"
        case widget = "widget"

        var openLiteral: String { "<\(rawValue)>" }
        var closeLiteral: String { "</\(rawValue)>" }
    }

    private var buffer: String = ""
    private var pending: String = ""
    private var state: State = .text
    private let decoder = JSONDecoder()

    func feed(_ chunk: String) -> [ModelStreamEvent] {
        buffer.append(chunk)
        var events: [ModelStreamEvent] = []
        while drain(into: &events) {}
        return events
    }

    func finish(reason: FinishReason) -> [ModelStreamEvent] {
        var events: [ModelStreamEvent] = []
        while drain(into: &events) {}
        if !pending.isEmpty {
            events.append(.text(pending))
            pending.removeAll()
        }
        events.append(.finished(reason))
        return events
    }

    private func drain(into events: inout [ModelStreamEvent]) -> Bool {
        switch state {
        case .text:
            return drainText(into: &events)
        case .insideTag(let name, _):
            return drainTag(name: name, into: &events)
        }
    }

    private func drainText(into events: inout [ModelStreamEvent]) -> Bool {
        guard !buffer.isEmpty else { return false }
        let openings = TagName.allCases.compactMap { name -> (Range<String.Index>, TagName)? in
            guard let r = buffer.range(of: name.openLiteral) else { return nil }
            return (r, name)
        }
        guard let next = openings.min(by: { $0.0.lowerBound < $1.0.lowerBound }) else {
            // No tag yet — but hold back tail bytes that could be a partial open.
            let safe = safeTextPrefixLength(in: buffer)
            if safe == 0 { return false }
            let chunk = String(buffer.prefix(safe))
            buffer.removeFirst(safe)
            pending += chunk
            flushPending(into: &events)
            return false
        }
        let prefix = String(buffer[..<next.0.lowerBound])
        if !prefix.isEmpty {
            pending += prefix
            flushPending(into: &events)
        }
        buffer.removeSubrange(buffer.startIndex..<next.0.upperBound)
        state = .insideTag(name: next.1, depth: 1)
        return true
    }

    private func drainTag(name: TagName, into events: inout [ModelStreamEvent]) -> Bool {
        guard let close = buffer.range(of: name.closeLiteral) else { return false }
        let body = String(buffer[..<close.lowerBound])
        buffer.removeSubrange(buffer.startIndex..<close.upperBound)
        state = .text
        switch name {
        case .toolCall:
            if let event = parseToolCall(body) {
                events.append(event)
            }
        case .widget:
            if let event = parseWidget(body) {
                events.append(event)
            }
        }
        return true
    }

    private func flushPending(into events: inout [ModelStreamEvent]) {
        guard !pending.isEmpty else { return }
        events.append(.text(pending))
        pending.removeAll()
    }

    /// Returns the length of `text` that is safe to flush without risking that
    /// the tail bytes are the start of an open tag (e.g. "<tool_c").
    private func safeTextPrefixLength(in text: String) -> Int {
        let candidates = TagName.allCases.map { $0.openLiteral }
        var maxHold = 0
        for candidate in candidates {
            for n in (1..<candidate.count).reversed() {
                let suffix = String(candidate.prefix(n))
                if text.hasSuffix(suffix) {
                    maxHold = max(maxHold, n)
                    break
                }
            }
        }
        return text.count - maxHold
    }

    private func parseToolCall(_ body: String) -> ModelStreamEvent? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let payload = try? decoder.decode(ToolCallEnvelope.self, from: data) else {
            return nil
        }
        let argsString: String
        if let argsObject = payload.arguments {
            argsString = argsObject.rawString
        } else {
            argsString = "{}"
        }
        let request = ToolCallRequest(
            id: payload.id ?? UUID().uuidString,
            identifier: ToolIdentifier(payload.name),
            argumentsJSON: argsString
        )
        return .toolCall(request)
    }

    private func parseWidget(_ body: String) -> ModelStreamEvent? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }
        guard let envelope = try? decoder.decode(WidgetEnvelope.self, from: data) else {
            return nil
        }
        guard let intent = envelope.intent(decoder: decoder) else { return nil }
        return .widget(intent)
    }
}

private nonisolated struct WidgetEnvelope: Decodable {
    let type: String
    let payload: RawJSONValue?

    func intent(decoder: JSONDecoder) -> WidgetIntent? {
        guard let payloadString = payload?.rawString,
              let payloadData = payloadString.data(using: .utf8) else { return nil }
        switch type {
        case "mealCard":
            return (try? decoder.decode(MealCardPayload.self, from: payloadData)).map(WidgetIntent.mealCard)
        case "macroChart":
            return (try? decoder.decode(MacroChartPayload.self, from: payloadData)).map(WidgetIntent.macroChart)
        case "weightGraph":
            return (try? decoder.decode(WeightGraphPayload.self, from: payloadData)).map(WidgetIntent.weightGraph)
        case "quickLog":
            return (try? decoder.decode(QuickLogPayload.self, from: payloadData)).map(WidgetIntent.quickLog)
        default:
            return nil
        }
    }
}

private nonisolated struct ToolCallEnvelope: Decodable {
    let id: String?
    let name: String
    let arguments: RawJSONValue?
}

private nonisolated struct RawJSONValue: Decodable {
    let rawString: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyDecodable].self) {
            let data = try JSONSerialization.data(withJSONObject: AnyDecodable.unwrap(dict))
            rawString = String(data: data, encoding: .utf8) ?? "{}"
        } else if let array = try? container.decode([AnyDecodable].self) {
            let data = try JSONSerialization.data(withJSONObject: AnyDecodable.unwrap(array))
            rawString = String(data: data, encoding: .utf8) ?? "[]"
        } else if let string = try? container.decode(String.self) {
            rawString = string
        } else {
            rawString = "{}"
        }
    }
}

private nonisolated struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues(\.value)
        } else {
            value = NSNull()
        }
    }

    static func unwrap(_ dict: [String: AnyDecodable]) -> [String: Any] {
        dict.mapValues(\.value)
    }

    static func unwrap(_ array: [AnyDecodable]) -> [Any] {
        array.map(\.value)
    }
}
