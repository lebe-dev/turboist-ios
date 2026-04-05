import SwiftUI

struct ContentView: View {
    @State private var apiClient: APIClient
    @State private var taskListViewModel: TaskListViewModel
    @State private var taskDetailViewModel: TaskDetailViewModel

    init() {
        let client = APIClient(baseURL: "http://localhost:8080")
        let repo = TaskRepository(apiClient: client)
        _apiClient = State(initialValue: client)
        _taskListViewModel = State(initialValue: TaskListViewModel(repository: repo))
        _taskDetailViewModel = State(initialValue: TaskDetailViewModel(repository: repo))
    }

    var body: some View {
        NavigationStack {
            TaskListView(viewModel: taskListViewModel)
                .navigationDestination(for: TaskItem.self) { task in
                    TaskDetailView(viewModel: {
                        let vm = taskDetailViewModel
                        vm.setTask(task)
                        return vm
                    }())
                }
        }
        .task {
            await taskListViewModel.loadTasks()
        }
    }
}

#Preview {
    ContentView()
}
