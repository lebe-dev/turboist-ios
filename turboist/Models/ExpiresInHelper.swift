import Foundation

enum ExpiresInHelper {
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterNoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ isoString: String) -> Date? {
        isoFormatter.date(from: isoString) ?? isoFormatterNoFrac.date(from: isoString)
    }

    static func expiresInText(for expiresAt: String?, now: Date = Date()) -> String? {
        guard let expiresAt, let date = parse(expiresAt) else { return nil }
        let ms = date.timeIntervalSince(now)
        if ms <= 0 { return "Expiring now" }
        let totalMinutes = Int(ms / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "Auto-removes in \(hours)h \(minutes)m"
        }
        return "Auto-removes in \(minutes)m"
    }

    static func hasExpiration(_ expiresAt: String?) -> Bool {
        guard let expiresAt else { return false }
        return parse(expiresAt) != nil
    }
}
