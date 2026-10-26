import Foundation
import CSMC

public enum SMCError: Error, CustomStringConvertible {
    case unavailable
    case keyMissing(String)
    case transportFailure
    case invalidValue(String)

    public var description: String {
        switch self {
        case .unavailable:
            return "SMC 不可用"
        case .keyMissing(let key):
            return "SMC 键不存在：\(key)"
        case .transportFailure:
            return "SMC 通信失败"
        case .invalidValue(let key):
            return "SMC 值无效：\(key)"
        }
    }
}

public struct SMCReading {
    public let key: String
    public let dataSize: UInt32
    public let dataType: UInt32
    public let bytes: [UInt8]

    public init(key: String, dataSize: UInt32, dataType: UInt32, bytes: [UInt8]) {
        self.key = key
        self.dataSize = dataSize
        self.dataType = dataType
        self.bytes = bytes
    }

    public var typeString: String {
        let chars: [Character] = [
            Character(UnicodeScalar((dataType >> 24) & 0xFF)!),
            Character(UnicodeScalar((dataType >> 16) & 0xFF)!),
            Character(UnicodeScalar((dataType >> 8) & 0xFF)!),
            Character(UnicodeScalar(dataType & 0xFF)!)
        ]
        return String(chars)
    }
}

public enum SMCFourCC {
    public static let flt = value("flt ")
    public static let ui8 = value("ui8 ")
    public static let ui16 = value("ui16")
    public static let ui32 = value("ui32")
    public static let sp78 = value("sp78")
    public static let fpe2 = value("fpe2")
    public static let hex = value("hex_")

    public static func value(_ string: String) -> UInt32 {
        let bytes = Array(string.utf8)
        guard bytes.count == 4 else { return 0 }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }
}

public enum SMCValueDecoder {
    public static func float(_ bytes: [UInt8]) -> Float? {
        guard bytes.count >= 4 else { return nil }
        let bits = UInt32(bytes[0]) | (UInt32(bytes[1]) << 8) | (UInt32(bytes[2]) << 16) | (UInt32(bytes[3]) << 24)
        let value = Float(bitPattern: bits)
        return value.isFinite ? value : nil
    }

    public static func uint8(_ bytes: [UInt8]) -> UInt8? {
        bytes.first
    }

    public static func uint16(_ bytes: [UInt8]) -> UInt16? {
        guard bytes.count >= 2 else { return nil }
        return (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
    }

    public static func uint32(_ bytes: [UInt8]) -> UInt32? {
        guard bytes.count >= 4 else { return nil }
        return (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
    }

    public static func sp78(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = Int16(bitPattern: (UInt16(bytes[0]) << 8) | UInt16(bytes[1]))
        return Double(raw) / 256.0
    }

    public static func fpe2(_ bytes: [UInt8]) -> Double? {
        guard bytes.count >= 2 else { return nil }
        let raw = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Double(raw) / 4.0
    }

    public static func decode(_ reading: SMCReading) -> Double? {
        switch reading.dataType {
        case SMCFourCC.flt:
            return float(reading.bytes).map(Double.init)
        case SMCFourCC.sp78:
            return sp78(reading.bytes)
        case SMCFourCC.fpe2:
            return fpe2(reading.bytes)
        case SMCFourCC.ui8:
            return uint8(reading.bytes).map(Double.init)
        case SMCFourCC.ui16:
            return uint16(reading.bytes).map(Double.init)
        case SMCFourCC.ui32:
            return uint32(reading.bytes).map(Double.init)
        default:
            return nil
        }
    }
}

public final class SMCClient {
    private var isOpen = false
    private var cachedKeys: [String]?

    public init?() {
        guard macpulse_smc_open() == 0 else { return nil }
        isOpen = true
    }

    deinit {
        if isOpen {
            macpulse_smc_close()
        }
    }

    public func enumerateKeys() -> [String] {
        if let cachedKeys { return cachedKeys }
        guard isOpen else { return [] }

        let count = macpulse_smc_key_count()
        guard count > 0 else { return [] }

        var keys: [String] = []
        keys.reserveCapacity(Int(count))
        for index in 0..<count {
            var buffer = [CChar](repeating: 0, count: 5)
            if macpulse_smc_key_by_index(index, &buffer) == 0 {
                let key = String(cString: buffer)
                if key.utf8.count == 4 {
                    keys.append(key)
                }
            }
        }
        cachedKeys = keys
        return keys
    }

    public func read(_ key: String) throws -> SMCReading {
        guard isOpen else { throw SMCError.unavailable }
        let keyBytes = Array(key.utf8)
        guard keyBytes.count == 4 else { throw SMCError.keyMissing(key) }

        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = key.withCString { keyPointer in
            bytes.withUnsafeMutableBufferPointer { buffer in
                macpulse_smc_read_key(keyPointer, &dataSize, &dataType, buffer.baseAddress, buffer.count)
            }
        }

        switch result {
        case 0:
            let size = Int(min(dataSize, UInt32(bytes.count)))
            return SMCReading(key: key, dataSize: dataSize, dataType: dataType, bytes: Array(bytes.prefix(size)))
        case -2, -3:
            throw SMCError.keyMissing(key)
        default:
            throw SMCError.transportFailure
        }
    }

    public func readNumber(_ key: String) -> Double? {
        guard let reading = try? read(key) else { return nil }
        return SMCValueDecoder.decode(reading)
    }
}
