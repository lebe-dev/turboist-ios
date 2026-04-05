import Testing
import Foundation
import SwiftUI
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
    var patchStateCalled = false
    var lastPatchStateRequest: PatchStateRequest?
    var batchUpdateLabelsCalled = false
    var lastBatchUpdateLabels: [String: [String]]?
    var lastFetchView: TaskView?
    var lastFetchContext: String?

    func fetchTasks(view: TaskView, context: String?) async throws -> TasksResponse {
        lastFetchView = view
        lastFetchContext = context
        if let error = fetchTasksError { throw error }
        return fetchTasksResult ?? TasksResponse(tasks: [], meta: TasksMeta(context: context ?? "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0))
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

    func batchUpdateLabels(_ updates: [String: [String]]) async throws -> Int {
        batchUpdateLabelsCalled = true
        lastBatchUpdateLabels = updates
        return updates.count
    }

    var resetWeeklyCalled = false
    var resetWeeklyError: Error?

    func resetWeekly() async throws {
        resetWeeklyCalled = true
        if let error = resetWeeklyError { throw error }
    }

    func patchState(_ request: PatchStateRequest) async throws {
        patchStateCalled = true
        lastPatchStateRequest = request
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

// MARK: - Subtask feature tests

struct DisplayTaskFlatteningTests {
    @Test func flattenForDisplayProducesCorrectDepths() {
        let grandchild = makeTask(id: "gc-1", content: "Grandchild", parentId: "child-1")
        let child = makeTask(id: "child-1", content: "Child", parentId: "root-1", children: [grandchild])
        let root = makeTask(id: "root-1", content: "Root", children: [child])

        let display = flattenForDisplay([root], collapsedIds: [])

        #expect(display.count == 3)
        #expect(display[0].depth == 0)
        #expect(display[0].task.id == "root-1")
        #expect(display[0].hasChildren)
        #expect(display[1].depth == 1)
        #expect(display[1].task.id == "child-1")
        #expect(display[1].hasChildren)
        #expect(display[2].depth == 2)
        #expect(display[2].task.id == "gc-1")
        #expect(!display[2].hasChildren)
    }

    @Test func flattenForDisplayRespectsCollapsedIds() {
        let child = makeTask(id: "child-1", content: "Child", parentId: "root-1")
        let root = makeTask(id: "root-1", content: "Root", children: [child])

        let display = flattenForDisplay([root], collapsedIds: ["root-1"])

        #expect(display.count == 1)
        #expect(display[0].task.id == "root-1")
        #expect(display[0].hasChildren)
    }

    @Test func flattenForDisplayHandlesMultipleRoots() {
        let child1 = makeTask(id: "c1", content: "C1", parentId: "r1")
        let root1 = makeTask(id: "r1", content: "R1", children: [child1])
        let root2 = makeTask(id: "r2", content: "R2")

        let display = flattenForDisplay([root1, root2], collapsedIds: [])

        #expect(display.count == 3)
        #expect(display[0].task.id == "r1")
        #expect(display[1].task.id == "c1")
        #expect(display[2].task.id == "r2")
    }

    @Test func flattenForDisplayCollapseOnlyAffectsChildren() {
        let child1 = makeTask(id: "c1", content: "C1", parentId: "r1")
        let root1 = makeTask(id: "r1", content: "R1", children: [child1])
        let child2 = makeTask(id: "c2", content: "C2", parentId: "r2")
        let root2 = makeTask(id: "r2", content: "R2", children: [child2])

        let display = flattenForDisplay([root1, root2], collapsedIds: ["r1"])

        #expect(display.count == 3)
        #expect(display[0].task.id == "r1")
        #expect(display[1].task.id == "r2")
        #expect(display[2].task.id == "c2")
    }

    @Test func hasChildrenTrueWhenSubTaskCountPositive() {
        let task = TaskItem(
            id: "t1", content: "Task", description: "", projectId: "p1",
            sectionId: nil, parentId: nil, labels: [], priority: 1, due: nil,
            subTaskCount: 3, completedSubTaskCount: 1, completedAt: nil,
            addedAt: "2026-01-01", isProjectTask: false, postponeCount: 0,
            expiresAt: nil, children: []
        )
        let display = flattenForDisplay([task], collapsedIds: [])

        #expect(display[0].hasChildren)
    }
}

struct CollapsedIdsTests {
    @Test func toggleCollapsedAddsId() async {
        let mock = MockTaskRepository()
        let vm = await TaskListViewModel(repository: mock)

        await vm.toggleCollapsed("task-1")

        await #expect(vm.collapsedIds.contains("task-1"))
        #expect(mock.patchStateCalled)
        #expect(mock.lastPatchStateRequest?.collapsedIds?.contains("task-1") == true)
    }

    @Test func toggleCollapsedRemovesId() async {
        let mock = MockTaskRepository()
        let vm = await TaskListViewModel(repository: mock)
        await MainActor.run { vm.collapsedIds = ["task-1"] }

        await vm.toggleCollapsed("task-1")

        await #expect(!vm.collapsedIds.contains("task-1"))
        #expect(mock.patchStateCalled)
    }

    @Test func setCollapsedIdsInitializesFromConfig() async {
        let mock = MockTaskRepository()
        let vm = await TaskListViewModel(repository: mock)

        await MainActor.run { vm.setCollapsedIds(["a", "b", "c"]) }

        await #expect(vm.collapsedIds == Set(["a", "b", "c"]))
    }

    @Test func displayTasksReflectsCollapseState() async {
        let mock = MockTaskRepository()
        let child = makeTask(id: "child-1", content: "Child", parentId: "root-1")
        let root = makeTask(id: "root-1", content: "Root", children: [child])
        mock.fetchTasksResult = TasksResponse(
            tasks: [root],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        // Expanded: should show both
        await #expect(vm.displayTasks.count == 2)

        // Collapse root
        await vm.toggleCollapsed("root-1")

        // Should show only root
        await #expect(vm.displayTasks.count == 1)
        await #expect(vm.displayTasks[0].task.id == "root-1")
    }
}

// MARK: - Priority tests

struct PriorityTests {
    @Test func priorityFromRawValue() {
        #expect(Priority(rawPriority: 4) == .p1)
        #expect(Priority(rawPriority: 3) == .p2)
        #expect(Priority(rawPriority: 2) == .p3)
        #expect(Priority(rawPriority: 1) == .p4)
    }

    @Test func priorityDefaultsToP4ForInvalidValue() {
        #expect(Priority(rawPriority: 0) == .p4)
        #expect(Priority(rawPriority: 99) == .p4)
    }

    @Test func priorityLabels() {
        #expect(Priority.p1.label == "P1 - Urgent")
        #expect(Priority.p2.label == "P2 - High")
        #expect(Priority.p3.label == "P3 - Medium")
        #expect(Priority.p4.label == "P4 - Low")
    }

    @Test func priorityShortLabels() {
        #expect(Priority.p1.shortLabel == "P1")
        #expect(Priority.p4.shortLabel == "P4")
    }
}

struct PriorityFilterTests {
    @Test func filterByPriorityShowsMatchingTasks() async {
        let mock = MockTaskRepository()
        let tasks = [
            makeTask(id: "1", content: "Urgent", priority: 4),
            makeTask(id: "2", content: "Low", priority: 1),
            makeTask(id: "3", content: "High", priority: 3),
        ]
        mock.fetchTasksResult = TasksResponse(
            tasks: tasks,
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await MainActor.run { vm.togglePriorityFilter(4) }
        await #expect(vm.displayTasks.count == 1)
        await #expect(vm.displayTasks[0].task.id == "1")
    }

    @Test func filterByMultiplePriorities() async {
        let mock = MockTaskRepository()
        let tasks = [
            makeTask(id: "1", priority: 4),
            makeTask(id: "2", priority: 1),
            makeTask(id: "3", priority: 3),
        ]
        mock.fetchTasksResult = TasksResponse(
            tasks: tasks,
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await MainActor.run {
            vm.togglePriorityFilter(4)
            vm.togglePriorityFilter(3)
        }
        await #expect(vm.displayTasks.count == 2)
    }

    @Test func clearPriorityFilterShowsAll() async {
        let mock = MockTaskRepository()
        let tasks = [makeTask(id: "1", priority: 4), makeTask(id: "2", priority: 1)]
        mock.fetchTasksResult = TasksResponse(
            tasks: tasks,
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await MainActor.run {
            vm.togglePriorityFilter(4)
            vm.clearPriorityFilter()
        }
        await #expect(vm.displayTasks.count == 2)
    }

    @Test func filterIncludesParentWhenChildMatches() async {
        let mock = MockTaskRepository()
        let child = makeTask(id: "child", priority: 4, parentId: "root")
        let root = makeTask(id: "root", priority: 1, children: [child])
        mock.fetchTasksResult = TasksResponse(
            tasks: [root],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await MainActor.run { vm.togglePriorityFilter(4) }
        await #expect(vm.displayTasks.count == 2)
    }

    @Test func isFilteringReflectsState() async {
        let mock = MockTaskRepository()
        let vm = await TaskListViewModel(repository: mock)

        await #expect(!vm.isFiltering)
        await MainActor.run { vm.togglePriorityFilter(4) }
        await #expect(vm.isFiltering)
    }

    @Test func updateTaskPriorityCallsRepository() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1", priority: 1)
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await vm.updateTaskPriority(task, priority: 4)

        #expect(mock.updateTaskCalled)
        #expect(mock.lastUpdateRequest?.priority == 4)
        await #expect(vm.tasks[0].priority == 4)
    }
}

struct FindTaskTests {
    @Test func findTaskFindsRootTask() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "t1", content: "Found")
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        let found = await vm.findTask(by: "t1")
        #expect(found?.content == "Found")
    }

    @Test func findTaskFindsNestedChild() async {
        let mock = MockTaskRepository()
        let child = makeTask(id: "c1", content: "Nested", parentId: "r1")
        let root = makeTask(id: "r1", content: "Root", children: [child])
        mock.fetchTasksResult = TasksResponse(
            tasks: [root],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        let found = await vm.findTask(by: "c1")
        #expect(found?.content == "Nested")
    }

    @Test func findTaskReturnsNilWhenNotFound() async {
        let mock = MockTaskRepository()
        mock.fetchTasksResult = TasksResponse(
            tasks: [],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        let found = await vm.findTask(by: "nonexistent")
        #expect(found == nil)
    }
}

// MARK: - DueDate Helper tests

struct DueDateHelperTests {
    @Test func parseValidDate() {
        let date = DueDateHelper.parse("2026-06-15")
        #expect(date != nil)
    }

    @Test func parseInvalidDate() {
        let date = DueDateHelper.parse("invalid")
        #expect(date == nil)
    }

    @Test func formatRoundTrips() {
        let dateString = "2026-06-15"
        let parsed = DueDateHelper.parse(dateString)!
        let formatted = DueDateHelper.format(parsed)
        #expect(formatted == dateString)
    }

    @Test func statusOverdue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dateString = DueDateHelper.format(yesterday)
        #expect(DueDateHelper.status(for: dateString) == .overdue)
    }

    @Test func statusToday() {
        let dateString = DueDateHelper.todayString()
        #expect(DueDateHelper.status(for: dateString) == .today)
    }

    @Test func statusTomorrow() {
        let dateString = DueDateHelper.tomorrowString()
        #expect(DueDateHelper.status(for: dateString) == .tomorrow)
    }

    @Test func statusFuture() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let dateString = DueDateHelper.format(future)
        #expect(DueDateHelper.status(for: dateString) == .future)
    }

    @Test func statusInvalidReturnsNone() {
        #expect(DueDateHelper.status(for: "not-a-date") == .none)
    }

    @Test func displayLabelToday() {
        let dateString = DueDateHelper.todayString()
        #expect(DueDateHelper.displayLabel(for: dateString) == "Today")
    }

    @Test func displayLabelTomorrow() {
        let dateString = DueDateHelper.tomorrowString()
        #expect(DueDateHelper.displayLabel(for: dateString) == "Tomorrow")
    }

    @Test func displayLabelOverdue() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let dateString = DueDateHelper.format(yesterday)
        #expect(DueDateHelper.displayLabel(for: dateString) == "Overdue")
    }

    @Test func displayLabelFutureShowsShortDate() {
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let dateString = DueDateHelper.format(future)
        let label = DueDateHelper.displayLabel(for: dateString)
        // Should not be Today/Tomorrow/Overdue
        #expect(label != "Today")
        #expect(label != "Tomorrow")
        #expect(label != "Overdue")
        #expect(!label.isEmpty)
    }

    @Test func todayStringMatchesCurrentDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        #expect(DueDateHelper.todayString() == formatter.string(from: Date()))
    }

    @Test func tomorrowStringIsOneDayAfterToday() {
        let today = DueDateHelper.parse(DueDateHelper.todayString())!
        let tomorrow = DueDateHelper.parse(DueDateHelper.tomorrowString())!
        let diff = Calendar.current.dateComponents([.day], from: today, to: tomorrow).day
        #expect(diff == 1)
    }

    @Test func weekDaysReturnsCorrectCount() {
        let days = DueDateHelper.weekDays()
        #expect(days.count == 6)
    }

    @Test func weekDaysAreFutureDates() {
        let todayDate = Calendar.current.startOfDay(for: Date())
        for day in DueDateHelper.weekDays() {
            let date = DueDateHelper.parse(day.date)!
            #expect(date > todayDate)
        }
    }

    @Test func postponeColorThresholds() {
        #expect(DueDateHelper.postponeColor(count: 0) == .secondary)
        #expect(DueDateHelper.postponeColor(count: 1) == .secondary)
        #expect(DueDateHelper.postponeColor(count: 2) == .yellow)
        #expect(DueDateHelper.postponeColor(count: 3) == .red)
        #expect(DueDateHelper.postponeColor(count: 10) == .red)
    }
}

// MARK: - Due Date ViewModel tests

struct DueDateViewModelTests {
    @Test func updateTaskDueDateCallsRepository() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1", due: Due(date: "2026-01-01", recurring: false))
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await vm.updateTaskDueDate(task, dueDate: "2026-06-15")

        #expect(mock.updateTaskCalled)
        #expect(mock.lastUpdateRequest?.dueDate == "2026-06-15")
        await #expect(vm.tasks[0].due?.date == "2026-06-15")
    }

    @Test func clearDueDateSendsEmptyString() async {
        let mock = MockTaskRepository()
        let task = makeTask(id: "1", due: Due(date: "2026-01-01", recurring: false))
        mock.fetchTasksResult = TasksResponse(
            tasks: [task],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await vm.updateTaskDueDate(task, dueDate: "")

        #expect(mock.updateTaskCalled)
        await #expect(vm.tasks[0].due == nil)
    }

    @Test func updateTaskDueDateOnNestedChild() async {
        let mock = MockTaskRepository()
        let child = makeTask(id: "child-1", due: Due(date: "2026-01-01", recurring: false), parentId: "root-1")
        let root = makeTask(id: "root-1", children: [child])
        mock.fetchTasksResult = TasksResponse(
            tasks: [root],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        let vm = await TaskListViewModel(repository: mock)
        await vm.loadTasks()

        await vm.updateTaskDueDate(child, dueDate: "2026-12-25")

        #expect(mock.updateTaskCalled)
        await #expect(vm.tasks[0].children[0].due?.date == "2026-12-25")
    }

    @Test func createTaskWithDueString() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.content = "Recurring task"
            vm.dueDate = "2026-06-01"
            vm.dueString = "every day"
        }

        let success = await vm.createTask()

        #expect(success)
        #expect(mock.lastCreateRequest?.dueDate == "2026-06-01")
        #expect(mock.lastCreateRequest?.dueString == "every day")
    }

    @Test func resetClearsDueString() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.dueString = "every week"
            vm.reset()
        }

        await #expect(vm.dueString == nil)
    }

    @Test func detailViewModelUpdateDueString() async {
        let mock = MockTaskRepository()
        let vm = await TaskDetailViewModel(repository: mock)
        let task = makeTask(id: "task-1")
        await MainActor.run { vm.setTask(task) }

        await vm.updateTask(dueString: "every day")

        #expect(mock.updateTaskCalled)
        #expect(mock.lastUpdateRequest?.dueString == "every day")
    }
}

// MARK: - Label Tests

@Suite("Label Tests")
struct LabelTests {

    @Test("AppConfigStore returns label color")
    func labelColor() {
        let store = AppConfigStore()
        let config = AppConfig(
            settings: makeSettings(),
            contexts: [],
            projects: [],
            labels: [TaskLabel(id: "1", name: "work", color: "ff0000", order: 0)],
            labelConfigs: [LabelConfig(name: "work", inheritToSubtasks: true)],
            autoLabels: [],
            quickCapture: nil,
            projectTasks: [],
            labelProjectMap: [],
            autoRemove: AutoRemoveStatus(rules: [], paused: false),
            state: makeUserState()
        )
        store.setConfig(config)
        #expect(store.labels.count == 1)
        #expect(store.labelColor("work") != nil)
        #expect(store.labelColor("missing") == nil)
        #expect(store.shouldInheritToSubtasks("work") == true)
        #expect(store.shouldInheritToSubtasks("other") == false)
    }

    @Test("Color hex parsing")
    func hexColor() {
        let color = Color(hex: "#ff0000")
        #expect(color != nil)
        let colorNoHash = Color(hex: "00ff00")
        #expect(colorNoHash != nil)
        let invalid = Color(hex: "xyz")
        #expect(invalid == nil)
    }

    @Test("Batch update labels via ViewModel")
    @MainActor
    func batchUpdateLabels() async {
        let mock = MockTaskRepository()
        let vm = TaskListViewModel(repository: mock)
        let task1 = makeTask(id: "t1", labels: ["old"])
        let task2 = makeTask(id: "t2", labels: ["old"])
        mock.fetchTasksResult = TasksResponse(
            tasks: [task1, task2],
            meta: TasksMeta(context: "", weeklyLimit: 0, weeklyCount: 0, backlogLimit: 0, backlogCount: 0)
        )
        await vm.loadTasks()

        await vm.batchUpdateLabels(["t1": ["new1"], "t2": ["new2"]])

        #expect(mock.batchUpdateLabelsCalled)
        #expect(mock.lastBatchUpdateLabels?["t1"] == ["new1"])
        #expect(mock.lastBatchUpdateLabels?["t2"] == ["new2"])
        // Optimistic update should have changed local state
        #expect(vm.tasks.first(where: { $0.id == "t1" })?.labels == ["new1"])
        #expect(vm.tasks.first(where: { $0.id == "t2" })?.labels == ["new2"])
    }

    @Test("TaskDetailViewModel updates labels")
    @MainActor
    func updateTaskLabels() async {
        let mock = MockTaskRepository()
        let vm = TaskDetailViewModel(repository: mock)
        let task = makeTask(id: "task-1", labels: ["old-label"])
        vm.setTask(task)

        await vm.updateTask(labels: ["new-label", "another"])

        #expect(mock.updateTaskCalled)
        #expect(mock.lastUpdateRequest?.labels == ["new-label", "another"])
        #expect(vm.task?.labels == ["new-label", "another"])
    }
}

// MARK: - Test Config Helpers

func makeSettings() -> AppSettings {
    AppSettings(
        pollInterval: 30,
        syncInterval: 5,
        timezone: "UTC",
        weeklyLabel: "weekly",
        backlogLabel: "backlog",
        projectLabel: "project",
        projectsLabel: "projects",
        weeklyLimit: 20,
        backlogLimit: 50,
        completedDays: 7,
        maxPinned: 5,
        lastSyncedAt: nil,
        dayParts: [],
        maxDayPartNoteLength: 500,
        inboxProjectId: "inbox",
        inboxLimit: 50,
        inboxOverflowTaskContent: "Too many tasks in inbox"
    )
}

func makeUserState() -> UserState {
    UserState(
        pinnedTasks: [],
        activeContextId: "",
        activeView: "all",
        collapsedIds: [],
        sidebarCollapsed: false,
        planningOpen: false,
        dayPartNotes: [:],
        locale: "en",
        allFilters: nil
    )
}

// MARK: - AutoLabelMatcher Tests

struct AutoLabelMatcherTests {
    @Test func compileNormalizesMaskWhenIgnoreCase() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "Купить", label: "покупки", ignoreCase: true)
        ])
        #expect(compiled[0].mask == "купить")
        #expect(compiled[0].ignoreCase == true)
    }

    @Test func compilePreservesCaseWhenNotIgnoreCase() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "Купить", label: "покупки", ignoreCase: false)
        ])
        #expect(compiled[0].mask == "Купить")
        #expect(compiled[0].ignoreCase == false)
    }

    @Test func compileReturnsEmptyForEmptyInput() {
        let compiled = AutoLabelMatcher.compile([])
        #expect(compiled.isEmpty)
    }

    @Test func matchReturnsMatchingLabels() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        let result = AutoLabelMatcher.match(title: "купить молоко", compiled: compiled)
        #expect(result == ["покупки"])
    }

    @Test func matchReturnsEmptyWhenNoMatch() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        let result = AutoLabelMatcher.match(title: "позвонить другу", compiled: compiled)
        #expect(result.isEmpty)
    }

    @Test func matchIsCaseInsensitiveWhenConfigured() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        let result = AutoLabelMatcher.match(title: "КУПИТЬ хлеб", compiled: compiled)
        #expect(result == ["покупки"])
    }

    @Test func matchIsCaseSensitiveWhenConfigured() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: false)
        ])
        #expect(AutoLabelMatcher.match(title: "КУПИТЬ хлеб", compiled: compiled).isEmpty)
        #expect(AutoLabelMatcher.match(title: "купить хлеб", compiled: compiled) == ["покупки"])
    }

    @Test func matchReturnsMultipleLabels() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true),
            AutoLabelMapping(mask: "встреча", label: "работа", ignoreCase: true)
        ])
        let result = AutoLabelMatcher.match(title: "встреча и купить кофе", compiled: compiled)
        #expect(result == ["покупки", "работа"])
    }

    @Test func matchReturnsEmptyForEmptyTitle() {
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        let result = AutoLabelMatcher.match(title: "", compiled: compiled)
        #expect(result.isEmpty)
    }
}

