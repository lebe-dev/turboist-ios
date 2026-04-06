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
    let labelProjectMap: LabelProjectMap
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
    let color: String?
    var sections: [ProjectSection]
}

struct ProjectSection: Identifiable, Codable {
    let id: String
    let name: String
    let projectId: String
    let order: Int?
}

struct TaskLabel: Identifiable, Codable {
    let id: String
    let name: String
    let color: String?
    let order: Int?
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

struct LabelProjectMap: Codable {
    let enabled: Bool
    let mappings: [LabelProjectMapping]
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

// MARK: - Lenient decoders
//
// Go's `encoding/json` marshals nil slices and maps as `null`, and fields may
// be missing entirely. These custom decoders treat null/missing collections as
// empty and null/missing scalars as sane defaults so a single backend tweak
// can't crash the whole iOS decode pipeline.

extension AppConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decode(AppSettings.self, forKey: .settings)
        contexts = try c.decodeIfPresent([TaskContext].self, forKey: .contexts) ?? []
        projects = try c.decodeIfPresent([Project].self, forKey: .projects) ?? []
        labels = try c.decodeIfPresent([TaskLabel].self, forKey: .labels) ?? []
        labelConfigs = try c.decodeIfPresent([LabelConfig].self, forKey: .labelConfigs) ?? []
        autoLabels = try c.decodeIfPresent([AutoLabelMapping].self, forKey: .autoLabels) ?? []
        quickCapture = try c.decodeIfPresent(QuickCaptureConfig.self, forKey: .quickCapture)
        projectTasks = try c.decodeIfPresent([ProjectTask].self, forKey: .projectTasks) ?? []
        labelProjectMap = try c.decodeIfPresent(LabelProjectMap.self, forKey: .labelProjectMap)
            ?? LabelProjectMap(enabled: false, mappings: [])
        autoRemove = try c.decodeIfPresent(AutoRemoveStatus.self, forKey: .autoRemove)
            ?? AutoRemoveStatus(rules: [], paused: false)
        state = try c.decode(UserState.self, forKey: .state)
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pollInterval = try c.decodeIfPresent(Int.self, forKey: .pollInterval) ?? 0
        syncInterval = try c.decodeIfPresent(Int.self, forKey: .syncInterval) ?? 0
        timezone = try c.decodeIfPresent(String.self, forKey: .timezone) ?? "UTC"
        weeklyLabel = try c.decodeIfPresent(String.self, forKey: .weeklyLabel) ?? ""
        backlogLabel = try c.decodeIfPresent(String.self, forKey: .backlogLabel) ?? ""
        projectLabel = try c.decodeIfPresent(String.self, forKey: .projectLabel) ?? ""
        projectsLabel = try c.decodeIfPresent(String.self, forKey: .projectsLabel) ?? ""
        weeklyLimit = try c.decodeIfPresent(Int.self, forKey: .weeklyLimit) ?? 0
        backlogLimit = try c.decodeIfPresent(Int.self, forKey: .backlogLimit) ?? 0
        completedDays = try c.decodeIfPresent(Int.self, forKey: .completedDays) ?? 0
        maxPinned = try c.decodeIfPresent(Int.self, forKey: .maxPinned) ?? 0
        lastSyncedAt = try c.decodeIfPresent(String.self, forKey: .lastSyncedAt)
        dayParts = try c.decodeIfPresent([DayPart].self, forKey: .dayParts) ?? []
        maxDayPartNoteLength = try c.decodeIfPresent(Int.self, forKey: .maxDayPartNoteLength) ?? 0
        inboxProjectId = try c.decodeIfPresent(String.self, forKey: .inboxProjectId) ?? ""
        inboxLimit = try c.decodeIfPresent(Int.self, forKey: .inboxLimit) ?? 0
        inboxOverflowTaskContent = try c.decodeIfPresent(String.self, forKey: .inboxOverflowTaskContent) ?? ""
    }
}

