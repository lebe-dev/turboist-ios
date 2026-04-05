import SwiftUI

struct ContentView: View {
    @State private var apiClient: APIClient
    @State private var taskListViewModel: TaskListViewModel
    @State private var planningViewModel: PlanningViewModel
    @State private var configStore = AppConfigStore()
    @State private var connectionStore = ConnectionStatusStore()
    @State private var showPlanning = false
    @State private var showQuickCapture = false
    @State private var navigationPath = NavigationPath()

    init() {
        let client = APIClient(baseURL: "http://localhost:8080")
        let repo = TaskRepository(apiClient: client)
        _apiClient = State(initialValue: client)
        _taskListViewModel = State(initialValue: TaskListViewModel(repository: repo))
        _planningViewModel = State(initialValue: PlanningViewModel(repository: repo))
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                ConnectionStatusView(
                    connectionState: connectionStore.connectionState,
                    pendingActionCount: connectionStore.pendingActionCount
                )

                AutoRemovePausedBanner(isVisible: configStore.autoRemovePaused)

                PinnedTasksView(
                    pinnedTasks: configStore.pinnedTasks,
                    onTapTask: { taskId in
                        navigateToPinnedTask(taskId)
                    },
                    onUnpin: { taskId in
                        configStore.unpinTask(taskId, repository: taskListViewModel.repository)
                    }
                )

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
                TaskDetailView(
                    viewModel: TaskDetailViewModel(repository: taskListViewModel.repository, task: task),
                    availableLabels: configStore.labels,
                    configStore: configStore
                )
            }
            .navigationDestination(for: String.self) { parentId in
                if let parentTask = taskListViewModel.findTask(by: parentId) {
                    TaskDetailView(
                        viewModel: TaskDetailViewModel(repository: taskListViewModel.repository, task: parentTask),
                        availableLabels: configStore.labels,
                        configStore: configStore
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    Button {
                        openPlanning()
                    } label: {
                        Label("Planning", systemImage: "list.clipboard")
                    }
                    Spacer()
                    if configStore.config?.quickCapture != nil {
                        Button {
                            showQuickCapture = true
                        } label: {
                            Label("Quick Capture", systemImage: "lightbulb")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showQuickCapture) {
            if let qc = configStore.config?.quickCapture {
                QuickCaptureView(
                    parentTaskId: qc.parentTaskId,
                    repository: taskListViewModel.repository
                )
                .presentationDetents([.medium])
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
        .onAppear {
            connectionStore.start()
        }
        .onDisappear {
            connectionStore.stop()
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
                if let allFilters = config.state.allFilters {
                    taskListViewModel.restoreFilters(from: allFilters)
                }
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
        taskListViewModel.clearAllFilters()
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

    private func navigateToPinnedTask(_ taskId: String) {
        if let task = taskListViewModel.findTask(by: taskId) {
            navigationPath.append(task)
        } else {
            navigationPath.append(taskId)
        }
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
