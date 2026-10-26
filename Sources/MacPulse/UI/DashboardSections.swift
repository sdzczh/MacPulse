import SwiftUI
import MacPulseCore

struct CPUCardView: View {
    let snapshot: SystemSnapshot
    let hardware: HardwareInfo
    let history: MetricsHistory

    private var subtitle: String {
        let performance = hardware.performanceCoreCount
        let efficiency = hardware.efficiencyCoreCount
        if performance + efficiency > 0 {
            return "\(hardware.logicalCoreCount) 核 · \(performance)P + \(efficiency)E"
        }
        return "\(hardware.logicalCoreCount) 核"
    }

    var body: some View {
        DashboardCard("处理器", systemImage: "cpu", accent: Palette.cpu, subtitle: subtitle) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    MetricValue(
                        value: String(format: "%.0f", snapshot.cpu.totalUsage * 100),
                        unit: "%",
                        size: 30,
                        color: Palette.cpu
                    )
                    Text("整体占用")
                        .font(.label(9.5))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                HStack(alignment: .bottom, spacing: 10) {
                    LoadCell(title: "1 分", value: snapshot.cpu.load1)
                    LoadCell(title: "5 分", value: snapshot.cpu.load5)
                    LoadCell(title: "15 分", value: snapshot.cpu.load15)
                }
            }

            SparklineView(values: history.cpu, color: Palette.cpu, upperBound: 1, height: 38)

            CoreBarsView(
                usages: snapshot.cpu.coreUsages,
                efficiencyCoreCount: hardware.efficiencyCoreCount,
                color: Palette.cpu
            )
        }
    }
}

private struct LoadCell: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(String(format: "%.2f", value.isFinite ? value : 0))
                .font(.mono(10.5, weight: .medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.label(8))
                .foregroundStyle(.tertiary)
        }
    }
}

struct MemoryCardView: View {
    let snapshot: SystemSnapshot

    private var memory: MemorySnapshot { snapshot.memory }

    private var pressureColor: Color {
        switch memory.pressure {
        case .normal: return Palette.network
        case .warning: return Palette.warning
        case .critical: return Palette.danger
        case .unknown: return .secondary
        }
    }

    private var segments: [MemorySegment] {
        let total = Double(max(1, memory.totalBytes))
        let active = Double(memory.activeBytes) / total
        let wired = Double(memory.wiredBytes) / total
        let compressed = Double(memory.compressedBytes) / total
        let cached = Double(memory.cachedBytes) / total
        let free = max(0, 1 - active - wired - compressed - cached)
        return [
            MemorySegment(fraction: active, color: Palette.memory),
            MemorySegment(fraction: wired, color: Palette.wired),
            MemorySegment(fraction: compressed, color: Palette.compressed),
            MemorySegment(fraction: cached, color: Palette.cached),
            MemorySegment(fraction: free, color: Color.primary.opacity(0.035))
        ]
    }

    private var swapText: String {
        guard memory.swapTotalBytes > 0 else { return "交换未使用" }
        return "交换 \(MetricFormat.memory(memory.swapUsedBytes)) / \(MetricFormat.memory(memory.swapTotalBytes))"
    }

    var body: some View {
        DashboardCard(
            "内存",
            systemImage: "memorychip",
            accent: Palette.memory,
            subtitle: "共 \(MetricFormat.memory(memory.totalBytes))"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                MetricValue(
                    value: String(format: "%.1f", MetricFormat.memoryGB(memory.usedBytes)),
                    unit: "GB",
                    size: 30,
                    color: Palette.memory
                )
                Text("已用 \(MetricFormat.percent(memory.usedFraction))")
                    .font(.label(9.5))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                StatusPill(text: "压力 \(memory.pressure.rawValue)", color: pressureColor)
            }

            SegmentedBar(segments: segments)

            HStack(spacing: 0) {
                LegendDot(color: Palette.memory, label: "活跃", value: MetricFormat.memoryCompact(memory.activeBytes))
                Spacer(minLength: 6)
                LegendDot(color: Palette.wired, label: "常驻", value: MetricFormat.memoryCompact(memory.wiredBytes))
                Spacer(minLength: 6)
                LegendDot(color: Palette.compressed, label: "压缩", value: MetricFormat.memoryCompact(memory.compressedBytes))
                Spacer(minLength: 6)
                LegendDot(color: Palette.cached, label: "缓存", value: MetricFormat.memoryCompact(memory.cachedBytes))
            }

            HStack(spacing: 8) {
                Text(swapText)
                Spacer(minLength: 4)
                Text("可用 \(MetricFormat.memory(memory.availableBytes))")
            }
            .font(.mono(8.5))
            .foregroundStyle(.tertiary)
        }
    }
}

struct ThermalCardView: View {
    let snapshot: SystemSnapshot
    let unit: TemperatureUnit

