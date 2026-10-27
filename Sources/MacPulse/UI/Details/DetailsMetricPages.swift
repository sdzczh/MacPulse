import SwiftUI
import MacPulseCore

// MARK: - Category router

struct DetailsCategoryView: View {
    let category: DetailCategory
    let state: MetricsState
    let hardware: HardwareInfo
    let settings: AppSettings
    let density: DetailDensity

    private var detailed: Bool { density == .detailed }

    var body: some View {
        switch category {
        case .cpu:
            CPUDetailPage(state: state, hardware: hardware, detailed: detailed)
        case .memory:
            MemoryDetailPage(state: state, detailed: detailed)
        case .gpu:
            GPUDetailPage(state: state, detailed: detailed)
        case .network:
            NetworkDetailPage(state: state, detailed: detailed)
        case .disk:
            DiskDetailPage(state: state, detailed: detailed)
        case .thermal:
            ThermalDetailPage(state: state, unit: settings.temperatureUnit, detailed: detailed)
        case .fan:
            FanDetailPage(state: state, detailed: detailed)
        case .battery:
            BatteryDetailPage(snapshot: state.snapshot, detailed: detailed)
        case .system:
            SystemDetailPage(state: state, hardware: hardware, detailed: detailed)
        case .processes:
            DetailsProcessesView(
                processes: state.snapshot.processes,
                isDetailed: state.isDetailed,
                interval: state.samplingInterval
            )
        }
    }
}

// MARK: - Page scaffolding

