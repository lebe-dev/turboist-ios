import SwiftUI

struct CreateTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateTaskViewModel
    let onCreated: () -> Void

    init(repository: TaskRepositoryProtocol, parentId: String? = nil, onCreated: @escaping () -> Void) {
        let vm = CreateTaskViewModel(repository: repository)
        vm.parentId = parentId
        _viewModel = State(initialValue: vm)
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

                Section("Due Date") {
                    TextField("YYYY-MM-DD (optional)", text: Binding(
                        get: { viewModel.dueDate ?? "" },
                        set: { viewModel.dueDate = $0.isEmpty ? nil : $0 }
                    ))
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
        }
    }
}