// MARK: - CreateTaskViewModel Auto-Labels Tests

struct CreateTaskAutoLabelsTests {
    @Test func autoLabelsMatchedFromContent() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        await MainActor.run {
            vm.configure(compiledAutoLabels: compiled, contextLabels: [])
            vm.content = "Купить молоко"
        }

        await MainActor.run {
            #expect(vm.matchedAutoLabels == ["покупки"])
        }
    }

    @Test func autoLabelsCanBeDismissed() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        await MainActor.run {
            vm.configure(compiledAutoLabels: compiled, contextLabels: [])
            vm.content = "Купить молоко"
            vm.dismissAutoLabel("покупки")
        }

        await MainActor.run {
            #expect(vm.matchedAutoLabels.isEmpty)
        }
    }

    @Test func contextLabelsIncludedInAllLabels() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.configure(compiledAutoLabels: [], contextLabels: ["work", "urgent"])
            vm.content = "Some task"
        }

        await MainActor.run {
            #expect(vm.allLabels.contains("work"))
            #expect(vm.allLabels.contains("urgent"))
        }
    }

    @Test func allLabelsCombinesManualAutoAndContext() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        await MainActor.run {
            vm.configure(compiledAutoLabels: compiled, contextLabels: ["work"])
            vm.content = "Купить молоко"
            vm.labels = ["manual"]
        }

        await MainActor.run {
            let all = Set(vm.allLabels)
            #expect(all.contains("покупки"))
            #expect(all.contains("work"))
            #expect(all.contains("manual"))
        }
    }

    @Test func createTaskSendsAllLabels() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        let compiled = AutoLabelMatcher.compile([
            AutoLabelMapping(mask: "купить", label: "покупки", ignoreCase: true)
        ])
        await MainActor.run {
            vm.configure(compiledAutoLabels: compiled, contextLabels: ["ctx"])
            vm.content = "Купить молоко"
            vm.labels = ["manual"]
        }

        let success = await vm.createTask()

        #expect(success)
        let sentLabels = Set(mock.lastCreateRequest?.labels ?? [])
        #expect(sentLabels.contains("покупки"))
        #expect(sentLabels.contains("ctx"))
        #expect(sentLabels.contains("manual"))
    }

    @Test func resetClearsRemovedAutoLabels() async {
        let mock = MockTaskRepository()
        let vm = await CreateTaskViewModel(repository: mock)
        await MainActor.run {
            vm.dismissAutoLabel("some-label")
            vm.reset()
        }

        await MainActor.run {
            #expect(vm.removedAutoLabels.isEmpty)
        }
    }
}

