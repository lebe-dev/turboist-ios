import Foundation

@Observable
final class TaskDetailViewModel {
    var task: TaskItem?
    var completedSubtasks: [TaskItem] = []
    var isLoading = false
    var isSaving = false
    var error: String?

    private let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    func setTask(_ task: TaskItem) {
        self.task = task
    }

    @MainActor
    func loadCompletedSubtasks() async {
        guard let task else { return }
        do {
            completedSubtasks = try await repository.fetchCompletedSubtasks(id: task.id)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    func updateTask(content: String? = nil, description: String? = nil, priority: Int? = nil,
                    labels: [String]? = nil, dueDate: String? = nil, dueString: String? = nil) async {
        guard let task else { return }
        isSaving = true
        let request = UpdateTaskRequest(
            content: content,
            description: description,
            labels: labels,
            priority: priority,
            dueDate: dueDate,
            dueString: dueString
        )
        do {
            try await repository.updateTask(id: task.id, request)
            // Update local state optimistically
            if let content { self.task?.content = content }
            if let description { self.task?.description = description }
            if let priority { self.task?.priority = priority }
            if let labels { self.task?.labels = labels }
            if let dueDate { self.task?.due = Due(date: dueDate, recurring: self.task?.due?.recurring ?? false) }
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    @MainActor
    func decomposeTask(subtasks: [String]) async -> Bool {
        guard let task else { return false }
        do {
            try await repository.decomposeTask(id: task.id, subtasks: subtasks)
            return true
        } catch let apiError as APIError {
            error = apiError.errorDescription
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
