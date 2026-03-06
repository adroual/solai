import AppKit

struct BarRenderer {
    static func render(bars: [Bar], size: CGFloat = 22, scale: CGFloat = 0) -> NSImage {
        let actualScale = scale > 0 ? scale : (NSScreen.main?.backingScaleFactor ?? 2)
        let pixelSize = size * actualScale
        let radius = pixelSize / 2

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep(width: Int(pixelSize), height: Int(pixelSize), scale: actualScale, bars: bars, radius: radius))
        image.isTemplate = true
        return image
    }

    private static func bitmapRep(width: Int, height: Int, scale: CGFloat, bars: [Bar], radius: CGFloat) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale)

        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = context
        let cgContext = context.cgContext

        cgContext.translateBy(x: radius, y: radius)

        for bar in bars {
            let innerR = bar.innerR * radius
            let outerR = bar.outerR * radius
            let lineWidth = max(bar.thickness * radius, 1.5 * scale)

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

        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
