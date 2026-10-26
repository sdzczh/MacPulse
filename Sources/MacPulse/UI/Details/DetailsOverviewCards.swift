import SwiftUI
import MacPulseCore

struct DetailsOverviewView: View {
    let state: MetricsState
    let hardware: HardwareInfo
    let settings: AppSettings
    let density: DetailDensity
    let onQuit: () -> Void

    private var detailed: Bool { density == .detailed }
    private var snapshot: SystemSnapshot { state.snapshot }
    private var history: MetricsHistory { state.history }
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    private var historyWindowText: String {
        guard history.timestamps.count > 1,
              let first = history.timestamps.first,
              let last = history.timestamps.last else {
            return "等待历史数据"
        }
        let seconds = max(0, last.timeIntervalSince(first))
        if seconds >= 120 {
            return "最近 \(Int((seconds / 60).rounded())) 分钟"
        }
        return "最近 \(Int(seconds.rounded())) 秒"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                if let error = state.lastError {
                    errorBanner(error)
                }

                HStack(alignment: .top, spacing: 12) {
                    CPUPanel(
                        snapshot: snapshot,
                        hardware: hardware,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    MemoryPanel(
                        snapshot: snapshot,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    GPUPanel(
                        snapshot: snapshot,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: detailed ? 324 : 214)

                HStack(alignment: .top, spacing: 12) {
                    NetworkPanel(
                        snapshot: snapshot,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    DiskPanel(
                        snapshot: snapshot,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    ThermalPanel(
                        snapshot: snapshot,
                        unit: settings.temperatureUnit,
                        history: history,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: detailed ? 296 : 196)

                HStack(alignment: .top, spacing: 12) {
                    if !snapshot.fans.isEmpty {
                        FanPanel(
                            snapshot: snapshot,
                            history: history,
                            detailed: detailed
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    if let battery = snapshot.battery {
                        BatteryPanel(
                            battery: battery,
                            detailed: detailed
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    SystemPanel(
                        snapshot: snapshot,
                        hardware: hardware,
                        state: state,
                        historyWindowText: historyWindowText,
                        detailed: detailed
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: detailed ? 240 : 194)

                footer
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(message)
                .font(.label(10))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.warning)
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.warning.opacity(0.11))
        }
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Palette.network)
                .frame(width: 4.5, height: 4.5)
            Text("历史 \(historyWindowText) · \(history.cpu.count) 个采样")
            Text("·")
            Text("SMC / IOKit 只读")
            Text("·")
            Text("每 \(formattedInterval(state.samplingInterval)) 秒刷新")
            Spacer(minLength: 4)
            Text("MacPulse \(version)")
            Button("退出", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.label(8.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 2)
        .padding(.top, 2)
    }

    private func formattedInterval(_ interval: TimeInterval) -> String {
        interval < 1 ? String(format: "%.1f", interval) : String(format: "%.0f", interval)
    }
}

// MARK: - CPU

private struct CPUPanel: View {
    let snapshot: SystemSnapshot
    let hardware: HardwareInfo
    let history: MetricsHistory
    let detailed: Bool

    private var cpu: CPUSnapshot { snapshot.cpu }
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
        DetailCard(
            title: "处理器",
            icon: "cpu",
            accent: Palette.cpu,
            severity: severity,
            note: coreSubtitle,
            emphasized: true
        ) {
            HStack(alignment: .center, spacing: 14) {
                DetailGaugeView(
                    fraction: cpu.totalUsage,
                    text: MetricFormat.percent(cpu.totalUsage),
                    color: Palette.cpu,
                    diameter: detailed ? 82 : 62,
                    textSize: detailed ? 20 : 16
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("整体占用")
                        .font(.label(11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(loadSummary)
                        .font(.mono(9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                    Text(coreSubtitle)
                        .font(.label(8.5))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            DetailSparklineView(
                values: history.cpu,
                timestamps: history.timestamps,
                color: Palette.cpu,
                fixedRange: 0...1,
                height: detailed ? 44 : 26,
                formatter: { MetricFormat.percent($0) },
                allowsHover: detailed
            )

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 8) {
                        HStack(spacing: 0) {
                            LoadStat(title: "1 分", value: cpu.load1)
                            Spacer(minLength: 8)
                            LoadStat(title: "5 分", value: cpu.load5)
                            Spacer(minLength: 8)
                            LoadStat(title: "15 分", value: cpu.load15)
                        }
                        DetailCoreBarsView(
                            usages: cpu.coreUsages,
                            efficiencyCoreCount: hardware.efficiencyCoreCount,
                            color: Palette.cpu
                        )
                    }
                }
            }
        }
    }

    private var loadSummary: String {
        String(format: "负载 %.2f / %.2f / %.2f", cpu.load1, cpu.load5, cpu.load15)
    }
}

private struct LoadStat: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.label(8))
                .foregroundStyle(.quaternary)
            Text(String(format: "%.2f", value.isFinite ? value : 0))
                .font(.mono(10.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Memory

private struct MemoryPanel: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory
    let detailed: Bool

    private var memory: MemorySnapshot { snapshot.memory }

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

    private var usedText: String {
        "已用 \(MetricFormat.memory(memory.usedBytes)) / \(MetricFormat.memory(memory.totalBytes))"
    }

    private var swapText: String {
        guard memory.swapTotalBytes > 0 else { return "0 B" }
        return "\(MetricFormat.memory(memory.swapUsedBytes)) / \(MetricFormat.memory(memory.swapTotalBytes))"
    }

    var body: some View {
        DetailCard(
            title: "内存",
            icon: "memorychip",
            accent: Palette.memory,
            severity: severity,
            note: "压力 \(memory.pressure.rawValue)"
        ) {
            HStack(alignment: .center, spacing: 14) {
                DetailGaugeView(
                    fraction: memory.usedFraction,
                    text: MetricFormat.percent(memory.usedFraction),
                    color: gaugeColor,
                    diameter: detailed ? 82 : 62,
                    textSize: detailed ? 20 : 16
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(usedText)
                        .font(.label(9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text("可用 \(MetricFormat.memory(memory.availableBytes))")
                        .font(.mono(9))
                        .foregroundStyle(.tertiary)
                    if !detailed {
                        Text("交换 \(swapText)")
                            .font(.mono(8.5))
                            .foregroundStyle(.quaternary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }

            DetailSparklineView(
                values: history.memoryUsed,
                timestamps: history.timestamps,
                color: Palette.memory,
                fixedRange: 0...Double(max(memory.totalBytes, 1)),
                height: detailed ? 44 : 26,
                formatter: { MetricFormat.memory(UInt64(max(0, $0))) },
                allowsHover: detailed
            )

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "活跃", value: MetricFormat.memory(memory.activeBytes))
                        DetailStatRow(label: "常驻", value: MetricFormat.memory(memory.wiredBytes))
                        DetailStatRow(label: "压缩", value: MetricFormat.memory(memory.compressedBytes))
                        DetailStatRow(label: "缓存", value: MetricFormat.memory(memory.cachedBytes))
                        DetailStatRow(label: "交换", value: swapText)
                    }
                }
            }
        }
    }
}

// MARK: - GPU

private struct GPUPanel: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory
    let detailed: Bool

    private var gpu: GPUSnapshot? { snapshot.gpu }

    private var severity: DetailSeverity {
        guard let gpu else { return .neutral }
        return DetailSeverity.level(gpu.utilization, warning: 0.7, critical: 0.9)
    }

    private var allocationFraction: Double {
        guard let gpu, gpu.allocatedMemoryBytes > 0 else { return 0 }
        return Double(gpu.inUseMemoryBytes) / Double(gpu.allocatedMemoryBytes)
    }

    var body: some View {
        DetailCard(
            title: "图形处理器",
            icon: "display",
            accent: Palette.gpu,
            severity: severity,
            note: gpu == nil ? "不可用" : "统一内存"
        ) {
            HStack(alignment: .center, spacing: 14) {
                DetailGaugeView(
                    fraction: gpu?.utilization ?? 0,
                    text: gpu == nil ? "--" : MetricFormat.percent(gpu?.utilization ?? 0),
                    color: Palette.gpu,
                    diameter: detailed ? 82 : 62,
                    textSize: detailed ? 20 : 16
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(gpu == nil ? "未检测到 GPU 统计" : "整体利用率")
                        .font(.label(10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if let gpu {
                        Text("分配 \(MetricFormat.memory(gpu.allocatedMemoryBytes))")
                            .font(.mono(9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 0)
            }

            DetailSparklineView(
                values: history.gpu,
                timestamps: history.timestamps,
                color: Palette.gpu,
                fixedRange: 0...1,
                height: detailed ? 44 : 26,
                formatter: { MetricFormat.percent($0) },
                allowsHover: detailed
            )

            if detailed, let gpu {
                DetailStatGroup {
                    VStack(spacing: 6) {
                        UsageBar(fraction: allocationFraction, color: Palette.gpu, height: 4)
                        DetailStatRow(label: "显存占用", value: MetricFormat.memory(gpu.inUseMemoryBytes))
                        DetailStatRow(label: "已分配", value: MetricFormat.memory(gpu.allocatedMemoryBytes))
                    }
                }
            }
        }
    }
}

// MARK: - Network

private struct NetworkPanel: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory
    let detailed: Bool

    private var network: NetworkSnapshot { snapshot.network }

    private var interfaceText: String {
        guard !network.activeInterfaces.isEmpty else { return "无活动接口" }
        return network.activeInterfaces.prefix(2).joined(separator: " · ")
    }

    var body: some View {
        DetailCard(
            title: "网络",
            icon: "arrow.up.arrow.down",
            accent: Palette.network,
            severity: .normal,
            note: interfaceText
        ) {
            HStack(alignment: .top, spacing: 14) {
                DetailRateStat(
                    title: "下载",
                    value: MetricFormat.rate(network.downloadBytesPerSecond),
                    color: Palette.network,
                    icon: "arrow.down"
                )
                Spacer(minLength: 4)
                DetailRateStat(
                    title: "上传",
                    value: MetricFormat.rate(network.uploadBytesPerSecond),
                    color: Palette.upload,
                    icon: "arrow.up"
                )
            }

            DetailSparklineView(
                values: history.download,
                timestamps: history.timestamps,
                color: Palette.network,
                secondaryValues: history.upload,
                secondaryColor: Palette.upload,
                secondaryLabel: "上传",
                minimumSpan: 1024,
                height: detailed ? 42 : 28,
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

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "活动接口", value: interfaceText)
                        DetailStatRow(label: "本次接收", value: MetricFormat.memory(network.totalReceivedBytes))
                        DetailStatRow(label: "本次发送", value: MetricFormat.memory(network.totalSentBytes))
                    }
                }
            }
        }
    }
}

// MARK: - Disk

private struct DiskPanel: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory
    let detailed: Bool

    private var disk: DiskSnapshot { snapshot.disk }

    private var severity: DetailSeverity {
        DetailSeverity.level(disk.usedFraction, warning: 0.82, critical: 0.93)
    }

    var body: some View {
        DetailCard(
            title: "存储",
            icon: "internaldrive",
            accent: Palette.disk,
            severity: severity,
            note: "启动磁盘"
        ) {
            HStack(alignment: .center, spacing: 14) {
                DetailGaugeView(
                    fraction: disk.usedFraction,
                    text: MetricFormat.percent(disk.usedFraction),
                    color: Palette.disk,
                    diameter: detailed ? 82 : 62,
                    textSize: detailed ? 20 : 16
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text("已用 \(MetricFormat.memory(disk.usedBytes))")
                        .font(.label(9.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("可用 \(MetricFormat.memory(disk.freeBytes)) / \(MetricFormat.memory(disk.totalBytes))")
                        .font(.mono(8.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            DetailSparklineView(
                values: history.diskRead,
                timestamps: history.timestamps,
                color: Palette.disk,
                secondaryValues: history.diskWrite,
                secondaryColor: Palette.upload,
                secondaryLabel: "写入",
                minimumSpan: 1024,
                height: detailed ? 42 : 26,
                formatter: { MetricFormat.rate($0) },
                allowsHover: detailed
            )

            HStack(spacing: 12) {
                DetailLegendDot(color: Palette.disk, label: "读取")
                DetailLegendDot(color: Palette.upload, label: "写入")
                Spacer(minLength: 0)
            }

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "读取", value: MetricFormat.rate(disk.readBytesPerSecond))
                        DetailStatRow(label: "写入", value: MetricFormat.rate(disk.writeBytesPerSecond))
                        DetailStatRow(label: "总容量", value: MetricFormat.memory(disk.totalBytes))
                    }
                }
            }
        }
    }
}

// MARK: - Thermal

private struct ThermalPanel: View {
    let snapshot: SystemSnapshot
    let unit: TemperatureUnit
    let history: MetricsHistory
    let detailed: Bool

    private var thermal: ThermalSnapshot { snapshot.thermal }

    private var severity: DetailSeverity {
        switch thermal.thermalState {
        case "正常": return .normal
        case "偏高": return .warning
        case "过热", "临界": return .critical
        default: return .neutral
        }
    }

    private var historyFormatter: (Double) -> String {
        { value in
            let converted = unit.convert(celsius: value)
            return String(format: "%.0f°", converted)
        }
    }

    var body: some View {
        DetailCard(
            title: "温度",
            icon: "thermometer.medium",
            accent: Palette.thermal,
            severity: severity,
            note: "\(thermal.sensorCount) 个传感器"
        ) {
            HStack(alignment: .top, spacing: 18) {
                TemperatureCell(
                    title: "CPU 平均",
                    celsius: thermal.cpuAverageCelsius,
                    peak: thermal.cpuMaxCelsius,
                    color: Palette.thermal,
                    unit: unit
                )
                TemperatureCell(
                    title: "GPU 平均",
                    celsius: thermal.gpuAverageCelsius,
                    peak: thermal.gpuMaxCelsius,
                    color: Palette.gpu,
                    unit: unit
                )
                Spacer(minLength: 0)
                StatusPill(text: thermal.thermalState, color: severity.color)
            }

            DetailSparklineView(
                values: history.cpuTemperature,
                timestamps: history.timestamps,
                color: Palette.thermal,
                includesZero: false,
                minimumSpan: 10,
                height: detailed ? 42 : 26,
                formatter: historyFormatter,
                allowsHover: detailed
            )

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "CPU 峰值", value: unit.string(celsius: thermal.cpuMaxCelsius))
                        DetailStatRow(label: "GPU 峰值", value: unit.string(celsius: thermal.gpuMaxCelsius))
                        DetailStatRow(label: "风扇", value: "\(snapshot.fans.count) 个")
                    }
                }
            }
        }
    }
}

private struct TemperatureCell: View {
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
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.label(8.5))
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.metric(24, weight: .bold))
                    .foregroundStyle(celsius == nil ? .secondary : .primary)
                Text(unit == .celsius ? "°C" : "°F")
                    .font(.label(8.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Text(peak.map { "峰值 \(unit.string(celsius: $0))" } ?? "峰值 --")
                .font(.mono(8))
                .foregroundStyle(.quaternary)
                .lineLimit(1)
        }
    }
}

// MARK: - Fans

private struct FanPanel: View {
    let snapshot: SystemSnapshot
    let history: MetricsHistory
    let detailed: Bool

    var body: some View {
        DetailCard(
            title: "风扇",
            icon: "fanblades",
            accent: Palette.fan,
            severity: .normal,
            note: "\(snapshot.fans.count) 个风扇"
        ) {
            VStack(spacing: 10) {
                ForEach(Array(snapshot.fans.prefix(2))) { fan in
                    FanDetailRow(fan: fan)
                }
                if snapshot.fans.count > 2 {
                    Text("另有 \(snapshot.fans.count - 2) 个风扇")
                        .font(.label(9))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if detailed {
                DetailStatGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("转速趋势")
                                .font(.label(8.5))
                                .foregroundStyle(.tertiary)
                            Spacer(minLength: 0)
                            Text("RPM")
                                .font(.mono(7.5))
                                .foregroundStyle(.quaternary)
                        }
                        DetailSparklineView(
                            values: history.fan,
                            timestamps: history.timestamps,
                            color: Palette.fan,
                            minimumSpan: 1000,
                            height: 28,
                            formatter: { MetricFormat.rpm($0) },
                            allowsHover: false
                        )
                    }
                }
            }
        }
    }
}

private struct FanDetailRow: View {
    let fan: FanReading

    private var stopped: Bool { fan.rpm < 1 }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "fanblades")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.fan)
                Text(fan.name)
                    .font(.label(10.5, weight: .medium))
                Text(stopped ? "停转" : "\(Int(fan.fraction * 100))%")
                    .font(.mono(8.5))
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 4)
                Text(MetricFormat.rpm(fan.rpm))
                    .font(.metric(17, weight: .semibold))
                Text("RPM")
                    .font(.label(8))
                    .foregroundStyle(.tertiary)
            }

            UsageBar(fraction: fan.fraction, color: Palette.fan, height: 4)

            HStack {
                Text("\(MetricFormat.rpm(fan.minRPM)) – \(MetricFormat.rpm(fan.maxRPM)) RPM")
                Spacer(minLength: 4)
                Text(stopped ? "低于启动转速" : "自动调速")
            }
            .font(.mono(8))
            .foregroundStyle(.quaternary)
        }
    }
}

