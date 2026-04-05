import SwiftUI

struct QuickCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var priority: Int = 1
    @State private var dueToday: Bool = false
    @State private var isSaving = false
    @FocusState private var isContentFocused: Bool

    let parentTaskId: String
    let repository: TaskRepositoryProtocol

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Idea...", text: $content, axis: .vertical)
                    .font(.title3)
                    .focused($isContentFocused)
                    .padding()
                    .submitLabel(.done)
                    .onSubmit { save() }

                Divider()

                HStack(spacing: 8) {
                    ForEach(priorityOptions, id: \.value) { option in
                        Button {
                            priority = option.value
                        } label: {
                            Label(option.label, systemImage: "flag.fill")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(priority == option.value ? option.color.opacity(0.2) : Color.clear)
                                .foregroundStyle(priority == option.value ? option.color : .secondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .strokeBorder(priority == option.value ? option.color.opacity(0.5) : Color.clear, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    Divider()
                        .frame(height: 20)

                    Button {
                        dueToday.toggle()
                    } label: {
                        Label("Today", systemImage: "calendar")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(dueToday ? Color.blue.opacity(0.15) : Color.clear)
                            .foregroundStyle(dueToday ? .blue : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(dueToday ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Spacer()
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                isContentFocused = true
            }
        }
    }

    private var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true

        let taskContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let pri = priority
        let dueDate = dueToday ? DueDateHelper.todayString() : nil

        let request = CreateTaskRequest(
            content: taskContent,
            priority: pri,
            parentId: parentTaskId,
            dueDate: dueDate
        )

        dismiss()

        Task {
            _ = try? await repository.createTask(request)
        }
    }

    private var priorityOptions: [PriorityOption] {
        [
            PriorityOption(value: 4, label: "P1", color: .red),
            PriorityOption(value: 3, label: "P2", color: .orange),
            PriorityOption(value: 2, label: "P3", color: .blue),
            PriorityOption(value: 1, label: "P4", color: .secondary),
        ]
    }
}

private struct PriorityOption {
    let value: Int
    let label: String
    let color: Color
}