extension Project {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color)
        sections = try c.decodeIfPresent([ProjectSection].self, forKey: .sections) ?? []
    }
}

extension ProjectSection {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId) ?? ""
        order = try c.decodeIfPresent(Int.self, forKey: .order)
    }
}

extension TaskLabel {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color)
        order = try c.decodeIfPresent(Int.self, forKey: .order)
    }
}

extension TaskContext {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        color = try c.decodeIfPresent(String.self, forKey: .color)
        inheritLabels = try c.decodeIfPresent(Bool.self, forKey: .inheritLabels) ?? false
        filters = try c.decodeIfPresent(ContextFilters.self, forKey: .filters)
            ?? ContextFilters(projects: [], sections: [], labels: [])
    }
}

extension ContextFilters {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projects = try c.decodeIfPresent([String].self, forKey: .projects) ?? []
        sections = try c.decodeIfPresent([String].self, forKey: .sections) ?? []
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
    }
}

extension UserState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinnedTasks = try c.decodeIfPresent([PinnedTask].self, forKey: .pinnedTasks) ?? []
        activeContextId = try c.decodeIfPresent(String.self, forKey: .activeContextId) ?? ""
        activeView = try c.decodeIfPresent(String.self, forKey: .activeView) ?? ""
        collapsedIds = try c.decodeIfPresent([String].self, forKey: .collapsedIds) ?? []
        sidebarCollapsed = try c.decodeIfPresent(Bool.self, forKey: .sidebarCollapsed) ?? false
        planningOpen = try c.decodeIfPresent(Bool.self, forKey: .planningOpen) ?? false
        dayPartNotes = try c.decodeIfPresent([String: String].self, forKey: .dayPartNotes) ?? [:]
        locale = try c.decodeIfPresent(String.self, forKey: .locale) ?? ""
        allFilters = try c.decodeIfPresent(AllFiltersState.self, forKey: .allFilters)
    }
}

extension AllFiltersState {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        selectedPriorities = try c.decodeIfPresent([Int].self, forKey: .selectedPriorities) ?? []
        selectedLabels = try c.decodeIfPresent([String].self, forKey: .selectedLabels) ?? []
        linksOnly = try c.decodeIfPresent(Bool.self, forKey: .linksOnly) ?? false
        filtersExpanded = try c.decodeIfPresent(Bool.self, forKey: .filtersExpanded) ?? false
    }
}

extension LabelConfig {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        inheritToSubtasks = try c.decodeIfPresent(Bool.self, forKey: .inheritToSubtasks) ?? false
    }
}

extension AutoLabelMapping {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mask = try c.decodeIfPresent(String.self, forKey: .mask) ?? ""
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        ignoreCase = try c.decodeIfPresent(Bool.self, forKey: .ignoreCase) ?? false
    }
}

extension LabelProjectMap {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        mappings = try c.decodeIfPresent([LabelProjectMapping].self, forKey: .mappings) ?? []
    }
}

extension AutoRemoveStatus {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rules = try c.decodeIfPresent([AutoRemoveRule].self, forKey: .rules) ?? []
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
    }
}

extension TasksMeta {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        context = try c.decodeIfPresent(String.self, forKey: .context) ?? ""
        weeklyLimit = try c.decodeIfPresent(Int.self, forKey: .weeklyLimit) ?? 0
        weeklyCount = try c.decodeIfPresent(Int.self, forKey: .weeklyCount) ?? 0
        backlogLimit = try c.decodeIfPresent(Int.self, forKey: .backlogLimit) ?? 0
        backlogCount = try c.decodeIfPresent(Int.self, forKey: .backlogCount) ?? 0
        inboxCount = try c.decodeIfPresent(Int.self, forKey: .inboxCount)
        lastSyncedAt = try c.decodeIfPresent(String.self, forKey: .lastSyncedAt)
    }
}

extension DayPart {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        start = try c.decodeIfPresent(Int.self, forKey: .start) ?? 0
        end = try c.decodeIfPresent(Int.self, forKey: .end) ?? 0
    }
}
