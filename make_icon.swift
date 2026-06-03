import AppKit

// Renders the app icon (a doughnut on a warm rounded tile) to a 1024px PNG.
// Usage: cu_genicon <output.png>
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

// Rounded "tile" with a warm gradient, inset to leave the macOS icon margin.
let inset = S * 0.08
let tileRect = NSRect(x: inset, y: inset, width: S - 2 * inset, height: S - 2 * inset)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: tileRect.width * 0.225, yRadius: tileRect.width * 0.225)
let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.98, green: 0.62, blue: 0.43, alpha: 1),
    NSColor(srgbRed: 0.84, green: 0.34, blue: 0.27, alpha: 1),
])!
gradient.draw(in: tile, angle: -90)

// Doughnut, ~66% filled, evoking the menu bar gauge.
let center = NSPoint(x: S / 2, y: S / 2)
let lineWidth = S * 0.088
let radius = S * 0.255

let track = NSBezierPath()
track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
track.lineWidth = lineWidth
NSColor.white.withAlphaComponent(0.28).setStroke()
track.stroke()

let prog = NSBezierPath()
prog.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 0.66 * 360, clockwise: true)
prog.lineWidth = lineWidth
prog.lineCapStyle = .round
NSColor.white.setStroke()
prog.stroke()

img.unlockFocus()

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to render icon\n", stderr); exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