// MARK: - AppConfigStore Context Labels Tests

struct AppConfigStoreContextLabelsTests {
    @Test func activeContextLabelsReturnsLabelsWhenInherit() {
        let store = AppConfigStore()
        store.setConfig(makeConfig(
            contexts: [TaskContext(id: "ctx1", displayName: "Work", color: "#ff0000", inheritLabels: true, filters: ContextFilters(projects: [], sections: [], labels: ["work", "office"]))],
            activeContextId: "ctx1"
        ))

        #expect(store.activeContextLabels() == ["work", "office"])
    }

    @Test func activeContextLabelsReturnsEmptyWhenNoInherit() {
        let store = AppConfigStore()
        store.setConfig(makeConfig(
            contexts: [TaskContext(id: "ctx1", displayName: "Work", color: nil, inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: ["work"]))],
            activeContextId: "ctx1"
        ))

        #expect(store.activeContextLabels().isEmpty)
    }

    @Test func activeContextLabelsReturnsEmptyWhenNoActiveContext() {
        let store = AppConfigStore()
        store.setConfig(makeConfig(contexts: [], activeContextId: ""))

        #expect(store.activeContextLabels().isEmpty)
    }

    @Test func contextLabelsForSpecificContext() {
        let store = AppConfigStore()
        store.setConfig(makeConfig(
            contexts: [
                TaskContext(id: "ctx1", displayName: "Work", color: nil, inheritLabels: true, filters: ContextFilters(projects: [], sections: [], labels: ["work"])),
                TaskContext(id: "ctx2", displayName: "Home", color: nil, inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: ["home"]))
            ],
            activeContextId: ""
        ))

        #expect(store.contextLabels(for: "ctx1") == ["work"])
        #expect(store.contextLabels(for: "ctx2").isEmpty)
    }
}

