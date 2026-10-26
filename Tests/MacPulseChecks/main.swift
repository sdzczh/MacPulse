import Foundation
import Darwin
import MacPulseCore

var checkCount = 0
var failures: [String] = []

func pass() {
    checkCount += 1
}

func fail(_ message: String, line: Int) {
    checkCount += 1
    let formatted = "line \(line): \(message)"
    failures.append(formatted)
    print("FAIL  \(formatted)")
}

func check(_ condition: @autoclosure () -> Bool, _ message: String, line: Int = #line) {
    if condition() {
        pass()
    } else {
        fail(message, line: line)
    }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, line: Int = #line) {
    if actual == expected {
        pass()
    } else {
        fail("\(message) — expected \(expected), got \(actual)", line: line)
    }
}

func checkClose(
    _ actual: Double,
    _ expected: Double,
    tolerance: Double = 0.0001,
    _ message: String,
    line: Int = #line
) {
    if abs(actual - expected) <= tolerance {
        pass()
    } else {
        fail("\(message) — expected \(expected)±\(tolerance), got \(actual)", line: line)
    }
}

func checkNil<T>(_ value: T?, _ message: String, line: Int = #line) {
    if value == nil {
        pass()
    } else {
        fail("\(message) — expected nil, got \(String(describing: value))", line: line)
    }
}

@discardableResult
func require<T>(_ value: T?, _ message: String, line: Int = #line) -> T? {
    if let value {
        pass()
        return value
    }
    fail("\(message) — value was nil", line: line)
    return nil
}

func floatBytes(_ value: Float) -> [UInt8] {
    let bits = value.bitPattern
    return (0..<4).map { UInt8((bits >> ($0 * 8)) & 0xFF) }
}

func testMetricFormat() {
    checkEqual(MetricFormat.percent(0.123), "12%", "percent rounds to integer")
    checkEqual(MetricFormat.percent(0.1234, decimals: 1), "12.3%", "percent supports decimals")
    checkEqual(MetricFormat.percent(-0.5), "0%", "percent clamps negatives")
    checkEqual(MetricFormat.percent(Double.nan), "0%", "percent handles NaN")
    checkEqual(MetricFormat.percent(1), "100%", "percent handles full usage")

    checkEqual(MetricFormat.memory(0), "0 B", "memory formats zero")
    checkEqual(MetricFormat.memory(1536), "2 KB", "memory formats kilobytes")
    checkEqual(MetricFormat.memory(20 * 1024 * 1024 * 1024), "20.0 GB", "memory formats gigabytes")
    checkEqual(MetricFormat.memory(2 * 1024 * 1024 * 1024 * 1024), "2.00 TB", "memory formats terabytes")

    checkEqual(MetricFormat.memoryCompact(0), "0B", "compact memory zero")
    checkEqual(MetricFormat.memoryCompact(1536), "2K", "compact memory kilobytes")
    checkEqual(MetricFormat.memoryCompact(14 * 1024 * 1024), "14M", "compact memory megabytes")
    checkEqual(MetricFormat.memoryCompact(643 * 1024 * 1024), "643M", "compact memory process size")
    checkEqual(MetricFormat.memoryCompact(20 * 1024 * 1024 * 1024), "20.0G", "compact memory gigabytes")
    checkEqual(MetricFormat.memoryCompact(2 * 1024 * 1024 * 1024 * 1024), "2.00T", "compact memory terabytes")

    checkEqual(MetricFormat.rate(0), "0 B/s", "rate zero")
    checkEqual(MetricFormat.rate(-1), "0 B/s", "rate clamps negative")
    checkEqual(MetricFormat.rate(1024), "1 KB/s", "rate kilobytes")
    checkEqual(MetricFormat.rate(3.3 * 1024 * 1024), "3.3 MB/s", "rate megabytes")
    checkEqual(MetricFormat.rateCompact(0), "0", "compact rate zero")
    checkEqual(MetricFormat.rateCompact(8 * 1024), "8K", "compact rate kilobytes")
    checkEqual(MetricFormat.rateCompact(2.5 * 1024 * 1024 * 1024), "2.5G", "compact rate gigabytes")

    checkEqual(MetricFormat.rpm(0), "0", "rpm zero")
    checkEqual(MetricFormat.rpm(5348.4), "5348", "rpm rounds")
    checkEqual(MetricFormat.rpm(Double.nan), "0", "rpm handles NaN")
    checkEqual(MetricFormat.celsius(58.4), "58°C", "celsius formats")
    checkEqual(MetricFormat.celsius(nil), "--", "celsius nil")
    checkEqual(MetricFormat.celsius(Double.nan), "--", "celsius NaN")

    checkEqual(MetricFormat.uptime(0), "--", "uptime zero")
    checkEqual(MetricFormat.uptime(59), "0 分", "uptime minutes")
    checkEqual(MetricFormat.uptime(3661), "1 小时 1 分", "uptime hours")
    checkEqual(MetricFormat.uptime(90_061), "1 天 1 小时", "uptime days")
}