// MARK: - Battery

private struct BatteryPanel: View {
    let battery: BatterySnapshot
    let detailed: Bool

    private var severity: DetailSeverity {
        if battery.percentage <= 20 { return .critical }
        if battery.percentage <= 40 { return .warning }
        return .normal
    }

    private var color: Color {
        switch severity {
        case .warning: return Palette.warning
        case .critical: return Palette.danger
        default: return Palette.battery
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

    var body: some View {
        DetailCard(
            title: "电池",
            icon: "battery.100",
            accent: Palette.battery,
            severity: severity,
            note: battery.healthPercent.map { "健康 \(String(format: "%.0f%%", $0))" }
        ) {
            HStack(alignment: .center, spacing: 14) {
                DetailGaugeView(
                    fraction: Double(battery.percentage) / 100,
                    text: "\(battery.percentage)%",
                    color: color,
                    diameter: detailed ? 66 : 58,
                    textSize: detailed ? 15 : 13
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        if battery.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Palette.battery)
                        }
                        Text(statusText)
                            .font(.label(10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Text(battery.isPluggedIn ? "已接电源" : "电池供电")
                        .font(.mono(8.5))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "循环次数", value: battery.cycleCount.map { "\($0) 次" } ?? "--")
                        DetailStatRow(
                            label: "健康度",
                            value: battery.healthPercent.map { String(format: "%.0f%%", $0) } ?? "--"
                        )
                        DetailStatRow(label: "状态", value: statusText)
                    }
                }
            }
        }
    }
}