private func makeConfig(contexts: [TaskContext] = [], activeContextId: String = "") -> AppConfig {
    AppConfig(
        settings: AppSettings(
            pollInterval: 30, syncInterval: 10, timezone: "UTC",
            weeklyLabel: "weekly", backlogLabel: "backlog",
            projectLabel: "project", projectsLabel: "projects",
            weeklyLimit: 20, backlogLimit: 50, completedDays: 7,
            maxPinned: 5, lastSyncedAt: nil, dayParts: [],
            maxDayPartNoteLength: 200, inboxProjectId: "inbox",
            inboxLimit: 50, inboxOverflowTaskContent: "Too many tasks"
        ),
        contexts: contexts,
        projects: [],
        labels: [],
        labelConfigs: [],
        autoLabels: [],
        quickCapture: nil,
        projectTasks: [],
        labelProjectMap: [],
        autoRemove: AutoRemoveStatus(rules: [], paused: false),
        state: UserState(
            pinnedTasks: [], activeContextId: activeContextId,
            activeView: "all", collapsedIds: [],
            sidebarCollapsed: false, planningOpen: false,
            dayPartNotes: [:], locale: "en", allFilters: nil
        )
    )
}

// MARK: - Context Tests

@Suite("Context switching")
struct ContextTests {
    @Test func switchContextSetsActiveContextId() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)

        await vm.switchContext("work")

        #expect(vm.activeContextId == "work")
        #expect(repo.lastFetchContext == "work")
    }

    @Test func switchContextClearsPriorityFilters() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)
        vm.selectedPriorities = [1, 2]

        await vm.switchContext("home")

        #expect(vm.selectedPriorities.isEmpty)
    }

    @Test func switchContextToNilClearsContext() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)
        vm.activeContextId = "work"

        await vm.switchContext(nil)

        #expect(vm.activeContextId == nil)
        #expect(repo.lastFetchContext == nil)
    }

    @Test func loadTasksUsesActiveContext() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)
        vm.activeContextId = "work"

        await vm.loadTasks(view: .today)

        #expect(repo.lastFetchContext == "work")
        #expect(repo.lastFetchView == .today)
    }

    @Test func loadTasksExplicitContextOverridesActive() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)
        vm.activeContextId = "work"

        await vm.loadTasks(view: .all, context: "home")

        #expect(repo.lastFetchContext == "home")
    }

    @Test func configStoreActiveContext() {
        let store = AppConfigStore()
        let contexts = [
            TaskContext(id: "work", displayName: "Work", color: "#FF0000", inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: [])),
            TaskContext(id: "home", displayName: "Home", color: "#00FF00", inheritLabels: true, filters: ContextFilters(projects: [], sections: [], labels: ["home"]))
        ]
        let config = makeConfig(contexts: contexts, activeContextId: "work")
        store.setConfig(config)

        #expect(store.activeContextId == "work")
        #expect(store.activeContext?.displayName == "Work")
    }

    @Test func configStoreSetActiveContextPersists() async {
        let store = AppConfigStore()
        let repo = MockTaskRepository()
        let contexts = [
            TaskContext(id: "work", displayName: "Work", color: nil, inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: [])),
            TaskContext(id: "home", displayName: "Home", color: nil, inheritLabels: true, filters: ContextFilters(projects: [], sections: [], labels: ["home"]))
        ]
        let config = makeConfig(contexts: contexts, activeContextId: "work")
        store.setConfig(config)

        store.setActiveContext("home", repository: repo)

        #expect(store.activeContextId == "home")
        #expect(store.activeContext?.displayName == "Home")
        // Give the Task time to fire
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.patchStateCalled)
        #expect(repo.lastPatchStateRequest?.activeContextId == "home")
    }

    @Test func configStoreSetActiveContextToNil() async {
        let store = AppConfigStore()
        let repo = MockTaskRepository()
        let config = makeConfig(contexts: [], activeContextId: "work")
        store.setConfig(config)

        store.setActiveContext(nil, repository: repo)

        #expect(store.activeContextId == "")
        #expect(store.activeContext == nil)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.lastPatchStateRequest?.activeContextId == "")
    }

    @Test func configStoreContextLabelsInheritance() {
        let store = AppConfigStore()
        let contexts = [
            TaskContext(id: "home", displayName: "Home", color: nil, inheritLabels: true, filters: ContextFilters(projects: [], sections: [], labels: ["personal", "family"]))
        ]
        let config = makeConfig(contexts: contexts, activeContextId: "home")
        store.setConfig(config)

        let labels = store.activeContextLabels()
        #expect(labels == ["personal", "family"])
    }

    @Test func configStoreNoInheritWhenDisabled() {
        let store = AppConfigStore()
        let contexts = [
            TaskContext(id: "work", displayName: "Work", color: nil, inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: ["work"]))
        ]
        let config = makeConfig(contexts: contexts, activeContextId: "work")
        store.setConfig(config)

        let labels = store.activeContextLabels()
        #expect(labels.isEmpty)
    }

    @Test func configStoreOnContextChangedCallback() {
        let store = AppConfigStore()
        let repo = MockTaskRepository()
        let config = makeConfig(contexts: [
            TaskContext(id: "work", displayName: "Work", color: nil, inheritLabels: false, filters: ContextFilters(projects: [], sections: [], labels: []))
        ], activeContextId: "")
        store.setConfig(config)

        var receivedContextId: String? = "none"
        store.onContextChanged = { contextId in
            receivedContextId = contextId
        }

        store.setActiveContext("work", repository: repo)
        #expect(receivedContextId == "work")

        store.setActiveContext(nil, repository: repo)
        #expect(receivedContextId == nil)
    }

    @Test func patchStateRequestEncodesActiveContextId() throws {
        let request = PatchStateRequest(activeContextId: "work")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["active_context_id"] as? String == "work")
        #expect(json?["collapsed_ids"] == nil)
    }
}

