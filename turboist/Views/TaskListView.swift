import SwiftUI

struct TaskListView: View {
    @Bindable var viewModel: TaskListViewModel
    var configStore: AppConfigStore?
    @State private var showCreateTask = false
    @State private var showLabelsView = false
    @State private var taskToDelete: TaskItem?
    @State private var taskToMove: TaskItem?
    @State private var moveParentId = ""
    @State private var subtaskParentId: String?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                ProgressView()
            } else if let error = viewModel.error, viewModel.tasks.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                taskList
            }
        }
        .navigationTitle(viewModel.currentView.rawValue.capitalized)
        .toolbar {
            if let configStore, !configStore.contexts.isEmpty {
                ToolbarItem(placement: .principal) {
                    ContextPickerView(
                        contexts: configStore.contexts,
                        activeContextId: viewModel.activeContextId
                    ) { contextId in
                        configStore.setActiveContext(contextId, repository: viewModel.repository)
                        Task { await viewModel.switchContext(contextId) }
                    }
                }
            }

            if viewModel.currentView == .all {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(Priority.allCases.reversed()) { priority in
                            Button {
                                viewModel.togglePriorityFilter(priority.rawValue)
                            } label: {
                                if viewModel.selectedPriorities.contains(priority.rawValue) {
                                    Label(priority.label, systemImage: "checkmark")
                                } else {
                                    Text(priority.label)
                                }
                            }
                        }
                        if viewModel.isFiltering {
                            Divider()
                            Button("Clear Filters") {
                                viewModel.clearPriorityFilter()
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    if let configStore, !configStore.labels.isEmpty {
                        Button {
                            showLabelsView = true
                        } label: {
                            Image(systemName: "tag")
                        }
                    }
                    Button {
                        subtaskParentId = nil
                        showCreateTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView(repository: viewModel.repository, parentId: subtaskParentId, availableLabels: configStore?.labels ?? [], configStore: configStore) {
                Task { await viewModel.loadTasks(view: viewModel.currentView) }
            }
        }
        .alert("Delete Task?", isPresented: .init(
            get: { taskToDelete != nil },
            set: { if !$0 { taskToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let task = taskToDelete {
                    Task { await viewModel.deleteTask(task) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will also delete all subtasks.")
        }
        .alert("Move Task", isPresented: .init(
            get: { taskToMove != nil },
            set: { if !$0 { taskToMove = nil; moveParentId = "" } }
        )) {
            TextField("Parent Task ID", text: $moveParentId)
            Button("Move") {
                if let task = taskToMove, !moveParentId.isEmpty {
                    Task { await viewModel.moveTask(task, parentId: moveParentId) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter the ID of the parent task.")
        }
        .sheet(isPresented: $showLabelsView) {
            if let configStore {
                NavigationStack {
                    LabelsListView(
                        labels: configStore.labels,
                        labelConfigs: configStore.labelConfigs,
                        tasks: viewModel.tasks
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showLabelsView = false }
                        }
                    }
                }
            }
        }
        .refreshable {
            await viewModel.loadTasks(view: viewModel.currentView)
        }
    }

    private var taskList: some View {
        List {
            ForEach(viewModel.displayTasks) { displayTask in
                NavigationLink(value: displayTask.task) {
                    TaskRowView(
                        task: displayTask.task,
                        depth: displayTask.depth,
                        hasChildren: displayTask.hasChildren,
                        isCollapsed: viewModel.collapsedIds.contains(displayTask.task.id),
                        availableLabels: configStore?.labels ?? [],
                        onComplete: {
                            Task { await viewModel.completeTask(displayTask.task) }
                        },
                        onToggleCollapse: {
                            Task { await viewModel.toggleCollapsed(displayTask.task.id) }
                        }
                    )
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        taskToDelete = displayTask.task
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await viewModel.completeTask(displayTask.task) }
                    } label: {
                        Label("Complete", systemImage: "checkmark")
                    }
                    .tint(.green)
                }
                .contextMenu {
                    Menu {
                        ForEach(Priority.allCases.reversed()) { priority in
                            Button {
                                Task { await viewModel.updateTaskPriority(displayTask.task, priority: priority.rawValue) }
                            } label: {
                                Label(priority.label, systemImage: displayTask.task.priority == priority.rawValue ? "checkmark" : "flag.fill")
                            }
                        }
                    } label: {
                        Label("Priority", systemImage: "flag")
                    }

                    Menu {
                        Button {
                            Task { await viewModel.updateTaskDueDate(displayTask.task, dueDate: DueDateHelper.todayString()) }
                        } label: {
                            Label("Today", systemImage: "calendar")
                        }
                        Button {
                            Task { await viewModel.updateTaskDueDate(displayTask.task, dueDate: DueDateHelper.tomorrowString()) }
                        } label: {
                            Label("Tomorrow", systemImage: "sun.max")
                        }
                        if displayTask.task.due != nil {
                            Divider()
                            Button(role: .destructive) {
                                Task { await viewModel.updateTaskDueDate(displayTask.task, dueDate: "") }
                            } label: {
                                Label("Clear Date", systemImage: "calendar.badge.minus")
                            }
                        }
                    } label: {
                        Label("Due Date", systemImage: "calendar")
                    }

                    Button {
                        subtaskParentId = displayTask.task.id
                        showCreateTask = true
                    } label: {
                        Label("Add Subtask", systemImage: "plus.square")
                    }
                    Button {
                        Task { await viewModel.duplicateTask(displayTask.task) }
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Button {
                        taskToMove = displayTask.task
                    } label: {
                        Label("Move", systemImage: "arrow.right")
                    }
                    Button(role: .destructive) {
                        taskToDelete = displayTask.task
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }
}
