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

    var displayTasks: [DisplayTask] {
        flattenForDisplay(tasks, collapsedIds: collapsedIds)
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
        isLoading = true
        error = nil
        do {
            let response = try await repository.fetchTasks(view: view, context: context)
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
    func completeTask(_ task: TaskItem) async {
        tasks.removeAll { $0.id == task.id }
        do {
            try await repository.completeTask(id: task.id)
        } catch {
            await loadTasks(view: currentView)
        }
    }

    @MainActor
    func deleteTask(_ task: TaskItem) async {
        tasks.removeAll { $0.id == task.id }
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
}
