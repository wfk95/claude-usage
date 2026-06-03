import Foundation
import Combine
import AppKit

/// Top-level UI state.
enum LoadState {
    case signedOut
    case loading
    case loaded(Usage)
    case error(String)
}

/// Owns the token, polls the usage API, and publishes state for both the menu
/// bar title and the popover contents.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: LoadState = .signedOut
    @Published private(set) var lastUpdated: Date?

    private let oauth = OAuth()
    private var timer: Timer?
    private let pollInterval: TimeInterval = 60

    init() {
        if OAuthToken.load() != nil {
            state = .loading
        }
    }

    /// Builds a model fixed in a given state for previews and doc snapshots.
    /// Does not load credentials or start polling.
    init(previewState: LoadState, lastUpdated: Date? = nil) {
        self.state = previewState
        self.lastUpdated = lastUpdated
    }

    func start() {
        guard OAuthToken.load() != nil else { return }
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.refresh() }
        }
    }

    func refresh() {
        guard let token = OAuthToken.load() else {
            state = .signedOut
            return
        }
        if case .loaded = state {} else if case .error = state {} else { state = .loading }
        Task {
            do {
                let usage = try await UsageAPI.fetch(token: token)
                self.state = .loaded(usage)
                self.lastUpdated = Date()
            } catch UsageError.unauthorized {
                Keychain.clear()
                self.state = .signedOut
            } catch {
                self.state = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Sign in / out

    func beginSignIn() { oauth.beginSignIn() }

    func completeSignIn(code: String) async -> String? {
        do {
            _ = try await oauth.completeSignIn(pasted: code)
            start()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func signOut() {
        Keychain.clear()
        timer?.invalidate()
        timer = nil
        state = .signedOut
        lastUpdated = nil
    }

    var isSignedIn: Bool {
        if case .signedOut = state { return false }
        return true
    }
}

// MARK: - Formatting helpers

enum UsageFormat {
    /// Color band for a utilization percentage.
    static func color(for percent: Int) -> NSColor {
        switch percent {
        case ..<50: return NSColor.systemGreen
        case 50..<80: return NSColor.systemYellow
        default: return NSColor.systemRed
        }
    }

    /// Compact reset for the menu bar title, e.g. "52m" or "1h4m". Empty if unknown.
    /// `now` is injectable so doc snapshots render deterministically.
    static func compactReset(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let secs = date.timeIntervalSince(now)
        if secs <= 0 { return "0m" }
        let h = Int(secs) / 3600
        let m = (Int(secs) % 3600) / 60
        return h > 0 ? "\(h)h\(m)m" : "\(m)m"
    }

    /// "resets in 1h 4m" for short windows, "resets Sat 1:00 PM" for weekly ones.
    static func resetText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else { return "" }
        let secs = date.timeIntervalSince(now)
        if secs <= 0 { return "resetting…" }
        if secs < 12 * 3600 {
            let h = Int(secs) / 3600
            let m = (Int(secs) % 3600) / 60
            if h > 0 { return "resets in \(h)h \(m)m" }
            return "resets in \(m)m"
        }
        let f = DateFormatter()
        f.dateFormat = "EEE h:mm a"
        return "resets \(f.string(from: date))"
    }
}
