import AppKit
import Combine
import MacPulseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings()
    private var engine: MetricsEngine!
    private var statusController: StatusItemController!
    private var settingsWindowController: SettingsWindowController?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        engine = MetricsEngine(interval: settings.refreshInterval)
        engine.start()

        statusController = StatusItemController(engine: engine, settings: settings)
        statusController.onOpenSettings = { [weak self] in
            self?.openSettings()
        }

        settings.$refreshInterval
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] interval in
                self?.engine.start(interval: interval)
            }
            .store(in: &cancellables)

        settings.refreshLoginItemStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController(engine: engine, settings: settings)
        }
        settingsWindowController?.present()
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            withTitle: "关于 MacPulse",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettingsFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)

        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "隐藏 MacPulse",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 MacPulse",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        NSApp.mainMenu = mainMenu
    }
}
