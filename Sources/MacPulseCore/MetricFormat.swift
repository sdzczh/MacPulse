import Foundation

public enum MetricFormat {
    private static let kb = 1024.0
    private static let mb = 1024.0 * 1024.0
    private static let gb = 1024.0 * 1024.0 * 1024.0
    private static let tb = 1024.0 * 1024.0 * 1024.0 * 1024.0

    public static func percent(_ fraction: Double, decimals: Int = 0) -> String {
        guard fraction.isFinite else { return "0%" }
        return String(format: "%.\(decimals)f%%", max(0, fraction) * 100)
    }

    public static func memory(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= tb {
            return String(format: "%.2f TB", value / tb)
        }
        if value >= gb {
            return String(format: "%.1f GB", value / gb)
        }
        if value >= mb {
            return String(format: "%.0f MB", value / mb)
        }
        if value >= kb {
            return String(format: "%.0f KB", value / kb)
        }
        return "\(bytes) B"
    }

    /// Compact, fixed-ish width form used in the menu bar and process list.
    public static func memoryCompact(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        if value >= tb {
            return String(format: "%.2fT", value / tb)
        }
        if value >= gb {
            return String(format: "%.1fG", value / gb)
        }
        if value >= mb {
            return String(format: "%.0fM", value / mb)
        }
        if value >= kb {
            return String(format: "%.0fK", value / kb)
        }
        return "\(bytes)B"
    }

    public static func memoryGB(_ bytes: UInt64) -> Double {
        Double(bytes) / gb
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "0 B/s" }
        if bytesPerSecond >= gb {
            return String(format: "%.2f GB/s", bytesPerSecond / gb)
        }
        if bytesPerSecond >= mb {
            return String(format: "%.1f MB/s", bytesPerSecond / mb)
        }
        if bytesPerSecond >= kb {
            return String(format: "%.0f KB/s", bytesPerSecond / kb)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    public static func rateCompact(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "0" }
        if bytesPerSecond >= gb {
            return String(format: "%.1fG", bytesPerSecond / gb)
        }
        if bytesPerSecond >= mb {
            return String(format: "%.1fM", bytesPerSecond / mb)
        }
        if bytesPerSecond >= kb {
            return String(format: "%.0fK", bytesPerSecond / kb)
        }
        return String(format: "%.0fB", bytesPerSecond)
    }

    public static func rpm(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        return String(format: "%.0f", max(0, value))
    }

    public static func celsius(_ value: Double?, decimals: Int = 0) -> String {
        guard let value, value.isFinite else { return "--" }
        return String(format: "%.\(decimals)f°C", value)
    }

    public static func uptime(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "--" }
        let totalMinutes = Int(interval / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        if days > 0 {
            return "\(days) 天 \(hours) 小时"
        }
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分"
        }
        return "\(minutes) 分"
    }

    public static func signedRate(_ bytesPerSecond: Double, prefix: String) -> String {
        "\(prefix) \(rate(bytesPerSecond))"
    }
}
