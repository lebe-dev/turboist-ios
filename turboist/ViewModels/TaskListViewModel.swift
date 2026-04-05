import Foundation
import SwiftUI

@Observable
final class TaskListViewModel {
    var tasks: [TaskItem] = []
    var meta: TasksMeta?
    var isLoading = false
    var error: String?
    var currentView: TaskView = .all

    let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
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
        // Optimistic removal
        tasks.removeAll { $0.id == task.id }
        do {
            try await repository.completeTask(id: task.id)
        } catch {
            // Revert on failure - reload
            await loadTasks(view: currentView)
        }
    }

    @MainActor
    func deleteTask(_ task: TaskItem) async {
        // Optimistic removal
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
}
