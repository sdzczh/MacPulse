import SwiftUI
import MacPulseCore

enum DetailTab: String, CaseIterable, Identifiable {
    case overview = "概览"
    case processes = "进程"

    var id: String { rawValue }
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

    @State private var tab: DetailTab = .overview
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

                Group {
                    switch tab {
                    case .overview:
                        DetailsOverviewView(
                            state: state,
                            hardware: engine.hardware,
                            settings: settings,
                            density: density,
                            onQuit: onQuit
                        )
                    case .processes:
                        DetailsProcessesView(
                            processes: state.snapshot.processes,
                            isDetailed: state.isDetailed,
                            interval: state.samplingInterval
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
    }

    private var header: some View {
        HStack(spacing: 14) {
            brandBlock

            Spacer(minLength: 8)

            DetailSegmentControl(
                items: DetailTab.allCases,
                selection: $tab,
                title: { $0.rawValue }
            )
            .frame(width: 146)

            Spacer(minLength: 8)

            if tab == .overview {
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

    private func formattedInterval(_ interval: TimeInterval) -> String {
        interval < 1 ? String(format: "%.1f", interval) : String(format: "%.0f", interval)
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