func testSMCDecoders() {
    checkEqual(SMCFourCC.value("flt "), 0x666C_7420, "fourcc flt")
    checkEqual(SMCFourCC.value("sp78"), 0x7370_3738, "fourcc sp78")
    checkEqual(SMCFourCC.value("bad"), 0, "fourcc rejects short strings")

    let reading = SMCReading(
        key: "TC0P",
        dataSize: 4,
        dataType: SMCFourCC.flt,
        bytes: floatBytes(58.5)
    )
    checkEqual(reading.typeString, "flt ", "SMCReading type string")

    checkClose(Double(require(SMCValueDecoder.float(floatBytes(58.5)), "flt decodes") ?? 0), 58.5, "flt value")
    checkNil(SMCValueDecoder.float([0, 1, 2]), "flt rejects short data")
    checkNil(SMCValueDecoder.float(floatBytes(.infinity)), "flt rejects infinity")

    checkEqual(SMCValueDecoder.uint8([42]), 42, "ui8 decodes")
    checkEqual(SMCValueDecoder.uint16([0x12, 0x34]), 0x1234, "ui16 big endian")
    checkNil(SMCValueDecoder.uint16([0x12]), "ui16 rejects short data")
    checkEqual(SMCValueDecoder.uint32([0x00, 0x00, 0x01, 0x02]), 258, "ui32 big endian")

    checkClose(require(SMCValueDecoder.sp78([0x0E, 0x80]), "sp78 decodes") ?? 0, 14.5, "sp78 positive")
    checkClose(require(SMCValueDecoder.sp78([0xF1, 0x80]), "sp78 decodes negative") ?? 0, -14.5, "sp78 negative")
    checkNil(SMCValueDecoder.sp78([]), "sp78 rejects empty data")

    checkClose(require(SMCValueDecoder.fpe2([0x1F, 0x40]), "fpe2 decodes") ?? 0, 2000, "fpe2 value")
    checkNil(SMCValueDecoder.fpe2([0x1F]), "fpe2 rejects short data")

    let flt = SMCReading(key: "TC0P", dataSize: 4, dataType: SMCFourCC.flt, bytes: floatBytes(58.5))
    checkClose(require(SMCValueDecoder.decode(flt), "decode flt") ?? 0, 58.5, "decode routes flt")

    let sp78 = SMCReading(key: "TB0T", dataSize: 2, dataType: SMCFourCC.sp78, bytes: [0x0E, 0x80])
    checkClose(require(SMCValueDecoder.decode(sp78), "decode sp78") ?? 0, 14.5, "decode routes sp78")

    let fpe2 = SMCReading(key: "F0Mn", dataSize: 2, dataType: SMCFourCC.fpe2, bytes: [0x1F, 0x40])
    checkClose(require(SMCValueDecoder.decode(fpe2), "decode fpe2") ?? 0, 2000, "decode routes fpe2")

    let unknown = SMCReading(key: "XXXX", dataSize: 4, dataType: SMCFourCC.hex, bytes: [1, 2, 3, 4])
    checkNil(SMCValueDecoder.decode(unknown), "decode rejects unknown type")
}

