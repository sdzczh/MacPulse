import Foundation
import Darwin

public final class ProcessSampler {
    private var previousTicks: [Int32: UInt64] = [:]
    private var previousTime: Date?
    private var timebase: mach_timebase_info_data_t = mach_timebase_info_data_t()

    public init() {
        mach_timebase_info(&timebase)
    }

    public func sample(now: Date = Date(), limit: Int = 8) -> [ProcessReading] {
        let interval = max(0.001, now.timeIntervalSince(previousTime ?? now))
        var pids = [pid_t](repeating: 0, count: 8192)

        let returnedBytes: Int32 = pids.withUnsafeMutableBytes { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, Int32(buffer.count))
        }

        guard returnedBytes > 0 else {
            return []
        }

        let count = min(pids.count, Int(returnedBytes) / MemoryLayout<pid_t>.size)
        var readings: [ProcessReading] = []
        readings.reserveCapacity(count)
        var currentTicks: [Int32: UInt64] = [:]
        currentTicks.reserveCapacity(count)

        for index in 0..<count {
            let pid = pids[index]
            guard pid > 0 else { continue }

            var info = proc_taskinfo()
            let infoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, infoSize) == infoSize else {
                continue
            }

            let ticks = info.pti_total_user &+ info.pti_total_system
            currentTicks[pid] = ticks

            var nameBuffer = [CChar](repeating: 0, count: 256)
            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = nameLength > 0 ? String(cString: nameBuffer) : "pid \(pid)"

            var load = 0.0
            if let previous = previousTicks[pid], ticks >= previous {
                let delta = ticks - previous
                let seconds = Double(delta) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000_000
                load = seconds / interval
            }

            readings.append(
                ProcessReading(
                    pid: pid,
                    name: name,
                    cpuLoad: load,
                    memoryBytes: info.pti_resident_size
                )
            )
        }

        previousTicks = currentTicks
        previousTime = now

        readings.sort { lhs, rhs in
            if lhs.cpuLoad == rhs.cpuLoad {
                return lhs.memoryBytes > rhs.memoryBytes
            }
            return lhs.cpuLoad > rhs.cpuLoad
        }

        return Array(readings.prefix(limit))
    }
}
