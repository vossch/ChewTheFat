import Foundation

@MainActor
@Observable
final class MealCardViewModel {
    enum Mode {
        /// Chat-emitted widget: pinned to a specific set of LoggedFood ids.
        case snapshot(ids: [UUID])
        /// Dashboard widget: all logs for (meal, date), recomputed live.
        case live(meal: MealType, date: Date)
    }

    private(set) var title: String
    private(set) var subtitle: String
    private(set) var items: [Item] = []
    private(set) var totals: NutritionFacts = .zero
    private(set) var isEmpty: Bool = true

    private let mode: Mode
    private let foodLog: FoodLogRepository
    private let dateContext: Date

    init(mode: Mode, foodLog: FoodLogRepository, dateContext: Date) {
        self.mode = mode
        self.foodLog = foodLog
        self.dateContext = dateContext
        self.title = ""
        self.subtitle = ""
    }

    func reload() {
        let logs: [LoggedFood]
        do {
            switch mode {
            case .snapshot(let ids):
                logs = try foodLog.loggedFoods(ids: ids)
            case .live(let meal, let date):
                logs = try foodLog.loggedFoods(on: date)
                    .filter { $0.meal == meal.rawValue }
            }
        } catch {
            self.items = []
            self.totals = .zero
            self.isEmpty = true
            return
        }

        let ordered = logs.sorted { $0.id.uuidString < $1.id.uuidString }
        self.items = ordered.compactMap(Self.makeItem(from:))
        self.totals = ordered.reduce(.zero) { $0 + Self.macros(for: $1) }
        self.isEmpty = ordered.isEmpty

        let (resolvedMeal, resolvedDate) = resolveLabels(from: ordered)
        self.title = resolvedMeal.displayName
        self.subtitle = Self.dateFormatter.string(from: resolvedDate)
    }

    private func resolveLabels(from logs: [LoggedFood]) -> (MealType, Date) {
        switch mode {
        case .snapshot:
            let meal = logs.first.flatMap { MealType(rawValue: $0.meal) } ?? .snack
            let date = logs.first?.date ?? dateContext
            return (meal, date)
        case .live(let meal, let date):
            return (meal, date)
        }
    }

    struct Item: Identifiable {
        let id: UUID
        let name: String
        let detail: String?
        let quantityDescription: String
        let calories: Int
    }

    private static func makeItem(from logged: LoggedFood) -> Item? {
        guard let entry = logged.foodEntry, let serving = logged.serving else { return nil }
        let qty = Self.quantityFormatter.string(from: NSNumber(value: logged.quantity)) ?? String(logged.quantity)
        let measurement = serving.measurementName
        return Item(
            id: logged.id,
            name: entry.name,
            detail: entry.detail,
            quantityDescription: "\(qty) \(measurement)",
            calories: Int((serving.calories * logged.quantity).rounded())
        )
    }

    private static func macros(for logged: LoggedFood) -> NutritionFacts {
        guard let serving = logged.serving else { return .zero }
        return NutritionFacts(
            calories: serving.calories,
            proteinG: serving.proteinG,
            carbsG: serving.carbsG,
            fatG: serving.fatG,
            fiberG: serving.fiberG
        ).scaled(by: logged.quantity)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
}
