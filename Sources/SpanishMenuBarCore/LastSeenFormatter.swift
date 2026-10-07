import Foundation

/// Formats dates as "15th of October 2026".
public enum LastSeenFormatter {
    public static func string(from date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.component(.day, from: date)
        let monthYear = DateFormatter()
        monthYear.calendar = calendar
        monthYear.timeZone = calendar.timeZone
        monthYear.locale = Locale(identifier: "en_US_POSIX")
        monthYear.dateFormat = "MMMM yyyy"
        return "\(day)\(ordinalSuffix(day)) of \(monthYear.string(from: date))"
    }

    static func ordinalSuffix(_ day: Int) -> String {
        if (11...13).contains(day % 100) { return "th" }
        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
