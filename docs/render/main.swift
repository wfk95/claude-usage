import AppKit
import SwiftUI

// Documentation snapshot renderer.
//
// Links the real Sources/ (everything except AppDelegate.swift) and renders the
// app's actual UI components — the menu bar doughnut+title via MenuBarRenderer,
// and the click-down panel via the real UsageView — to PNGs under docs/assets/.
// Because it uses the shipping render code, the docs can never drift from the app.

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let outDir = "docs/assets"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Fixed reference clock so renders are deterministic (no diff churn on rebuild).
func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents()
    (c.year, c.month, c.day, c.hour, c.minute) = (y, mo, d, h, mi)
    return Calendar(identifier: .gregorian).date(from: c)!
}
let now = date(2026, 6, 3, 10, 8)        // a fixed "now"
let weeklyReset = date(2026, 6, 6, 13, 0) // Saturday 1:00 PM

let iso = ISO8601DateFormatter()
func atMinutes(_ m: Double) -> String { iso.string(from: now.addingTimeInterval(m * 60)) }

func session(_ pct: Double, minutes: Double) -> UsageBucket {
    UsageBucket(utilization: pct, resets_at: atMinutes(minutes))
}
func weekly(_ pct: Double) -> UsageBucket {
    UsageBucket(utilization: pct, resets_at: iso.string(from: weeklyReset))
}

// MARK: - PNG output

func makeRep(size: NSSize, scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    return rep
}

func write(_ rep: NSBitmapImageRep?, _ name: String) {
    guard let rep, let data = rep.representation(using: .png, properties: [:]) else {
        print("✗ \(name): render failed"); return
    }
    try? data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("✓ \(name)  \(rep.pixelsWide)×\(rep.pixelsHigh)")
}

// MARK: - Menu bar strip (uses the real MenuBarRenderer)

@MainActor
func menuBarStrip(_ state: LoadState, settings: SettingsStore, now: Date, scale: CGFloat = 3) -> NSBitmapImageRep {
    var rep: NSBitmapImageRep!
    NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
        let content = MenuBarRenderer.content(for: state, settings: settings, now: now)
        let titleSize = content.title.size()
        let padX: CGFloat = 13
        let gap: CGFloat = 5
        let iconW = content.image?.size.width ?? 0
        let iconGap: CGFloat = content.image != nil ? gap : 0
        let height: CGFloat = 26
        let width = padX + iconW + iconGap + ceil(titleSize.width) + padX
        let size = NSSize(width: width, height: height)

        rep = makeRep(size: size, scale: scale)
        let ctx = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx

        NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 7, yRadius: 7).fill()

        var x = padX
        if let img = content.image {
            img.draw(in: NSRect(x: x, y: (height - img.size.height) / 2,
                                width: img.size.width, height: img.size.height))
            x += img.size.width + iconGap
        }
        content.title.draw(at: NSPoint(x: x, y: (height - titleSize.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
    }
    return rep
}

// MARK: - Panel (uses the real UsageView)

@MainActor
func panel(_ state: LoadState, settings: SettingsStore, now: Date) -> NSBitmapImageRep? {
    let model = AppModel(previewState: state)
    let root = UsageView(model: model, settings: settings, onQuit: {}, now: now)
        .background(Color(NSColor.windowBackgroundColor))

    // Host in a real (offscreen) window so AppKit-backed controls — the toggles,
    // stepper and buttons — actually render. ImageRenderer rasterizes the SwiftUI
    // layer tree and leaves those as placeholders, so cacheDisplay is required.
    let host = NSHostingView(rootView: root)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
    window.contentView = host
    window.displayIfNeeded()
    RunLoop.current.run(until: Date().addingTimeInterval(0.35)) // let controls realize
    host.layoutSubtreeIfNeeded()

    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep
}

// MARK: - Scenarios

@MainActor
func renderAll() {
let defaults = SettingsStore(showWeeklyInBar: true, weeklyThreshold: 50)

// Menu bar at three usage levels.
write(menuBarStrip(.loaded(Usage(
    five_hour: session(12, minutes: 199),
    seven_day: weekly(8),
    seven_day_sonnet: weekly(1),
    seven_day_opus: nil)), settings: defaults, now: now), "menubar-low.png")

write(menuBarStrip(.loaded(Usage(
    five_hour: session(64, minutes: 48),
    seven_day: weekly(33),
    seven_day_sonnet: weekly(9),
    seven_day_opus: nil)), settings: defaults, now: now), "menubar-mid.png")

write(menuBarStrip(.loaded(Usage(
    five_hour: session(88, minutes: 12),
    seven_day: weekly(71),
    seven_day_sonnet: weekly(23),
    seven_day_opus: nil)), settings: defaults, now: now), "menubar-high.png")

write(menuBarStrip(.signedOut, settings: defaults, now: now), "menubar-signedout.png")

// Panel states.
write(panel(.loaded(Usage(
    five_hour: session(34, minutes: 52),
    seven_day: weekly(18),
    seven_day_sonnet: weekly(2),
    seven_day_opus: nil)), settings: defaults, now: now), "panel-loaded.png")

write(panel(.loaded(Usage(
    five_hour: session(88, minutes: 12),
    seven_day: weekly(71),
    seven_day_sonnet: weekly(23),
    seven_day_opus: nil)), settings: defaults, now: now), "panel-high.png")

write(panel(.signedOut, settings: defaults, now: now), "panel-signedout.png")
}

MainActor.assumeIsolated { renderAll() }
print("done")
exit(0)
