import Foundation
import Darwin
import IOKit
import IOKit.ps

public final class GPUSampler {
    public init() {}

    public func sample() -> GPUSnapshot? {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        guard matching != nil,
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var best: GPUSnapshot?
        var service: io_service_t = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            guard let property = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? NSDictionary else {
                continue
            }

            guard let utilizationNumber = property["Device Utilization %"] as? NSNumber else {
                continue
            }

            var gpu = GPUSnapshot()
            gpu.utilization = min(1, max(0, utilizationNumber.doubleValue / 100.0))
            gpu.inUseMemoryBytes = (property["In use system memory"] as? NSNumber)?.uint64Value ?? 0
            gpu.allocatedMemoryBytes = (property["Alloc system memory"] as? NSNumber)?.uint64Value ?? 0

            if best == nil || gpu.utilization > (best?.utilization ?? 0) {
                best = gpu
            }
        }

        return best
    }
}

public final class NetworkSampler {
    private var previousReceived: UInt64 = 0
    private var previousSent: UInt64 = 0
    private var previousTime: Date?
    private var cumulativeReceived: UInt64 = 0
    private var cumulativeSent: UInt64 = 0
    private var hasBaseline = false

    public init() {}

    public func sample(now: Date = Date()) -> NetworkSnapshot {
        var snapshot = NetworkSnapshot()
        var currentReceived: UInt64 = 0
        var currentSent: UInt64 = 0
        var activeNames: Set<String> = []

        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0 else { return snapshot }
        defer { freeifaddrs(head) }

        var pointer = head
        while let current = pointer {
            let interface = current.pointee
            defer { pointer = interface.ifa_next }

            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  let dataPointer = interface.ifa_data else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard Self.isRelevantInterface(name) else { continue }

            let data = dataPointer.assumingMemoryBound(to: if_data.self).pointee
            let received = UInt64(data.ifi_ibytes)
            let sent = UInt64(data.ifi_obytes)
            guard received > 0 || sent > 0 else { continue }

            currentReceived += received
            currentSent += sent
            activeNames.insert(name)
        }

        snapshot.activeInterfaces = activeNames.sorted()

        if !hasBaseline {
            hasBaseline = true
            previousReceived = currentReceived
            previousSent = currentSent
            cumulativeReceived = currentReceived
            cumulativeSent = currentSent
            previousTime = now
            snapshot.totalReceivedBytes = cumulativeReceived
            snapshot.totalSentBytes = cumulativeSent
            return snapshot
        }

        let deltaIn = currentReceived >= previousReceived ? currentReceived - previousReceived : 0
        let deltaOut = currentSent >= previousSent ? currentSent - previousSent : 0
        cumulativeReceived += deltaIn
        cumulativeSent += deltaOut

        let interval = max(0.001, now.timeIntervalSince(previousTime ?? now))
        snapshot.downloadBytesPerSecond = Double(deltaIn) / interval
        snapshot.uploadBytesPerSecond = Double(deltaOut) / interval
        snapshot.totalReceivedBytes = cumulativeReceived
        snapshot.totalSentBytes = cumulativeSent

        previousReceived = currentReceived
        previousSent = currentSent
        previousTime = now
        return snapshot
    }

    private static func isRelevantInterface(_ name: String) -> Bool {
        let excludedPrefixes = ["lo", "awdl", "llw", "utun", "gif", "stf", "anpi", "ap", "vmenet", "ipsec"]
        for prefix in excludedPrefixes where name.hasPrefix(prefix) {
            return false
        }
        return true
    }
}

public final class DiskSampler {
    private var previousRead: UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousTime: Date?
    private var hasBaseline = false

    public init() {}

    public func sample(now: Date = Date()) -> DiskSnapshot {
        var snapshot = DiskSnapshot()

        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: "/") {
            snapshot.totalBytes = (attributes[.systemSize] as? NSNumber)?.uint64Value ?? 0
            snapshot.freeBytes = (attributes[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
            snapshot.usedBytes = snapshot.totalBytes > snapshot.freeBytes
                ? snapshot.totalBytes - snapshot.freeBytes
                : 0
        }

        var readBytes: UInt64 = 0
        var writeBytes: UInt64 = 0

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        if matching != nil, IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS {
            var service: io_service_t = IOIteratorNext(iterator)
            while service != 0 {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }

                guard let statistics = IORegistryEntryCreateCFProperty(
                    service,
                    "Statistics" as CFString,
                    kCFAllocatorDefault,
                    0
                )?.takeRetainedValue() as? NSDictionary else {
                    continue
                }

                readBytes += (statistics["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
                writeBytes += (statistics["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
            }
            IOObjectRelease(iterator)
        }

        guard hasBaseline else {
            hasBaseline = true
            previousRead = readBytes
            previousWrite = writeBytes
            previousTime = now
            return snapshot
        }

        let deltaRead = readBytes >= previousRead ? readBytes - previousRead : 0
        let deltaWrite = writeBytes >= previousWrite ? writeBytes - previousWrite : 0
        let interval = max(0.001, now.timeIntervalSince(previousTime ?? now))
        snapshot.readBytesPerSecond = Double(deltaRead) / interval
        snapshot.writeBytesPerSecond = Double(deltaWrite) / interval

        previousRead = readBytes
        previousWrite = writeBytes
        previousTime = now
        return snapshot
    }
}

public final class BatterySampler {
    public init() {}

    public func sample() -> BatterySnapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? NSDictionary else {
                continue
            }

            let transport = description[kIOPSTransportTypeKey as String] as? String
            if let transport, transport != (kIOPSInternalType as String) {
                continue
            }

            guard let current = (description[kIOPSCurrentCapacityKey as String] as? NSNumber)?.intValue,
                  let maximum = (description[kIOPSMaxCapacityKey as String] as? NSNumber)?.intValue,
                  maximum > 0 else {
                continue
            }

            var battery = BatterySnapshot()
            battery.percentage = Int((Double(current) / Double(maximum) * 100).rounded())
            battery.isCharging = (description[kIOPSIsChargingKey as String] as? NSNumber)?.boolValue ?? false
            battery.powerSource = description[kIOPSPowerSourceStateKey as String] as? String ?? "未知"
            battery.isPluggedIn = battery.powerSource == (kIOPSACPowerValue as String)

            if let minutes = (description[kIOPSTimeToEmptyKey as String] as? NSNumber)?.intValue, minutes > 0 {
                battery.timeRemainingMinutes = minutes
            }

            let smartBattery = Self.smartBatteryProperties()
            battery.cycleCount = (smartBattery?["CycleCount"] as? NSNumber)?.intValue

            if let design = (smartBattery?["DesignCapacity"] as? NSNumber)?.doubleValue,
               let rawMax = (smartBattery?["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue,
               design > 0, rawMax > 0 {
                battery.healthPercent = min(100, rawMax / design * 100)
            }

            return battery
        }

        return nil
    }

    private static func smartBatteryProperties() -> NSDictionary? {
        var iterator: io_iterator_t = 0
        guard let matching = IOServiceMatching("AppleSmartBattery"),
              IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS, let unmanagedProperties else {
            return nil
        }
        return unmanagedProperties.takeRetainedValue() as NSDictionary
    }
}

public enum UptimeProvider {
    public static func uptime() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}
