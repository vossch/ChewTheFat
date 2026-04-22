import Foundation
import SwiftData

struct ModelContextFactory: Sendable {
    let container: ModelContainer

    @MainActor
    func mainContext() -> ModelContext {
        container.mainContext
    }

    func backgroundActor() -> BackgroundModelActor {
        BackgroundModelActor(modelContainer: container)
    }
}

@ModelActor
actor BackgroundModelActor {
}
