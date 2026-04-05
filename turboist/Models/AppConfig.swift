import Foundation

struct AppConfig: Codable {
    let settings: AppSettings
    let contexts: [TaskContext]
    let projects: [Project]
    let labels: [TaskLabel]
    let labelConfigs: [LabelConfig]
    let autoLabels: [AutoLabelMapping]
    let quickCapture: QuickCaptureConfig?
    let projectTasks: [ProjectTask]
    let labelProjectMap: [LabelProjectMapping]
    let autoRemove: AutoRemoveStatus
    var state: UserState
}

struct AppSettings: Codable {
    let pollInterval: Int
    let syncInterval: Int
    let timezone: String
    let weeklyLabel: String
    let backlogLabel: String
    let projectLabel: String
    let projectsLabel: String
    let weeklyLimit: Int
    let backlogLimit: Int
    let completedDays: Int
    let maxPinned: Int
    let lastSyncedAt: String?
    let dayParts: [DayPart]
    let maxDayPartNoteLength: Int
    let inboxProjectId: String
    let inboxLimit: Int
    let inboxOverflowTaskContent: String
}

struct Project: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
    var sections: [ProjectSection]
}

struct ProjectSection: Identifiable, Codable {
    let id: String
    let name: String
    let projectId: String
    let order: Int
}

struct TaskLabel: Identifiable, Codable {
    let id: String
    let name: String
    let color: String
    let order: Int
}

struct TaskContext: Identifiable, Codable {
    let id: String
    let displayName: String
    var color: String?
    var inheritLabels: Bool
    var filters: ContextFilters
}

struct ContextFilters: Codable {
    var projects: [String]
    var sections: [String]
    var labels: [String]
}

struct TasksMeta: Codable {
    var context: String
    var weeklyLimit: Int
    var weeklyCount: Int
    var backlogLimit: Int
    var backlogCount: Int
    var inboxCount: Int?
    var lastSyncedAt: String?
}

enum TaskView: String, Codable, CaseIterable {
    case all, inbox, today, tomorrow, weekly, backlog, completed

    var displayName: String {
        switch self {
        case .all: return "All Tasks"
        case .inbox: return "Inbox"
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekly: return "Weekly"
        case .backlog: return "Backlog"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .inbox: return "tray"
        case .today: return "sun.max"
        case .tomorrow: return "sun.horizon"
        case .weekly: return "calendar.badge.clock"
        case .backlog: return "archivebox"
        case .completed: return "checkmark.circle"
        }
    }
}

struct PinnedTask: Codable, Identifiable {
    let id: String
    let content: String
}

struct DayPart: Codable {
    let label: String
    let start: Int
    let end: Int
}

struct UserState: Codable {
    var pinnedTasks: [PinnedTask]
    var activeContextId: String
    var activeView: String
    var collapsedIds: [String]
    var sidebarCollapsed: Bool
    var planningOpen: Bool
    var dayPartNotes: [String: String]
    var locale: String
    var allFilters: AllFiltersState?
}

struct AllFiltersState: Codable {
    var selectedPriorities: [Int]
    var selectedLabels: [String]
    var linksOnly: Bool
    var filtersExpanded: Bool
}

struct LabelConfig: Codable {
    let name: String
    let inheritToSubtasks: Bool
}

struct AutoLabelMapping: Codable {
    let mask: String
    let label: String
    let ignoreCase: Bool
}

struct QuickCaptureConfig: Codable {
    let parentTaskId: String
}

struct ProjectTask: Codable, Identifiable {
    let id: String
    let content: String
}

struct LabelProjectMapping: Codable {
    let label: String
    let project: String
    let section: String?
}

struct AutoRemoveStatus: Codable {
    let rules: [AutoRemoveRule]
    let paused: Bool
}

struct AutoRemoveRule: Codable {
    let label: String
    let ttl: Int
}
