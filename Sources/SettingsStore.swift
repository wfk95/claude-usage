import Foundation
import Combine

/// User-configurable preferences, persisted in UserDefaults.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @Published var showWeeklyInBar: Bool { didSet { d.set(showWeeklyInBar, forKey: K.showWeekly) } }
    @Published var weeklyThreshold: Int { didSet { d.set(weeklyThreshold, forKey: K.threshold) } }

    private let d = UserDefaults.standard
    private enum K {
        static let showWeekly = "showWeeklyInBar"
        static let threshold = "weeklyThreshold"
    }

    private init() {
        if d.object(forKey: K.showWeekly) == nil { d.set(true, forKey: K.showWeekly) }
        if d.object(forKey: K.threshold) == nil { d.set(50, forKey: K.threshold) }
        showWeeklyInBar = d.bool(forKey: K.showWeekly)
        weeklyThreshold = d.integer(forKey: K.threshold)
    }

    /// A non-persisting instance for previews/snapshots. `didSet` observers do
    /// not run during init, so this never writes to UserDefaults.
    init(showWeeklyInBar: Bool, weeklyThreshold: Int) {
        self.showWeeklyInBar = showWeeklyInBar
        self.weeklyThreshold = weeklyThreshold
    }
}
