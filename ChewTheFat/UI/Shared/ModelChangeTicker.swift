import Foundation
import SwiftData

/// Broadcasts a monotonically-increasing tick every time the SwiftData
/// `ModelContext` saves. Live-bound widget view-models observe this tick to
/// re-query their repositories and re-render, so an edit to a `LoggedFood`
/// on one surface flows through to every widget that references it.
@MainActor
@Observable
final class ModelChangeTicker {
    private(set) var tick: UInt64 = 0

    init() {
        // The ticker is owned by AppEnvironment for the app's lifetime, so we
        // intentionally do not remove the observer — `[weak self]` makes the
        // callback a no-op if this instance is ever released.
        NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick &+= 1
            }
        }
    }

    /// Test hook — invoke after a repository mutation to force a reload
    /// without going through `NotificationCenter`.
    func bump() {
        tick &+= 1
    }
}