    private var thermal: ThermalSnapshot { snapshot.thermal }

    private var stateColor: Color {
        switch thermal.thermalState {
        case "正常": return Palette.network
        case "偏高": return Palette.warning
        case "过热", "临界": return Palette.danger
        default: return .secondary
        }
    }

    var body: some View {
        DashboardCard(
            "温度与风扇",
            systemImage: "thermometer.medium",
            accent: Palette.thermal,
            subtitle: "\(thermal.sensorCount) 个传感器"
        ) {
            HStack(alignment: .top, spacing: 12) {
                ThermalValueView(
                    title: "CPU 平均",
                    celsius: thermal.cpuAverageCelsius,
                    peak: thermal.cpuMaxCelsius,
                    color: Palette.thermal,
                    unit: unit
                )

                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 1, height: 42)

                ThermalValueView(
                    title: "GPU 平均",
                    celsius: thermal.gpuAverageCelsius,
                    peak: thermal.gpuMaxCelsius,
                    color: Palette.gpu,
                    unit: unit
                )

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    StatusPill(text: thermal.thermalState, color: stateColor, systemImage: "thermometer")
                    Text("系统热状态")
                        .font(.label(8.5))
                        .foregroundStyle(.tertiary)
                }
            }

            if snapshot.fans.isEmpty {
                Hairline()
                Text("当前机型未提供风扇数据")
                    .font(.label(10))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                Hairline()
                VStack(spacing: 9) {
                    ForEach(snapshot.fans) { fan in
                        FanRowView(fan: fan)
                    }
                }
            }
        }
    }
}

private struct ThermalValueView: View {
    let title: String
    let celsius: Double?
    let peak: Double?
    let color: Color
    let unit: TemperatureUnit

    private var display: String {
        guard let celsius else { return "--" }
        return String(format: "%.0f", unit.convert(celsius: celsius))
    }

    private var peakText: String {
        guard let peak else { return "峰值 --" }
        return "峰值 \(unit.string(celsius: peak))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.label(8.5))
                .foregroundStyle(.tertiary)
            MetricValue(value: display, unit: unit.shortSymbol, size: 25, color: celsius == nil ? .secondary : color)
            Text(peakText)
                .font(.mono(8.5))
                .foregroundStyle(.tertiary)
        }
    }
}

struct GPUAndBatteryRow: View {
    let snapshot: SystemSnapshot

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            GPUCardView(gpu: snapshot.gpu)
                .frame(maxWidth: .infinity)

            if let battery = snapshot.battery {
                BatteryCardView(battery: battery)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct GPUCardView: View {
    let gpu: GPUSnapshot?

    var body: some View {
        DashboardCard(
            "GPU",
            systemImage: "display",
            accent: Palette.gpu,
            subtitle: gpu == nil ? "不可用" : nil
        ) {
            MetricValue(
                value: gpu == nil ? "--" : String(format: "%.0f", (gpu?.utilization ?? 0) * 100),
                unit: "%",
                size: 26,
                color: Palette.gpu
            )
            UsageBar(fraction: gpu?.utilization ?? 0, color: Palette.gpu, height: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("显存 \(MetricFormat.memory(gpu?.inUseMemoryBytes ?? 0))")
                Text("分配 \(MetricFormat.memory(gpu?.allocatedMemoryBytes ?? 0))")
            }
            .font(.mono(8.5))
            .foregroundStyle(.tertiary)
        }
    }
}

struct BatteryCardView: View {
    let battery: BatterySnapshot

    private var color: Color {
        if battery.isCharging { return Palette.battery }
        if battery.percentage <= 20 { return Palette.danger }
        if battery.percentage <= 40 { return Palette.warning }
        return Palette.battery
    }

    var body: some View {
        DashboardCard(
            "电池",
            systemImage: "battery.100",
            accent: Palette.battery,
            subtitle: battery.isPluggedIn ? "已接电源" : nil
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MetricValue(value: "\(battery.percentage)", unit: "%", size: 26, color: color)
                if battery.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Palette.battery)
                }
                Spacer(minLength: 0)
            }
            UsageBar(fraction: Double(battery.percentage) / 100, color: color, height: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(statusText)
                Text(detailText)
            }
            .font(.mono(8.5))
            .foregroundStyle(.tertiary)
        }
    }

    private var statusText: String {
        if battery.isCharging { return "正在充电" }
        if battery.isPluggedIn { return "已接通电源" }
        if let minutes = battery.timeRemainingMinutes {
            let hours = minutes / 60
            let remaining = minutes % 60
            return hours > 0 ? "剩余 \(hours) 小时 \(remaining) 分" : "剩余 \(remaining) 分"
        }
        return "使用电池"
    }

    private var detailText: String {
        var parts: [String] = []
        if let cycles = battery.cycleCount {
            parts.append("循环 \(cycles) 次")
        }
        if let health = battery.healthPercent {
            parts.append("健康 \(String(format: "%.0f%%", health))")
        }
        return parts.isEmpty ? "电池信息不可用" : parts.joined(separator: " · ")
    }
}

