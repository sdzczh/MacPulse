import AppKit
import SwiftUI
import MacPulseCore

final class SettingsWindowController: NSWindowController {
    init(engine: MetricsEngine, settings: AppSettings) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacPulse 设置"
        window.isReleasedWhenClosed = false
        window.backgroundColor = .windowBackgroundColor
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let root = SettingsView(
            engine: engine,
            settings: settings,
            onClose: { [weak window] in
                window?.close()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )
        window.contentViewController = NSHostingController(rootView: root)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        guard let window else { return }
        if !window.isVisible {
            window.center()
        }
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }
}