// MARK: - System

private struct SystemPanel: View {
    let snapshot: SystemSnapshot
    let hardware: HardwareInfo
    let state: MetricsState
    let historyWindowText: String
    let detailed: Bool

    var body: some View {
        DetailCard(
            title: "系统",
            icon: "info.circle",
            accent: Palette.cached,
            severity: .normal,
            note: "只读采样"
        ) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MetricFormat.uptime(snapshot.uptime))
                    .font(.metric(22, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("已运行")
                    .font(.label(8.5))
                    .foregroundStyle(.tertiary)
            }

            if detailed {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "芯片", value: hardware.chipName)
                        DetailStatRow(label: "系统", value: hardware.osVersion)
                        DetailStatRow(label: "历史窗口", value: "\(historyWindowText) · \(state.history.cpu.count) 采样")
                        DetailStatRow(
                            label: "刷新",
                            value: "每 \(state.samplingInterval < 1 ? String(format: "%.1f", state.samplingInterval) : String(format: "%.0f", state.samplingInterval)) 秒"
                        )
                    }
                }
            } else {
                DetailStatGroup {
                    VStack(spacing: 2) {
                        DetailStatRow(label: "芯片", value: hardware.chipName)
                        DetailStatRow(label: "历史", value: historyWindowText)
                    }
                }
            }
        }
    }
}
