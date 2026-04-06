import Foundation

func currentDayPartLabel(dayParts: [DayPart]) -> String? {
    let hour = Calendar.current.component(.hour, from: Date())
    return dayParts.first { hour >= $0.start && hour < $0.end }?.label
}

struct DayPartSection: Identifiable {
    let id: String
    let label: String
    let start: Int
    let end: Int
    let icon: String
    var tasks: [TaskItem]
    var note: String

    var timeRange: String {
        String(format: "%d:00–%d:00", start, end)
    }
}

func groupTasksByDayPart(
    tasks: [TaskItem],
    dayParts: [DayPart],
    dayPartNotes: [String: String]
) -> [DayPartSection] {
    guard !dayParts.isEmpty else {
        return [DayPartSection(
            id: "__all__",
            label: "All",
            start: 0,
            end: 24,
            icon: "clock",
            tasks: tasks,
            note: ""
        )]
    }

    let dayPartLabels = Set(dayParts.map(\.label))

    var sectionMap: [String: [TaskItem]] = [:]
    for dp in dayParts {
        sectionMap[dp.label] = []
    }
    var unassigned: [TaskItem] = []

    for task in tasks {
        let matchingLabel = task.labels.first { dayPartLabels.contains($0) }
        if let label = matchingLabel {
            sectionMap[label, default: []].append(task)
        } else {
            unassigned.append(task)
        }
    }

    var sections: [DayPartSection] = []
    for (index, dp) in dayParts.enumerated() {
        let icon: String
        if index == 0 {
            icon = "sunrise"
        } else if index == dayParts.count - 1 {
            icon = "moon"
        } else {
            icon = "sun.max"
        }
        sections.append(DayPartSection(
            id: dp.label,
            label: dp.label,
            start: dp.start,
            end: dp.end,
            icon: icon,
            tasks: sectionMap[dp.label] ?? [],
            note: dayPartNotes[dp.label] ?? ""
        ))
    }

    sections.append(DayPartSection(
        id: "__unassigned__",
        label: "Без времени",
        start: 0,
        end: 0,
        icon: "clock",
        tasks: unassigned,
        note: dayPartNotes["__unassigned__"] ?? ""
    ))

    return sections
}