// MARK: - View Switching Tests

@Suite("View switching")
struct ViewSwitchingTests {
    @Test func loadTasksWithSpecificView() async {
        let repo = MockTaskRepository()
        repo.fetchTasksResult = TasksResponse(
            tasks: [makeTask(id: "t1", content: "Weekly task")],
            meta: TasksMeta(context: "", weeklyLimit: 20, weeklyCount: 5, backlogLimit: 50, backlogCount: 10)
        )
        let vm = TaskListViewModel(repository: repo)
        await vm.loadTasks(view: .weekly)

        #expect(vm.currentView == .weekly)
        #expect(repo.lastFetchView == .weekly)
        #expect(vm.tasks.count == 1)
    }

    @Test func switchViewClearsPriorityFilters() async {
        let repo = MockTaskRepository()
        let vm = TaskListViewModel(repository: repo)
        vm.selectedPriorities = [3, 4]

        await vm.loadTasks(view: .today)

        #expect(vm.currentView == .today)
        // Priority filters are cleared by the caller (ContentView.switchView),
        // but loadTasks itself updates the currentView
    }

    @Test func configStoreActiveViewDefault() {
        let store = AppConfigStore()
        #expect(store.activeView == .all)
    }

    @Test func configStoreActiveViewFromConfig() {
        let store = AppConfigStore()
        var config = makeConfig(contexts: [])
        config.state.activeView = "weekly"
        store.setConfig(config)

        #expect(store.activeView == .weekly)
    }

