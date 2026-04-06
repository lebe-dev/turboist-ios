import SwiftUI

struct TaskDetailView: View {
    @Bindable var viewModel: TaskDetailViewModel
    @State private var editedContent: String = ""
    @State private var editedDescription: String = ""
    @State private var editedPriority: Int = 1
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
                taskCanvas(task)
            } else {
                ContentUnavailableView("No Task Selected", systemImage: "doc")
            }
        }
        .background(DS.Palette.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            if viewModel.task != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing { saveChanges() } else { startEditing() }
                    }
                    .font(DS.Typography.bodyEmph)
                    .foregroundStyle(DS.Palette.accent)
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .sheet(isPresented: $showDecompose) {
            DecomposeTaskView(viewModel: viewModel) { dismiss() }
        }
        .sheet(isPresented: $showCreateSubtask) {
            if let task = viewModel.task {
                CreateTaskView(repository: viewModel.repository, parentId: task.id, availableLabels: availableLabels) {
                    viewModel.task?.subTaskCount += 1
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

    // MARK: - Canvas

    @ViewBuilder
    private func taskCanvas(_ task: TaskItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero(task)
                metaStrip(task)

                if isEditing || !task.description.isEmpty {
                    descriptionBlock(task)
                }

                if let parentId = task.parentId {
                    parentLink(parentId: parentId)
                }

                subtasksBlock(task)
                actionsBlock(task)

                if let error = viewModel.error {
                    Text(error)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, DS.Spacing.gutter)
                        .padding(.top, DS.Spacing.lg)
                }

                Color.clear.frame(height: DS.Spacing.xxl)
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                completeButton(task)
                if isEditing {
                    TextField("Title", text: $editedContent, axis: .vertical)
                        .font(DS.Typography.hero)
                        .lineLimit(1...4)
                        .textFieldStyle(.plain)
                } else {
                    Text(task.content)
                        .font(DS.Typography.hero)
                        .foregroundStyle(DS.Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.gutter)
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.md)
    }

    private func completeButton(_ task: TaskItem) -> some View {
        Circle()
            .strokeBorder(priorityColor(task.priority), lineWidth: 2)
            .background(
                Circle().fill(priorityColor(task.priority).opacity(task.priority >= 3 ? 0.12 : 0))
            )
            .frame(width: 26, height: 26)
            .padding(.top, 8)
    }

    // MARK: - Meta strip

    @ViewBuilder
    private func metaStrip(_ task: TaskItem) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                // Priority
                Button { cyclePriority(task) } label: {
                    Chip(
                        Priority(rawPriority: task.priority).shortLabel,
                        icon: "flag.fill",
                        tint: priorityColor(task.priority),
                        filled: true
                    )
                }
                .buttonStyle(.plain)

                // Date
                Button { showDatePicker = true } label: {
                    if let due = task.due {
                        Chip(
                            DueDateHelper.displayLabel(for: due.date),
                            icon: "calendar",
                            tint: DueDateHelper.status(for: due.date).color,
                            filled: true
                        )
                    } else {
                        Chip("Schedule", icon: "calendar.badge.plus")
                    }
                }
                .buttonStyle(.plain)

                // Recurrence
                Button { showRecurrencePicker = true } label: {
                    if task.due?.recurring == true {
                        Chip("Recurring", icon: "arrow.triangle.2.circlepath", tint: .blue, filled: true)
                    } else {
                        Chip("Repeat", icon: "arrow.triangle.2.circlepath")
                    }
                }
                .buttonStyle(.plain)

                // Labels
                ForEach(task.labels, id: \.self) { name in
                    let color = labelColor(name)
                    Chip(name, icon: "number", tint: color, filled: true)
                }
                Button {
                    editedLabels = task.labels
                    showLabelPicker = true
                } label: {
                    Chip(task.labels.isEmpty ? "Labels" : "Edit", icon: "tag")
                }
                .buttonStyle(.plain)

                if task.postponeCount > 0 {
                    Chip(
                        "\(task.postponeCount)×",
                        icon: "clock.arrow.circlepath",
                        tint: DueDateHelper.postponeColor(count: task.postponeCount),
                        filled: true
                    )
                }
                if let expiresText = ExpiresInHelper.expiresInText(for: task.expiresAt) {
                    Chip(expiresText, icon: "flame", tint: .orange, filled: true)
                }
            }
            .padding(.horizontal, DS.Spacing.gutter)
        }
        .padding(.bottom, DS.Spacing.lg)
    }

    // MARK: - Description

    @ViewBuilder
    private func descriptionBlock(_ task: TaskItem) -> some View {
        Hairline(inset: DS.Spacing.gutter)
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            InlineSectionHeader(title: "Notes")
            if isEditing {
                TextField("Add notes…", text: $editedDescription, axis: .vertical)
                    .font(DS.Typography.body)
                    .lineLimit(3...12)
                    .textFieldStyle(.plain)
            } else {
                MarkdownText(task.description)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textSecondary)
            }
        }
        .padding(.horizontal, DS.Spacing.gutter)
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Parent link

    @ViewBuilder
    private func parentLink(parentId: String) -> some View {
        Hairline(inset: DS.Spacing.gutter)
        NavigationLink(value: parentId) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DS.Palette.textTertiary)
                Text("Parent task")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DS.Palette.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtasks

    @ViewBuilder
    private func subtasksBlock(_ task: TaskItem) -> some View {
        if task.subTaskCount > 0 || !task.children.isEmpty {
            Hairline(inset: DS.Spacing.gutter)
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                InlineSectionHeader(
                    title: "Subtasks",
                    trailing: "\(task.completedSubTaskCount) / \(task.subTaskCount)"
                )

                if !task.children.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(task.children.enumerated()), id: \.element.id) { idx, child in
                            NavigationLink(value: child) {
                                subtaskRow(child)
                            }
                            .buttonStyle(.plain)
                            if idx < task.children.count - 1 {
                                Hairline(inset: 38)
                            }
                        }
                    }
                } else if task.subTaskCount > 0 {
                    ProgressView(value: Double(task.completedSubTaskCount), total: Double(task.subTaskCount))
                        .tint(task.completedSubTaskCount == task.subTaskCount ? .green : DS.Palette.accent)
                }

                if task.subTaskCount > 0 {
                    Button {
                        showCompletedSubtasks.toggle()
                        if showCompletedSubtasks {
                            Task { await viewModel.loadCompletedSubtasks() }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showCompletedSubtasks ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                            Text(showCompletedSubtasks ? "Hide completed" : "Show completed")
                                .font(DS.Typography.caption)
                        }
                        .foregroundStyle(DS.Palette.textTertiary)
                    }
                    .buttonStyle(.plain)

                    if showCompletedSubtasks {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            ForEach(viewModel.completedSubtasks) { subtask in
                                HStack(spacing: DS.Spacing.md) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(subtask.content)
                                        .strikethrough()
                                        .foregroundStyle(DS.Palette.textTertiary)
                                        .font(DS.Typography.body)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.vertical, DS.Spacing.lg)
        }
    }

    private func subtaskRow(_ child: TaskItem) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Circle()
                .strokeBorder(priorityColor(child.priority), lineWidth: 1.5)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(child.content)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textPrimary)
                if child.subTaskCount > 0 {
                    Text("\(child.completedSubTaskCount) / \(child.subTaskCount) subtasks")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Palette.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DS.Palette.textTertiary)
        }
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionsBlock(_ task: TaskItem) -> some View {
        Hairline(inset: DS.Spacing.gutter)
        VStack(spacing: 0) {
            if let configStore {
                let isPinned = configStore.isTaskPinned(task.id)
                actionRow(
                    title: isPinned ? "Unpin task" : "Pin task",
                    icon: isPinned ? "pin.slash" : "pin"
                ) {
                    configStore.togglePinTask(task, repository: viewModel.repository)
                }
                Hairline(inset: 52)
            }
            actionRow(title: "Add subtask", icon: "plus.square") { showCreateSubtask = true }
            Hairline(inset: 52)
            actionRow(title: "Decompose", icon: "rectangle.split.3x1") { showDecompose = true }
        }
        .padding(.top, DS.Spacing.sm)
    }

    private func actionRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DS.Palette.accent)
                    .frame(width: 22)
                Text(title)
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.gutter)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

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

    private func cyclePriority(_ task: TaskItem) {
        // P4 -> P3 -> P2 -> P1 -> P4
        let next = task.priority >= 4 ? 1 : task.priority + 1
        Task { await viewModel.updateTask(priority: next) }
    }

    private func priorityColor(_ priority: Int) -> Color {
        Priority(rawPriority: priority).color
    }

    private func labelColor(_ name: String) -> Color {
        guard let label = availableLabels.first(where: { $0.name == name }),
              let hex = label.color,
              let color = Color(hex: hex) else {
            return DS.Palette.textSecondary
        }
        return color
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