func testSMCIntegration() {
    guard let client = SMCClient() else {
        print("SKIP  AppleSMC 不可用，跳过硬件读取检查")
        return
    }

    let keys = client.enumerateKeys()
    check(keys.count > 100, "SMC exposes keys (got \(keys.count))")
    check(keys.contains("FNum"), "SMC exposes FNum")

    guard keys.contains("FNum") else { return }

    do {
        let count = try client.read("FNum")
        checkEqual(count.dataSize, 1, "FNum data size")
        checkEqual(count.typeString, "ui8 ", "FNum type")

        if keys.contains("F0Ac") {
            if let rpm = client.readNumber("F0Ac") {
                check(rpm >= 0 && rpm < 20_000, "fan RPM in range (got \(rpm))")
            } else {
                fail("F0Ac decodes", line: #line)
            }
        } else {
            print("SKIP  未发现 F0Ac，跳过风扇转速检查")
        }

        if keys.contains("Tp0P") {
            if let temperature = client.readNumber("Tp0P") {
                check(temperature > 1 && temperature < 125, "CPU temperature in range (got \(temperature))")
            } else {
                print("SKIP  Tp0P 没有数值")
            }
        }
    } catch {
        fail("SMC read failed: \(error)", line: #line)
    }
}

func testModels() {
    let gib: UInt64 = 1024 * 1024 * 1024
    var memory = MemorySnapshot()
    memory.totalBytes = 16 * gib
    memory.activeBytes = 4 * gib
    memory.wiredBytes = 2 * gib
    memory.compressedBytes = 1 * gib
    memory.inactiveBytes = 3 * gib
    memory.purgeableBytes = 1 * gib
    memory.freeBytes = 5 * gib
    memory.pressure = .normal

    checkEqual(memory.usedBytes, 7 * gib, "memory used = active + wired + compressed")
    checkEqual(memory.cachedBytes, 4 * gib, "memory cached = inactive + purgeable")
    checkEqual(memory.availableBytes, 9 * gib, "memory available = free + cached")
    checkClose(memory.usedFraction, 7.0 / 16.0, "memory used fraction")
    checkEqual(memory.pressure.rawValue, "正常", "memory pressure label")

    let fan = FanReading(index: 0, rpm: 2500, minRPM: 1500, maxRPM: 5500)
    checkEqual(fan.name, "风扇 1", "fan name")
    checkClose(fan.fraction, 0.25, "fan fraction")

    let stopped = FanReading(index: 1, rpm: 0, minRPM: 1500, maxRPM: 5500)
    checkClose(stopped.fraction, 0, "stopped fan fraction")

    let invalid = FanReading(index: 2, rpm: 100, minRPM: 500, maxRPM: 500)
    checkClose(invalid.fraction, 0, "invalid fan range fraction")

    var disk = DiskSnapshot()
    disk.totalBytes = 1000
    disk.usedBytes = 250
    checkClose(disk.usedFraction, 0.25, "disk fraction")

    var history = MetricsHistory()
    history.capacity = 3
    for index in 0..<5 {
        var snapshot = SystemSnapshot()
        snapshot.cpu.totalUsage = Double(index) / 10
        snapshot.memory.activeBytes = UInt64(index)
        snapshot.network.downloadBytesPerSecond = Double(index * 100)
        history.append(snapshot: snapshot)
    }

    checkEqual(history.cpu, [0.2, 0.3, 0.4], "history trims to capacity")
    checkEqual(history.memoryUsed, [2, 3, 4], "history trims memory samples")
    checkEqual(history.download, [200, 300, 400], "history trims network samples")

    var nanHistory = MetricsHistory()
    var nanSnapshot = SystemSnapshot()
    nanSnapshot.cpu.totalUsage = .nan
    nanSnapshot.network.downloadBytesPerSecond = .infinity
    nanHistory.append(snapshot: nanSnapshot)
    checkEqual(nanHistory.cpu, [0], "history replaces NaN")
    checkEqual(nanHistory.download, [0], "history replaces infinity")

    let state = MetricsState()
    checkEqual(state.sampleCount, 0, "state sample count default")
    checkEqual(state.isDetailed, false, "state detailed default")
    checkEqual(state.samplingInterval, 1, "state interval default")
    checkNil(state.lastError, "state error default")
}

testMetricFormat()
testSMCDecoders()
testSMCIntegration()
testModels()

print("")
print("MacPulseChecks: \(checkCount) checks, \(failures.count) failure(s)")
if failures.isEmpty {
    exit(0)
}
for failure in failures {
    print("  \(failure)")
}
exit(1)
