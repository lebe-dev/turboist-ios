import SwiftUI

enum DueDateStatus {
    case overdue
    case today
    case tomorrow
    case future
    case none

    var color: Color {
        switch self {
        case .overdue: return .red
        case .today: return .green
        case .tomorrow: return .orange
        case .future: return .secondary
        case .none: return .secondary
        }
    }
}

enum DueDateHelper {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    private static let weekDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    static func parse(_ dateString: String) -> Date? {
        dateFormatter.date(from: dateString)
    }

    static func format(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func status(for dateString: String) -> DueDateStatus {
        guard let date = parse(dateString) else { return .none }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let taskDate = calendar.startOfDay(for: date)

        if taskDate < today { return .overdue }
        if calendar.isDateInToday(taskDate) { return .today }
        if calendar.isDateInTomorrow(taskDate) { return .tomorrow }
        return .future
    }

    static func displayLabel(for dateString: String) -> String {
        guard let date = parse(dateString) else { return dateString }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let taskDate = calendar.startOfDay(for: date)

        if taskDate < today { return displayFormatter.string(from: date) }
        if calendar.isDateInToday(taskDate) { return "Today" }
        if calendar.isDateInTomorrow(taskDate) { return "Tomorrow" }

        return displayFormatter.string(from: date)
    }

    static func todayString() -> String {
        format(Date())
    }

    static func tomorrowString() -> String {
        format(Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
    }

    static func weekDays() -> [(label: String, date: String)] {
        let calendar = Calendar.current
        let today = Date()
        return (2...7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return (label: weekDayFormatter.string(from: date), date: format(date))
        }
    }

    static func postponeColor(count: Int) -> Color {
        if count >= 3 { return .red }
        if count >= 2 { return .yellow }
        return .secondary
    }
}
