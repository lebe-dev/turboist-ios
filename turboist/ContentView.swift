import SwiftUI

struct ContentView: View {
    @State private var apiClient: APIClient
    @State private var authStore: AuthStore
    @State private var taskListViewModel: TaskListViewModel
    @State private var planningViewModel: PlanningViewModel
    @State private var browseViewModel: BrowseViewModel
    @State private var configStore = AppConfigStore()
    @State private var connectionStore = ConnectionStatusStore()
    @State private var showPlanning = false
    @State private var showQuickCapture = false
    @State private var showCreateTask = false
    @State private var showBrowse = false
    @State private var navigationPath = NavigationPath()

    init() {
        let client = APIClient(baseURL: "https://t.tinyops.ru")
        let repo = TaskRepository(apiClient: client)
        _apiClient = State(initialValue: client)
        _authStore = State(initialValue: AuthStore(apiClient: client))
        _taskListViewModel = State(initialValue: TaskListViewModel(repository: repo))
        _planningViewModel = State(initialValue: PlanningViewModel(repository: repo))
        _browseViewModel = State(initialValue: BrowseViewModel(repository: repo))
    }

    var body: some View {
        Group {
            switch authStore.state {
            case .unknown:
                ProgressView()
                    .task { await authStore.checkAuth() }
            case .unauthenticated:
                LoginView(authStore: authStore)
            case .authenticated:
                mainContent
            }
        }
    }

    private var mainContent: some View {
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

                Group {
                    if showBrowse {
                        BrowseView(
                            viewModel: browseViewModel,
                            configStore: configStore,
                            onOpenTask: { task in navigationPath.append(task) }
                        )
                    } else {
                        TaskListView(
                            viewModel: taskListViewModel,
                            configStore: configStore,
                            onViewChange: { switchView($0) },
                            onOpenTask: { task in navigationPath.append(task) }
                        )
                    }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ViewSwitcherView(
                        currentView: taskListViewModel.currentView,
                        isBrowseActive: showBrowse,
                        onSelect: {
                            showBrowse = false
                            switchView($0)
                        },
                        onAdd: { showCreateTask = true },
                        onBrowse: { showBrowse = true }
                    )
                }
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
                } else {
                    ContentUnavailableView(
                        "Task Not Found",
                        systemImage: "doc.questionmark",
                        description: Text("This task may have been deleted or is not loaded")
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 14) {
                    Button {
                        openPlanning()
                    } label: {
                        Image(systemName: "list.clipboard")
                    }
                    if configStore.config?.quickCapture != nil {
                        Button {
                            showQuickCapture = true
                        } label: {
                            Image(systemName: "lightbulb")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView(
                repository: taskListViewModel.repository,
                availableLabels: configStore.labels,
                configStore: configStore
            ) {
                Task { await taskListViewModel.loadTasks(view: taskListViewModel.currentView) }
            }
        }
        .sheet(isPresented: $showQuickCapture) {
            if let qc = configStore.config?.quickCapture {
                QuickCaptureView(
                    parentTaskId: qc.parentTaskId,
                    repository: taskListViewModel.repository,
                    onCreated: {
                        Task { await taskListViewModel.loadTasks(view: taskListViewModel.currentView) }
                    }
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
            } catch APIError.unauthorized {
                authStore.markUnauthenticated()
            } catch let apiError as APIError {
                taskListViewModel.error = "Config: \(apiError.errorDescription ?? "unknown")"
            } catch {
                taskListViewModel.error = "Config: \(error.localizedDescription)"
            }
        }
    }

    private func switchView(_ newView: TaskView) {
        guard newView != taskListViewModel.currentView else { return }
        configStore.setActiveView(newView, repository: taskListViewModel.repository)
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
            Task {
                if let task = await fetchTaskFromAllView(taskId) {
                    navigationPath.append(task)
                } else {
                    navigationPath.append(taskId)
                }
            }
        }
    }

    private func fetchTaskFromAllView(_ taskId: String) async -> TaskItem? {
        guard let response = try? await taskListViewModel.repository.fetchTasks(view: .all, context: nil) else {
            return nil
        }
        return findTaskRecursive(id: taskId, in: response.tasks)
    }

    private func findTaskRecursive(id: String, in tasks: [TaskItem]) -> TaskItem? {
        for task in tasks {
            if task.id == id { return task }
            if let found = findTaskRecursive(id: id, in: task.children) { return found }
        }
        return nil
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
