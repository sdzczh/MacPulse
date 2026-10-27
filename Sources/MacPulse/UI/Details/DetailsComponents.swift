import SwiftUI
import MacPulseCore

enum DetailSeverity {
    case normal
    case warning
    case critical
    case neutral

    var color: Color {
        switch self {
        case .normal: return Palette.network
        case .warning: return Palette.warning
        case .critical: return Palette.danger
        case .neutral: return .secondary
        }
    }

    var glyph: String {
        switch self {
        case .normal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .critical: return "exclamationmark.triangle.fill"
        case .neutral: return "info.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "注意"
        case .critical: return "偏高"
        case .neutral: return "暂无数据"
        }
    }

    static func level(_ fraction: Double, warning: Double, critical: Double) -> DetailSeverity {
        guard fraction.isFinite else { return .neutral }
        if fraction >= critical { return .critical }
        if fraction >= warning { return .warning }
        return .normal
    }
}

struct DetailSurface<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct DetailGaugeView: View {
    let fraction: Double
    let text: String
    let color: Color
    var diameter: CGFloat = 78
    var textSize: CGFloat = 21

    private var clamped: Double { clamp(fraction) }
    private var lineWidth: CGFloat { max(diameter * 0.085, 3.5) }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    Color.primary.opacity(0.10),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: 0.75 * clamped)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))

            Text(text)
                .font(.metric(textSize, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.horizontal, lineWidth + 2)
        }
        .frame(width: diameter, height: diameter)
    }
}

struct DetailSparklineView: View {
    let values: [Double]
    let timestamps: [Date]
    let color: Color
    let secondaryValues: [Double]
    let secondaryColor: Color
    let secondaryLabel: String?
    let fixedRange: ClosedRange<Double>?
    let includesZero: Bool
    let minimumSpan: Double
    let showsScaleLabels: Bool
    let height: CGFloat
    let formatter: (Double) -> String
    let allowsHover: Bool

