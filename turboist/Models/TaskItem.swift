import Foundation

struct TaskItem: Identifiable, Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: String
    var content: String
    var description: String
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var labels: [String]
    var priority: Int
    var due: Due?
    var subTaskCount: Int
    var completedSubTaskCount: Int
    var completedAt: String?
    var addedAt: String
    var isProjectTask: Bool
    var postponeCount: Int
    var expiresAt: String?
    var children: [TaskItem]
}

struct Due: Codable, Equatable {
    let date: String
    let recurring: Bool
}
