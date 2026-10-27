import SwiftUI
import MacPulseCore

enum DetailCategory: String, CaseIterable, Identifiable {
    case cpu = "处理器"
    case memory = "内存"
    case gpu = "图形处理器"
    case network = "网络"
    case disk = "存储"
    case thermal = "温度"
    case fan = "风扇"
    case battery = "电池"
    case system = "系统"
    case processes = "进程"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "display"
        case .network: return "arrow.up.arrow.down"
        case .disk: return "internaldrive"
        case .thermal: return "thermometer.medium"
        case .fan: return "fanblades"
        case .battery: return "battery.100"
        case .system: return "info.circle"
        case .processes: return "list.bullet.rectangle"
        }
    }

    var accent: Color {
        switch self {
        case .cpu: return Palette.cpu
        case .memory: return Palette.memory
        case .gpu: return Palette.gpu
        case .network: return Palette.network
        case .disk: return Palette.disk
        case .thermal: return Palette.thermal
        case .fan: return Palette.fan
        case .battery: return Palette.battery
        case .system: return Palette.upload
        case .processes: return Palette.memory
        }
    }
}

enum DetailDensity: String, CaseIterable, Identifiable {
    case detailed = "详细"
    case compact = "紧凑"

    var id: String { rawValue }
}

struct DetailsDashboardView: View {
    @ObservedObject var engine: MetricsEngine
    @ObservedObject var settings: AppSettings
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @State private var category: DetailCategory = .cpu
    @State private var density: DetailDensity = .detailed

    private var state: MetricsState { engine.state }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .underWindowBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Palette.cpu.opacity(0.055),
                    Color.clear,
                    Palette.memory.opacity(0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Hairline()
                    .opacity(0.8)

                HStack(spacing: 0) {
                    DetailSidebar(
                        selection: $category,
                        snapshot: state.snapshot,
                        unit: settings.temperatureUnit
                    )

                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 1)

                    VStack(spacing: 0) {
                        if let error = state.lastError {
                            errorBanner(error)
                                .padding(.horizontal, 24)
                                .padding(.top, 12)
                        }

                        DetailsCategoryView(
                            category: category,
                            state: state,
                            hardware: engine.hardware,
                            settings: settings,
                            density: density
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Hairline()
                        footer
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var header: some View {
        HStack(spacing: 14) {
            brandBlock

            Spacer(minLength: 8)

            if category != .processes {
                DetailSegmentControl(
                    items: DetailDensity.allCases,
                    selection: $density,
                    title: { $0.rawValue }
                )
                .frame(width: 118)
            }

            intervalPill
            IconButton(systemImage: "gearshape.fill", help: "设置", action: onOpenSettings)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private var brandBlock: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.cpu, Palette.memory],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Palette.memory.opacity(0.26), radius: 5, x: 0, y: 2)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("MacPulse")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    liveBadge
                }

                Text(subtitle)
                    .font(.label(9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Palette.network)
                .frame(width: 4.5, height: 4.5)
            Text("实时")
                .font(.label(8.5, weight: .semibold))
                .foregroundStyle(Palette.network)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2.5)
        .background {
            Capsule(style: .continuous)
                .fill(Palette.network.opacity(0.11))
        }
    }

    private var subtitle: String {
        "\(engine.hardware.summary) · \(engine.hardware.osVersion) · 已运行 \(MetricFormat.uptime(state.snapshot.uptime))"
    }

    private var intervalPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 8, weight: .medium))
            Text("每 \(formattedInterval(state.samplingInterval)) 秒")
                .font(.label(9, weight: .medium))
        }
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .help("在设置中调整刷新间隔")
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Palette.network)
                .frame(width: 4.5, height: 4.5)
            Text("历史 \(historyWindowText) · \(state.history.cpu.count) 个采样")
            Text("·")
            Text("SMC / IOKit 只读")
            Text("·")
            Text("仅渲染当前页面")
            Spacer(minLength: 4)
            Text("MacPulse \(version)")
            Button("退出", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.label(8.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
    }

    private var historyWindowText: String {
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

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
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

    private func formattedInterval(_ interval: TimeInterval) -> String {
        interval < 1 ? String(format: "%.1f", interval) : String(format: "%.0f", interval)
    }
}

private struct DetailSidebar: View {
    @Binding var selection: DetailCategory
    let snapshot: SystemSnapshot
    let unit: TemperatureUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("监控页面")
                .font(.label(9, weight: .semibold))
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 13)
                .padding(.top, 16)
                .padding(.bottom, 8)

            VStack(spacing: 2) {
                ForEach(DetailCategory.allCases) { item in
                    row(item)
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Palette.network)
                        .frame(width: 4.5, height: 4.5)
                    Text("只读采样")
                        .font(.label(8.5, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Text("每次只构建一个页面")
                    .font(.label(8.5))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 172)
        .frame(maxHeight: .infinity)
        .background(Color.primary.opacity(0.012))
    }

    private func row(_ item: DetailCategory) -> some View {
        let active = selection == item
        return Button {
            selection = item
        } label: {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(active ? item.accent : Color.secondary)
                    .frame(width: 16)

                Text(item.rawValue)
                    .font(.label(11.5, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let badge = badge(for: item) {
                    Text(badge)
                        .font(.mono(8.5, weight: .medium))
                        .foregroundStyle(active ? item.accent : Color.secondary.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(item.accent.opacity(0.13))
                }
            }
            .overlay {
                if active {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(item.accent.opacity(0.22), lineWidth: 1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.rawValue)
    }

    private func badge(for item: DetailCategory) -> String? {
        switch item {
        case .cpu:
            return String(format: "%.0f%%", snapshot.cpu.totalUsage * 100)
        case .memory:
            return String(format: "%.0f%%", snapshot.memory.usedFraction * 100)
        case .gpu:
            guard let gpu = snapshot.gpu else { return "--" }
            return String(format: "%.0f%%", gpu.utilization * 100)
        case .network:
            return MetricFormat.rateCompact(snapshot.network.downloadBytesPerSecond)
        case .disk:
            return String(format: "%.0f%%", snapshot.disk.usedFraction * 100)
        case .thermal:
            guard let celsius = snapshot.thermal.cpuAverageCelsius else { return "--" }
            return String(format: "%.0f°", unit.convert(celsius: celsius))
        case .fan:
            guard let fan = snapshot.fans.first else { return "--" }
            return String(format: "%.0f", fan.rpm)
        case .battery:
            guard let battery = snapshot.battery else { return "--" }
            return "\(battery.percentage)%"
        case .system:
            return nil
        case .processes:
            guard !snapshot.processes.isEmpty else { return nil }
            return "\(snapshot.processes.count)"
        }
    }
}

private struct DetailSegmentControl<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                Button {
                    selection = item
                } label: {
                    Text(title(item))
                        .font(.label(10.5, weight: .semibold))
                        .foregroundStyle(selection == item ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 23)
                        .background {
                            if selection == item {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.primary.opacity(0.09))
                                    .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        }
    }
}
