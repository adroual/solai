import AppKit

struct BarRenderer {
    static func render(bars: [Bar], size: CGFloat = 22, scale: CGFloat = 0) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let cgContext = NSGraphicsContext.current?.cgContext else { return false }
            
            let radius = size / 2
            cgContext.saveGState()
            cgContext.translateBy(x: radius, y: radius)

            for bar in bars {
                let innerR = bar.innerR * radius
                let outerR = bar.outerR * radius
                // Use a minimum of 1.5 points line width to ensure lines are sharp and visible on all screens
                let lineWidth = max(bar.thickness * radius, 1.5)

                let startX = cos(bar.angle) * innerR
                let startY = sin(bar.angle) * innerR
                let endX = cos(bar.angle) * outerR
                let endY = sin(bar.angle) * outerR

                // Boost opacity for menu bar visibility — ensure minimum 0.4
                let boostedOpacity = max(bar.opacity * 1.4, 0.4)
                cgContext.setStrokeColor(NSColor.black.withAlphaComponent(min(boostedOpacity, 1.0)).cgColor)
                cgContext.setLineWidth(lineWidth)
                cgContext.setLineCap(.round)
                cgContext.beginPath()
                cgContext.move(to: CGPoint(x: startX, y: startY))
                cgContext.addLine(to: CGPoint(x: endX, y: endY))
                cgContext.strokePath()
            }

            cgContext.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
