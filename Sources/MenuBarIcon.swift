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
