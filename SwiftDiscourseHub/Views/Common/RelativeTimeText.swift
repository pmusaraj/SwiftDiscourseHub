import SwiftUI

struct RelativeTimeText: View {
    let dateString: String?

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

    private var date: Date? {
        guard let dateString else { return nil }
        return Self.isoFormatter.date(from: dateString)
            ?? Self.isoFormatterNoFrac.date(from: dateString)
    }

    var concise: Bool = false

    var body: some View {
        if let date {
            if concise {
                Text(Self.conciseString(from: date))
                    .foregroundStyle(.secondary)
            } else if date.timeIntervalSinceNow > -7 * 86400 {
                Text(date, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
            } else if Calendar.current.component(.year, from: date) == Calendar.current.component(.year, from: .now) {
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(.secondary)
            } else {
                Text(date, format: .dateTime.month(.abbreviated).day().year())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func conciseString(from date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60 { return "\(Int(seconds))s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(Int(minutes))m" }
        let hours = minutes / 60
        if hours < 24 { return "\(Int(hours))h" }
        let days = hours / 24
        if days < 30 { return "\(Int(days))d" }
        let months = days / 30
        if months < 12 { return "\(Int(months))mo" }
        let years = days / 365
        return "\(Int(years))y"
    }
}
