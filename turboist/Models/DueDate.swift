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
        case .today: return .orange
        case .tomorrow: return .blue
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

        if taskDate < today { return "Overdue" }
        if calendar.isDateInToday(taskDate) { return "Today" }
        if calendar.isDateInTomorrow(taskDate) { return "Tomorrow" }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (2...7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return (label: formatter.string(from: date), date: format(date))
        }
    }

    static func postponeColor(count: Int) -> Color {
        if count >= 3 { return .red }
        if count >= 2 { return .yellow }
        return .secondary
    }
}