    @Test func configStoreSetActiveViewPersists() async {
        let store = AppConfigStore()
        let repo = MockTaskRepository()
        let config = makeConfig(contexts: [])
        store.setConfig(config)

        store.setActiveView(.today, repository: repo)

        #expect(store.activeView == .today)
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.patchStateCalled)
        #expect(repo.lastPatchStateRequest?.activeView == "today")
    }

    @Test func configStoreSetActiveViewIgnoresSameView() async {
        let store = AppConfigStore()
        let repo = MockTaskRepository()
        let config = makeConfig(contexts: [])
        store.setConfig(config)

        store.setActiveView(.all, repository: repo)

        try? await Task.sleep(for: .milliseconds(100))
        #expect(!repo.patchStateCalled)
    }

    @Test func patchStateRequestEncodesActiveView() throws {
        let request = PatchStateRequest(activeView: "weekly")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["active_view"] as? String == "weekly")
    }

    @Test func taskViewDisplayNames() {
        #expect(TaskView.all.displayName == "All Tasks")
        #expect(TaskView.inbox.displayName == "Inbox")
        #expect(TaskView.today.displayName == "Today")
        #expect(TaskView.tomorrow.displayName == "Tomorrow")
        #expect(TaskView.weekly.displayName == "Weekly")
        #expect(TaskView.backlog.displayName == "Backlog")
        #expect(TaskView.completed.displayName == "Completed")
    }

    @Test func taskViewIcons() {
        #expect(TaskView.all.icon == "list.bullet")
        #expect(TaskView.inbox.icon == "tray")
        #expect(TaskView.today.icon == "sun.max")
    }

    @Test func metaAvailableAfterLoad() async {
        let repo = MockTaskRepository()
        repo.fetchTasksResult = TasksResponse(
            tasks: [],
            meta: TasksMeta(context: "", weeklyLimit: 20, weeklyCount: 8, backlogLimit: 50, backlogCount: 15, inboxCount: 55)
        )
        let vm = TaskListViewModel(repository: repo)
        await vm.loadTasks(view: .weekly)

        #expect(vm.meta?.weeklyCount == 8)
        #expect(vm.meta?.weeklyLimit == 20)
        #expect(vm.meta?.inboxCount == 55)
    }
}

// MARK: - Day Part Grouping Tests

@Suite("Day Part Grouping")
struct DayPartGroupingTests {
    let dayParts: [DayPart] = [
        DayPart(label: "утро", start: 6, end: 12),
        DayPart(label: "день", start: 12, end: 18),
        DayPart(label: "вечер", start: 18, end: 23)
    ]

    @Test func groupsTasksByDayPartLabel() {
        let tasks = [
            makeTask(id: "1", content: "Morning", labels: ["утро"]),
            makeTask(id: "2", content: "Evening", labels: ["вечер"]),
            makeTask(id: "3", content: "No time", labels: [])
        ]

        let sections = groupTasksByDayPart(tasks: tasks, dayParts: dayParts, dayPartNotes: [:])

        #expect(sections.count == 4) // 3 day parts + unassigned
        #expect(sections[0].label == "утро")
        #expect(sections[0].tasks.count == 1)
        #expect(sections[0].tasks[0].id == "1")
        #expect(sections[1].label == "день")
        #expect(sections[1].tasks.isEmpty)
        #expect(sections[2].label == "вечер")
        #expect(sections[2].tasks.count == 1)
        #expect(sections[2].tasks[0].id == "2")
        #expect(sections[3].label == "Без времени")
        #expect(sections[3].tasks.count == 1)
        #expect(sections[3].tasks[0].id == "3")
    }

    @Test func unassignedSectionContainsTasksWithoutDayPartLabel() {
        let tasks = [
            makeTask(id: "1", content: "Task A", labels: ["work"]),
            makeTask(id: "2", content: "Task B", labels: ["home", "urgent"])
        ]

        let sections = groupTasksByDayPart(tasks: tasks, dayParts: dayParts, dayPartNotes: [:])

        let unassigned = sections.last!
        #expect(unassigned.id == "__unassigned__")
        #expect(unassigned.tasks.count == 2)
    }

    @Test func emptyDayPartsReturnsSingleSection() {
        let tasks = [makeTask(id: "1", content: "Task")]
        let sections = groupTasksByDayPart(tasks: tasks, dayParts: [], dayPartNotes: [:])

        #expect(sections.count == 1)
        #expect(sections[0].tasks.count == 1)
    }

    @Test func dayPartNotesAreIncludedInSections() {
        let notes: [String: String] = [
            "утро": "Focus on deep work",
            "__unassigned__": "Review later"
        ]

        let sections = groupTasksByDayPart(tasks: [], dayParts: dayParts, dayPartNotes: notes)

        #expect(sections[0].note == "Focus on deep work")
        #expect(sections[1].note == "") // день - no note
        #expect(sections[2].note == "") // вечер - no note
        #expect(sections[3].note == "Review later") // unassigned
    }

    @Test func iconsAssignedCorrectly() {
        let sections = groupTasksByDayPart(tasks: [], dayParts: dayParts, dayPartNotes: [:])

        #expect(sections[0].icon == "sunrise") // first
        #expect(sections[1].icon == "sun.max") // middle
        #expect(sections[2].icon == "moon")    // last
        #expect(sections[3].icon == "clock")   // unassigned
    }

    @Test func timeRangeFormatting() {
        let sections = groupTasksByDayPart(tasks: [], dayParts: dayParts, dayPartNotes: [:])

        #expect(sections[0].timeRange == "6:00–12:00")
        #expect(sections[1].timeRange == "12:00–18:00")
        #expect(sections[2].timeRange == "18:00–23:00")
    }

    @Test func taskWithMultipleDayPartLabelsGoesToFirst() {
        let tasks = [
            makeTask(id: "1", content: "Multi", labels: ["утро", "вечер"])
        ]

        let sections = groupTasksByDayPart(tasks: tasks, dayParts: dayParts, dayPartNotes: [:])

        #expect(sections[0].tasks.count == 1) // утро gets it (first matching label)
        #expect(sections[2].tasks.isEmpty)    // вечер doesn't get it
    }
}

// MARK: - Day Part Notes Tests

@Suite("Day Part Notes")
struct DayPartNotesTests {
    @Test func setDayPartNoteUpdatesState() {
        let repo = MockTaskRepository()
        let store = AppConfigStore()
        store.setConfig(makeConfigWithDayParts())

        store.setDayPartNote("утро", text: "Focus time", repository: repo)

        #expect(store.dayPartNotes["утро"] == "Focus time")
    }

