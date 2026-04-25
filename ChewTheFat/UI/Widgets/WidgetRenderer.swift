import Foundation
import SwiftUI

/// Renders a `WidgetIntent` into a concrete SwiftUI view. All chat and
/// dashboard widget surfaces go through here. Payloads carry references
/// (ids, dates), never snapshots — views resolve against the live store
/// at render time so edits to an underlying log reflect everywhere.
@MainActor
struct WidgetRenderer: View {
    let intent: WidgetIntent
    let environment: AppEnvironment
    var onReply: ((String) -> Void)? = nil

    var body: some View {
        switch intent {
        case .mealCard(let payload):
            MealCardView.snapshot(payload: payload, environment: environment)
        case .macroChart(let payload):
            MacroChartView.live(date: payload.date, environment: environment)
        case .weightGraph(let payload):
            WeightGraphView.live(
                range: payload.dateRange.start...payload.dateRange.end,
                environment: environment
            )
        case .weightLogPrompt(let payload):
            WeightLogPromptView(
                viewModel: WeightLogPromptViewModel(payload: payload),
                onPick: { value in onReply?(value) }
            )
        case .quickLog:
            EmptyView()
        }
    }
}

/// Decodes a stored `MessageWidget` row into the in-memory `WidgetIntent`
/// so rehydrated chat history renders through the same pipeline as fresh
/// widget emissions from the current turn.
enum WidgetIntentDecoder {
    static func decode(_ row: MessageWidget) -> WidgetIntent? {
        let decoder = JSONDecoder()
        switch row.type {
        case "mealCard":
            guard let payload = try? decoder.decode(MealCardPayload.self, from: row.payload) else { return nil }
            return .mealCard(payload)
        case "macroChart":
            guard let payload = try? decoder.decode(MacroChartPayload.self, from: row.payload) else { return nil }
            return .macroChart(payload)
        case "weightGraph":
            guard let payload = try? decoder.decode(WeightGraphPayload.self, from: row.payload) else { return nil }
            return .weightGraph(payload)
        case "weightLogPrompt":
            guard let payload = try? decoder.decode(WeightLogPromptPayload.self, from: row.payload) else { return nil }
            return .weightLogPrompt(payload)
        case "quickLog":
            guard let payload = try? decoder.decode(QuickLogPayload.self, from: row.payload) else { return nil }
            return .quickLog(payload)
        default:
            return nil
        }
    }
}
