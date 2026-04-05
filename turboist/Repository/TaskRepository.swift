import Foundation

protocol TaskRepositoryProtocol {
    func fetchTasks(view: TaskView, context: String?) async throws -> TasksResponse
    func createTask(_ request: CreateTaskRequest) async throws -> CreateTaskResponse
    func updateTask(id: String, _ request: UpdateTaskRequest) async throws
    func deleteTask(id: String) async throws
    func completeTask(id: String) async throws
    func duplicateTask(id: String) async throws -> CreateTaskResponse
    func decomposeTask(id: String, subtasks: [String]) async throws
    func moveTask(id: String, parentId: String) async throws
    func fetchCompletedSubtasks(id: String) async throws -> [TaskItem]
}

final class TaskRepository: TaskRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTasks(view: TaskView, context: String?) async throws -> TasksResponse {
        try await apiClient.fetchTasks(view: view, context: context)
    }

    func createTask(_ request: CreateTaskRequest) async throws -> CreateTaskResponse {
        try await apiClient.createTask(request)
    }

    func updateTask(id: String, _ request: UpdateTaskRequest) async throws {
        let _: OkResponse = try await apiClient.updateTask(id: id, request)
    }

    func deleteTask(id: String) async throws {
        let _: OkResponse = try await apiClient.deleteTask(id: id)
    }

    func completeTask(id: String) async throws {
        let _: OkResponse = try await apiClient.completeTask(id: id)
    }

    func duplicateTask(id: String) async throws -> CreateTaskResponse {
        try await apiClient.duplicateTask(id: id)
    }

    func decomposeTask(id: String, subtasks: [String]) async throws {
        let _: OkResponse = try await apiClient.decomposeTask(id: id, DecomposeRequest(tasks: subtasks))
    }

    func moveTask(id: String, parentId: String) async throws {
        let _: OkResponse = try await apiClient.moveTask(id: id, MoveTaskRequest(parentId: parentId))
    }

    func fetchCompletedSubtasks(id: String) async throws -> [TaskItem] {
        let response = try await apiClient.fetchCompletedSubtasks(id: id)
        return response.tasks
    }
}