    @State private var hoverIndex: Int?

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    init(
        values: [Double],
        timestamps: [Date] = [],
        color: Color,
        secondaryValues: [Double] = [],
        secondaryColor: Color = Palette.upload,
        secondaryLabel: String? = nil,
        fixedRange: ClosedRange<Double>? = nil,
        includesZero: Bool = true,
        minimumSpan: Double = 1,
        showsScaleLabels: Bool = true,
        height: CGFloat = 44,
        formatter: @escaping (Double) -> String = { String(format: "%.0f", $0) },
        allowsHover: Bool = true
    ) {
        self.values = values
        self.timestamps = timestamps
        self.color = color
        self.secondaryValues = secondaryValues
        self.secondaryColor = secondaryColor
        self.secondaryLabel = secondaryLabel
        self.fixedRange = fixedRange
        self.includesZero = includesZero
        self.minimumSpan = minimumSpan
        self.showsScaleLabels = showsScaleLabels
        self.height = height
        self.formatter = formatter
        self.allowsHover = allowsHover
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let samples = Array(values.suffix(240))
            let count = samples.count
            let secondary = secondaryValues.isEmpty
                ? []
                : Array(secondaryValues.suffix(count))
            let showGutter = showsScaleLabels && size.height >= 30
            let gutters = showGutter ? min(44, size.width * 0.24) : 0
            let plotWidth = max(size.width - gutters, 1)

            if count >= 2 {
                let bounds = resolvedBounds(samples: samples, secondary: secondary)
                let xs = (0..<count).map { index in
                    gutters + plotWidth * CGFloat(index) / CGFloat(count - 1)
                }
                let sampleDates = dateList(for: count)

                ZStack(alignment: .topLeading) {
                    gridLines(gutter: gutters, size: size)

                    let points = zip(xs, samples).map { point -> CGPoint in
                        CGPoint(x: point.0, y: yPosition(point.1, bounds: bounds, height: size.height))
                    }
                    if let last = points.last {
                        areaPath(points: points, height: size.height)
                            .fill(
                                LinearGradient(
                                    colors: [color.opacity(0.24), color.opacity(0.015)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        linePath(points: points)
                            .stroke(
                                color,
                                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                            )
                        Circle()
                            .fill(color)
                            .frame(width: 4.5, height: 4.5)
                            .position(x: last.x, y: last.y)
                            .opacity(hoverIndex == nil ? 1 : 0)
                    }

                    if !secondary.isEmpty {
                        let secondaryPoints = zip(xs, secondary).map { point -> CGPoint in
                            CGPoint(x: point.0, y: yPosition(point.1, bounds: bounds, height: size.height))
                        }
                        linePath(points: secondaryPoints)
                            .stroke(
                                secondaryColor.opacity(0.9),
                                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round, dash: [4, 3])
                            )
                    }

                    if let index = hoverIndex,
                       xs.indices.contains(index),
                       samples.indices.contains(index) {
                        let x = xs[index]
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))

                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: yPosition(samples[index], bounds: bounds, height: size.height))

                        if secondary.indices.contains(index) {
                            Circle()
                                .fill(secondaryColor)
                                .frame(width: 5, height: 5)
                                .position(x: x, y: yPosition(secondary[index], bounds: bounds, height: size.height))
                        }

                        tooltip(
                            index: index,
                            samples: samples,
                            secondary: secondary,
                            dates: sampleDates,
                            x: x,
                            width: size.width
                        )
                    }

                    if showGutter, hoverIndex == nil {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(formatter(bounds.upperBound))
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .minimumScaleFactor(0.65)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if bounds.upperBound - bounds.lowerBound > 0.001 {
                                Text(formatter(bounds.lowerBound))
                                    .font(.system(size: 8, weight: .medium, design: .rounded))
                                    .minimumScaleFactor(0.65)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, 4)
                        .frame(width: gutters, height: size.height, alignment: .topTrailing)
                    }
                }
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    guard allowsHover else { return }
                    switch phase {
                    case .active(let location):
                        let relative = (location.x - gutters) / plotWidth
                        let raw = Int((relative * CGFloat(count - 1)).rounded())
                        hoverIndex = min(max(raw, 0), count - 1)
                    case .ended:
                        hoverIndex = nil
                    @unknown default:
                        hoverIndex = nil
                    }
                }
            } else {
                HStack(spacing: 7) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 10, weight: .medium))
                    Text("正在积累趋势…")
                        .font(.label(9.5))
                }
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
    }

    private func dateList(for count: Int) -> [Date?] {
        guard timestamps.count == values.count, timestamps.count >= count else {
            return Array(repeating: nil, count: count)
        }
        return timestamps.suffix(count).map { Optional($0) }
    }

    private func resolvedBounds(samples: [Double], secondary: [Double]) -> ClosedRange<Double> {
        if let fixedRange {
            return fixedRange
        }
        let all = samples + secondary
        guard let maxValue = all.max(), let minValue = all.min() else {
            return 0...1
        }
        if includesZero {
            let top = max(maxValue, minimumSpan)
            return 0...(top > 0 ? top * 1.06 : 1)
        }
        let span = max(maxValue - minValue, minimumSpan)
        let lower = max(0, minValue - span * 0.12)
        let upper = max(maxValue + span * 0.12, minimumSpan)
        return lower...max(upper, lower + 0.001)
    }

    private func yPosition(_ value: Double, bounds: ClosedRange<Double>, height: CGFloat) -> CGFloat {
        let span = max(bounds.upperBound - bounds.lowerBound, 0.0001)
        let normalized = (value - bounds.lowerBound) / span
        return height - CGFloat(clamp(normalized)) * height
    }

    @ViewBuilder
    private func gridLines(gutter: CGFloat, size: CGSize) -> some View {
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { fraction in
            let y = size.height - CGFloat(fraction) * size.height
            Path { path in
                path.move(to: CGPoint(x: gutter, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            .stroke(
                Color.primary.opacity(fraction == 0 ? 0.07 : 0.045),
                style: StrokeStyle(lineWidth: 0.5)
            )
        }
    }

    private func linePath(points: [CGPoint]) -> Path {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
    }

    private func areaPath(points: [CGPoint], height: CGFloat) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: height))
            path.closeSubpath()
        }
    }

    @ViewBuilder
    private func tooltip(
        index: Int,
        samples: [Double],
        secondary: [Double],
        dates: [Date?],
        x: CGFloat,
        width: CGFloat
    ) -> some View {
        let estimatedWidth: CGFloat = secondary.isEmpty ? 112 : 190
        let halfWidth = min(estimatedWidth / 2 + 6, width / 2)
        let clampedX = max(halfWidth, min(x, width - halfWidth))

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(formatter(samples[index]))
                    .font(.mono(10, weight: .semibold))
                    .foregroundStyle(.primary)

                if secondary.indices.contains(index) {
                    Circle()
                        .fill(secondaryColor)
                        .frame(width: 5, height: 5)
                    if let secondaryLabel {
                        Text(secondaryLabel)
                            .font(.label(8.5))
                            .foregroundStyle(.tertiary)
                    }
                    Text(formatter(secondary[index]))
                        .font(.mono(9.5))
                        .foregroundStyle(.secondary)
                }
            }

            if dates.indices.contains(index), let date = dates[index] {
                Text(Self.timeFormatter.string(from: date))
                    .font(.mono(8.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.thickMaterial)
                .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 2)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .fixedSize()
        .position(x: clampedX, y: 18)
        .allowsHitTesting(false)
    }
}

struct DetailCoreBarsView: View {
    let usages: [Double]
    let efficiencyCoreCount: Int
    let color: Color
    var barHeight: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text("核心占用")
                    .font(.label(9))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    legend(opacity: 0.45, text: "能效核")
                    legend(opacity: 0.95, text: "性能核")
                }
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(usages.enumerated()), id: \.offset) { index, usage in
                    VStack(spacing: 2) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color.opacity(0.09))
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color.opacity(index < efficiencyCoreCount ? 0.45 : 0.92))
                                .frame(height: max(1.5, barHeight * CGFloat(clamp(usage))))
                        }
                        .frame(height: barHeight)

                        Text("\(index + 1)")
                            .font(.mono(6.5, weight: .medium))
                            .foregroundStyle(.quaternary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func legend(opacity: Double, text: String) -> some View {
        HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(color.opacity(opacity))
                .frame(width: 5, height: 5)
            Text(text)
                .font(.label(8))
                .foregroundStyle(.quaternary)
        }
    }
}

struct DetailLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.label(8.5))
                .foregroundStyle(.tertiary)
        }
    }
}