struct NetworkDiskRow: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            NetworkCardView(network: snapshot.network, history: history)
                .frame(maxWidth: .infinity)
            DiskCardView(disk: snapshot.disk)
                .frame(maxWidth: .infinity)
        }
    }
}

struct NetworkCardView: View {
    let network: NetworkSnapshot
    let history: MetricsHistory

    private var interfaceText: String? {
        guard !network.activeInterfaces.isEmpty else { return nil }
        return network.activeInterfaces.prefix(2).joined(separator: " · ")
    }

    var body: some View {
        DashboardCard(
            "网络",
            systemImage: "arrow.up.arrow.down",
            accent: Palette.network,
            subtitle: interfaceText ?? "无活动接口"
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                RateCell(
                    symbol: "arrow.down",
                    title: "下载",
                    value: MetricFormat.rateCompact(network.downloadBytesPerSecond),
                    color: Palette.network
                )
                Spacer(minLength: 0)
                RateCell(
                    symbol: "arrow.up",
                    title: "上传",
                    value: MetricFormat.rateCompact(network.uploadBytesPerSecond),
                    color: Palette.upload
                )
            }

            SparklineView(
                values: history.download,
                color: Palette.network,
                height: 16,
                showsGrid: false
            )

            Text("本次 ↓ \(MetricFormat.memory(network.totalReceivedBytes))  ↑ \(MetricFormat.memory(network.totalSentBytes))")
                .font(.mono(8))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

struct DiskCardView: View {
    let disk: DiskSnapshot

    var body: some View {
        DashboardCard(
            "存储",
            systemImage: "internaldrive",
            accent: Palette.disk,
            subtitle: MetricFormat.memory(disk.totalBytes)
        ) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                MetricValue(
                    value: String(format: "%.0f", disk.usedFraction * 100),
                    unit: "%",
                    size: 26,
                    color: Palette.disk
                )
                Spacer(minLength: 0)
                Text(MetricFormat.memory(disk.usedBytes))
                    .font(.mono(8.5))
                    .foregroundStyle(.tertiary)
            }
            UsageBar(fraction: disk.usedFraction, color: Palette.disk, height: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text("可用 \(MetricFormat.memory(disk.freeBytes))")
                Text("读 \(MetricFormat.rate(disk.readBytesPerSecond)) · 写 \(MetricFormat.rate(disk.writeBytesPerSecond))")
            }
            .font(.mono(8))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
    }
}

private struct RateCell: View {
    let symbol: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.metric(16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("B/s")
                    .font(.label(8, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(title)
                .font(.label(8))
                .foregroundStyle(.tertiary)
        }
    }
}

struct ProcessesCardView: View {
    let processes: [ProcessReading]
    let isDetailed: Bool

    var body: some View {
        DashboardCard(
            "进程",
            systemImage: "list.bullet",
            accent: Palette.memory,
            subtitle: isDetailed ? "CPU Top 8 · 每 3 秒" : "打开面板时采样"
        ) {
            HStack(spacing: 8) {
                Color.clear.frame(width: 17, height: 1)
                Text("进程")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("CPU")
                    .frame(width: 46, alignment: .trailing)
                Text("内存")
                    .frame(width: 48, alignment: .trailing)
            }
            .font(.label(8.5, weight: .medium))
            .foregroundStyle(.tertiary)

            if processes.isEmpty {
                HStack(spacing: 8) {
                    if isDetailed {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在采集进程数据…")
                    } else {
                        Image(systemName: "pause.circle")
                        Text("打开面板后开始采样")
                    }
                }
                .font(.label(10))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(processes.prefix(8).enumerated()), id: \.element.id) { index, process in
                        ProcessRowView(process: process)
                        if index < min(8, processes.count) - 1 {
                            Hairline()
                                .opacity(0.7)
                        }
                    }
                }
            }
        }
    }
}

private struct ProcessRowView: View {
    let process: ProcessReading

    private var cpuColor: Color {
        if process.cpuLoad >= 1 { return Palette.danger }
        if process.cpuLoad >= 0.4 { return Palette.cpu }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 8) {
            ProcessIconView(process: process)
            Text(process.name)
                .font(.label(11))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(String(format: "%.1f%%", process.cpuLoad * 100))
                .font(.mono(10, weight: .medium))
                .foregroundStyle(cpuColor)
                .frame(width: 46, alignment: .trailing)

            Text(MetricFormat.memoryCompact(process.memoryBytes))
                .font(.mono(10))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 22)
        .help("\(process.name) · PID \(process.pid)\nCPU \(String(format: "%.1f%%", process.cpuLoad * 100)) · 内存 \(MetricFormat.memory(process.memoryBytes))")
    }
}
