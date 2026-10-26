import SwiftUI
import MacPulseCore

struct DashboardView: View {
    @ObservedObject var engine: MetricsEngine
    @ObservedObject var settings: AppSettings

    var onOpenSettings: () -> Void
    var onQuit: () -> Void
    var height: CGFloat = 760

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }

    var body: some View {
        let state = engine.state
        let snapshot = state.snapshot

        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 11) {
                    header(snapshot: snapshot)

                    if let error = state.lastError {
                        errorBanner(error)
                    }

                    CPUCardView(
                        snapshot: snapshot,
                        hardware: engine.hardware,
                        history: state.history
                    )

                    MemoryCardView(snapshot: snapshot)

                    ThermalCardView(
                        snapshot: snapshot,
                        unit: settings.temperatureUnit
                    )

                    GPUAndBatteryRow(snapshot: snapshot)

                    NetworkDiskRow(
                        snapshot: snapshot,
                        history: state.history
                    )

                    ProcessesCardView(
                        processes: snapshot.processes,
                        isDetailed: state.isDetailed
                    )

                    footer(state: state)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 440, height: height)
        .background(Color.clear)
    }

    private func header(snapshot: SystemSnapshot) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Palette.cpu, Palette.memory],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Palette.memory.opacity(0.28), radius: 5, x: 0, y: 2)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 33, height: 33)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("MacPulse")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Palette.network)
                            .frame(width: 4.5, height: 4.5)
                        Text("实时")
                            .font(.label(8.5, weight: .semibold))
                            .foregroundStyle(Palette.network)
                    }
                }

                Text("\(engine.hardware.summary) · \(engine.hardware.osVersion) · 已运行 \(MetricFormat.uptime(snapshot.uptime))")
                    .font(.label(9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 6)

            IconButton(systemImage: "gearshape.fill", help: "设置", action: onOpenSettings)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(message)
                .font(.label(10))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Palette.warning)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Palette.warning.opacity(0.12))
        }
    }

    private func footer(state: MetricsState) -> some View {
        HStack(spacing: 6) {
            Text("MacPulse \(version)")
            Text("·")
            Text("SMC / IOKit 只读采样")
            Spacer(minLength: 4)
            Text("每 \(formattedInterval(state.samplingInterval)) 秒刷新")
            Button("退出", action: onQuit)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.label(8.5))
        .foregroundStyle(.tertiary)
        .padding(.top, 1)
    }

    private func formattedInterval(_ interval: TimeInterval) -> String {
        if interval < 1 {
            return String(format: "%.1f", interval)
        }
        return String(format: "%.0f", interval)
    }
}
