import Foundation
import AppKit

public final class SensorService {
    private let smc: SMCClient?
    private var fanIndices: [Int] = []
    private var cpuTemperatureKeys: [String] = []
    private var gpuTemperatureKeys: [String] = []

    public init() {
        smc = SMCClient()
        discoverSensorsIfPossible()
    }

    public var isAvailable: Bool {
        smc != nil
    }

    private func discoverSensorsIfPossible() {
        guard let smc else { return }

        let keys = smc.enumerateKeys()
        var fans: Set<Int> = []
        var cpuKeys: [String] = []
        var gpuKeys: [String] = []

        for key in keys {
            if key.count == 4, key.hasPrefix("F"), key.hasSuffix("Ac") {
                let middle = key.dropFirst().dropLast(2)
                if let index = Int(middle) {
                    fans.insert(index)
                }
                continue
            }

            let isCPUCandidate = key.hasPrefix("Tp") || key.hasPrefix("Te") || key.hasPrefix("Ts")
            let isGPUCandidate = key.hasPrefix("Tg")
            guard isCPUCandidate || isGPUCandidate else { continue }

            if let value = smc.readNumber(key), value > 1, value < 125 {
                if isCPUCandidate {
                    cpuKeys.append(key)
                } else {
                    gpuKeys.append(key)
                }
            }
        }

        fanIndices = fans.sorted()
        cpuTemperatureKeys = cpuKeys.sorted()
        gpuTemperatureKeys = gpuKeys.sorted()
    }

    public func sample() -> (fans: [FanReading], thermal: ThermalSnapshot) {
        guard let smc else {
            return ([], ThermalSnapshot())
        }

        var fans: [FanReading] = []
        for index in fanIndices {
            let actualKey = "F\(index)Ac"
            guard let rpm = smc.readNumber(actualKey), rpm >= 0 else { continue }
            let minRPM = smc.readNumber("F\(index)Mn") ?? 0
            let maxRPM = smc.readNumber("F\(index)Mx") ?? max(rpm, 6000)
            fans.append(FanReading(index: index, rpm: rpm, minRPM: minRPM, maxRPM: maxRPM))
        }

        let cpuValues = cpuTemperatureKeys.compactMap { key -> Double? in
            guard let value = smc.readNumber(key), value > 1, value < 125 else { return nil }
            return value
        }
        let gpuValues = gpuTemperatureKeys.compactMap { key -> Double? in
            guard let value = smc.readNumber(key), value > 1, value < 125 else { return nil }
            return value
        }

        var thermal = ThermalSnapshot()
        if !cpuValues.isEmpty {
            thermal.cpuAverageCelsius = cpuValues.reduce(0, +) / Double(cpuValues.count)
            thermal.cpuMaxCelsius = cpuValues.max()
        }
        if !gpuValues.isEmpty {
            thermal.gpuAverageCelsius = gpuValues.reduce(0, +) / Double(gpuValues.count)
            thermal.gpuMaxCelsius = gpuValues.max()
        }
        thermal.sensorCount = cpuValues.count + gpuValues.count
        thermal.thermalState = Self.thermalStateLabel(ProcessInfo.processInfo.thermalState)

        return (fans, thermal)
    }

    private static func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "正常"
        case .fair: return "偏高"
        case .serious: return "过热"
        case .critical: return "临界"
        @unknown default: return "未知"
        }
    }
}
