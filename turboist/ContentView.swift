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
            TaskListView(viewModel: taskListViewModel, configStore: configStore)
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
            } catch {
                // Non-critical, proceed without persisted state
            }
            await taskListViewModel.loadTasks()
        }
    }
}

#Preview {
    ContentView()
}
