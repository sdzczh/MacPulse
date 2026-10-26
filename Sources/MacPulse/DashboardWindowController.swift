import AppKit
import SwiftUI
import MacPulseCore

final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let engine: MetricsEngine
    private let settings: AppSettings
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void

    init(
        engine: MetricsEngine,
        settings: AppSettings,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.engine = engine
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 760),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacPulse 详情"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.center()

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        if window.contentViewController == nil {
            let dashboard = DashboardView(
                engine: engine,
                settings: settings,
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
            window.contentViewController = NSHostingController(rootView: dashboard)
        }

        engine.setDetailed(true)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        engine.setDetailed(false)
        // 关闭后释放 SwiftUI 视图树，避免隐藏窗口持续跟随采样刷新。
        window?.contentViewController = nil
    }
}
