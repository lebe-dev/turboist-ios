import SwiftUI

@Observable
final class AppConfigStore {
    var config: AppConfig?
    var onContextChanged: ((String?) -> Void)?

    var labels: [TaskLabel] {
        config?.labels ?? []
    }

    var labelConfigs: [LabelConfig] {
        config?.labelConfigs ?? []
    }

    var autoLabels: [AutoLabelMapping] {
        config?.autoLabels ?? []
    }

    var compiledAutoLabels: [CompiledAutoLabel] {
        AutoLabelMatcher.compile(autoLabels)
    }

    var contexts: [TaskContext] {
        config?.contexts ?? []
    }

    var activeView: TaskView {
        guard let viewStr = config?.state.activeView,
              let view = TaskView(rawValue: viewStr) else { return .all }
        return view
    }

    var activeContextId: String {
        config?.state.activeContextId ?? ""
    }

    var activeContext: TaskContext? {
        guard !activeContextId.isEmpty else { return nil }
        return contexts.first { $0.id == activeContextId }
    }

    func contextLabels(for contextId: String) -> [String] {
        guard let context = contexts.first(where: { $0.id == contextId }),
              context.inheritLabels else { return [] }
        return context.filters.labels
    }

    func activeContextLabels() -> [String] {
        guard let context = activeContext, context.inheritLabels else { return [] }
        return context.filters.labels
    }

    func labelColor(_ name: String) -> Color? {
        guard let label = labels.first(where: { $0.name == name }) else { return nil }
        return Color(hex: label.color)
    }

    func shouldInheritToSubtasks(_ labelName: String) -> Bool {
        labelConfigs.first(where: { $0.name == labelName })?.inheritToSubtasks ?? false
    }

    func setConfig(_ config: AppConfig) {
        self.config = config
    }

    var settings: AppSettings? {
        config?.settings
    }

    var autoRemovePaused: Bool {
        config?.autoRemove.paused ?? false
    }

    var meta: TasksMeta? {
        nil // meta comes from task responses, not config
    }

    func setActiveView(_ view: TaskView, repository: TaskRepositoryProtocol) {
        guard view.rawValue != (config?.state.activeView ?? "all") else { return }
        config?.state.activeView = view.rawValue
        Task {
            try? await repository.patchState(PatchStateRequest(activeView: view.rawValue))
        }
    }

    var dayPartNotes: [String: String] {
        config?.state.dayPartNotes ?? [:]
    }

    var dayParts: [DayPart] {
        config?.settings.dayParts ?? []
    }

    var maxDayPartNoteLength: Int {
        config?.settings.maxDayPartNoteLength ?? 200
    }

    func setDayPartNote(_ label: String, text: String, repository: TaskRepositoryProtocol) {
        let trimmed = String(text.prefix(maxDayPartNoteLength))
        if trimmed.isEmpty {
            config?.state.dayPartNotes.removeValue(forKey: label)
        } else {
            config?.state.dayPartNotes[label] = trimmed
        }
        let notes = config?.state.dayPartNotes ?? [:]
        Task {
            try? await repository.patchState(PatchStateRequest(dayPartNotes: notes))
        }
    }

    func setActiveContext(_ contextId: String?, repository: TaskRepositoryProtocol) {
        let newId = contextId ?? ""
        guard newId != activeContextId else { return }
        config?.state.activeContextId = newId
        onContextChanged?(contextId)
        Task {
            try? await repository.patchState(PatchStateRequest(activeContextId: newId))
        }
    }

    // MARK: - Pinned Tasks

    var pinnedTasks: [PinnedTask] {
        config?.state.pinnedTasks ?? []
    }

    var maxPinned: Int {
        config?.settings.maxPinned ?? 5
    }

    func isTaskPinned(_ taskId: String) -> Bool {
        pinnedTasks.contains { $0.id == taskId }
    }

    func pinTask(_ task: TaskItem, repository: TaskRepositoryProtocol) {
        guard !isTaskPinned(task.id) else { return }
        guard pinnedTasks.count < maxPinned else { return }
        let pinned = PinnedTask(id: task.id, content: task.content)
        config?.state.pinnedTasks.append(pinned)
        let updated = config?.state.pinnedTasks ?? []
        Task {
            try? await repository.patchState(PatchStateRequest(pinnedTasks: updated))
        }
    }

    func unpinTask(_ taskId: String, repository: TaskRepositoryProtocol) {
        guard isTaskPinned(taskId) else { return }
        config?.state.pinnedTasks.removeAll { $0.id == taskId }
        let updated = config?.state.pinnedTasks ?? []
        Task {
            try? await repository.patchState(PatchStateRequest(pinnedTasks: updated))
        }
    }

    func togglePinTask(_ task: TaskItem, repository: TaskRepositoryProtocol) {
        if isTaskPinned(task.id) {
            unpinTask(task.id, repository: repository)
        } else {
            pinTask(task, repository: repository)
        }
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else { return nil }
        var rgbValue: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&rgbValue) else { return nil }
        self.init(
            red: Double((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: Double((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgbValue & 0x0000FF) / 255.0
        )
    }
}
