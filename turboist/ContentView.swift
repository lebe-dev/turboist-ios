import SwiftUI

struct ContentView: View {
    @State private var apiClient: APIClient
    @State private var taskListViewModel: TaskListViewModel
    @State private var taskDetailViewModel: TaskDetailViewModel
    @State private var planningViewModel: PlanningViewModel
    @State private var configStore = AppConfigStore()
    @State private var showPlanning = false

    init() {
        let client = APIClient(baseURL: "http://localhost:8080")
        let repo = TaskRepository(apiClient: client)
        _apiClient = State(initialValue: client)
        _taskListViewModel = State(initialValue: TaskListViewModel(repository: repo))
        _taskDetailViewModel = State(initialValue: TaskDetailViewModel(repository: repo))
        _planningViewModel = State(initialValue: PlanningViewModel(repository: repo))
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
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button {
                    openPlanning()
                } label: {
                    Label("Planning", systemImage: "list.clipboard")
                }
            }
        }
        .sheet(isPresented: $showPlanning) {
            onDismissPlanning()
        } content: {
            NavigationStack {
                PlanningView(
                    viewModel: planningViewModel,
                    configStore: configStore,
                    onExit: { closePlanning() }
                )
            }
        }
        .task {
            do {
                let config = try await apiClient.fetchConfig()
                configStore.setConfig(config)
                planningViewModel.configure(settings: config.settings)
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

    private func openPlanning() {
        showPlanning = true
        configStore.config?.state.planningOpen = true
        let contextId = configStore.activeContextId.isEmpty ? nil : configStore.activeContextId
        Task {
            try? await taskListViewModel.repository.patchState(PatchStateRequest(planningOpen: true))
            await planningViewModel.enter(contextId: contextId)
        }
    }

    private func closePlanning() {
        showPlanning = false
    }

    private func onDismissPlanning() {
        configStore.config?.state.planningOpen = false
        Task {
            try? await taskListViewModel.repository.patchState(PatchStateRequest(planningOpen: false))
            await taskListViewModel.loadTasks(view: taskListViewModel.currentView)
        }
    }
}

#Preview {
    ContentView()
}
