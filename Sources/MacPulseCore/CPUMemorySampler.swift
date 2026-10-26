import Foundation
import Darwin
import IOKit

public enum Sysctl {
    public static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size + 1)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    public static func int32(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    public static func int64(_ name: String) -> Int64? {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }

    public static func uint64(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}

public enum HardwareInfoProvider {
    public static func load() -> HardwareInfo {
        var info = HardwareInfo()
        info.modelIdentifier = Sysctl.string("hw.model") ?? "Mac"
        info.chipName = Sysctl.string("machdep.cpu.brand_string") ?? "Apple Silicon"
        info.totalMemoryBytes = Sysctl.uint64("hw.memsize") ?? 0
        info.logicalCoreCount = Int(Sysctl.int32("hw.logicalcpu") ?? 0)

        var performance = 0
        var efficiency = 0
        let perfLevelCount = Int(Sysctl.int32("hw.nperflevels") ?? 0)
        if perfLevelCount > 0 {
            for level in 0..<perfLevelCount {
                let name = Sysctl.string("hw.perflevel\(level).name") ?? ""
                let count = Int(Sysctl.int32("hw.perflevel\(level).physicalcpu") ?? 0)
                if name.localizedCaseInsensitiveContains("efficiency") {
                    efficiency += count
                } else if name.localizedCaseInsensitiveContains("performance") {
                    performance += count
                } else if level == perfLevelCount - 1 && performance > 0 {
                    efficiency += count
                } else {
                    performance += count
                }
            }
        }
        if performance + efficiency == 0 {
            let total = Int(Sysctl.int32("hw.physicalcpu") ?? 0)
            performance = total
        }
        info.performanceCoreCount = performance
        info.efficiencyCoreCount = efficiency

        let version = ProcessInfo.processInfo.operatingSystemVersion
        info.osVersion = "macOS \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        return info
    }
}

public final class CPUSampler {
    private var previousTicks: [UInt64] = []
    private let hardware: HardwareInfo

    public init(hardware: HardwareInfo) {
        self.hardware = hardware
    }

    public func sample() -> CPUSnapshot {
        var snapshot = CPUSnapshot()
        snapshot.logicalCoreCount = hardware.logicalCoreCount
        snapshot.performanceCoreCount = hardware.performanceCoreCount
        snapshot.efficiencyCoreCount = hardware.efficiencyCoreCount

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 {
            snapshot.load1 = loads[0]
            snapshot.load5 = loads[1]
            snapshot.load15 = loads[2]
        }

        var processorCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &processorCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let cpuInfo else {
            return snapshot
        }

        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: cpuInfo)), size)
        }

        let coreCount = Int(processorCount)
        let values = UnsafeBufferPointer(start: cpuInfo, count: Int(cpuInfoCount))
        var ticks = [UInt64](repeating: 0, count: coreCount * 4)
        for index in 0..<ticks.count where index < values.count {
            ticks[index] = UInt64(max(0, values[index]))
        }

        guard previousTicks.count == ticks.count else {
            previousTicks = ticks
            snapshot.coreUsages = [Double](repeating: 0, count: coreCount)
            return snapshot
        }

        var totalBusy: UInt64 = 0
        var totalAll: UInt64 = 0
        var usages: [Double] = []
        usages.reserveCapacity(coreCount)

        for core in 0..<coreCount {
            let base = core * 4
            let user = delta(ticks[base], previousTicks[base])
            let system = delta(ticks[base + 1], previousTicks[base + 1])
            let idle = delta(ticks[base + 2], previousTicks[base + 2])
            let nice = delta(ticks[base + 3], previousTicks[base + 3])
            let busy = user + system + nice
            let total = busy + idle
            totalBusy += busy
            totalAll += total
            usages.append(total > 0 ? min(1, Double(busy) / Double(total)) : 0)
        }

        previousTicks = ticks
        snapshot.coreUsages = usages
        snapshot.totalUsage = totalAll > 0 ? min(1, Double(totalBusy) / Double(totalAll)) : 0
        return snapshot
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64 {
        if current >= previous { return current - previous }
        return (UInt64(UInt32.max) - previous) + current
    }
}

public enum MemorySampler {
    public static func sample(totalBytes: UInt64) -> MemorySnapshot {
        var snapshot = MemorySnapshot()
        snapshot.totalBytes = totalBytes

        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            snapshot.activeBytes = UInt64(stats.active_count) * pageSize
            snapshot.inactiveBytes = UInt64(stats.inactive_count) * pageSize
            snapshot.wiredBytes = UInt64(stats.wire_count) * pageSize
            snapshot.compressedBytes = UInt64(stats.compressor_page_count) * pageSize
            snapshot.purgeableBytes = UInt64(stats.purgeable_count) * pageSize
            snapshot.speculativeBytes = UInt64(stats.speculative_count) * pageSize
            snapshot.freeBytes = UInt64(stats.free_count) * pageSize
        }

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0 {
            snapshot.swapTotalBytes = swap.xsu_total
            snapshot.swapUsedBytes = swap.xsu_used
        }

        if let level = Sysctl.int32("kern.memorystatus_vm_pressure_level") {
            switch level {
            case 1: snapshot.pressure = .normal
            case 2: snapshot.pressure = .warning
            case 4: snapshot.pressure = .critical
            default: snapshot.pressure = .unknown
            }
        }

        return snapshot
    }
}
