import AppKit

/// Draws the small doughnut/pie progress indicator shown in the menu bar.
enum MenuBarIcon {
    static func donut(percent: Int, color: NSColor, diameter: CGFloat = 15, lineWidth: CGFloat = 3.2) -> NSImage {
        let img = NSImage(size: NSSize(width: diameter, height: diameter))
        img.lockFocus()

        let center = NSPoint(x: diameter / 2, y: diameter / 2)
        let radius = (diameter - lineWidth) / 2

        // Track ring (the unused portion).
        let track = NSBezierPath()
        track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = lineWidth
        NSColor.tertiaryLabelColor.setStroke()
        track.stroke()

        // Filled arc, clockwise from 12 o'clock.
        let p = max(0, min(percent, 100))
        if p > 0 {
            let start: CGFloat = 90
            let end = start - CGFloat(p) / 100 * 360
            let prog = NSBezierPath()
            prog.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
            prog.lineWidth = lineWidth
            prog.lineCapStyle = .round
            color.setStroke()
            prog.stroke()
        }

        img.unlockFocus()
        img.isTemplate = false
        return img
    }
}

/// What the menu bar shows: the doughnut image plus the text beside it.
struct MenuBarContent {
    let image: NSImage?
    let title: NSAttributedString
}

/// Builds the menu bar's image + title for a given state. Shared by the live
/// app (`AppDelegate`) and the documentation snapshot renderer, so both stay
/// pixel-identical.
enum MenuBarRenderer {
    static func content(for state: LoadState, settings: SettingsStore, now: Date = Date()) -> MenuBarContent {
        switch state {
        case .signedOut:
            return MenuBarContent(image: nil, title: plain("Sign in"))

        case .loading:
            return MenuBarContent(image: MenuBarIcon.donut(percent: 0, color: .secondaryLabelColor),
                                  title: plain("…"))

        case .error:
            return MenuBarContent(image: MenuBarIcon.donut(percent: 100, color: .systemRed),
                                  title: plain("!"))

        case .loaded(let usage):
            let session = usage.five_hour
            let pct = session?.percent ?? 0
            let image = MenuBarIcon.donut(percent: pct, color: UsageFormat.color(for: pct))

            let reset = UsageFormat.compactReset(session?.resetDate, now: now)
            let base = reset.isEmpty ? "\(pct)%" : "\(pct)% · \(reset)"
            let title = NSMutableAttributedString(attributedString: plain(base))

            if settings.showWeeklyInBar,
               let weekly = usage.seven_day,
               weekly.percent >= settings.weeklyThreshold {
                title.append(plain("  ·  ", color: .secondaryLabelColor))
                title.append(NSAttributedString(string: "Week \(weekly.percent)%", attributes: [
                    .font: NSFont.menuBarFont(ofSize: 0),
                    .foregroundColor: UsageFormat.color(for: weekly.percent),
                ]))
                let wkReset = UsageFormat.compactResetDays(weekly.resetDate, now: now)
                if !wkReset.isEmpty {
                    title.append(plain(" · \(wkReset)", color: .secondaryLabelColor))
                }
            }
            return MenuBarContent(image: image, title: title)
        }
    }

    static func plain(_ s: String, color: NSColor = .labelColor) -> NSAttributedString {
        NSAttributedString(string: s, attributes: [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: color,
        ])
    }
}
