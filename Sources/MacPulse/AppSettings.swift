import Foundation
import Combine
import ServiceManagement

public enum TemperatureUnit: String, CaseIterable, Identifiable {
    case celsius
    case fahrenheit

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .celsius: return "摄氏 °C"
        case .fahrenheit: return "华氏 °F"
        }
    }

    public var shortSymbol: String {
        self == .celsius ? "°C" : "°F"
    }

    public func convert(celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }

    public func string(celsius: Double?, decimals: Int = 0) -> String {
        guard let celsius, celsius.isFinite else { return "--" }
        return String(format: "%.\(decimals)f%@", convert(celsius: celsius), shortSymbol)
    }

    public func shortString(celsius: Double?) -> String {
        guard let celsius, celsius.isFinite else { return "--°" }
        return String(format: "%.0f°", convert(celsius: celsius))
    }
}

public final class AppSettings: ObservableObject {
    private enum Key {
        static let showCPU = "menu.showCPU"
        static let showMemory = "menu.showMemory"
        static let showTemperature = "menu.showTemperature"
        static let showFan = "menu.showFan"
        static let showNetwork = "menu.showNetwork"
        static let showGPU = "menu.showGPU"
        static let showDisk = "menu.showDisk"
        static let showBattery = "menu.showBattery"
        static let refreshInterval = "engine.refreshInterval"
        static let temperatureUnit = "ui.temperatureUnit"
    }

    @Published var showCPU: Bool { didSet { persist() } }
    @Published var showMemory: Bool { didSet { persist() } }
    @Published var showTemperature: Bool { didSet { persist() } }
    @Published var showFan: Bool { didSet { persist() } }
    @Published var showNetwork: Bool { didSet { persist() } }
    @Published var showGPU: Bool { didSet { persist() } }
    @Published var showDisk: Bool { didSet { persist() } }
    @Published var showBattery: Bool { didSet { persist() } }
    @Published var refreshInterval: Double { didSet { persist() } }
    @Published var temperatureUnit: TemperatureUnit { didSet { persist() } }

    @Published private(set) var launchAtLogin: Bool = false
    @Published private(set) var loginItemError: String?

    private let defaults: UserDefaults
    private var isLoading = true

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.showCPU = defaults.object(forKey: Key.showCPU) as? Bool ?? true
        self.showMemory = defaults.object(forKey: Key.showMemory) as? Bool ?? true
        self.showTemperature = defaults.object(forKey: Key.showTemperature) as? Bool ?? true
        self.showFan = defaults.object(forKey: Key.showFan) as? Bool ?? true
        self.showNetwork = defaults.object(forKey: Key.showNetwork) as? Bool ?? false
        self.showGPU = defaults.object(forKey: Key.showGPU) as? Bool ?? false
        self.showDisk = defaults.object(forKey: Key.showDisk) as? Bool ?? false
        self.showBattery = defaults.object(forKey: Key.showBattery) as? Bool ?? false
        self.refreshInterval = defaults.object(forKey: Key.refreshInterval) as? Double ?? 1
        if let raw = defaults.string(forKey: Key.temperatureUnit),
           let unit = TemperatureUnit(rawValue: raw) {
            self.temperatureUnit = unit
        } else {
            self.temperatureUnit = .celsius
        }
        isLoading = false
        refreshLoginItemStatus()
    }

    private func persist() {
        guard !isLoading else { return }
        defaults.set(showCPU, forKey: Key.showCPU)
        defaults.set(showMemory, forKey: Key.showMemory)
        defaults.set(showTemperature, forKey: Key.showTemperature)
        defaults.set(showFan, forKey: Key.showFan)
        defaults.set(showNetwork, forKey: Key.showNetwork)
        defaults.set(showGPU, forKey: Key.showGPU)
        defaults.set(showDisk, forKey: Key.showDisk)
        defaults.set(showBattery, forKey: Key.showBattery)
        defaults.set(refreshInterval, forKey: Key.refreshInterval)
        defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit)
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        if enabled {
            do {
                try SMAppService.mainApp.register()
                launchAtLogin = true
                loginItemError = nil
            } catch {
                launchAtLogin = false
                loginItemError = "无法启用开机启动，请先把 App 放入「应用程序」文件夹。"
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
                launchAtLogin = false
                loginItemError = nil
            } catch {
                refreshLoginItemStatus()
                loginItemError = "无法关闭开机启动：\(error.localizedDescription)"
            }
        }
    }

    public func refreshLoginItemStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    public func resetMenuBarDefaults() {
        showCPU = true
        showMemory = true
        showTemperature = true
        showFan = true
        showNetwork = false
        showGPU = false
        showDisk = false
        showBattery = false
        refreshInterval = 1
        temperatureUnit = .celsius
    }
}
