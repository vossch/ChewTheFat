import Foundation

nonisolated struct ToolArguments: Sendable {
    let raw: Data

    init(raw: Data) { self.raw = raw }

    init(json: String) {
        self.raw = Data(json.utf8)
    }

    init<Value: Encodable>(value: Value, encoder: JSONEncoder = .init()) throws {
        self.raw = try encoder.encode(value)
    }

    func decode<Value: Decodable>(
        _: Value.Type = Value.self,
        decoder: JSONDecoder = .init()
    ) throws -> Value {
        try decoder.decode(Value.self, from: raw)
    }
}
