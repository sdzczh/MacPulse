import AppKit
import Combine
import MacPulseCore

final class StatusItemController: NSObject {
    private let engine: MetricsEngine
    private let settings: AppSettings
    private let statusItem: NSStatusItem
    private let renderer = StatusItemRenderer()
    private var detailsWindowController: DashboardWindowController?
    private var cancellables: Set<AnyCancellable> = []

    var onOpenSettings: (() -> Void)?

    init(engine: MetricsEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: 150)
        super.init()
        configure()
    }

    private func configure() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(statusButtonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        renderer.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(renderer)
        NSLayoutConstraint.activate([
            renderer.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            renderer.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            renderer.topAnchor.constraint(equalTo: button.topAnchor),
            renderer.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])

        engine.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.refresh() }
            }
            .store(in: &cancellables)

        refresh()
    }

    @objc private func statusButtonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            presentDetails()
        }
    }

    private func presentDetails() {
        if detailsWindowController == nil {
            detailsWindowController = DashboardWindowController(
                engine: engine,
                settings: settings,
                onOpenSettings: { [weak self] in
                    self?.detailsWindowController?.close()
                    self?.onOpenSettings?()
                },
                onQuit: {
                    NSApp.terminate(nil)
                }
            )
        }
        detailsWindowController?.present()
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "打开详情窗口", action: #selector(openDetailsFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettingsFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "关于 MacPulse", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "退出 MacPulse", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    @objc private func openDetailsFromMenu() {
        presentDetails()
    }

    @objc private func openSettingsFromMenu() {
        detailsWindowController?.close()
        onOpenSettings?()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let alert = NSAlert()
        alert.messageText = "MacPulse"
        alert.informativeText = """
        版本 \(version)
        \(engine.hardware.chipName) · \(MetricFormat.memory(engine.hardware.totalMemoryBytes))
        \(engine.hardware.osVersion)

        只读监控，不修改风扇或系统设置。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好")
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func refresh() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.refresh() }
            return
        }

        let state = engine.state
        let snapshot = state.snapshot
        let segments = fittedSegments(makeSegments(snapshot: snapshot))
        renderer.update(segments: segments)

        let width = max(70, renderer.intrinsicContentSize.width)
        if abs(statusItem.length - width) > 0.5 {
            statusItem.length = width
        }

        var tooltipParts: [String] = ["MacPulse"]
        tooltipParts.append("CPU \(MetricFormat.percent(snapshot.cpu.totalUsage))")
        tooltipParts.append("内存 \(MetricFormat.memory(snapshot.memory.usedBytes)) / \(MetricFormat.memory(snapshot.memory.totalBytes))")
        if let temp = snapshot.thermal.cpuAverageCelsius {
            tooltipParts.append("CPU \(settings.temperatureUnit.string(celsius: temp))")
        }
        if let fan = snapshot.fans.first {
            tooltipParts.append("风扇 \(MetricFormat.rpm(fan.rpm)) RPM")
        }
        if let gpu = snapshot.gpu {
            tooltipParts.append("GPU \(MetricFormat.percent(gpu.utilization))")
        }
        tooltipParts.append("网络 ↓ \(MetricFormat.rate(snapshot.network.downloadBytesPerSecond)) ↑ \(MetricFormat.rate(snapshot.network.uploadBytesPerSecond))")
        tooltipParts.append("磁盘 \(MetricFormat.percent(snapshot.disk.usedFraction))")
        if let battery = snapshot.battery {
            tooltipParts.append("电池 \(battery.percentage)%")
        }
        statusItem.button?.toolTip = tooltipParts.joined(separator: " · ")
    }

    private func fittedSegments(_ segments: [StatusSegment]) -> [StatusSegment] {
        guard segments.count > 1,
              renderer.fittingWidth(for: segments) > StatusItemRenderer.maximumWidth else {
            return segments
        }

        for visibleCount in stride(from: segments.count - 1, through: 1, by: -1) {
            let hidden = segments.count - visibleCount
            let candidate = Array(segments.prefix(visibleCount)) + [
                StatusSegment(
                    text: "+\(hidden)",
                    reserveText: "+\(segments.count)"
                )
            ]
            if renderer.fittingWidth(for: candidate) <= StatusItemRenderer.maximumWidth {
                return candidate
            }
        }

        return Array(segments.prefix(1))
    }

    private func makeSegments(snapshot: SystemSnapshot) -> [StatusSegment] {
        var segments: [StatusSegment] = []

        if settings.showCPU {
            segments.append(
                StatusSegment(
                    text: MetricFormat.percent(snapshot.cpu.totalUsage),
                    reserveText: "100%",
                    emphasized: true
                )
            )
        }

        if settings.showMemory {
            segments.append(
                StatusSegment(
                    text: MetricFormat.memoryCompact(snapshot.memory.usedBytes),
                    reserveText: MetricFormat.memoryCompact(engine.hardware.totalMemoryBytes)
                )
            )
        }

        if settings.showTemperature {
            segments.append(
                StatusSegment(
                    text: settings.temperatureUnit.shortString(celsius: snapshot.thermal.cpuAverageCelsius),
                    reserveText: settings.temperatureUnit == .celsius ? "100°" : "212°"
                )
            )
        }

        if settings.showFan, let fan = snapshot.fans.first {
            let maxRPM = snapshot.fans.map(\.maxRPM).max() ?? fan.maxRPM
            segments.append(
                StatusSegment(
                    text: MetricFormat.rpm(fan.rpm),
                    reserveText: MetricFormat.rpm(maxRPM)
                )
            )
        }

        if settings.showGPU, let gpu = snapshot.gpu {
            segments.append(
                StatusSegment(
                    text: MetricFormat.percent(gpu.utilization),
                    reserveText: "100%"
                )
            )
        }

        if settings.showNetwork {
            let text = "↓\(MetricFormat.rateCompact(snapshot.network.downloadBytesPerSecond)) ↑\(MetricFormat.rateCompact(snapshot.network.uploadBytesPerSecond))"
            segments.append(
                StatusSegment(
                    text: text,
                    reserveText: "↓999M ↑999M"
                )
            )
        }

        if settings.showDisk {
            segments.append(
                StatusSegment(
                    text: MetricFormat.percent(snapshot.disk.usedFraction),
                    reserveText: "100%"
                )
            )
        }

        if settings.showBattery, let battery = snapshot.battery {
            segments.append(
                StatusSegment(
                    text: "\(battery.percentage)%",
                    reserveText: "100%"
                )
            )
        }

        if segments.isEmpty {
            segments.append(
                StatusSegment(
                    text: "MacPulse",
                    reserveText: "MacPulse",
                    emphasized: true
                )
            )
        }

        return segments
    }
}