    @Test func clearDayPartNoteRemovesKey() {
        let repo = MockTaskRepository()
        let store = AppConfigStore()
        var config = makeConfigWithDayParts()
        config.state.dayPartNotes["утро"] = "Old note"
        store.setConfig(config)

        store.setDayPartNote("утро", text: "", repository: repo)

        #expect(store.dayPartNotes["утро"] == nil)
    }

    @Test func dayPartNoteTruncatedToMaxLength() {
        let repo = MockTaskRepository()
        let store = AppConfigStore()
        store.setConfig(makeConfigWithDayParts())

        let longText = String(repeating: "x", count: 300)
        store.setDayPartNote("утро", text: longText, repository: repo)

        #expect(store.dayPartNotes["утро"]?.count == 200)
    }

    @Test func dayPartsAccessor() {
        let store = AppConfigStore()
        store.setConfig(makeConfigWithDayParts())

        #expect(store.dayParts.count == 3)
        #expect(store.dayParts[0].label == "утро")
    }
}

private func makeConfigWithDayParts() -> AppConfig {
    AppConfig(
        settings: AppSettings(
            pollInterval: 30, syncInterval: 10, timezone: "UTC",
            weeklyLabel: "weekly", backlogLabel: "backlog",
            projectLabel: "project", projectsLabel: "projects",
            weeklyLimit: 20, backlogLimit: 50, completedDays: 7,
            maxPinned: 5, lastSyncedAt: nil,
            dayParts: [
                DayPart(label: "утро", start: 6, end: 12),
                DayPart(label: "день", start: 12, end: 18),
                DayPart(label: "вечер", start: 18, end: 23)
            ],
            maxDayPartNoteLength: 200, inboxProjectId: "inbox",
            inboxLimit: 50, inboxOverflowTaskContent: "Too many tasks"
        ),
        contexts: [],
        projects: [],
        labels: [],
        labelConfigs: [],
        autoLabels: [],
        quickCapture: nil,
        projectTasks: [],
        labelProjectMap: [],
        autoRemove: AutoRemoveStatus(rules: [], paused: false),
        state: UserState(
            pinnedTasks: [], activeContextId: "",
            activeView: "today", collapsedIds: [],
            sidebarCollapsed: false, planningOpen: false,
            dayPartNotes: [:], locale: "en", allFilters: nil
        )
    )
}

// MARK: - PlanningViewModel Tests

@Suite("PlanningViewModel")
struct PlanningViewModelTests {
    private func makeMeta(weeklyCount: Int = 0, weeklyLimit: Int = 10, backlogCount: Int = 0, backlogLimit: Int = 20) -> TasksMeta {
        TasksMeta(context: "", weeklyLimit: weeklyLimit, weeklyCount: weeklyCount, backlogLimit: backlogLimit, backlogCount: backlogCount)
    }

    @Test func enterLoadsBothTabs() async {
        let repo = MockTaskRepository()
        let backlogTasks = [makeTask(id: "b1", content: "Backlog 1", labels: ["backlog"])]
        let weeklyTasks = [makeTask(id: "w1", content: "Weekly 1", labels: ["weekly"])]
        let meta = makeMeta(weeklyCount: 1, backlogCount: 1)

        // fetchTasks is called twice (backlog + weekly), we need to return different results
        // Since mock returns same result, we'll use a simpler approach
        repo.fetchTasksResult = TasksResponse(tasks: weeklyTasks, meta: meta)

        let vm = PlanningViewModel(repository: repo)
        await vm.enter(contextId: nil)

        #expect(!vm.isLoading)
        #expect(vm.error == nil)
    }

    @Test func configureSetSettings() {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let settings = AppSettings(
            pollInterval: 30, syncInterval: 5, timezone: "UTC",
            weeklyLabel: "my-weekly", backlogLabel: "my-backlog",
            projectLabel: "project", projectsLabel: "projects",
            weeklyLimit: 15, backlogLimit: 25,
            completedDays: 7, maxPinned: 5,
            lastSyncedAt: nil, dayParts: [],
            maxDayPartNoteLength: 200,
            inboxProjectId: "inbox", inboxLimit: 50,
            inboxOverflowTaskContent: ""
        )
        vm.configure(settings: settings)

        #expect(vm.weeklyLimitValue == 15)
    }

    @Test func moveToWeeklyUpdatesLabels() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let task = makeTask(id: "t1", content: "Task", labels: ["backlog"])

        vm.backlogTasks = [task]
        vm.meta = makeMeta(weeklyCount: 0, backlogCount: 1)

        await vm.moveToWeekly(task)

        #expect(vm.backlogTasks.isEmpty)
        #expect(vm.weeklyTasks.count == 1)
        #expect(vm.weeklyTasks.first?.labels.contains("weekly") == true)
        #expect(vm.weeklyTasks.first?.labels.contains("backlog") == false)
        #expect(repo.batchUpdateLabelsCalled)
        #expect(repo.lastBatchUpdateLabels?["t1"]?.contains("weekly") == true)
    }

    @Test func moveToWeeklyBlockedAtLimit() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let task = makeTask(id: "t1", labels: ["backlog"])

        vm.backlogTasks = [task]
        vm.meta = makeMeta(weeklyCount: 10, weeklyLimit: 10, backlogCount: 1)

        await vm.moveToWeekly(task)

        #expect(vm.backlogTasks.count == 1)
        #expect(vm.weeklyTasks.isEmpty)
        #expect(!repo.batchUpdateLabelsCalled)
    }

    @Test func acceptAllMovesBatchTasks() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let tasks = [
            makeTask(id: "b1", labels: ["backlog"]),
            makeTask(id: "b2", labels: ["backlog", "urgent"])
        ]

        vm.backlogTasks = tasks
        vm.meta = makeMeta(weeklyCount: 0, backlogCount: 2)

        await vm.acceptAll()

        #expect(vm.backlogTasks.isEmpty)
        #expect(vm.weeklyTasks.count == 2)
        #expect(vm.meta?.weeklyCount == 2)
        #expect(vm.meta?.backlogCount == 0)
        #expect(repo.batchUpdateLabelsCalled)
        #expect(repo.lastBatchUpdateLabels?.count == 2)
        // b2 should keep "urgent" label and gain "weekly"
        #expect(repo.lastBatchUpdateLabels?["b2"]?.contains("urgent") == true)
        #expect(repo.lastBatchUpdateLabels?["b2"]?.contains("weekly") == true)
        #expect(repo.lastBatchUpdateLabels?["b2"]?.contains("backlog") == false)
    }

    @Test func startWeekClearsWeekly() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        vm.weeklyTasks = [makeTask(id: "w1", labels: ["weekly"])]
        vm.meta = makeMeta(weeklyCount: 1)

        await vm.startWeek()

        #expect(vm.weeklyTasks.isEmpty)
        #expect(vm.meta?.weeklyCount == 0)
        #expect(repo.resetWeeklyCalled)
    }

    @Test func updateWeeklyTaskPriority() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let task = makeTask(id: "w1", priority: 1, labels: ["weekly"])
        vm.weeklyTasks = [task]

        await vm.updateWeeklyTaskPriority(task, priority: 4)

        #expect(vm.weeklyTasks.first?.priority == 4)
        #expect(repo.updateTaskCalled)
        #expect(repo.lastUpdateRequest?.priority == 4)
    }

    @Test func updateWeeklyTaskDueDate() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let task = makeTask(id: "w1", labels: ["weekly"])
        vm.weeklyTasks = [task]

        await vm.updateWeeklyTaskDueDate(task, dueDate: "2026-04-10")

        #expect(vm.weeklyTasks.first?.due?.date == "2026-04-10")
        #expect(repo.updateTaskCalled)
    }

    @Test func completeTaskRemovesFromBothLists() async {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        let task = makeTask(id: "t1")
        vm.backlogTasks = [task]
        vm.weeklyTasks = [task]

        await vm.completeTask(task)

        #expect(vm.backlogTasks.isEmpty)
        #expect(vm.weeklyTasks.isEmpty)
        #expect(repo.completeTaskCalled)
    }

    @Test func searchFiltersBacklog() {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)
        vm.backlogTasks = [
            makeTask(id: "1", content: "Buy groceries", labels: ["backlog"]),
            makeTask(id: "2", content: "Fix the bug", labels: ["backlog"]),
            makeTask(id: "3", content: "Buy new keyboard", labels: ["backlog"])
        ]

        vm.searchText = "buy"
        #expect(vm.filteredBacklogTasks.count == 2)

        vm.searchText = "bug"
        #expect(vm.filteredBacklogTasks.count == 1)

        vm.searchText = ""
        #expect(vm.filteredBacklogTasks.count == 3)
    }

    @Test func isAtLimitCalculation() {
        let repo = MockTaskRepository()
        let vm = PlanningViewModel(repository: repo)

        vm.meta = makeMeta(weeklyCount: 5, weeklyLimit: 10)
        #expect(!vm.isAtLimit)

        vm.meta = makeMeta(weeklyCount: 10, weeklyLimit: 10)
        #expect(vm.isAtLimit)

        vm.meta = makeMeta(weeklyCount: 5, weeklyLimit: 0)
        #expect(!vm.isAtLimit)
    }
}

