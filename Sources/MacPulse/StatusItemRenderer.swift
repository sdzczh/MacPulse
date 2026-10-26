import AppKit
import MacPulseCore

struct StatusSegment {
    let symbolName: String
    let text: String
    let reserveText: String
}

final class StatusItemRenderer: NSView {
    private(set) var segments: [StatusSegment] = []
    private(set) var cpuHistory: [Double] = []
    private var symbolCache: [String: NSImage] = [:]
    private var measurementCache: [String: CGFloat] = [:]

    private let textFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let height: CGFloat = 22
    private let leading: CGFloat = 6
    private let trailing: CGFloat = 6
    private let sparklineWidth: CGFloat = 22
    private let sparklineGap: CGFloat = 7
    private let symbolWidth: CGFloat = 13
    private let symbolGap: CGFloat = 3
    private let segmentGap: CGFloat = 10

    static let maximumWidth: CGFloat = 430

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: contentWidth, height: height)
    }

    /// 一次采样只做一次刷新，宽度不变时不再触发布局。
    func update(segments: [StatusSegment], cpuHistory: [Double]) {
        let widthChanged = contentWidth != fittingWidth(for: segments)
        self.segments = segments
        self.cpuHistory = cpuHistory
        if widthChanged {
            invalidateIntrinsicContentSize()
        }
        needsDisplay = true
    }

    private var contentWidth: CGFloat {
        fittingWidth(for: segments)
    }

    func fittingWidth(for segments: [StatusSegment]) -> CGFloat {
        var width = leading + sparklineWidth + sparklineGap + trailing
        for segment in segments {
            let textWidth = max(measure(segment.text), measure(segment.reserveText))
            width += symbolWidth + symbolGap + textWidth + segmentGap
        }
        if !segments.isEmpty {
            width -= segmentGap
        }
        return max(60, ceil(width))
    }

    private func measure(_ text: String) -> CGFloat {
        if let cached = measurementCache[text] {
            return cached
        }
        let width = (text as NSString).size(withAttributes: [.font: textFont]).width
        if measurementCache.count >= 512 {
            measurementCache.removeAll(keepingCapacity: true)
        }
        measurementCache[text] = width
        return width
    }

    private func textHeight() -> CGFloat {
        ceil(textFont.ascender - textFont.descender + textFont.leading)
    }

    private func symbolImage(_ name: String) -> NSImage? {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue ?? "aqua"
        let cacheKey = "\(name)|\(appearance)|\(Int(scale.rounded()))"
        if let cached = symbolCache[cacheKey] {
            return cached
        }

        let pointSize = NSSize(width: 12, height: 12)
        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            .applying(NSImage.SymbolConfiguration(hierarchicalColor: .labelColor))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            return nil
        }

        // SF Symbol 是矢量表示，直接重复绘制每次都会重新栅格化；先压成位图再缓存。
        let pixelsWide = Int(ceil(pointSize.width * scale))
        let pixelsHigh = Int(ceil(pointSize.height * scale))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let bitmapContext = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = pointSize

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = bitmapContext
        bitmapContext.imageInterpolation = .high
        effectiveAppearance.performAsCurrentDrawingAppearance {
            symbol.draw(in: NSRect(origin: .zero, size: pointSize), from: .zero, operation: .sourceOver, fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: pointSize)
        image.addRepresentation(rep)
        if symbolCache.count >= 64 {
            symbolCache.removeAll(keepingCapacity: true)
        }
        symbolCache[cacheKey] = image
        return image
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)

        var x = leading
        drawSparkline(in: NSRect(x: x, y: 5, width: sparklineWidth, height: 12))
        x += sparklineWidth + sparklineGap

        let labelColor = NSColor.labelColor
        let lineHeight = textHeight()

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                let separatorX = x - segmentGap / 2
                labelColor.withAlphaComponent(0.16).setFill()
                NSBezierPath(rect: NSRect(x: separatorX, y: 6, width: 0.5, height: height - 12)).fill()
            }

            if let image = symbolImage(segment.symbolName) {
                let symbolRect = NSRect(x: x, y: (height - 12) / 2, width: 12, height: 12)
                image.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
            }
            x += symbolWidth + symbolGap

            let cellWidth = max(measure(segment.text), measure(segment.reserveText))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: labelColor
            ]
            let textRect = NSRect(
                x: x,
                y: (height - lineHeight) / 2,
                width: cellWidth,
                height: lineHeight
            )
            (segment.text as NSString).draw(in: textRect, withAttributes: attributes)
            x += cellWidth + segmentGap
        }
    }

    private func drawSparkline(in rect: NSRect) {
        let values = Array(cpuHistory.suffix(60))
        let baseline = NSBezierPath()
        baseline.move(to: NSPoint(x: rect.minX, y: rect.maxY - 0.5))
        baseline.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 0.5))
        NSColor.labelColor.withAlphaComponent(0.15).setStroke()
        baseline.lineWidth = 0.5
        baseline.stroke()

        guard values.count > 1 else {
            let flat = NSBezierPath()
            flat.move(to: NSPoint(x: rect.minX, y: rect.maxY - 1))
            flat.line(to: NSPoint(x: rect.maxX, y: rect.maxY - 1))
            NSColor.labelColor.withAlphaComponent(0.55).setStroke()
            flat.lineWidth = 1
            flat.stroke()
            return
        }

        let path = NSBezierPath()
        for (index, value) in values.enumerated() {
            let fraction = min(1, max(0, value))
            let px = rect.minX + rect.width * CGFloat(index) / CGFloat(max(1, values.count - 1))
            let py = rect.maxY - rect.height * CGFloat(fraction)
            if index == 0 {
                path.move(to: NSPoint(x: px, y: py))
            } else {
                path.line(to: NSPoint(x: px, y: py))
            }
        }
        NSColor.labelColor.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 1.1
        path.lineJoinStyle = .round
        path.stroke()
    }
}
