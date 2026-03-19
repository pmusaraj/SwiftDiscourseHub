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

    var body: some View {
        if let date {
            if date.timeIntervalSinceNow > -7 * 86400 {
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
}
