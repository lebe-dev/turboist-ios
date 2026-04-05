import Foundation

// MARK: - Request types

struct CreateTaskRequest: Codable {
    let content: String
    var description: String = ""
    var labels: [String] = []
    var priority: Int = 1
    var parentId: String?
    var dueDate: String?
    var dueString: String?
}

struct UpdateTaskRequest: Codable {
    var content: String?
    var description: String?
    var labels: [String]?
    var priority: Int?
    var dueDate: String?
    var dueString: String?
}

struct DecomposeRequest: Codable {
    let tasks: [String]
}

struct BatchUpdateLabelsRequest: Codable {
    let updates: [String: [String]]
}

struct MoveTaskRequest: Codable {
    let parentId: String
}

struct LoginRequest: Codable {
    let password: String
}

struct PatchStateRequest: Codable {
    var collapsedIds: [String]?
    var activeContextId: String?
    var activeView: String?
    var dayPartNotes: [String: String]?
}

// MARK: - Response types

struct TasksResponse: Codable {
    let tasks: [TaskItem]
    let meta: TasksMeta
}

struct CompletedSubtasksResponse: Codable {
    let tasks: [TaskItem]
}

struct OkResponse: Codable {
    let ok: Bool
}

struct CreateTaskResponse: Codable {
    let ok: Bool
    let id: String
}

struct BatchUpdateLabelsResponse: Codable {
    let ok: Bool
    let updated: Int
}

struct AuthMeResponse: Codable {
    let authenticated: Bool
}
