import Foundation

@Observable
final class PlanningViewModel {
    var backlogTasks: [TaskItem] = []
    var weeklyTasks: [TaskItem] = []
    var meta: TasksMeta?
    var isLoading = false
    var error: String?
    var searchText = ""
    var mobileTab: PlanningTab = .backlog
    var isStartingWeek = false
    var isAcceptingAll = false

    let repository: TaskRepositoryProtocol

    private var backlogLabel: String = "backlog"
    private var weeklyLabel: String = "weekly"
    private var weeklyLimit: Int = 0

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    var filteredBacklogTasks: [TaskItem] {
        guard !searchText.isEmpty else { return backlogTasks }
        let query = searchText.lowercased()
        return backlogTasks.filter { $0.content.lowercased().contains(query) }
    }

    var weeklyCount: Int {
        meta?.weeklyCount ?? 0
    }

    var weeklyLimitValue: Int {
        meta?.weeklyLimit ?? weeklyLimit
    }

    var backlogCount: Int {
        meta?.backlogCount ?? backlogTasks.count
    }

    var backlogLimitValue: Int {
        meta?.backlogLimit ?? 0
    }

    var isAtLimit: Bool {
        guard weeklyLimitValue > 0 else { return false }
        return weeklyCount >= weeklyLimitValue
    }

    func configure(settings: AppSettings) {
        backlogLabel = settings.backlogLabel
        weeklyLabel = settings.weeklyLabel
        weeklyLimit = settings.weeklyLimit
    }

    // MARK: - Data Loading

    @MainActor
    func enter(contextId: String?) async {
        isLoading = true
        error = nil
        await loadBothTabs(contextId: contextId)
        isLoading = false
    }

    @MainActor
    func refresh(contextId: String?) async {
        await loadBothTabs(contextId: contextId)
    }

    @MainActor
    private func loadBothTabs(contextId: String?) async {
        do {
            async let backlogResponse = repository.fetchTasks(view: .backlog, context: contextId)
            async let weeklyResponse = repository.fetchTasks(view: .weekly, context: contextId)
            let (bl, wk) = try await (backlogResponse, weeklyResponse)
            backlogTasks = bl.tasks
            weeklyTasks = wk.tasks
            meta = wk.meta
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Move Backlog → Weekly

    @MainActor
    func moveToWeekly(_ task: TaskItem) async {
        guard !isAtLimit else { return }

        var newLabels = task.labels.filter { $0 != backlogLabel }
        if !newLabels.contains(weeklyLabel) {
            newLabels.append(weeklyLabel)
        }

        // Optimistic update
        backlogTasks.removeAll { $0.id == task.id }
        var movedTask = task
        movedTask.labels = newLabels
        weeklyTasks.append(movedTask)
        meta?.weeklyCount += 1
        meta?.backlogCount -= 1

        do {
            _ = try await repository.batchUpdateLabels([task.id: newLabels])
        } catch {
            await refresh(contextId: meta?.context)
        }
    }

    // MARK: - Accept All (Backlog → Weekly)

    @MainActor
    func acceptAll() async {
        guard !backlogTasks.isEmpty, !isAtLimit else { return }
        isAcceptingAll = true

        let remaining = weeklyLimitValue > 0 ? max(0, weeklyLimitValue - weeklyCount) : backlogTasks.count
        let tasksToMove = Array(backlogTasks.prefix(remaining))

        var updates: [String: [String]] = [:]
        var movedTasks: [TaskItem] = []

        for task in tasksToMove {
            var newLabels = task.labels.filter { $0 != backlogLabel }
            if !newLabels.contains(weeklyLabel) {
                newLabels.append(weeklyLabel)
            }
            updates[task.id] = newLabels
            var moved = task
            moved.labels = newLabels
            movedTasks.append(moved)
        }

        // Optimistic update
        let movedCount = tasksToMove.count
        let movedIds = Set(tasksToMove.map(\.id))
        backlogTasks.removeAll { movedIds.contains($0.id) }
        weeklyTasks.append(contentsOf: movedTasks)
        meta?.weeklyCount += movedCount
        meta?.backlogCount = max(0, (meta?.backlogCount ?? 0) - movedCount)

        do {
            _ = try await repository.batchUpdateLabels(updates)
        } catch {
            await refresh(contextId: meta?.context)
        }
        isAcceptingAll = false
    }

    // MARK: - Start Week (Reset Weekly)

    @MainActor
    func startWeek() async {
        isStartingWeek = true

        // Optimistic update
        weeklyTasks.removeAll()
        meta?.weeklyCount = 0

        do {
            try await repository.resetWeekly()
        } catch {
            await refresh(contextId: meta?.context)
        }
        isStartingWeek = false
    }

    // MARK: - Quick Actions (Weekly)

    @MainActor
    func updateWeeklyTaskPriority(_ task: TaskItem, priority: Int) async {
        updateTaskPriorityLocally(task.id, priority: priority, in: &weeklyTasks)
        do {
            try await repository.updateTask(id: task.id, UpdateTaskRequest(priority: priority))
        } catch {
            await refresh(contextId: meta?.context)
        }
    }

    @MainActor
    func updateWeeklyTaskDueDate(_ task: TaskItem, dueDate: String) async {
        updateTaskDueDateLocally(task.id, dueDate: dueDate, in: &weeklyTasks)
        let request = UpdateTaskRequest(dueDate: dueDate)
        do {
            try await repository.updateTask(id: task.id, request)
        } catch {
            await refresh(contextId: meta?.context)
        }
    }

    @MainActor
    func completeTask(_ task: TaskItem) async {
        backlogTasks.removeAll { $0.id == task.id }
        weeklyTasks.removeAll { $0.id == task.id }
        do {
            try await repository.completeTask(id: task.id)
        } catch {
            await refresh(contextId: meta?.context)
        }
    }

    // MARK: - Private Helpers

    private func updateTaskPriorityLocally(_ taskId: String, priority: Int, in tasks: inout [TaskItem]) {
        for i in tasks.indices {
            if tasks[i].id == taskId {
                tasks[i].priority = priority
                return
            }
            updateTaskPriorityLocally(taskId, priority: priority, in: &tasks[i].children)
        }
    }

    private func updateTaskDueDateLocally(_ taskId: String, dueDate: String, in tasks: inout [TaskItem]) {
        for i in tasks.indices {
            if tasks[i].id == taskId {
                tasks[i].due = dueDate.isEmpty ? nil : Due(date: dueDate, recurring: tasks[i].due?.recurring ?? false)
                return
            }
            updateTaskDueDateLocally(taskId, dueDate: dueDate, in: &tasks[i].children)
        }
    }
}

enum PlanningTab: String, CaseIterable {
    case backlog
    case weekly

    var displayName: String {
        switch self {
        case .backlog: return "Backlog"
        case .weekly: return "Weekly"
        }
    }

    var icon: String {
        switch self {
        case .backlog: return "archivebox"
        case .weekly: return "calendar.badge.clock"
        }
    }
}
