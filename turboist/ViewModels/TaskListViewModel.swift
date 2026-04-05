import Foundation
import SwiftUI

@Observable
final class TaskListViewModel {
    var tasks: [TaskItem] = []
    var meta: TasksMeta?
    var isLoading = false
    var error: String?
    var currentView: TaskView = .all
    var collapsedIds: Set<String> = []
    var selectedPriorities: Set<Int> = []
    var selectedLabels: Set<String> = []
    var linksOnly = false
    var activeContextId: String?
    var searchText = ""
    var nextActionPrompt: NextActionPrompt?

    var searchableView: Bool {
        currentView == .all || currentView == .backlog
    }

    var displayTasks: [DisplayTask] {
        var result = tasks
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = filterBySearch(result, query: query)
        }
        if !selectedPriorities.isEmpty {
            result = filterByPriority(result, priorities: selectedPriorities)
        }
        if !selectedLabels.isEmpty {
            result = filterByLabels(result, labels: selectedLabels)
        }
        if linksOnly {
            result = filterByLinks(result)
        }
        return flattenForDisplay(result, collapsedIds: collapsedIds)
    }

    var isFiltering: Bool {
        !selectedPriorities.isEmpty || !selectedLabels.isEmpty || linksOnly
    }

    var isSearching: Bool {
        !searchText.isEmpty
    }

    let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    func setCollapsedIds(_ ids: [String]) {
        collapsedIds = Set(ids)
    }

    @MainActor
    func toggleCollapsed(_ taskId: String) async {
        if collapsedIds.contains(taskId) {
            collapsedIds.remove(taskId)
        } else {
            collapsedIds.insert(taskId)
        }
        do {
            try await repository.patchState(PatchStateRequest(collapsedIds: Array(collapsedIds)))
        } catch {
            // State sync failure is non-critical, keep local state
        }
    }

    @MainActor
    func loadTasks(view: TaskView = .all, context: String? = nil) async {
        let effectiveContext = context ?? activeContextId
        isLoading = true
        error = nil
        do {
            let response = try await repository.fetchTasks(view: view, context: effectiveContext)
            tasks = response.tasks
            meta = response.meta
            currentView = view
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    func switchContext(_ contextId: String?) async {
        activeContextId = contextId
        clearAllFilters()
        searchText = ""
        await loadTasks(view: currentView)
    }

    @MainActor
    func completeTask(_ task: TaskItem) async {
        // Build next action prompt before removing
        if let parentId = task.parentId {
            let parentContent = findTask(by: parentId)?.content ?? ""
            nextActionPrompt = NextActionPrompt(
                parentId: parentId,
                parentContent: parentContent,
                completedTaskLabels: task.labels,
                completedTaskContent: task.content
            )
        } else if task.subTaskCount > 0 || !task.children.isEmpty {
            nextActionPrompt = NextActionPrompt(
                parentId: task.id,
                parentContent: task.content,
                completedTaskLabels: task.labels,
                completedTaskContent: task.content
            )
        } else {
            nextActionPrompt = nil
        }

        removeTaskRecursive(task.id, from: &tasks)
        do {
            try await repository.completeTask(id: task.id)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    func dismissNextAction() {
        nextActionPrompt = nil
    }

    @MainActor
    func deleteTask(_ task: TaskItem) async {
        removeTaskRecursive(task.id, from: &tasks)
        do {
            try await repository.deleteTask(id: task.id)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    @MainActor
    func duplicateTask(_ task: TaskItem) async {
        do {
            _ = try await repository.duplicateTask(id: task.id)
            await loadTasks(view: currentView)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func moveTask(_ task: TaskItem, parentId: String) async {
        do {
            try await repository.moveTask(id: task.id, parentId: parentId)
            await loadTasks(view: currentView)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func updateTaskPriority(_ task: TaskItem, priority: Int) async {
        updateTaskPriorityLocally(task.id, priority: priority, in: &tasks)
        let request = UpdateTaskRequest(priority: priority)
        do {
            try await repository.updateTask(id: task.id, request)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    @MainActor
    func updateTaskDueDate(_ task: TaskItem, dueDate: String) async {
        updateTaskDueDateLocally(task.id, dueDate: dueDate, in: &tasks)
        let request = UpdateTaskRequest(dueDate: dueDate)
        do {
            try await repository.updateTask(id: task.id, request)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    private func removeTaskRecursive(_ taskId: String, from tasks: inout [TaskItem]) {
        if tasks.contains(where: { $0.id == taskId }) {
            tasks.removeAll { $0.id == taskId }
            return
        }
        for i in tasks.indices {
            removeTaskRecursive(taskId, from: &tasks[i].children)
        }
    }

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

    @MainActor
    func batchUpdateLabels(_ updates: [String: [String]]) async {
        // Optimistic update
        for (taskId, newLabels) in updates {
            updateTaskLabelsLocally(taskId, labels: newLabels, in: &tasks)
        }
        do {
            _ = try await repository.batchUpdateLabels(updates)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    private func updateTaskLabelsLocally(_ taskId: String, labels: [String], in tasks: inout [TaskItem]) {
        for i in tasks.indices {
            if tasks[i].id == taskId {
                tasks[i].labels = labels
                return
            }
            updateTaskLabelsLocally(taskId, labels: labels, in: &tasks[i].children)
        }
    }

    func togglePriorityFilter(_ priority: Int) {
        if selectedPriorities.contains(priority) {
            selectedPriorities.remove(priority)
        } else {
            selectedPriorities.insert(priority)
        }
        persistFilters()
    }

    func toggleLabelFilter(_ label: String) {
        if selectedLabels.contains(label) {
            selectedLabels.remove(label)
        } else {
            selectedLabels.insert(label)
        }
        persistFilters()
    }

    func toggleLinksOnly() {
        linksOnly.toggle()
        persistFilters()
    }

    func clearAllFilters() {
        selectedPriorities.removeAll()
        selectedLabels.removeAll()
        linksOnly = false
        persistFilters()
    }

    func restoreFilters(from state: AllFiltersState) {
        selectedPriorities = Set(state.selectedPriorities)
        selectedLabels = Set(state.selectedLabels)
        linksOnly = state.linksOnly
    }

    private func persistFilters() {
        let filters = AllFiltersState(
            selectedPriorities: Array(selectedPriorities),
            selectedLabels: Array(selectedLabels),
            linksOnly: linksOnly,
            filtersExpanded: false
        )
        Task {
            try? await repository.patchState(PatchStateRequest(allFilters: filters))
        }
    }

    func findTask(by id: String) -> TaskItem? {
        findTaskRecursive(id: id, in: tasks)
    }

    private func findTaskRecursive(id: String, in tasks: [TaskItem]) -> TaskItem? {
        for task in tasks {
            if task.id == id { return task }
            if let found = findTaskRecursive(id: id, in: task.children) { return found }
        }
        return nil
    }

    private func filterBySearch(_ tasks: [TaskItem], query: String) -> [TaskItem] {
        tasks.compactMap { task in
            let filteredChildren = filterBySearch(task.children, query: query)
            if task.content.lowercased().contains(query) || !filteredChildren.isEmpty {
                var filtered = task
                filtered.children = filteredChildren
                return filtered
            }
            return nil
        }
    }

    private func filterByPriority(_ tasks: [TaskItem], priorities: Set<Int>) -> [TaskItem] {
        tasks.compactMap { task in
            let filteredChildren = filterByPriority(task.children, priorities: priorities)
            if priorities.contains(task.priority) || !filteredChildren.isEmpty {
                var filtered = task
                filtered.children = filteredChildren
                return filtered
            }
            return nil
        }
    }

    private static let linkRegex = try! NSRegularExpression(pattern: "https?://\\S+")

    private func filterByLabels(_ tasks: [TaskItem], labels: Set<String>) -> [TaskItem] {
        tasks.compactMap { task in
            let filteredChildren = filterByLabels(task.children, labels: labels)
            if task.labels.contains(where: { labels.contains($0) }) || !filteredChildren.isEmpty {
                var filtered = task
                filtered.children = filteredChildren
                return filtered
            }
            return nil
        }
    }

    private func filterByLinks(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.compactMap { task in
            let filteredChildren = filterByLinks(task.children)
            let range = NSRange(task.content.startIndex..., in: task.content)
            let hasLink = Self.linkRegex.firstMatch(in: task.content, range: range) != nil
            if hasLink || !filteredChildren.isEmpty {
                var filtered = task
                filtered.children = filteredChildren
                return filtered
            }
            return nil
        }
    }
}
