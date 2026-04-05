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
                CreateTaskView(repository: viewModel.repository, parentId: task.id) {
                    // Reload to show new subtask
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
                        Text(task.description)
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

            if isEditing {
                Section("Due Date") {
                    TextField("YYYY-MM-DD", text: $editedDueDate)
                }
            } else if let due = task.due {
                Section("Due Date") {
                    Label(due.date, systemImage: due.recurring ? "arrow.triangle.2.circlepath" : "calendar")
                    if due.recurring {
                        Text("Recurring").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            if !task.labels.isEmpty {
                Section("Labels") {
                    FlowLayout(spacing: 6) {
                        ForEach(task.labels, id: \.self) { label in
                            Text(label)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if task.postponeCount > 0 {
                Section {
                    Label("Postponed \(task.postponeCount) time(s)", systemImage: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
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
        editedDueDate = task.due?.date ?? ""
        isEditing = true
    }

    private func saveChanges() {
        guard let task = viewModel.task else { return }
        isEditing = false
        Task {
            await viewModel.updateTask(
                content: editedContent != task.content ? editedContent : nil,
                description: editedDescription != task.description ? editedDescription : nil,
                priority: editedPriority != task.priority ? editedPriority : nil,
                dueDate: editedDueDate != (task.due?.date ?? "") ? (editedDueDate.isEmpty ? nil : editedDueDate) : nil
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
