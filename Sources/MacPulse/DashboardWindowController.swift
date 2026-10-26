import AppKit
import SwiftUI
import MacPulseCore

final class DashboardWindowController: NSWindowController, NSWindowDelegate {
    private let engine: MetricsEngine
    private let settings: AppSettings
    private let onOpenSettings: () -> Void
    private let onQuit: () -> Void
    private let onClose: () -> Void

    init(
        engine: MetricsEngine,
        settings: AppSettings,
        onOpenSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.engine = engine
        self.settings = settings
        self.onOpenSettings = onOpenSettings
        self.onQuit = onQuit
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacPulse 详情"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.moveToActiveSpace]
        window.tabbingMode = .disallowed
        window.contentMinSize = NSSize(width: 960, height: 640)
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
            let contentSize = window.contentLayoutRect.size
            let details = DetailsDashboardView(
                engine: engine,
                settings: settings,
                onOpenSettings: onOpenSettings,
                onQuit: onQuit
            )
            window.contentViewController = NSHostingController(rootView: details)
            if contentSize.width > 0, contentSize.height > 0 {
                window.setContentSize(contentSize)
            }
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
        // 关闭动画结束后释放 SwiftUI 视图树，并同步详细采样状态。
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.window?.isVisible == false {
                self.window?.contentViewController = nil
            }
            self.onClose()
        }
    }
}
