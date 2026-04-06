import SwiftUI

struct DecomposeTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TaskDetailViewModel
    @State private var subtaskText: String = ""
    @State private var isSubmitting = false
    let onDecomposed: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                if let task = viewModel.task {
                    Section {
                        Text("Decomposing: \(task.content)")
                            .font(.headline)
                    }
                }

                Section("Subtasks (one per line)") {
                    TextEditor(text: $subtaskText)
                        .frame(minHeight: 150)
                }

                Section {
                    Text("The original task will be deleted and replaced with these subtasks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = viewModel.error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Decompose")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Decompose") {
                        decompose()
                    }
                    .disabled(subtasks.isEmpty || isSubmitting)
                }
            }
        }
    }

    private var subtasks: [String] {
        subtaskText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func decompose() {
        isSubmitting = true
        Task {
            let success = await viewModel.decomposeTask(subtasks: subtasks)
            isSubmitting = false
            if success {
                onDecomposed()
                dismiss()
            }
        }
    }
}
