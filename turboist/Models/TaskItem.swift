import Foundation

struct TaskItem: Identifiable, Codable, Hashable {
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

extension TaskItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = try c.decodeIfPresent(String.self, forKey: .content) ?? ""
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        projectId = try c.decodeIfPresent(String.self, forKey: .projectId) ?? ""
        sectionId = try c.decodeIfPresent(String.self, forKey: .sectionId)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        labels = try c.decodeIfPresent([String].self, forKey: .labels) ?? []
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        due = try c.decodeIfPresent(Due.self, forKey: .due)
        subTaskCount = try c.decodeIfPresent(Int.self, forKey: .subTaskCount) ?? 0
        completedSubTaskCount = try c.decodeIfPresent(Int.self, forKey: .completedSubTaskCount) ?? 0
        completedAt = try c.decodeIfPresent(String.self, forKey: .completedAt)
        addedAt = try c.decodeIfPresent(String.self, forKey: .addedAt) ?? ""
        isProjectTask = try c.decodeIfPresent(Bool.self, forKey: .isProjectTask) ?? false
        postponeCount = try c.decodeIfPresent(Int.self, forKey: .postponeCount) ?? 0
        expiresAt = try c.decodeIfPresent(String.self, forKey: .expiresAt)
        children = try c.decodeIfPresent([TaskItem].self, forKey: .children) ?? []
    }
}

struct Due: Codable, Hashable {
    let date: String
    let recurring: Bool
}

extension Due {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        date = try c.decodeIfPresent(String.self, forKey: .date) ?? ""
        recurring = try c.decodeIfPresent(Bool.self, forKey: .recurring) ?? false
    }
}
