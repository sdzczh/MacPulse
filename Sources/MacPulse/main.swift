import AppKit
import Foundation
import MacPulseCore

func probeText(engine: MetricsEngine) -> String {
    let state = engine.state
    let s = state.snapshot
    var lines: [String] = []
    lines.append("MacPulse probe")
    lines.append("hardware: \(engine.hardware.summary) · \(engine.hardware.modelIdentifier) · \(engine.hardware.osVersion)")
    lines.append("cores: logical=\(engine.hardware.logicalCoreCount) P=\(engine.hardware.performanceCoreCount) E=\(engine.hardware.efficiencyCoreCount) · uptime=\(MetricFormat.uptime(s.uptime))")
    lines.append(String(format: "cpu: %.1f%% · cores=%@ · load=%.2f %.2f %.2f",
                        s.cpu.totalUsage * 100,
                        s.cpu.coreUsages.map { String(format: "%.0f", $0 * 100) }.joined(separator: "/"),
                        s.cpu.load1, s.cpu.load5, s.cpu.load15))
    lines.append("memory: used=\(MetricFormat.memory(s.memory.usedBytes)) / \(MetricFormat.memory(s.memory.totalBytes)) · active=\(MetricFormat.memory(s.memory.activeBytes)) wired=\(MetricFormat.memory(s.memory.wiredBytes)) compressed=\(MetricFormat.memory(s.memory.compressedBytes)) cached=\(MetricFormat.memory(s.memory.cachedBytes)) · pressure=\(s.memory.pressure.rawValue)")
    lines.append("swap: \(MetricFormat.memory(s.memory.swapUsedBytes)) / \(MetricFormat.memory(s.memory.swapTotalBytes))")
    if s.fans.isEmpty {
        lines.append("fans: none")
    } else {
        lines.append("fans: " + s.fans.map { "\($0.name)=\(MetricFormat.rpm($0.rpm)) rpm [\(MetricFormat.rpm($0.minRPM))-\(MetricFormat.rpm($0.maxRPM))]" }.joined(separator: " · "))
    }
    lines.append("temps: cpu=\(MetricFormat.celsius(s.thermal.cpuAverageCelsius)) max=\(MetricFormat.celsius(s.thermal.cpuMaxCelsius)) gpu=\(MetricFormat.celsius(s.thermal.gpuAverageCelsius)) max=\(MetricFormat.celsius(s.thermal.gpuMaxCelsius)) sensors=\(s.thermal.sensorCount) state=\(s.thermal.thermalState)")
    if let gpu = s.gpu {
        lines.append("gpu: util=\(MetricFormat.percent(gpu.utilization)) inUse=\(MetricFormat.memory(gpu.inUseMemoryBytes)) alloc=\(MetricFormat.memory(gpu.allocatedMemoryBytes))")
    } else {
        lines.append("gpu: unavailable")
    }
    lines.append("network: down=\(MetricFormat.rate(s.network.downloadBytesPerSecond)) up=\(MetricFormat.rate(s.network.uploadBytesPerSecond)) · ifaces=\(s.network.activeInterfaces.joined(separator: ","))")
    lines.append("disk: used=\(MetricFormat.memory(s.disk.usedBytes)) / \(MetricFormat.memory(s.disk.totalBytes)) · read=\(MetricFormat.rate(s.disk.readBytesPerSecond)) write=\(MetricFormat.rate(s.disk.writeBytesPerSecond))")
    if let battery = s.battery {
        lines.append("battery: \(battery.percentage)% · charging=\(battery.isCharging) · plugged=\(battery.isPluggedIn) · cycles=\(battery.cycleCount.map(String.init) ?? "-") · health=\(battery.healthPercent.map { String(format: "%.1f%%", $0) } ?? "-")")
    } else {
        lines.append("battery: none")
    }
    lines.append("processes: \(s.processes.map { "\($0.name)(\($0.pid)) \(String(format: "%.1f%%", $0.cpuLoad * 100)) \(MetricFormat.memory($0.memoryBytes))" }.joined(separator: " · "))")
    lines.append("samples=\(state.sampleCount) detailed=\(state.isDetailed) interval=\(state.samplingInterval)")
    if let error = state.lastError { lines.append("error: \(error)") }
    return lines.joined(separator: "\n")
}

if CommandLine.arguments.contains("--probe") {
    let engine = MetricsEngine(interval: 1)
    engine.start()
    engine.setDetailed(true)
    RunLoop.main.run(until: Date().addingTimeInterval(3.4))
    print(probeText(engine: engine))
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
_ = app.setActivationPolicy(.accessory)
app.run()
