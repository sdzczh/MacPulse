import Foundation

public struct CPUSnapshot: Equatable {
    public var totalUsage: Double = 0
    public var coreUsages: [Double] = []
    public var load1: Double = 0
    public var load5: Double = 0
    public var load15: Double = 0
    public var logicalCoreCount: Int = 0
    public var performanceCoreCount: Int = 0
    public var efficiencyCoreCount: Int = 0

    public init() {}
}

public enum MemoryPressure: String, Equatable {
    case normal = "正常"
    case warning = "警告"
    case critical = "严重"
    case unknown = "未知"

    public var level: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        case .unknown: return -1
        }
    }
}

public struct MemorySnapshot: Equatable {
    public var totalBytes: UInt64 = 0
    public var activeBytes: UInt64 = 0
    public var inactiveBytes: UInt64 = 0
    public var wiredBytes: UInt64 = 0
    public var compressedBytes: UInt64 = 0
    public var purgeableBytes: UInt64 = 0
    public var speculativeBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var swapTotalBytes: UInt64 = 0
    public var swapUsedBytes: UInt64 = 0
    public var pressure: MemoryPressure = .unknown

    public init() {}

    public var cachedBytes: UInt64 {
        inactiveBytes + purgeableBytes
    }

    public var availableBytes: UInt64 {
        freeBytes + cachedBytes
    }

    /// A practical approximation of "memory used" (active + wired + compressed).
    public var usedBytes: UInt64 {
        activeBytes + wiredBytes + compressedBytes
    }

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }
}

public struct FanReading: Identifiable, Equatable {
    public var id: Int { index }
    public var index: Int
    public var rpm: Double
    public var minRPM: Double
    public var maxRPM: Double

    public var name: String { "风扇 \(index + 1)" }

    public var fraction: Double {
        guard maxRPM > minRPM else { return 0 }
        return min(1, max(0, (rpm - minRPM) / (maxRPM - minRPM)))
    }

    public init(index: Int, rpm: Double, minRPM: Double, maxRPM: Double) {
        self.index = index
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
    }
}

public struct ThermalSnapshot: Equatable {
    public var cpuAverageCelsius: Double?
    public var cpuMaxCelsius: Double?
    public var gpuAverageCelsius: Double?
    public var gpuMaxCelsius: Double?
    public var sensorCount: Int = 0
    public var thermalState: String = "未知"

    public init() {}

    public var hasData: Bool {
        cpuAverageCelsius != nil || gpuAverageCelsius != nil
    }
}

public struct GPUSnapshot: Equatable {
    public var utilization: Double = 0
    public var inUseMemoryBytes: UInt64 = 0
    public var allocatedMemoryBytes: UInt64 = 0

    public init() {}
}

public struct NetworkSnapshot: Equatable {
    public var downloadBytesPerSecond: Double = 0
    public var uploadBytesPerSecond: Double = 0
    public var totalReceivedBytes: UInt64 = 0
    public var totalSentBytes: UInt64 = 0
    public var activeInterfaces: [String] = []

    public init() {}
}

public struct DiskSnapshot: Equatable {
    public var usedBytes: UInt64 = 0
    public var totalBytes: UInt64 = 0
    public var freeBytes: UInt64 = 0
    public var readBytesPerSecond: Double = 0
    public var writeBytesPerSecond: Double = 0

    public init() {}

    public var usedFraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }
}

public struct BatterySnapshot: Equatable {
    public var percentage: Int = 0
    public var isCharging: Bool = false
    public var isPluggedIn: Bool = false
    public var timeRemainingMinutes: Int?
    public var cycleCount: Int?
    public var healthPercent: Double?
    public var powerSource: String = "未知"

    public init() {}
}

public struct ProcessReading: Identifiable, Equatable {
    public var id: Int32 { pid }
    public var pid: Int32
    public var name: String
    /// Fraction of one CPU core. Values above 1 mean multiple threads were busy.
    public var cpuLoad: Double
    public var memoryBytes: UInt64

    public init(pid: Int32, name: String, cpuLoad: Double, memoryBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuLoad = cpuLoad
        self.memoryBytes = memoryBytes
    }
}

public struct SystemSnapshot: Equatable {
    public var sampledAt: Date = .init()
    public var cpu = CPUSnapshot()
    public var memory = MemorySnapshot()
    public var fans: [FanReading] = []
    public var thermal = ThermalSnapshot()
    public var gpu: GPUSnapshot?
    public var network = NetworkSnapshot()
    public var disk = DiskSnapshot()
    public var battery: BatterySnapshot?
    public var processes: [ProcessReading] = []
    public var uptime: TimeInterval = 0
    public var processSampled: Bool = false

    public init() {}
}

public struct MetricsHistory: Equatable {
    public static let defaultCapacity = 90

    public var cpu: [Double] = []
    public var memoryUsed: [Double] = []
    public var cpuTemperature: [Double] = []
    public var gpu: [Double] = []
    public var download: [Double] = []
    public var upload: [Double] = []
    public var fan: [Double] = []
    public var diskRead: [Double] = []
    public var diskWrite: [Double] = []
    public var capacity: Int = MetricsHistory.defaultCapacity

    public init() {}

    public mutating func append(snapshot: SystemSnapshot) {
        append(snapshot.cpu.totalUsage, to: &cpu)
        append(Double(snapshot.memory.usedBytes), to: &memoryUsed)
        if let temp = snapshot.thermal.cpuAverageCelsius {
            append(temp, to: &cpuTemperature)
        } else {
            append(0, to: &cpuTemperature)
        }
        append(snapshot.gpu?.utilization ?? 0, to: &gpu)
        append(snapshot.network.downloadBytesPerSecond, to: &download)
        append(snapshot.network.uploadBytesPerSecond, to: &upload)
        append(snapshot.fans.first?.rpm ?? 0, to: &fan)
        append(snapshot.disk.readBytesPerSecond, to: &diskRead)
        append(snapshot.disk.writeBytesPerSecond, to: &diskWrite)
    }

    private func append(_ value: Double, to array: inout [Double]) {
        array.append(value.isFinite ? value : 0)
        if array.count > capacity {
            array.removeFirst(array.count - capacity)
        }
    }
}

public struct MetricsState {
    public var snapshot: SystemSnapshot
    public var history: MetricsHistory
    public var sampleCount: Int
    public var isDetailed: Bool
    public var lastError: String?
    public var samplingInterval: TimeInterval

    public init(
        snapshot: SystemSnapshot = SystemSnapshot(),
        history: MetricsHistory = MetricsHistory(),
        sampleCount: Int = 0,
        isDetailed: Bool = false,
        lastError: String? = nil,
        samplingInterval: TimeInterval = 1
    ) {
        self.snapshot = snapshot
        self.history = history
        self.sampleCount = sampleCount
        self.isDetailed = isDetailed
        self.lastError = lastError
        self.samplingInterval = samplingInterval
    }
}

public struct HardwareInfo: Equatable {
    public var modelIdentifier: String = "Mac"
    public var chipName: String = "Apple Silicon"
    public var osVersion: String = "macOS"
    public var logicalCoreCount: Int = 0
    public var performanceCoreCount: Int = 0
    public var efficiencyCoreCount: Int = 0
    public var totalMemoryBytes: UInt64 = 0

    public init() {}

    public var summary: String {
        "\(chipName) · \(MetricFormat.memory(totalMemoryBytes))"
    }
}
