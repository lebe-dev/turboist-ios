import Testing
@testable import turboist

// MARK: - Mock Repository

final class MockTaskRepository: TaskRepositoryProtocol {
    var fetchTasksResult: TasksResponse?
    var fetchTasksError: Error?
    var createTaskResult: CreateTaskResponse?
    var createTaskError: Error?
    var updateTaskCalled = false
    var deleteTaskCalled = false
    var completeTaskCalled = false
    var duplicateTaskResult: CreateTaskResponse?
    var decomposeTaskCalled = false
    var moveTaskCalled = false
    var completedSubtasksResult: [TaskItem] = []

    var lastCreateRequest: CreateTaskRequest?
    var lastUpdateRequest: UpdateTaskRequest?
    var lastUpdateId: String?
    var lastDeleteId: String?
    var lastCompleteId: String?
    var lastDuplicateId: String?
    var lastDecomposeId: String?
    var lastDecomposeSubtasks: [String]?
    var lastMoveId: String?
    var lastMoveParentId: String?

    func fetchTasks(view: TaskView, context: String?) async throws -> TasksResponse {
        if let error = fetchTasksError { throw error }
        return fetchTasksResult ?? TasksResponse(tasks: [], meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0))
    }

    func createTask(_ request: CreateTaskRequest) async throws -> CreateTaskResponse {
        lastCreateRequest = request
        if let error = createTaskError { throw error }
        return createTaskResult ?? CreateTaskResponse(ok: true, id: "new-id")
    }

    func updateTask(id: String, _ request: UpdateTaskRequest) async throws {
        lastUpdateId = id
        lastUpdateRequest = request
        updateTaskCalled = true
    }

    func deleteTask(id: String) async throws {
        lastDeleteId = id
        deleteTaskCalled = true
    }

    func completeTask(id: String) async throws {
        lastCompleteId = id
        completeTaskCalled = true
    }

    func duplicateTask(id: String) async throws -> CreateTaskResponse {
        lastDuplicateId = id
        return duplicateTaskResult ?? CreateTaskResponse(ok: true, id: "dup-id")
    }

    func decomposeTask(id: String, subtasks: [String]) async throws {
        lastDecomposeId = id
        lastDecomposeSubtasks = subtasks
        decomposeTaskCalled = true
    }

    func moveTask(id: String, parentId: String) async throws {
        lastMoveId = id
        lastMoveParentId = parentId
        moveTaskCalled = true
    }

    func fetchCompletedSubtasks(id: String) async throws -> [TaskItem] {
        completedSubtasksResult
    }
}

// MARK: - Test helpers

func makeTask(
    id: String = "task-1",
    content: String = "Test task",
    description: String = "",
    priority: Int = 1,
    labels: [String] = [],
    due: Due? = nil,
    parentId: String? = nil,
    children: [TaskItem] = []
) -> TaskItem {
    TaskItem(
        id: id,
        content: content,
        description: description,
        projectId: "proj-1",
        sectionId: nil,
        parentId: parentId,
        labels: labels,
        priority: priority,
        due: due,
        subTaskCount: children.count,
        completedSubTaskCount: 0,
        completedAt: nil,
        addedAt: "2026-01-01T00:00:00Z",
        isProjectTask: false,
        postponeCount: 0,
        expiresAt: nil,
        children: children
    )
}

// MARK: - FlatTask / Tree conversion tests

struct FlatTaskConversionTests {
    @Test func taskToFlatConvertsCorrectly() {
        let task = makeTask(id: "1", content: "Root", due: Due(date: "2026-01-15", recurring: true))
        let flat = taskToFlat(task)

        #expect(flat.id == "1")
        #expect(flat.content == "Root")
        #expect(flat.dueDate == "2026-01-15")
        #expect(flat.dueRecurring == true)
    }

    @Test func flatToTaskConvertsCorrectly() {
        let flat = FlatTask(
            id: "1", content: "Task", description: "", projectId: "p1",
            sectionId: nil, parentId: nil, labels: [], priority: 2,
            dueDate: "2026-02-01", dueRecurring: false,
            subTaskCount: 0, completedSubTaskCount: 0,
            completedAt: nil, addedAt: "2026-01-01", isProjectTask: false,
            postponeCount: 0, expiresAt: nil
        )
        let task = flatToTask(flat)

        #expect(task.id == "1")
        #expect(task.due?.date == "2026-02-01")
        #expect(task.due?.recurring == false)
        #expect(task.children.isEmpty)
    }

    @Test func flattenTasksHandlesTree() {
        let child = makeTask(id: "child-1", content: "Child", parentId: "root-1")
        let root = makeTask(id: "root-1", content: "Root", children: [child])

        let flats = flattenTasks([root])
        #expect(flats.count == 2)
        #expect(flats[0].id == "root-1")
        #expect(flats[1].id == "child-1")
    }

