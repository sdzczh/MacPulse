import SwiftUI
import MacPulseCore

struct SettingsView: View {
    @ObservedObject var engine: MetricsEngine
    @ObservedObject var settings: AppSettings

    var onClose: () -> Void
    var onQuit: () -> Void

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        ZStack {
            VisualEffectBackground(material: .sidebar)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    SettingsSection(
                        title: "菜单栏显示",
                        subtitle: "选择常驻指标，空间不足时自动折叠为 +N"
                    ) {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            MenuBarToggleRow(icon: "cpu", title: "CPU", color: Palette.cpu, isOn: $settings.showCPU)
                            MenuBarToggleRow(icon: "memorychip", title: "内存", color: Palette.memory, isOn: $settings.showMemory)
                            MenuBarToggleRow(icon: "thermometer.medium", title: "温度", color: Palette.thermal, isOn: $settings.showTemperature)
                            MenuBarToggleRow(icon: "fanblades", title: "风扇", color: Palette.fan, isOn: $settings.showFan)
                            MenuBarToggleRow(icon: "arrow.up.arrow.down", title: "网络", color: Palette.network, isOn: $settings.showNetwork)
                            MenuBarToggleRow(icon: "display", title: "GPU", color: Palette.gpu, isOn: $settings.showGPU)
                            MenuBarToggleRow(icon: "internaldrive", title: "磁盘", color: Palette.disk, isOn: $settings.showDisk)
                            MenuBarToggleRow(icon: "battery.100", title: "电池", color: Palette.battery, isOn: $settings.showBattery)
                        }
                    }

                    SettingsSection(title: "采样与显示") {
                        VStack(spacing: 0) {
                            SettingRow(
                                title: "刷新间隔",
                                subtitle: "菜单栏与仪表盘同步刷新"
                            ) {
                                Picker("", selection: $settings.refreshInterval) {
                                    Text("0.5 秒").tag(0.5)
                                    Text("1 秒").tag(1.0)
                                    Text("2 秒").tag(2.0)
                                    Text("5 秒").tag(5.0)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .controlSize(.small)
                                .frame(width: 222)
                            }

                            Hairline()
                                .padding(.vertical, 10)

                            SettingRow(
                                title: "温度单位",
                                subtitle: "菜单栏与所有温度读数同步"
                            ) {
                                Picker("", selection: $settings.temperatureUnit) {
                                    ForEach(TemperatureUnit.allCases) { unit in
                                        Text(unit.label).tag(unit)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .controlSize(.small)
                                .frame(width: 170)
                            }

                            Hairline()
                                .padding(.vertical, 10)

                            SettingRow(
                                title: "登录时自动启动",
                                subtitle: settings.loginItemError ?? "需要将 MacPulse 放入「应用程序」文件夹"
                            ) {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { settings.launchAtLogin },
                                        set: { settings.setLaunchAtLogin($0) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }

                            if let error = settings.loginItemError {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                    Text(error)
                                        .lineLimit(2)
                                    Spacer(minLength: 0)
                                }
                                .font(.label(9))
                                .foregroundStyle(Palette.warning)
                                .padding(.top, 8)
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(engine.hardware.summary) · \(engine.hardware.osVersion)")
                            .font(.label(9))
                            .foregroundStyle(.tertiary)
                        Spacer(minLength: 8)
                        Text("v\(version)")
                            .font(.mono(9))
                            .foregroundStyle(.tertiary)
                    }

                    HStack(spacing: 8) {
                        Button("恢复菜单栏默认项") {
                            settings.resetMenuBarDefaults()
                        }
                        .controlSize(.small)

                        Spacer(minLength: 8)

                        Button("退出 MacPulse", action: onQuit)
                            .controlSize(.small)

                        Button("完成", action: onClose)
                            .controlSize(.small)
                            .keyboardShortcut(.defaultAction)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 620)
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.cpu, Palette.memory],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Palette.memory.opacity(0.25), radius: 6, x: 0, y: 2)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("MacPulse 设置")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("只读监控 · 数据不离开本机 · 不修改风扇")
                    .font(.label(9.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.label(11, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.label(9))
                        .foregroundStyle(.tertiary)
                }
            }

            content
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.66))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}

private struct MenuBarToggleRow: View {
    let icon: String
    let title: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isOn ? color : Color.secondary)
                .frame(width: 16, alignment: .leading)

            Text(title)
                .font(.label(11, weight: .medium))
                .foregroundStyle(isOn ? Color.primary : Color.secondary)

            Spacer(minLength: 4)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isOn ? 0.045 : 0.025))
        }
        .opacity(isOn ? 1 : 0.72)
    }
}

private struct SettingRow<Control: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let control: Control

    init(title: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.label(11, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.label(9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
            control
        }
    }
}
