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

let iso = ISO8601DateFormatter()
func inMinutes(_ m: Double) -> String { iso.string(from: Date().addingTimeInterval(m * 60)) }

func bucket(_ pct: Double, minutes: Double) -> UsageBucket {
    UsageBucket(utilization: pct, resets_at: inMinutes(minutes))
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
func menuBarStrip(_ state: LoadState, settings: SettingsStore, scale: CGFloat = 3) -> NSBitmapImageRep {
    var rep: NSBitmapImageRep!
    NSAppearance(named: .darkAqua)!.performAsCurrentDrawingAppearance {
        let content = MenuBarRenderer.content(for: state, settings: settings)
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
func panel(_ state: LoadState, settings: SettingsStore, lastUpdated: Date? = Date()) -> NSBitmapImageRep? {
    let model = AppModel(previewState: state, lastUpdated: lastUpdated)
    let root = UsageView(model: model, settings: settings, onQuit: {})
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
    five_hour: bucket(12, minutes: 200),
    seven_day: bucket(8, minutes: 4000),
    seven_day_sonnet: bucket(1, minutes: 4000),
    seven_day_opus: nil)), settings: defaults), "menubar-low.png")

write(menuBarStrip(.loaded(Usage(
    five_hour: bucket(64, minutes: 48),
    seven_day: bucket(33, minutes: 4000),
    seven_day_sonnet: bucket(9, minutes: 4000),
    seven_day_opus: nil)), settings: defaults), "menubar-mid.png")

write(menuBarStrip(.loaded(Usage(
    five_hour: bucket(88, minutes: 12),
    seven_day: bucket(71, minutes: 4000),
    seven_day_sonnet: bucket(23, minutes: 4000),
    seven_day_opus: nil)), settings: defaults), "menubar-high.png")

write(menuBarStrip(.signedOut, settings: defaults), "menubar-signedout.png")

// Panel states.
write(panel(.loaded(Usage(
    five_hour: bucket(34, minutes: 52),
    seven_day: bucket(18, minutes: 4000),
    seven_day_sonnet: bucket(2, minutes: 4000),
    seven_day_opus: nil)), settings: defaults), "panel-loaded.png")

write(panel(.loaded(Usage(
    five_hour: bucket(88, minutes: 12),
    seven_day: bucket(71, minutes: 4000),
    seven_day_sonnet: bucket(23, minutes: 4000),
    seven_day_opus: nil)), settings: defaults), "panel-high.png")

write(panel(.signedOut, settings: defaults, lastUpdated: nil), "panel-signedout.png")
}

MainActor.assumeIsolated { renderAll() }
print("done")
exit(0)
