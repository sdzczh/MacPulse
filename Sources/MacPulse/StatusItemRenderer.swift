import AppKit
import MacPulseCore

struct StatusSegment {
    let symbolName: String
    let text: String
    let reserveText: String
    var emphasized: Bool = false
}

final class StatusItemRenderer: NSView {
    private(set) var segments: [StatusSegment] = []
    private var symbolCache: [String: NSImage] = [:]
    private var measurementCache: [String: CGFloat] = [:]

    private let primaryTextFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let secondaryTextFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private let height: CGFloat = 22
    private let leading: CGFloat = 7
    private let trailing: CGFloat = 7
    private let symbolWidth: CGFloat = 11
    private let symbolGap: CGFloat = 4
    private let segmentGap: CGFloat = 9

    static let maximumWidth: CGFloat = 430

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: contentWidth, height: height)
    }

    /// 一次采样只做一次刷新，宽度不变时不再触发布局。
    func update(segments: [StatusSegment]) {
        let widthChanged = contentWidth != fittingWidth(for: segments)
        self.segments = segments
        if widthChanged {
            invalidateIntrinsicContentSize()
        }
        needsDisplay = true
    }

    private var contentWidth: CGFloat {
        fittingWidth(for: segments)
    }

    func fittingWidth(for segments: [StatusSegment]) -> CGFloat {
        var width = leading + trailing
        for segment in segments {
            let textWidth = max(
                measure(segment.text, emphasized: segment.emphasized),
                measure(segment.reserveText, emphasized: segment.emphasized)
            )
            width += symbolWidth + symbolGap + textWidth + segmentGap
        }
        if !segments.isEmpty {
            width -= segmentGap
        }
        return max(60, ceil(width))
    }

    private func font(emphasized: Bool) -> NSFont {
        emphasized ? primaryTextFont : secondaryTextFont
    }

    private func measure(_ text: String, emphasized: Bool) -> CGFloat {
        let key = (emphasized ? "e|" : "r|") + text
        if let cached = measurementCache[key] {
            return cached
        }
        let width = (text as NSString).size(withAttributes: [.font: font(emphasized: emphasized)]).width
        if measurementCache.count >= 512 {
            measurementCache.removeAll(keepingCapacity: true)
        }
        measurementCache[key] = width
        return width
    }

    private func textHeight() -> CGFloat {
        ceil(primaryTextFont.ascender - primaryTextFont.descender + primaryTextFont.leading)
    }

    private func symbolImage(_ name: String) -> NSImage? {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let appearance = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])?.rawValue ?? "aqua"
        let cacheKey = "\(name)|\(appearance)|\(Int(scale.rounded()))"
        if let cached = symbolCache[cacheKey] {
            return cached
        }

        let pointSize = NSSize(width: 11, height: 11)
        let configuration = NSImage.SymbolConfiguration(pointSize: 10.5, weight: .regular)
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
        let labelColor = NSColor.labelColor
        let lineHeight = textHeight()

        for segment in segments {
            if let image = symbolImage(segment.symbolName) {
                let symbolRect = NSRect(x: x, y: (height - symbolWidth) / 2, width: symbolWidth, height: symbolWidth)
                image.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 0.62)
            }
            x += symbolWidth + symbolGap

            let cellWidth = max(
                measure(segment.text, emphasized: segment.emphasized),
                measure(segment.reserveText, emphasized: segment.emphasized)
            )
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font(emphasized: segment.emphasized),
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
}
