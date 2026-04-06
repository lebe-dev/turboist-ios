import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateTaskViewModel
    @State private var showDatePicker = false
    @State private var showRecurrencePicker = false
    @State private var showLabelPicker = false
    @FocusState private var isTitleFocused: Bool
    let availableLabels: [TaskLabel]
    let onCreated: () -> Void

    init(
        repository: TaskRepositoryProtocol,
        parentId: String? = nil,
        initialLabels: [String] = [],
        initialDueDate: String? = nil,
        availableLabels: [TaskLabel] = [],
        configStore: AppConfigStore? = nil,
        onCreated: @escaping () -> Void
    ) {
        let vm = CreateTaskViewModel(repository: repository)
        vm.parentId = parentId
        vm.labels = initialLabels
        vm.dueDate = initialDueDate
        if let store = configStore {
            vm.configure(
                compiledAutoLabels: store.compiledAutoLabels,
                contextLabels: store.activeContextLabels()
            )
        }
        _viewModel = State(initialValue: vm)
        self.availableLabels = availableLabels
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                titleField
                Hairline()
                descriptionField
                Hairline()
                chipsRow
                Hairline()
                quickDates

                if let error = viewModel.error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                }

                Spacer()
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await viewModel.createTask() {
                                onCreated()
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .onAppear { isTitleFocused = true }
            .sheet(isPresented: $showLabelPicker) {
                LabelPickerView(availableLabels: availableLabels, selectedLabels: $viewModel.labels)
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(currentDate: viewModel.dueDate) { dateString in
                    viewModel.dueDate = dateString
                    viewModel.dueString = nil
                } onClear: {
                    viewModel.dueDate = nil
                    viewModel.dueString = nil
                }
            }
            .sheet(isPresented: $showRecurrencePicker) {
                let due = viewModel.dueDate.map { Due(date: $0, recurring: viewModel.dueString != nil) }
                RecurrencePickerView(currentDue: due) { dueString in
                    if dueString.hasPrefix("__clear_recurrence__:") {
                        let date = String(dueString.dropFirst("__clear_recurrence__:".count))
                        viewModel.dueDate = date
                        viewModel.dueString = nil
                    } else {
                        viewModel.dueString = dueString
                        if viewModel.dueDate == nil {
                            viewModel.dueDate = DueDateHelper.todayString()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Fields

    private var titleField: some View {
        TextField("Task title", text: $viewModel.content, axis: .vertical)
            .font(.body.weight(.medium))
            .focused($isTitleFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    private var descriptionField: some View {
        TextField("Note (optional)", text: $viewModel.description, axis: .vertical)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(2...4)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    // MARK: - Chips row

    private var chipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                dueDateChip
                priorityChip

                ForEach(viewModel.contextLabels, id: \.self) { label in
                    labelChip(label, style: .context)
                }
                ForEach(viewModel.matchedAutoLabels, id: \.self) { label in
                    HStack(spacing: 3) {
                        labelChip(label, style: .auto)
                        Button {
                            viewModel.dismissAutoLabel(label)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(viewModel.labels.filter { l in
                    !viewModel.contextLabels.contains(l) && !viewModel.matchedAutoLabels.contains(l)
                }, id: \.self) { label in
                    labelChip(label, style: .manual)
                }

                if !availableLabels.isEmpty {
                    Button {
                        showLabelPicker = true
                    } label: {
                        Chip("Labels", icon: "tag")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private enum LabelChipStyle { case context, auto, manual }

    private func labelChip(_ label: String, style: LabelChipStyle) -> some View {
        let color = labelColor(label)
        let tint = color ?? DS.Palette.textSecondary
        return Chip(label, tint: tint, filled: true)
    }

    private func labelColor(_ name: String) -> Color? {
        guard let label = availableLabels.first(where: { $0.name == name }),
              let hex = label.color else { return nil }
        return Color(hex: hex)
    }

    private var dueDateChip: some View {
        Group {
            if let dueDate = viewModel.dueDate {
                HStack(spacing: 4) {
                    Button {
                        showDatePicker = true
                    } label: {
                        Chip(
                            DueDateHelper.displayLabel(for: dueDate),
                            icon: viewModel.dueString != nil ? "arrow.triangle.2.circlepath" : "calendar",
                            tint: DueDateHelper.status(for: dueDate).color,
                            filled: true
                        )
                    }
                    .buttonStyle(.plain)
                    Button {
                        viewModel.dueDate = nil
                        viewModel.dueString = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button {
                    showDatePicker = true
                } label: {
                    Chip("Date", icon: "calendar")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var priorityChip: some View {
        Menu {
            ForEach(Priority.allCases.reversed()) { p in
                Button {
                    viewModel.priority = p.rawValue
                } label: {
                    if viewModel.priority == p.rawValue {
                        Label(p.label, systemImage: "checkmark")
                    } else {
                        Text(p.label)
                    }
                }
            }
        } label: {
            let p = Priority(rawValue: viewModel.priority) ?? .p4
            Chip(p.shortLabel, icon: viewModel.priority == 1 ? "flag" : "flag.fill", tint: p.color, filled: viewModel.priority != 1)
        }
    }

    // MARK: - Quick dates

    private var quickDates: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickDateButton("Today", icon: "calendar", color: .green) {
                    viewModel.dueDate = DueDateHelper.todayString()
                    viewModel.dueString = nil
                }
                quickDateButton("Tomorrow", icon: "sun.max", color: .orange) {
                    viewModel.dueDate = DueDateHelper.tomorrowString()
                    viewModel.dueString = nil
                }
                ForEach(DueDateHelper.weekDays(), id: \.date) { day in
                    quickDateButton(day.label, icon: "calendar.badge.clock", color: .blue) {
                        viewModel.dueDate = day.date
                        viewModel.dueString = nil
                    }
                }
                Button {
                    showRecurrencePicker = true
                } label: {
                    Label("Recur", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.12))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func quickDateButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