    @Test func buildTreeReconstructsHierarchy() {
        let rootFlat = FlatTask(
            id: "root", content: "Root", description: "", projectId: "p1",
            sectionId: nil, parentId: nil, labels: [], priority: 1,
            dueDate: nil, dueRecurring: false,
            subTaskCount: 1, completedSubTaskCount: 0,
            completedAt: nil, addedAt: "2026-01-01", isProjectTask: false,
            postponeCount: 0, expiresAt: nil
        )
        let childFlat = FlatTask(
            id: "child", content: "Child", description: "", projectId: "p1",
            sectionId: nil, parentId: "root", labels: [], priority: 1,
            dueDate: nil, dueRecurring: false,
            subTaskCount: 0, completedSubTaskCount: 0,
            completedAt: nil, addedAt: "2026-01-01", isProjectTask: false,
            postponeCount: 0, expiresAt: nil
        )

        let tree = buildTree(from: [rootFlat, childFlat])
        #expect(tree.count == 1)
        #expect(tree[0].id == "root")
        #expect(tree[0].children.count == 1)
        #expect(tree[0].children[0].id == "child")
    }
}

// MARK: - ViewModel tests

struct TaskListViewModelTests {
    @Test func loadTasksPopulatesList() async {
        let mock = MockTaskRepository()
        let tasks = [makeTask(id: "1", content: "First"), makeTask(id: "2", content: "Second")]
        mock.fetchTasksResult = TasksResponse(
            tasks: tasks,
            meta: TasksMeta(context: "", weeklyLimit: 10, weeklyCount: 2, backlogLimit: 20, backlogCount: 5)
        )

        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await #expect(vm.tasks.count == 2)
        await #expect(vm.tasks[0].content == "First")
    }

    @Test func completeTaskRemovesFromList() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1", content: "To complete")
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )

        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()
        await vm.completeTask(task)

        #expect(mock.completeTaskCalled)
        #expect(mock.lastCompleteId == "1")
    }

    @Test func deleteTaskRemovesFromList() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1")
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )

        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()
        await vm.deleteTask(task)

        #expect(mock.deleteTaskCalled)
        #expect(mock.lastDeleteId == "1")
    }

    @Test func duplicateTaskCallsRepository() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1")
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )

        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()
        await vm.duplicateTask(task)

        #expect(mock.lastDuplicateId == "1")
    }

    @Test func moveTaskCallsRepository() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1")
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )

        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()
        await vm.moveTask(task, parentId: "parent-1")

        #expect(mock.moveTaskCalled)
        #expect(mock.lastMoveId == "1")
        #expect(mock.lastMoveParentId == "parent-1")
    }
}

struct CreateTaskViewModelTests {
    @Test func createTaskSendsRequest() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.content = "New task"
            vm.description = "Desc"
            vm.priority = 3
            vm.dueDate = "2026-06-01"
            vm.parentId = "parent-1"
        }

        let success = await vm.createTask()

        #expect(success)
        #expect(mock.lastCreateRequest?.content == "New task")
        #expect(mock.lastCreateRequest?.description == "Desc")
        #expect(mock.lastCreateRequest?.priority == 3)
        #expect(mock.lastCreateRequest?.dueDate == "2026-06-01")
        #expect(mock.lastCreateRequest?.parentId == "parent-1")
    }

    @Test func createTaskFailsWhenEmpty() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)

        let success = await vm.createTask()
        #expect(!success)
    }

    @Test func resetClearsFields() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.content = "Something"
            vm.priority = 4
            vm.reset()
        }

        await #expect(vm.content == "")
        await #expect(vm.priority == 1)
    }
}

struct TaskDetailViewModelTests {
    @Test func updateTaskCallsRepository() async {
        let mock = MockTaskRepository()
        let vm = await TaskDetailViewModel(repository: mock)
        let task = makeTask(id: "task-1", content: "Original")
        await MainActor.run { vm.setTask(task) }

        await vm.updateTask(content: "Updated", priority: 3)

        #expect(mock.updateTaskCalled)
        #expect(mock.lastUpdateId == "task-1")
        #expect(mock.lastUpdateRequest?.content == "Updated")
        #expect(mock.lastUpdateRequest?.priority == 3)
    }

    @Test func decomposeTaskCallsRepository() async {
        let mock = MockTaskRepository()
        let vm = await TaskDetailViewModel(repository: mock)
        let task = makeTask(id: "task-1")
        await MainActor.run { vm.setTask(task) }

        let success = await vm.decomposeTask(subtasks: ["Sub 1", "Sub 2"])

        #expect(success)
        #expect(mock.decomposeTaskCalled)
        #expect(mock.lastDecomposeId == "task-1")
        #expect(mock.lastDecomposeSubtasks == ["Sub 1", "Sub 2"])
    }

    @Test func loadCompletedSubtasks() async {
        let mock = MockTaskRepository()
        mock.completedSubtasksResult = [makeTask(id: "done-1", content: "Done")]
        let vm = await TaskDetailViewModel(repository: mock)
        let task = makeTask(id: "task-1")
        await MainActor.run { vm.setTask(task) }

        await vm.loadCompletedSubtasks()

        await #expect(vm.completedSubtasks.count == 1)
        await #expect(vm.completedSubtasks[0].content == "Done")
    }
}
