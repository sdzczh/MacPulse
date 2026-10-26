import SwiftUI
import AppKit
import MacPulseCore

enum Palette {
    static let cpu = Color(red: 0.33, green: 0.58, blue: 1.00)
    static let memory = Color(red: 0.64, green: 0.46, blue: 0.98)
    static let wired = Color(red: 0.43, green: 0.38, blue: 0.86)
    static let compressed = Color(red: 0.86, green: 0.44, blue: 0.88)
    static let cached = Color.primary.opacity(0.20)
    static let thermal = Color(red: 1.00, green: 0.52, blue: 0.24)
    static let fan = Color(red: 0.26, green: 0.76, blue: 0.76)
    static let gpu = Color(red: 0.94, green: 0.40, blue: 0.62)
    static let network = Color(red: 0.24, green: 0.76, blue: 0.52)
    static let upload = Color(red: 0.36, green: 0.62, blue: 0.98)
    static let disk = Color(red: 0.94, green: 0.71, blue: 0.26)
    static let battery = Color(red: 0.35, green: 0.80, blue: 0.40)
    static let warning = Color(red: 0.95, green: 0.66, blue: 0.20)
    static let danger = Color(red: 0.94, green: 0.32, blue: 0.32)
}

func clamp(_ value: Double, to range: ClosedRange<Double> = 0...1) -> Double {
    guard value.isFinite else { return range.lowerBound }
    return min(range.upperBound, max(range.lowerBound, value))
}

extension Font {
    static func metric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accent: Color
    var subtitle: String?
    @ViewBuilder let content: Content

    init(
        _ title: String,
        systemImage: String,
        accent: Color,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accent = accent
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 14, alignment: .leading)

                Text(title)
                    .font(.label(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer(minLength: 8)

                if let subtitle {
                    Text(subtitle)
                        .font(.label(9.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            content
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.66))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.065), lineWidth: 1)
        }
    }
}

struct MetricValue: View {
    let value: String
    var unit: String?
    var size: CGFloat = 27
    var color: Color = .primary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.metric(size))
                .foregroundStyle(color)
            if let unit {
                Text(unit)
                    .font(.metric(max(10, size * 0.36), weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct StatusPill: View {
    let text: String
    var color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 8, weight: .bold))
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(text)
                .font(.label(9.5, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            Capsule(style: .continuous).fill(color.opacity(0.13))
        }
    }
}

struct UsageBar: View {
    let fraction: Double
    var color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * clamp(fraction)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.55), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width > 0 ? max(2.5, width) : 0)
            }
        }
        .frame(height: height)
    }
}

struct MemorySegment {
    let fraction: Double
    let color: Color
}

struct SegmentedBar: View {
    let segments: [MemorySegment]
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let total = max(1, segments.reduce(0) { $0 + max(0, $1.fraction) })
            HStack(spacing: 1.5) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let fraction = max(0, segment.fraction) / total
                    if fraction > 0.0005 {
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(1, proxy.size.width * fraction - 1.5))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.055))
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: height)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(label)
                    .font(.label(9))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.mono(9.5, weight: .medium))
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}

struct SparklineView: View {
    let values: [Double]
    var color: Color
    var upperBound: Double?
    var height: CGFloat = 40
    var showsGrid: Bool = true

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let samples = Array(values.suffix(60))
            let top = max(upperBound ?? (samples.max() ?? 1), 0.0001)
            let points = samples.enumerated().map { index, value in
                CGPoint(
                    x: samples.count <= 1 ? size.width : size.width * CGFloat(index) / CGFloat(samples.count - 1),
                    y: size.height * (1 - CGFloat(clamp(value / top)))
                )
            }

            ZStack(alignment: .topLeading) {
                if showsGrid {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: size.height * 0.5))
                        path.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                    }
                    .stroke(
                        Color.primary.opacity(0.055),
                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 3])
                    )
                }

                if points.count > 1 {
                    areaPath(points: points, size: size)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.26), color.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    linePath(points: points)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                        )
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .position(points[points.count - 1])
                } else if let point = points.first {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: point.y))
                        path.addLine(to: CGPoint(x: size.width, y: point.y))
                    }
                    .stroke(color.opacity(0.45), lineWidth: 1.2)
                }
            }
        }
        .frame(height: height)
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

    private func areaPath(points: [CGPoint], size: CGSize) -> Path {
        Path { path in
            guard let first = points.first, let last = points.last else { return }
            path.move(to: CGPoint(x: first.x, y: size.height))
            path.addLine(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            path.addLine(to: CGPoint(x: last.x, y: size.height))
            path.closeSubpath()
        }
    }
}

struct CoreBarsView: View {
    let usages: [Double]
    var efficiencyCoreCount: Int
    var color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(usages.enumerated()), id: \.offset) { index, usage in
                VStack(spacing: 3) {
                    GeometryReader { proxy in
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(color.opacity(0.10))
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(color.opacity(index < efficiencyCoreCount ? 0.45 : 0.90))
                                .frame(height: max(2, proxy.size.height * CGFloat(clamp(usage))))
                        }
                    }
                    .frame(height: 25)

                    Text("\(index + 1)")
                        .font(.mono(7.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

struct FanRowView: View {
    let fan: FanReading
    var color: Color = Palette.fan

    private var isStopped: Bool { fan.rpm < 1 }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "fanblades")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(fan.name)
                        .font(.label(11, weight: .medium))
                    Text(isStopped ? "停转" : "\(Int(fan.fraction * 100))% 转速")
                        .font(.label(9))
                        .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
                UsageBar(fraction: fan.fraction, color: color, height: 4)
                Text("\(MetricFormat.rpm(fan.minRPM)) – \(MetricFormat.rpm(fan.maxRPM)) RPM")
                    .font(.mono(8.5))
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(MetricFormat.rpm(fan.rpm))
                    .font(.metric(17, weight: .semibold))
                Text("RPM")
                    .font(.label(8.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .frame(minWidth: 54, alignment: .trailing)
        }
    }
}

struct ProcessIconView: View {
    let process: ProcessReading
    var size: CGFloat = 17

    var body: some View {
        Group {
            if let icon = NSRunningApplication(processIdentifier: process.pid)?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .overlay {
                        Image(systemName: "terminal")
                            .font(.system(size: size * 0.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.065))
            .frame(height: 1)
    }
}

struct IconButton: View {
    let systemImage: String
    var help: String?
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hovering ? Color.primary : Color.secondary)
                .frame(width: 26, height: 26)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(hovering ? 0.09 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help ?? "")
    }
}