private enum PageClock {
    static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct MetricPage<Content: View>: View {
    let category: DetailCategory
    let subtitle: String
    let severity: DetailSeverity?
    let sampledAt: Date
    let content: Content

    init(
        category: DetailCategory,
        subtitle: String,
        severity: DetailSeverity? = nil,
        sampledAt: Date,
        @ViewBuilder content: () -> Content
    ) {
        self.category = category
        self.subtitle = subtitle
        self.severity = severity
        self.sampledAt = sampledAt
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                header
                content
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(category.accent.opacity(0.14))
                Image(systemName: category.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(category.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(category.rawValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    if let severity {
                        StatusPill(text: severity.label, color: severity.color)
                    }
                }
                Text(subtitle)
                    .font(.label(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Circle()
                    .fill(Palette.network)
                    .frame(width: 5, height: 5)
                Text("实时 · \(clockText)")
                    .font(.label(9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 2)
    }

    private var clockText: String {
        PageClock.formatter.string(from: sampledAt)
    }
}

private let metricColumns = [
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14),
    GridItem(.flexible(), spacing: 14)
]

private struct SurfaceTitle: View {
    let title: String
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.label(11, weight: .semibold))
                .foregroundStyle(.secondary)
            if let note {
                Text(note)
                    .font(.label(8.5))
                    .foregroundStyle(.quaternary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MetricFact: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.label(9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(value)
                .font(.metric(14, weight: .semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MetricFactSmall: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.label(8.5))
                .foregroundStyle(.quaternary)
            Text(value)
                .font(.mono(11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct EmptySurface: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        DetailSurface {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.label(13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.label(10))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 230)
        }
    }
}

private struct LoadChip: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.label(8))
                .foregroundStyle(.quaternary)
            Text(String(format: "%.2f", value.isFinite ? value : 0))
                .font(.mono(12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
    }
}

private struct RateHeadline: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.label(10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(value)
                .font(.metric(30, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct TemperatureHeadline: View {
    let title: String
    let celsius: Double?
    let peak: Double?
    let color: Color
    let unit: TemperatureUnit

    private var value: String {
        guard let celsius else { return "--" }
        return String(format: "%.0f", unit.convert(celsius: celsius))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(title)
                    .font(.label(10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.metric(38, weight: .bold))
                    .foregroundStyle(celsius == nil ? .secondary : .primary)
                Text(unit == .celsius ? "°C" : "°F")
                    .font(.label(11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(peak.map { "峰值 \(unit.string(celsius: $0))" } ?? "峰值 --")
                .font(.mono(9))
                .foregroundStyle(.quaternary)
        }
        .frame(minWidth: 110, alignment: .leading)
    }
}

// MARK: - CPU

private struct CPUDetailPage: View {
    let state: MetricsState
    let hardware: HardwareInfo
    let detailed: Bool

    private var cpu: CPUSnapshot { state.snapshot.cpu }
    private var history: MetricsHistory { state.history }

    private var severity: DetailSeverity {
        DetailSeverity.level(cpu.totalUsage, warning: 0.7, critical: 0.9)
    }

    private var coreSubtitle: String {
        let performance = hardware.performanceCoreCount
        let efficiency = hardware.efficiencyCoreCount
        if performance + efficiency > 0 {
            return "\(hardware.logicalCoreCount) 核 · \(performance)P + \(efficiency)E"
        }
        return "\(hardware.logicalCoreCount) 核"
    }

    var body: some View {
        MetricPage(
            category: .cpu,
            subtitle: "\(coreSubtitle) · 每 \(intervalText(state.samplingInterval)) 秒采样",
            severity: severity,
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                    HStack(alignment: .center, spacing: 26) {
                        DetailGaugeView(
                            fraction: cpu.totalUsage,
                            text: MetricFormat.percent(cpu.totalUsage),
                            color: Palette.cpu,
                            diameter: detailed ? 132 : 104,
                            textSize: detailed ? 30 : 23
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("整体占用")
                                .font(.label(10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 6) {
                                LoadChip(title: "1 分", value: cpu.load1)
                                LoadChip(title: "5 分", value: cpu.load5)
                                LoadChip(title: "15 分", value: cpu.load15)
                            }
                            Text(coreSubtitle)
                                .font(.mono(9.5))
                                .foregroundStyle(.quaternary)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            MetricFactSmall(label: "性能核", value: "\(hardware.performanceCoreCount)")
                            MetricFactSmall(label: "能效核", value: "\(hardware.efficiencyCoreCount)")
                            MetricFactSmall(label: "逻辑核心", value: "\(hardware.logicalCoreCount)")
                        }
                    }

                    DetailSparklineView(
                        values: history.cpu,
                        timestamps: history.timestamps,
                        color: Palette.cpu,
                        fixedRange: 0...1,
                        height: detailed ? 190 : 116,
                        formatter: { MetricFormat.percent($0) },
                        allowsHover: detailed
                    )
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "核心占用", note: coreSubtitle)
                        DetailCoreBarsView(
                            usages: cpu.coreUsages,
                            efficiencyCoreCount: hardware.efficiencyCoreCount,
                            color: Palette.cpu,
                            barHeight: 46
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Memory

private struct MemoryDetailPage: View {
    let state: MetricsState
    let detailed: Bool

    private var memory: MemorySnapshot { state.snapshot.memory }

    private var severity: DetailSeverity {
        switch memory.pressure {
        case .normal: return .normal
        case .warning: return .warning
        case .critical: return .critical
        case .unknown: return .neutral
        }
    }

    private var gaugeColor: Color {
        switch memory.pressure {
        case .warning: return Palette.warning
        case .critical: return Palette.danger
        default: return Palette.memory
        }
    }

    private var swapText: String {
        guard memory.swapTotalBytes > 0 else { return "未启用" }
        return "\(MetricFormat.memory(memory.swapUsedBytes)) / \(MetricFormat.memory(memory.swapTotalBytes))"
    }

    var body: some View {
        MetricPage(
            category: .memory,
            subtitle: "物理内存 \(MetricFormat.memory(memory.totalBytes)) · 压力 \(memory.pressure.rawValue)",
            severity: severity,
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                    HStack(alignment: .center, spacing: 26) {
                        DetailGaugeView(
                            fraction: memory.usedFraction,
                            text: MetricFormat.percent(memory.usedFraction),
                            color: gaugeColor,
                            diameter: detailed ? 132 : 104,
                            textSize: detailed ? 30 : 23
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("已用内存")
                                .font(.label(10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text("\(MetricFormat.memory(memory.usedBytes)) / \(MetricFormat.memory(memory.totalBytes))")
                                .font(.metric(20, weight: .semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("可用 \(MetricFormat.memory(memory.availableBytes)) · 缓存 \(MetricFormat.memory(memory.cachedBytes))")
                                .font(.mono(10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            MetricFactSmall(label: "活跃", value: MetricFormat.memory(memory.activeBytes))
                            MetricFactSmall(label: "常驻", value: MetricFormat.memory(memory.wiredBytes))
                            MetricFactSmall(label: "交换", value: swapText)
                        }
                    }

                    DetailSparklineView(
                        values: state.history.memoryUsed,
                        timestamps: state.history.timestamps,
                        color: Palette.memory,
                        fixedRange: 0...Double(max(memory.totalBytes, 1)),
                        height: detailed ? 190 : 116,
                        formatter: { MetricFormat.memory(UInt64(max(0, $0))) },
                        allowsHover: detailed
                    )
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "内存构成", note: "按已统计内存比例")
                        MemoryCompositionBar(memory: memory)
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 12) {
                            MemoryLegendItem(label: "活跃", bytes: memory.activeBytes, color: Palette.memory)
                            MemoryLegendItem(label: "常驻", bytes: memory.wiredBytes, color: Palette.wired)
                            MemoryLegendItem(label: "压缩", bytes: memory.compressedBytes, color: Palette.compressed)
                            MemoryLegendItem(label: "缓存", bytes: memory.cachedBytes, color: Color.primary.opacity(0.28))
                            MemoryLegendItem(label: "空闲", bytes: memory.freeBytes, color: Color.primary.opacity(0.10))
                            MetricFact(label: "交换", value: swapText, valueColor: .secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct MemoryCompositionBar: View {
    let memory: MemorySnapshot

    private var segments: [(UInt64, Color)] {
        [
            (memory.activeBytes, Palette.memory),
            (memory.wiredBytes, Palette.wired),
            (memory.compressedBytes, Palette.compressed),
            (memory.cachedBytes, Color.primary.opacity(0.28)),
            (memory.freeBytes, Color.primary.opacity(0.10))
        ]
    }

    var body: some View {
        let total = max(segments.reduce(UInt64(0)) { $0 + $1.0 }, 1)
        let spacing = CGFloat(segments.count - 1) * 2
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(segments.indices, id: \.self) { index in
                    let fraction = Double(segments[index].0) / Double(total)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(segments[index].1)
                        .frame(width: max(fraction > 0.0005 ? 2 : 0, (proxy.size.width - spacing) * fraction))
                }
            }
            .frame(width: proxy.size.width, height: 14)
            .clipShape(Capsule(style: .continuous))
        }
        .frame(height: 14)
    }
}

private struct MemoryLegendItem: View {
    let label: String
    let bytes: UInt64
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.label(9))
                    .foregroundStyle(.tertiary)
                Text(MetricFormat.memory(bytes))
                    .font(.mono(10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - GPU

private struct GPUDetailPage: View {
    let state: MetricsState
    let detailed: Bool

    private var gpu: GPUSnapshot? { state.snapshot.gpu }

    private var severity: DetailSeverity {
        guard let gpu else { return .neutral }
        return DetailSeverity.level(gpu.utilization, warning: 0.7, critical: 0.9)
    }

    private var allocationFraction: Double {
        guard let gpu, gpu.allocatedMemoryBytes > 0 else { return 0 }
        return Double(gpu.inUseMemoryBytes) / Double(gpu.allocatedMemoryBytes)
    }

    var body: some View {
        MetricPage(
            category: .gpu,
            subtitle: gpu == nil ? "未检测到 GPU 统计" : "统一内存架构 · 只读采样",
            severity: gpu == nil ? nil : severity,
            sampledAt: state.snapshot.sampledAt
        ) {
            if let gpu {
                DetailSurface {
                    VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                        HStack(alignment: .center, spacing: 26) {
                            DetailGaugeView(
                                fraction: gpu.utilization,
                                text: MetricFormat.percent(gpu.utilization),
                                color: Palette.gpu,
                                diameter: detailed ? 132 : 104,
                                textSize: detailed ? 30 : 23
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("整体利用率")
                                    .font(.label(10, weight: .medium))
                                    .foregroundStyle(.tertiary)
                                Text(MetricFormat.percent(gpu.utilization))
                                    .font(.metric(24, weight: .semibold))
                                Text("显存 \(MetricFormat.memory(gpu.inUseMemoryBytes)) · 已分配 \(MetricFormat.memory(gpu.allocatedMemoryBytes))")
                                    .font(.mono(10))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            VStack(alignment: .trailing, spacing: 9) {
                                MetricFactSmall(label: "显存占用", value: MetricFormat.memory(gpu.inUseMemoryBytes))
                                MetricFactSmall(label: "已分配", value: MetricFormat.memory(gpu.allocatedMemoryBytes))
                                MetricFactSmall(label: "分配率", value: MetricFormat.percent(allocationFraction))
                            }
                        }

                        DetailSparklineView(
                            values: state.history.gpu,
                            timestamps: state.history.timestamps,
                            color: Palette.gpu,
                            fixedRange: 0...1,
                            height: detailed ? 190 : 116,
                            formatter: { MetricFormat.percent($0) },
                            allowsHover: detailed
                        )
                    }
                }

                if detailed {
                    DetailSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SurfaceTitle(title: "显存分配", note: "统一内存")
                            UsageBar(fraction: allocationFraction, color: Palette.gpu, height: 6)
                            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
                                MetricFact(label: "显存占用", value: MetricFormat.memory(gpu.inUseMemoryBytes))
                                MetricFact(label: "已分配", value: MetricFormat.memory(gpu.allocatedMemoryBytes))
                                MetricFact(
                                    label: "剩余分配",
                                    value: MetricFormat.memory(gpu.allocatedMemoryBytes > gpu.inUseMemoryBytes ? gpu.allocatedMemoryBytes - gpu.inUseMemoryBytes : 0)
                                )
                            }
                        }
                    }
                }
            } else {
                EmptySurface(
                    icon: "display",
                    title: "没有可用的 GPU 指标",
                    message: "当前设备或系统未提供 GPU 利用率统计。"
                )
            }
        }
    }
}

// MARK: - Network

private struct NetworkDetailPage: View {
    let state: MetricsState
    let detailed: Bool

    private var network: NetworkSnapshot { state.snapshot.network }

    private var interfaceText: String {
        guard !network.activeInterfaces.isEmpty else { return "无活动接口" }
        return network.activeInterfaces.prefix(3).joined(separator: " · ")
    }

    var body: some View {
        MetricPage(
            category: .network,
            subtitle: interfaceText,
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                    HStack(alignment: .top, spacing: 40) {
                        RateHeadline(
                            title: "下载",
                            value: MetricFormat.rate(network.downloadBytesPerSecond),
                            icon: "arrow.down",
                            color: Palette.network
                        )
                        RateHeadline(
                            title: "上传",
                            value: MetricFormat.rate(network.uploadBytesPerSecond),
                            icon: "arrow.up",
                            color: Palette.upload
                        )

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            MetricFactSmall(label: "活动接口", value: "\(network.activeInterfaces.count) 个")
                            MetricFactSmall(label: "本次接收", value: MetricFormat.memory(network.totalReceivedBytes))
                            MetricFactSmall(label: "本次发送", value: MetricFormat.memory(network.totalSentBytes))
                        }
                    }

                    DetailSparklineView(
                        values: state.history.download,
                        timestamps: state.history.timestamps,
                        color: Palette.network,
                        secondaryValues: state.history.upload,
                        secondaryColor: Palette.upload,
                        secondaryLabel: "上传",
                        minimumSpan: 1024,
                        height: detailed ? 190 : 116,
                        formatter: { MetricFormat.rate($0) },
                        allowsHover: detailed
                    )

                    HStack(spacing: 12) {
                        DetailLegendDot(color: Palette.network, label: "下载")
                        DetailLegendDot(color: Palette.upload, label: "上传")
                        Spacer(minLength: 0)
                        Text("双线共用量程")
                            .font(.label(8))
                            .foregroundStyle(.quaternary)
                    }
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "接口与累计", note: interfaceText)
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
                            MetricFact(label: "下载速率", value: MetricFormat.rate(network.downloadBytesPerSecond))
                            MetricFact(label: "上传速率", value: MetricFormat.rate(network.uploadBytesPerSecond))
                            MetricFact(label: "活动接口", value: "\(network.activeInterfaces.count) 个")
                            MetricFact(label: "本次接收", value: MetricFormat.memory(network.totalReceivedBytes))
                            MetricFact(label: "本次发送", value: MetricFormat.memory(network.totalSentBytes))
                            MetricFact(label: "采样间隔", value: "\(intervalText(state.samplingInterval)) 秒")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Disk

private struct DiskDetailPage: View {
    let state: MetricsState
    let detailed: Bool

    private var disk: DiskSnapshot { state.snapshot.disk }

    private var severity: DetailSeverity {
        DetailSeverity.level(disk.usedFraction, warning: 0.82, critical: 0.93)
    }

    var body: some View {
        MetricPage(
            category: .disk,
            subtitle: "启动磁盘 · \(MetricFormat.memory(disk.totalBytes))",
            severity: severity,
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                    HStack(alignment: .center, spacing: 26) {
                        DetailGaugeView(
                            fraction: disk.usedFraction,
                            text: MetricFormat.percent(disk.usedFraction),
                            color: Palette.disk,
                            diameter: detailed ? 132 : 104,
                            textSize: detailed ? 30 : 23
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("容量占用")
                                .font(.label(10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text("已用 \(MetricFormat.memory(disk.usedBytes))")
                                .font(.metric(20, weight: .semibold))
                            Text("可用 \(MetricFormat.memory(disk.freeBytes)) / 总容量 \(MetricFormat.memory(disk.totalBytes))")
                                .font(.mono(10))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            MetricFactSmall(label: "读取", value: MetricFormat.rate(disk.readBytesPerSecond))
                            MetricFactSmall(label: "写入", value: MetricFormat.rate(disk.writeBytesPerSecond))
                            MetricFactSmall(label: "可用", value: MetricFormat.memory(disk.freeBytes))
                        }
                    }

                    DetailSparklineView(
                        values: state.history.diskRead,
                        timestamps: state.history.timestamps,
                        color: Palette.disk,
                        secondaryValues: state.history.diskWrite,
                        secondaryColor: Palette.upload,
                        secondaryLabel: "写入",
                        minimumSpan: 1024,
                        height: detailed ? 190 : 116,
                        formatter: { MetricFormat.rate($0) },
                        allowsHover: detailed
                    )

                    HStack(spacing: 12) {
                        DetailLegendDot(color: Palette.disk, label: "读取")
                        DetailLegendDot(color: Palette.upload, label: "写入")
                        Spacer(minLength: 0)
                        Text("双线共用量程")
                            .font(.label(8))
                            .foregroundStyle(.quaternary)
                    }
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "容量与吞吐", note: "启动磁盘")
                        UsageBar(fraction: disk.usedFraction, color: Palette.disk, height: 6)
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
                            MetricFact(label: "总容量", value: MetricFormat.memory(disk.totalBytes))
                            MetricFact(label: "已用", value: MetricFormat.memory(disk.usedBytes))
                            MetricFact(label: "可用", value: MetricFormat.memory(disk.freeBytes))
                            MetricFact(label: "读取速率", value: MetricFormat.rate(disk.readBytesPerSecond))
                            MetricFact(label: "写入速率", value: MetricFormat.rate(disk.writeBytesPerSecond))
                            MetricFact(label: "使用率", value: MetricFormat.percent(disk.usedFraction))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Thermal

private struct ThermalDetailPage: View {
    let state: MetricsState
    let unit: TemperatureUnit
    let detailed: Bool

    private var thermal: ThermalSnapshot { state.snapshot.thermal }

    private var severity: DetailSeverity {
        switch thermal.thermalState {
        case "正常": return .normal
        case "偏高": return .warning
        case "过热", "临界": return .critical
        default: return .neutral
        }
    }

    var body: some View {
        MetricPage(
            category: .thermal,
            subtitle: "\(thermal.sensorCount) 个传感器 · 温控状态 \(thermal.thermalState)",
            severity: severity,
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: detailed ? 18 : 12) {
                    HStack(alignment: .top, spacing: 34) {
                        TemperatureHeadline(
                            title: "CPU 平均",
                            celsius: thermal.cpuAverageCelsius,
                            peak: thermal.cpuMaxCelsius,
                            color: Palette.thermal,
                            unit: unit
                        )
                        TemperatureHeadline(
                            title: "GPU 平均",
                            celsius: thermal.gpuAverageCelsius,
                            peak: thermal.gpuMaxCelsius,
                            color: Palette.gpu,
                            unit: unit
                        )

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            StatusPill(text: thermal.thermalState, color: severity.color)
                            MetricFactSmall(label: "传感器", value: "\(thermal.sensorCount) 个")
                            MetricFactSmall(label: "风扇", value: "\(state.snapshot.fans.count) 个")
                        }
                    }

                    DetailSparklineView(
                        values: state.history.cpuTemperature,
                        timestamps: state.history.timestamps,
                        color: Palette.thermal,
                        includesZero: false,
                        minimumSpan: 10,
                        height: detailed ? 190 : 116,
                        formatter: { value in
                            String(format: "%.0f°", unit.convert(celsius: value))
                        },
                        allowsHover: detailed
                    )
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "温度概览", note: "CPU 曲线 · 只读 SMC")
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
                            MetricFact(label: "CPU 平均", value: thermal.cpuAverageCelsius.map { unit.string(celsius: $0) } ?? "--")
                            MetricFact(label: "CPU 峰值", value: thermal.cpuMaxCelsius.map { unit.string(celsius: $0) } ?? "--")
                            MetricFact(label: "GPU 平均", value: thermal.gpuAverageCelsius.map { unit.string(celsius: $0) } ?? "--")
                            MetricFact(label: "GPU 峰值", value: thermal.gpuMaxCelsius.map { unit.string(celsius: $0) } ?? "--")
                            MetricFact(label: "传感器", value: "\(thermal.sensorCount) 个")
                            MetricFact(label: "温度单位", value: unit == .celsius ? "摄氏 °C" : "华氏 °F")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Fans

private struct FanDetailPage: View {
    let state: MetricsState
    let detailed: Bool

    private var fans: [FanReading] { state.snapshot.fans }

    var body: some View {
        MetricPage(
            category: .fan,
            subtitle: fans.isEmpty ? "未检测到风扇" : "\(fans.count) 个风扇 · 自动调速",
            sampledAt: state.snapshot.sampledAt
        ) {
            if fans.isEmpty {
                EmptySurface(
                    icon: "fanblades",
                    title: "没有可用的风扇",
                    message: "此设备未提供风扇转速传感器，或无风扇设计。"
                )
            } else {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SurfaceTitle(title: "风扇转速", note: "\(fans.count) 个风扇")
                            Text("RPM")
                                .font(.mono(8.5))
                                .foregroundStyle(.quaternary)
                        }

                        VStack(spacing: 16) {
                            ForEach(fans) { fan in
                                FanPageRow(fan: fan)
                            }
                        }

                        if detailed {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(fans.count > 1 ? "风扇 1 趋势" : "转速趋势")
                                        .font(.label(8.5))
                                        .foregroundStyle(.tertiary)
                                    Spacer(minLength: 0)
                                    Text("历史 \(state.history.fan.count) 个采样")
                                        .font(.mono(8))
                                        .foregroundStyle(.quaternary)
                                }
                                DetailSparklineView(
                                    values: state.history.fan,
                                    timestamps: state.history.timestamps,
                                    color: Palette.fan,
                                    minimumSpan: 1000,
                                    height: 170,
                                    formatter: { MetricFormat.rpm($0) },
                                    allowsHover: true
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct FanPageRow: View {
    let fan: FanReading

    private var stopped: Bool { fan.rpm < 1 }

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: "fanblades")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.fan)
                Text(fan.name)
                    .font(.label(12, weight: .medium))
                Text(stopped ? "停转" : "\(Int(fan.fraction * 100))%")
                    .font(.mono(9))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                Text(MetricFormat.rpm(fan.rpm))
                    .font(.metric(24, weight: .bold))
                Text("RPM")
                    .font(.label(9))
                    .foregroundStyle(.tertiary)
            }

            UsageBar(fraction: fan.fraction, color: Palette.fan, height: 6)

            HStack {
                Text("\(MetricFormat.rpm(fan.minRPM)) – \(MetricFormat.rpm(fan.maxRPM)) RPM")
                Spacer(minLength: 4)
                Text(stopped ? "低于启动转速" : "自动调速")
            }
            .font(.mono(8.5))
            .foregroundStyle(.quaternary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Battery

private struct BatteryDetailPage: View {
    let snapshot: SystemSnapshot
    let detailed: Bool

    private var battery: BatterySnapshot? { snapshot.battery }

    var body: some View {
        MetricPage(
            category: .battery,
            subtitle: subtitle,
            severity: battery.map { severity(for: $0) },
            sampledAt: snapshot.sampledAt
        ) {
            if let battery {
                DetailSurface {
                    HStack(alignment: .center, spacing: 26) {
                        DetailGaugeView(
                            fraction: Double(battery.percentage) / 100,
                            text: "\(battery.percentage)%",
                            color: color(for: battery),
                            diameter: detailed ? 132 : 104,
                            textSize: detailed ? 28 : 22
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("电池电量")
                                .font(.label(10, weight: .medium))
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 6) {
                                if battery.isCharging {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(Palette.battery)
                                }
                                Text(statusText(for: battery))
                                    .font(.metric(20, weight: .semibold))
                            }
                            Text(battery.isPluggedIn ? "已接通电源" : "电池供电")
                                .font(.mono(10))
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 9) {
                            MetricFactSmall(label: "健康度", value: battery.healthPercent.map { String(format: "%.0f%%", $0) } ?? "--")
                            MetricFactSmall(label: "循环次数", value: battery.cycleCount.map { "\($0) 次" } ?? "--")
                            MetricFactSmall(label: "电源", value: battery.powerSource)
                        }
                    }
                }

                if detailed {
                    DetailSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            SurfaceTitle(title: "电池状态", note: battery.isCharging ? "正在充电" : "使用中")
                            UsageBar(fraction: Double(battery.percentage) / 100, color: color(for: battery), height: 6)
                            LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 14) {
                                MetricFact(label: "健康度", value: battery.healthPercent.map { String(format: "%.0f%%", $0) } ?? "--")
                                MetricFact(label: "循环次数", value: battery.cycleCount.map { "\($0) 次" } ?? "--")
                                MetricFact(label: "电源来源", value: battery.powerSource)
                                MetricFact(label: "当前状态", value: statusText(for: battery))
                                MetricFact(label: "剩余时间", value: remainingText(for: battery))
                                MetricFact(label: "接入电源", value: battery.isPluggedIn ? "是" : "否")
                            }
                        }
                    }
                }
            } else {
                EmptySurface(
                    icon: "battery.0",
                    title: "未检测到电池",
                    message: "当前设备没有电池，或系统未提供电池统计。"
                )
            }
        }
    }

    private var subtitle: String {
        guard let battery else { return "未检测到电池" }
        return "\(battery.powerSource) · \(battery.isCharging ? "正在充电" : (battery.isPluggedIn ? "已接通电源" : "电池供电"))"
    }

    private func severity(for battery: BatterySnapshot) -> DetailSeverity {
        if battery.percentage <= 20 { return .critical }
        if battery.percentage <= 40 { return .warning }
        return .normal
    }

    private func color(for battery: BatterySnapshot) -> Color {
        switch severity(for: battery) {
        case .warning: return Palette.warning
        case .critical: return Palette.danger
        default: return Palette.battery
        }
    }

    private func statusText(for battery: BatterySnapshot) -> String {
        if battery.isCharging { return "正在充电" }
        if battery.isPluggedIn { return "已接通电源" }
        if let minutes = battery.timeRemainingMinutes {
            let hours = minutes / 60
            let remaining = minutes % 60
            return hours > 0 ? "剩余 \(hours) 小时 \(remaining) 分" : "剩余 \(remaining) 分"
        }
        return "使用电池"
    }

    private func remainingText(for battery: BatterySnapshot) -> String {
        guard let minutes = battery.timeRemainingMinutes else { return "--" }
        let hours = minutes / 60
        let remaining = minutes % 60
        return hours > 0 ? "\(hours) 小时 \(remaining) 分" : "\(remaining) 分"
    }
}

// MARK: - System

private struct SystemDetailPage: View {
    let state: MetricsState
    let hardware: HardwareInfo
    let detailed: Bool

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        MetricPage(
            category: .system,
            subtitle: "\(hardware.chipName) · \(hardware.osVersion)",
            sampledAt: state.snapshot.sampledAt
        ) {
            DetailSurface {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(MetricFormat.uptime(state.snapshot.uptime))
                            .font(.metric(42, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text("已运行")
                            .font(.label(10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 8)
                        StatusPill(text: "只读采样", color: Palette.network)
                    }

                    LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 16) {
                        MetricFact(label: "芯片", value: hardware.chipName)
                        MetricFact(label: "系统", value: hardware.osVersion)
                        MetricFact(label: "逻辑核心", value: "\(hardware.logicalCoreCount)")
                        MetricFact(label: "统一内存", value: MetricFormat.memory(hardware.totalMemoryBytes))
                        MetricFact(label: "历史窗口", value: historyText)
                        MetricFact(label: "采样间隔", value: "每 \(intervalText(state.samplingInterval)) 秒")
                    }
                }
            }

            if detailed {
                DetailSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        SurfaceTitle(title: "运行信息", note: "无第三方依赖")
                        LazyVGrid(columns: metricColumns, alignment: .leading, spacing: 16) {
                            MetricFact(label: "应用版本", value: "\(version) (\(build))")
                            MetricFact(label: "数据来源", value: "SMC / IOKit")
                            MetricFact(label: "进程采样", value: state.isDetailed ? "已开启" : "按需开启")
                            MetricFact(label: "历史采样", value: "\(state.history.cpu.count) 个")
                            MetricFact(
                                label: "采样策略",
                                value: state.snapshot.processSampled ? "指标 + 进程" : "仅指标"
                            )
                            MetricFact(label: "页面渲染", value: "单页按需")
                        }
                        Text("关闭详情窗口后会释放全部页面与图表，进程采样同时停止。")
                            .font(.label(9))
                            .foregroundStyle(.quaternary)
                    }
                }
            }
        }
    }

    private var historyText: String {
        guard state.history.timestamps.count > 1,
              let first = state.history.timestamps.first,
              let last = state.history.timestamps.last else {
            return "等待历史数据"
        }
        let seconds = max(0, last.timeIntervalSince(first))
        if seconds >= 120 {
            return "最近 \(Int((seconds / 60).rounded())) 分钟"
        }
        return "最近 \(Int(seconds.rounded())) 秒"
    }
}

// MARK: - Helpers

private func intervalText(_ interval: TimeInterval) -> String {
    interval < 1 ? String(format: "%.1f", interval) : String(format: "%.0f", interval)
}
