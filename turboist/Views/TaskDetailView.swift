import SwiftUI

struct TaskDetailView: View {
    @Bindable var viewModel: TaskDetailViewModel
    @State private var editedContent: String = ""
    @State private var editedDescription: String = ""
    @State private var editedPriority: Int = 1
    @State private var editedDueDate: String = ""
    @State private var isEditing = false
    @State private var showDecompose = false
    @State private var showCompletedSubtasks = false
    @State private var showCreateSubtask = false
    @State private var showDatePicker = false
    @State private var showRecurrencePicker = false
    @State private var showLabelPicker = false
    @State private var editedLabels: [String] = []
    var availableLabels: [TaskLabel] = []
    var configStore: AppConfigStore?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let task = viewModel.task {
                taskContent(task)
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "doc")
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.task != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .sheet(isPresented: $showDecompose) {
            DecomposeTaskView(viewModel: viewModel) {
                dismiss()
            }
        }
        .sheet(isPresented: $showCreateSubtask) {
            if let task = viewModel.task {
                CreateTaskView(repository: viewModel.repository, parentId: task.id, availableLabels: availableLabels) {
                    // Reload to show new subtask
                }
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(currentDate: viewModel.task?.due?.date) { dateString in
                Task { await viewModel.updateTask(dueDate: dateString) }
            } onClear: {
                Task { await viewModel.updateTask(dueDate: "") }
            }
        }
        .sheet(isPresented: $showLabelPicker) {
            LabelPickerView(availableLabels: availableLabels, selectedLabels: $editedLabels)
                .onDisappear {
                    guard let task = viewModel.task, editedLabels != task.labels else { return }
                    Task { await viewModel.updateTask(labels: editedLabels) }
                }
        }
        .sheet(isPresented: $showRecurrencePicker) {
            RecurrencePickerView(currentDue: viewModel.task?.due) { dueString in
                if dueString.hasPrefix("__clear_recurrence__:") {
                    let date = String(dueString.dropFirst("__clear_recurrence__:".count))
                    Task { await viewModel.updateTask(dueDate: date) }
                } else {
                    Task { await viewModel.updateTask(dueString: dueString) }
                }
            }
        }
    }

    @ViewBuilder
    private func taskContent(_ task: TaskItem) -> some View {
        List {
            // Parent task navigation
            if let parentId = task.parentId {
                Section {
                    NavigationLink(value: parentId) {
                        Label("Go to Parent Task", systemImage: "arrow.up.square")
                    }
                }
            }

            Section("Content") {
                if isEditing {
                    TextField("Title", text: $editedContent)
                    TextField("Description", text: $editedDescription, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    Text(task.content)
                        .font(.headline)
                    if !task.description.isEmpty {
                        MarkdownText(task.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Priority") {
                if isEditing {
                    Picker("Priority", selection: $editedPriority) {
                        Text("P1 - Urgent").tag(4)
                        Text("P2 - High").tag(3)
                        Text("P3 - Medium").tag(2)
                        Text("P4 - Low").tag(1)
                    }
                } else {
                    Label(priorityLabel(task.priority), systemImage: "flag.fill")
                        .foregroundStyle(priorityColor(task.priority))
                }
            }

            Section("Due Date") {
                if let due = task.due {
                    HStack {
                        Label(DueDateHelper.displayLabel(for: due.date),
                              systemImage: due.recurring ? "arrow.triangle.2.circlepath" : "calendar")
                            .foregroundStyle(DueDateHelper.status(for: due.date).color)
                        Spacer()
                        Text(due.date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if due.recurring {
                        Label("Recurring", systemImage: "repeat")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("No date set")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showDatePicker = true
                } label: {
                    Label("Set Date", systemImage: "calendar.badge.plus")
                }
                Button {
                    showRecurrencePicker = true
                } label: {
                    Label("Set Recurrence", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            Section("Labels") {
                if !task.labels.isEmpty {
                    FlowLayout(spacing: 6) {
                        ForEach(task.labels, id: \.self) { label in
                            LabelBadge(name: label, availableLabels: availableLabels)
                        }
                    }
                }
                Button {
                    editedLabels = task.labels
                    showLabelPicker = true
                } label: {
                    Label(task.labels.isEmpty ? "Add Labels" : "Edit Labels", systemImage: "tag")
                }
            }

            if task.postponeCount > 0 {
                Section {
                    Label("Postponed \(task.postponeCount) time(s)", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(DueDateHelper.postponeColor(count: task.postponeCount))
                }
            }

            if let expiresText = ExpiresInHelper.expiresInText(for: task.expiresAt) {
                Section {
                    Label(expiresText, systemImage: "flame")
                        .foregroundStyle(.orange)
                }
            }

            // Subtasks
            if !task.children.isEmpty {
                Section("Subtasks (\(task.completedSubTaskCount)/\(task.subTaskCount))") {
                    ForEach(task.children) { child in
                        NavigationLink(value: child) {
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundStyle(priorityColor(child.priority))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.content)
                                    if child.subTaskCount > 0 {
                                        Text("\(child.completedSubTaskCount)/\(child.subTaskCount) subtasks")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if task.subTaskCount > 0 {
                Section("Subtasks (\(task.completedSubTaskCount)/\(task.subTaskCount))") {
                    ProgressView(value: Double(task.completedSubTaskCount), total: Double(task.subTaskCount))
                        .tint(task.completedSubTaskCount == task.subTaskCount ? .green : .blue)
                }
            }

            // Completed subtasks
            if task.subTaskCount > 0 {
                Section {
                    Button {
                        showCompletedSubtasks.toggle()
                        if showCompletedSubtasks {
                            Task { await viewModel.loadCompletedSubtasks() }
                        }
                    } label: {
                        Label(showCompletedSubtasks ? "Hide Completed" : "Show Completed Subtasks",
                              systemImage: showCompletedSubtasks ? "chevron.up" : "chevron.down")
                    }

                    if showCompletedSubtasks {
                        ForEach(viewModel.completedSubtasks) { subtask in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(subtask.content)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            // Actions
            Section {
                if let configStore {
                    let isPinned = configStore.isTaskPinned(task.id)
                    Button {
                        configStore.togglePinTask(task, repository: viewModel.repository)
                    } label: {
                        Label(isPinned ? "Unpin Task" : "Pin Task", systemImage: isPinned ? "pin.slash" : "pin")
                    }
                }

                Button {
                    showCreateSubtask = true
                } label: {
                    Label("Add Subtask", systemImage: "plus.square")
                }

                Button {
                    showDecompose = true
                } label: {
                    Label("Decompose into Subtasks", systemImage: "rectangle.split.3x1")
                }
            }

            if let error = viewModel.error {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }

    private func startEditing() {
        guard let task = viewModel.task else { return }
        editedContent = task.content
        editedDescription = task.description
        editedPriority = task.priority
        isEditing = true
    }

    private func saveChanges() {
        guard let task = viewModel.task else { return }
        isEditing = false
        Task {
            await viewModel.updateTask(
                content: editedContent != task.content ? editedContent : nil,
                description: editedDescription != task.description ? editedDescription : nil,
                priority: editedPriority != task.priority ? editedPriority : nil
            )
        }
    }

    private func priorityLabel(_ priority: Int) -> String {
        Priority(rawPriority: priority).label
    }

    private func priorityColor(_ priority: Int) -> Color {
        Priority(rawPriority: priority).color
    }
}

// Simple flow layout for labels
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                                  proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
