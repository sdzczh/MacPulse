import AppKit

struct StatusSegment {
    let text: String
    let reserveText: String
    var emphasized: Bool = false
}

final class StatusItemRenderer: NSView {
    private(set) var segments: [StatusSegment] = []
    private var measurementCache: [String: CGFloat] = [:]

    private let primaryTextFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    private let secondaryTextFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private let height: CGFloat = 22
    private let leading: CGFloat = 7
    private let trailing: CGFloat = 7
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
            width += textWidth + segmentGap
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

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setShouldAntialias(true)

        var x = leading
        let labelColor = NSColor.labelColor
        let lineHeight = textHeight()

        for segment in segments {
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
