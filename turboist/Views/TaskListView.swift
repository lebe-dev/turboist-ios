import SwiftUI

struct TaskListView: View {
    @Bindable var viewModel: TaskListViewModel
    @State private var showCreateTask = false
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    subtaskParentId = nil
                    showCreateTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView(repository: viewModel.repository, parentId: subtaskParentId) {
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