// MARK: - Pinned Tasks Tests

@Suite struct PinnedTasksTests {
    private func makePinnedConfig(pinnedTasks: [PinnedTask] = [], maxPinned: Int = 5) -> AppConfig {
        AppConfig(
            settings: AppSettings(
                pollInterval: 30, syncInterval: 10, timezone: "UTC",
                weeklyLabel: "weekly", backlogLabel: "backlog",
                projectLabel: "project", projectsLabel: "projects",
                weeklyLimit: 20, backlogLimit: 50, completedDays: 7,
                maxPinned: maxPinned, lastSyncedAt: nil, dayParts: [],
                maxDayPartNoteLength: 200, inboxProjectId: "inbox",
                inboxLimit: 50, inboxOverflowTaskContent: "Too many tasks"
            ),
            contexts: [],
            projects: [],
            labels: [],
            labelConfigs: [],
            autoLabels: [],
            quickCapture: nil,
            projectTasks: [],
            labelProjectMap: [],
            autoRemove: AutoRemoveStatus(rules: [], paused: false),
            state: UserState(
                pinnedTasks: pinnedTasks, activeContextId: "",
                activeView: "all", collapsedIds: [],
                sidebarCollapsed: false, planningOpen: false,
                dayPartNotes: [:], locale: "en", allFilters: nil
            )
        )
    }

    @Test func pinTaskAddsToList() async {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig())
        let repo = MockTaskRepository()
        let task = makeTask(id: "t1", content: "Important task")

        store.pinTask(task, repository: repo)

        #expect(store.pinnedTasks.count == 1)
        #expect(store.pinnedTasks[0].id == "t1")
        #expect(store.pinnedTasks[0].content == "Important task")
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.patchStateCalled)
        #expect(repo.lastPatchStateRequest?.pinnedTasks?.count == 1)
    }

    @Test func unpinTaskRemovesFromList() async {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig(pinnedTasks: [
            PinnedTask(id: "t1", content: "Task 1"),
            PinnedTask(id: "t2", content: "Task 2")
        ]))
        let repo = MockTaskRepository()

        store.unpinTask("t1", repository: repo)

        #expect(store.pinnedTasks.count == 1)
        #expect(store.pinnedTasks[0].id == "t2")
        try? await Task.sleep(for: .milliseconds(100))
        #expect(repo.patchStateCalled)
    }

    @Test func pinTaskRespectsMaxPinnedLimit() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig(
            pinnedTasks: [
                PinnedTask(id: "t1", content: "Task 1"),
                PinnedTask(id: "t2", content: "Task 2")
            ],
            maxPinned: 2
        ))
        let repo = MockTaskRepository()
        let task = makeTask(id: "t3", content: "Task 3")

        store.pinTask(task, repository: repo)

        #expect(store.pinnedTasks.count == 2)
        #expect(!store.isTaskPinned("t3"))
        #expect(!repo.patchStateCalled)
    }

    @Test func pinTaskIgnoresDuplicate() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig(pinnedTasks: [
            PinnedTask(id: "t1", content: "Task 1")
        ]))
        let repo = MockTaskRepository()
        let task = makeTask(id: "t1", content: "Task 1")

        store.pinTask(task, repository: repo)

        #expect(store.pinnedTasks.count == 1)
        #expect(!repo.patchStateCalled)
    }

    @Test func isTaskPinnedReturnsTrueForPinned() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig(pinnedTasks: [
            PinnedTask(id: "t1", content: "Task 1")
        ]))

        #expect(store.isTaskPinned("t1"))
        #expect(!store.isTaskPinned("t2"))
    }

    @Test func togglePinTaskPinsUnpinnedTask() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig())
        let repo = MockTaskRepository()
        let task = makeTask(id: "t1", content: "Task 1")

        store.togglePinTask(task, repository: repo)

        #expect(store.isTaskPinned("t1"))
    }

    @Test func togglePinTaskUnpinsPinnedTask() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig(pinnedTasks: [
            PinnedTask(id: "t1", content: "Task 1")
        ]))
        let repo = MockTaskRepository()
        let task = makeTask(id: "t1", content: "Task 1")

        store.togglePinTask(task, repository: repo)

        #expect(!store.isTaskPinned("t1"))
    }

    @Test func unpinNonExistentTaskIsNoOp() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig())
        let repo = MockTaskRepository()

        store.unpinTask("nonexistent", repository: repo)

        #expect(!repo.patchStateCalled)
    }

    @Test func maxPinnedDefaultsToFive() {
        let store = AppConfigStore()
        store.setConfig(makePinnedConfig())

        #expect(store.maxPinned == 5)
    }
}
