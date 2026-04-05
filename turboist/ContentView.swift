import SwiftUI

struct ContentView: View {
    @State private var apiClient: APIClient
    @State private var taskListViewModel: TaskListViewModel
    @State private var taskDetailViewModel: TaskDetailViewModel
    @State private var configStore = AppConfigStore()

    init() {
        let client = APIClient(baseURL: "http://localhost:8080")
        let repo = TaskRepository(apiClient: client)
        _apiClient = State(initialValue: client)
        _taskListViewModel = State(initialValue: TaskListViewModel(repository: repo))
        _taskDetailViewModel = State(initialValue: TaskDetailViewModel(repository: repo))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ViewSwitcherView(
                    currentView: taskListViewModel.currentView
                ) { newView in
                    switchView(newView)
                }

                TaskListView(
                    viewModel: taskListViewModel,
                    configStore: configStore,
                    onViewChange: { switchView($0) }
                )
            }
            .navigationDestination(for: TaskItem.self) { task in
                TaskDetailView(viewModel: {
                    let vm = taskDetailViewModel
                    vm.setTask(task)
                    return vm
                }(), availableLabels: configStore.labels)
            }
            .navigationDestination(for: String.self) { parentId in
                TaskDetailView(viewModel: {
                    let vm = taskDetailViewModel
                    if let parentTask = taskListViewModel.findTask(by: parentId) {
                        vm.setTask(parentTask)
                    }
                    return vm
                }(), availableLabels: configStore.labels)
            }
        }
        .task {
            do {
                let config = try await apiClient.fetchConfig()
                configStore.setConfig(config)
                taskListViewModel.setCollapsedIds(config.state.collapsedIds)
                let contextId = config.state.activeContextId
                if !contextId.isEmpty {
                    taskListViewModel.activeContextId = contextId
                }
                let initialView = TaskView(rawValue: config.state.activeView) ?? .all
                taskListViewModel.currentView = initialView
                await taskListViewModel.loadTasks(view: initialView)
            } catch {
                await taskListViewModel.loadTasks()
            }
        }
    }

    private func switchView(_ newView: TaskView) {
        guard newView != taskListViewModel.currentView else { return }
        configStore.setActiveView(newView, repository: taskListViewModel.repository)
        taskListViewModel.selectedPriorities.removeAll()
        Task {
            await taskListViewModel.loadTasks(view: newView)
        }
    }
}

#Preview {
    ContentView()
}
