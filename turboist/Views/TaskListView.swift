import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TaskListView: View {
    @Bindable var viewModel: TaskListViewModel
    var configStore: AppConfigStore?
    var onViewChange: ((TaskView) -> Void)?
    var onOpenTask: ((TaskItem) -> Void)?
    @State private var showCreateTask = false
    @State private var showLabelsView = false
    @State private var taskToDelete: TaskItem?
    @State private var taskToMove: TaskItem?
    @State private var moveParentId = ""
    @State private var subtaskParentId: String?
    @State private var menuTask: TaskItem?
    @State private var datePickerTask: TaskItem?
    @State private var pickedDate: Date = Date()
    @State private var decomposeTask: TaskItem?
    @State private var createForPhaseLabel: String?

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.tasks.isEmpty {
                ProgressView()
            } else if let error = viewModel.error, viewModel.tasks.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                VStack(spacing: 0) {
                    if viewModel.searchableView {
                        searchBar
                    }
                    viewSpecificHeader
                    taskList
                }
            }
        }
        .navigationTitle(viewModel.currentView.displayName)
        .toolbar {
            if let configStore, !configStore.contexts.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
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
                        Menu("Priority") {
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
                        }
                        if let configStore, !configStore.labels.isEmpty {
                            Menu("Labels") {
                                ForEach(configStore.labels) { label in
                                    Button {
                                        viewModel.toggleLabelFilter(label.name)
                                    } label: {
                                        if viewModel.selectedLabels.contains(label.name) {
                                            Label(label.name, systemImage: "checkmark")
                                        } else {
                                            Text(label.name)
                                        }
                                    }
                                }
                            }
                        }
                        Button {
                            viewModel.toggleLinksOnly()
                        } label: {
                            if viewModel.linksOnly {
                                Label("Links Only", systemImage: "checkmark")
                            } else {
                                Text("Links Only")
                            }
                        }
                        if viewModel.isFiltering {
                            Divider()
                            Button("Clear Filters") {
                                viewModel.clearAllFilters()
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                }
            }
            if let configStore, !configStore.labels.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLabelsView = true
                    } label: {
                        Image(systemName: "tag")
                    }
                }
            }
        }
        .sheet(isPresented: $showCreateTask) {
            CreateTaskView(repository: viewModel.repository, parentId: subtaskParentId, availableLabels: configStore?.labels ?? [], configStore: configStore) {
                Task { await viewModel.loadTasks(view: viewModel.currentView) }
            }
        }
        .sheet(isPresented: .init(
            get: { createForPhaseLabel != nil },
            set: { if !$0 { createForPhaseLabel = nil } }
        )) {
            if let phaseLabel = createForPhaseLabel {
                CreateTaskView(
                    repository: viewModel.repository,
                    initialLabels: [phaseLabel],
                    availableLabels: configStore?.labels ?? [],
                    configStore: configStore
                ) {
                    Task { await viewModel.loadTasks(view: viewModel.currentView) }
                }
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
        .sheet(isPresented: .init(
            get: { viewModel.nextActionPrompt != nil },
            set: { if !$0 { viewModel.dismissNextAction() } }
        )) {
            if let prompt = viewModel.nextActionPrompt {
                NextActionView(
                    prompt: prompt,
                    repository: viewModel.repository,
                    availableLabels: configStore?.labels ?? []
                ) {
                    Task { await viewModel.loadTasks(view: viewModel.currentView) }
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(item: $datePickerTask) { task in
            NavigationStack {
                VStack {
                    DatePicker(
                        "Дата",
                        selection: $pickedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    Spacer()
                }
                .navigationTitle("Выбрать дату")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { datePickerTask = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово") {
                            let dateStr = DueDateHelper.format(pickedDate)
                            Task { await viewModel.updateTaskDueDate(task, dueDate: dateStr) }
                            datePickerTask = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $decomposeTask) { task in
            DecomposeTaskView(
                viewModel: TaskDetailViewModel(repository: viewModel.repository, task: task),
                onDecomposed: {
                    Task { await viewModel.loadTasks(view: viewModel.currentView) }
                }
            )
        }
        .refreshable {
            await viewModel.loadTasks(view: viewModel.currentView)
        }
        .overlay {
            TaskContextMenuOverlay(
                isPresented: menuTask != nil,
                onDismiss: { menuTask = nil }
            ) {
                if let task = menuTask {
                    TaskContextMenuView(
                        task: task,
                        isInBacklog: isInBacklog(task),
                        backlogLabel: configStore?.settings?.backlogLabel ?? "",
                        isPinned: configStore?.isTaskPinned(task.id) ?? false,
                        canPin: configStore != nil,
                        dayParts: configStore?.dayParts ?? [],
                        currentDayPartLabel: task.labels.first { dayPartLabels.contains($0) },
                        onEdit: { onOpenTask?(task) },
                        onDuplicate: { Task { await viewModel.duplicateTask(task) } },
                        onCopy: { copyToPasteboard(task.content) },
                        onToggleBacklog: { toggleBacklog(task) },
                        onTogglePin: {
                            configStore?.togglePinTask(task, repository: viewModel.repository)
                        },
                        onDecompose: { decomposeTask = task },
                        onSetDate: { date in
                            Task { await viewModel.updateTaskDueDate(task, dueDate: date) }
                        },
                        onClearDate: {
                            Task { await viewModel.updateTaskDueDate(task, dueDate: "") }
                        },
                        onPickDate: {
                            pickedDate = DueDateHelper.parse(task.due?.date ?? "") ?? Date()
                            datePickerTask = task
                        },
                        onSetPriority: { priority in
                            Task { await viewModel.updateTaskPriority(task, priority: priority) }
                        },
                        onMoveToPhase: { phaseLabel in
                            moveTaskToPhase(task, phaseLabel: phaseLabel)
                        },
                        onDelete: { taskToDelete = task },
                        onDismiss: { menuTask = nil }
                    )
                }
            }
        }
    }

    private func moveTaskToPhase(_ task: TaskItem, phaseLabel: String) {
        var newLabels = task.labels.filter { !dayPartLabels.contains($0) }
        newLabels.append(phaseLabel)
        Task { await viewModel.batchUpdateLabels([task.id: newLabels]) }
    }

    private func isInBacklog(_ task: TaskItem) -> Bool {
        guard let label = configStore?.settings?.backlogLabel, !label.isEmpty else { return false }
        return task.labels.contains(label)
    }

    private func toggleBacklog(_ task: TaskItem) {
        guard let label = configStore?.settings?.backlogLabel, !label.isEmpty else { return }
        var newLabels = task.labels
        if let idx = newLabels.firstIndex(of: label) {
            newLabels.remove(at: idx)
        } else {
            newLabels.append(label)
        }
        Task { await viewModel.batchUpdateLabels([task.id: newLabels]) }
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tasks...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var viewSpecificHeader: some View {
        if let meta = viewModel.meta, let settings = configStore?.settings {
            switch viewModel.currentView {
            case .weekly:
                TaskLimitProgressView(
                    count: meta.weeklyCount,
                    limit: meta.weeklyLimit,
                    label: "Weekly"
                )
            case .backlog:
                TaskLimitProgressView(
                    count: meta.backlogCount,
                    limit: meta.backlogLimit,
                    label: "Backlog"
                )
            case .inbox:
                if let inboxCount = meta.inboxCount {
                    InboxOverflowBanner(
                        inboxCount: inboxCount,
                        inboxLimit: settings.inboxLimit,
                        warningText: settings.inboxOverflowTaskContent
                    )
                }
            default:
                EmptyView()
            }
        }
    }

    private var isDayPartView: Bool {
        viewModel.currentView == .today || viewModel.currentView == .tomorrow
    }

    private var dayPartLabels: Set<String> {
        Set(configStore?.dayParts.map(\.label) ?? [])
    }

    private var dayPartSections: [DayPartSection] {
        guard let configStore else { return [] }
        return groupTasksByDayPart(
            tasks: viewModel.tasks,
            dayParts: configStore.dayParts,
            dayPartNotes: configStore.dayPartNotes
        ).filter { !$0.tasks.isEmpty }
    }

    private var taskList: some View {
        List {
            if isDayPartView && configStore != nil {
                ForEach(dayPartSections) { section in
                    DayPartSectionView(
                        section: section,
                        collapsedIds: viewModel.collapsedIds,
                        availableLabels: configStore?.labels ?? [],
                        dayPartLabels: dayPartLabels,
                        onComplete: { task in
                            Task { await viewModel.completeTask(task) }
                        },
                        onToggleCollapse: { taskId in
                            Task { await viewModel.toggleCollapsed(taskId) }
                        },
                        onNoteChanged: { label, text in
                            configStore?.setDayPartNote(label, text: text, repository: viewModel.repository)
                        },
                        onLongPress: { task in
                            menuTask = task
                        },
                        onCreateForPhase: { phaseLabel in
                            createForPhaseLabel = phaseLabel
                        }
                    )
                }
            } else {
                ForEach(viewModel.displayTasks) { displayTask in
                    taskRow(displayTask)
                }
            }
        }
        .listStyle(.plain)
        .listRowSeparatorTint(DS.Palette.hairline)
        .overlay {
            if viewModel.isSearching && viewModel.displayTasks.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search")
                )
            }
        }
    }

    private func taskRow(_ displayTask: DisplayTask) -> some View {
        Button {
            onOpenTask?(displayTask.task)
        } label: {
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
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: 0.4) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            menuTask = displayTask.task
        }
    }
}
