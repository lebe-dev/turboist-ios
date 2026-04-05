import Foundation

struct FlatTask: Identifiable, Codable, Equatable {
    let id: String
    var content: String
    var description: String
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var labels: [String]
    var priority: Int
    var dueDate: String?
    var dueRecurring: Bool
    var subTaskCount: Int
    var completedSubTaskCount: Int
    var completedAt: String?
    var addedAt: String
    var isProjectTask: Bool
    var postponeCount: Int
    var expiresAt: String?
}

// MARK: - Conversion functions

func taskToFlat(_ task: TaskItem) -> FlatTask {
    FlatTask(
        id: task.id,
        content: task.content,
        description: task.description,
        projectId: task.projectId,
        sectionId: task.sectionId,
        parentId: task.parentId,
        labels: task.labels,
        priority: task.priority,
        dueDate: task.due?.date,
        dueRecurring: task.due?.recurring ?? false,
        subTaskCount: task.subTaskCount,
        completedSubTaskCount: task.completedSubTaskCount,
        completedAt: task.completedAt,
        addedAt: task.addedAt,
        isProjectTask: task.isProjectTask,
        postponeCount: task.postponeCount,
        expiresAt: task.expiresAt
    )
}

func flatToTask(_ flat: FlatTask, children: [TaskItem] = []) -> TaskItem {
    let due: Due? = flat.dueDate.map { Due(date: $0, recurring: flat.dueRecurring) }
    return TaskItem(
        id: flat.id,
        content: flat.content,
        description: flat.description,
        projectId: flat.projectId,
        sectionId: flat.sectionId,
        parentId: flat.parentId,
        labels: flat.labels,
        priority: flat.priority,
        due: due,
        subTaskCount: flat.subTaskCount,
        completedSubTaskCount: flat.completedSubTaskCount,
        completedAt: flat.completedAt,
        addedAt: flat.addedAt,
        isProjectTask: flat.isProjectTask,
        postponeCount: flat.postponeCount,
        expiresAt: flat.expiresAt,
        children: children
    )
}

func flattenTasks(_ tasks: [TaskItem]) -> [FlatTask] {
    var result: [FlatTask] = []
    for task in tasks {
        result.append(taskToFlat(task))
        result.append(contentsOf: flattenTasks(task.children))
    }
    return result
}

struct DisplayTask: Identifiable {
    let task: TaskItem
    let depth: Int
    let hasChildren: Bool

    var id: String { task.id }
}

func flattenForDisplay(_ tasks: [TaskItem], collapsedIds: Set<String>, depth: Int = 0) -> [DisplayTask] {
    var result: [DisplayTask] = []
    for task in tasks {
        let hasChildren = !task.children.isEmpty || task.subTaskCount > 0
        result.append(DisplayTask(task: task, depth: depth, hasChildren: hasChildren))
        if !task.children.isEmpty && !collapsedIds.contains(task.id) {
            result.append(contentsOf: flattenForDisplay(task.children, collapsedIds: collapsedIds, depth: depth + 1))
        }
    }
    return result
}

func buildTree(from flats: [FlatTask]) -> [TaskItem] {
    var childrenMap: [String: [FlatTask]] = [:]
    var roots: [FlatTask] = []

    for flat in flats {
        if let parentId = flat.parentId {
            childrenMap[parentId, default: []].append(flat)
        } else {
            roots.append(flat)
        }
    }

    func build(_ flat: FlatTask) -> TaskItem {
        let kids = childrenMap[flat.id] ?? []
        return flatToTask(flat, children: kids.map { build($0) })
    }

    return roots.map { build($0) }
}
