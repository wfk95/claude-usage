import SwiftUI

/// The dropdown shown when the menu bar item is clicked.
struct UsageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings = SettingsStore.shared
    var onQuit: () -> Void
    var now: Date = Date() // injectable for deterministic doc snapshots
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            Divider()
            launchRow
            Divider()
            weeklyRow
            Divider()
            footer
        }
        .frame(width: 300)
    }

    private var weeklyRow: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Show weekly in menu bar").font(.system(size: 12))
                Spacer()
                Toggle("", isOn: $settings.showWeeklyInBar)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            if settings.showWeeklyInBar {
                HStack {
                    Text("…only when above").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Stepper(value: $settings.weeklyThreshold, in: 0...100, step: 5) {
                        Text("\(settings.weeklyThreshold)%")
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var launchRow: some View {
        HStack {
            Text("Launch at login").font(.system(size: 12))
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: launchAtLogin) { newValue in
                    LaunchAtLogin.isEnabled = newValue
                    launchAtLogin = LaunchAtLogin.isEnabled // reflect actual state
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var header: some View {
        HStack {
            Text("Claude Usage")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action: { model.refresh(force: true) }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .signedOut:
            signedOut
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Loading usage…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
        case .error(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Try again") { model.refresh(force: true) }
            }
        case .loaded(let usage):
            VStack(alignment: .leading, spacing: 16) {
                if let b = usage.five_hour { bar("Current session", b) }
                if let b = usage.seven_day { bar("Weekly · all models", b) }
                if let b = usage.seven_day_sonnet { bar("Weekly · Sonnet", b) }
                if let b = usage.seven_day_opus { bar("Weekly · Opus", b) }
            }
        }
    }

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sign in to see your Claude plan usage.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button(action: { NotificationCenter.default.post(name: .startSignIn, object: nil) }) {
                Text("Sign in with Claude")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
        }
        .padding(.vertical, 4)
    }

    private func bar(_ title: String, _ bucket: UsageBucket) -> some View {
        let pct = bucket.percent
        let color = Color(UsageFormat.color(for: pct))
        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(pct)%").font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * CGFloat(min(pct, 100)) / 100))
                }
            }
            .frame(height: 6)
            Text(UsageFormat.resetText(bucket.resetDate, now: now))
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
        }
    }

    private var footer: some View {
        HStack {
            if let updated = model.lastUpdated {
                Text("Updated \(relative(updated))")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if model.isSignedIn {
                Button("Sign out") { model.signOut() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Button("Quit") { onQuit() }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: now)
    }
}

extension Notification.Name {
    static let startSignIn = Notification.Name("ClaudeUsage.startSignIn")
}
