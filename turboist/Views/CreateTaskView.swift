import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateTaskViewModel
    @State private var showDatePicker = false
    @State private var showRecurrencePicker = false
    @State private var showLabelPicker = false
    let availableLabels: [TaskLabel]
    let onCreated: () -> Void

    init(repository: TaskRepositoryProtocol, parentId: String? = nil, availableLabels: [TaskLabel] = [], onCreated: @escaping () -> Void) {
        let vm = CreateTaskViewModel(repository: repository)
        vm.parentId = parentId
        _viewModel = State(initialValue: vm)
        self.availableLabels = availableLabels
        self.onCreated = onCreated
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Content") {
                    TextField("Task title", text: $viewModel.content)
                    TextField("Description (optional)", text: $viewModel.description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Priority") {
                    Picker("Priority", selection: $viewModel.priority) {
                        Text("P1 - Urgent").tag(4)
                        Text("P2 - High").tag(3)
                        Text("P3 - Medium").tag(2)
                        Text("P4 - Low").tag(1)
                    }
                }

                if !availableLabels.isEmpty {
                    Section("Labels") {
                        if !viewModel.labels.isEmpty {
                            FlowLayout(spacing: 6) {
                                ForEach(viewModel.labels, id: \.self) { label in
                                    LabelBadge(name: label, availableLabels: availableLabels)
                                }
                            }
                        }
                        Button {
                            showLabelPicker = true
                        } label: {
                            Label(viewModel.labels.isEmpty ? "Add Labels" : "Edit Labels", systemImage: "tag")
                        }
                    }
                }

                Section("Due Date") {
                    if let dueDate = viewModel.dueDate {
                        HStack {
                            Label(DueDateHelper.displayLabel(for: dueDate), systemImage: "calendar")
                                .foregroundStyle(DueDateHelper.status(for: dueDate).color)
                            Spacer()
                            Button {
                                viewModel.dueDate = nil
                                viewModel.dueString = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        if viewModel.dueString != nil {
                            Label("Recurring", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    QuickDateButtons { dateString in
                        viewModel.dueDate = dateString
                        viewModel.dueString = nil
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                    Button {
                        showDatePicker = true
                    } label: {
                        Label("Pick Date", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        showRecurrencePicker = true
                    } label: {
                        Label("Set Recurrence", systemImage: "arrow.triangle.2.circlepath")
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
    }
}
