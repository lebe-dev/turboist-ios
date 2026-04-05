import SwiftUI

struct NextActionPrompt {
    let parentId: String?
    let parentContent: String
    let completedTaskLabels: [String]
    let completedTaskContent: String

    var isSubtask: Bool { parentId != nil }
}

struct NextActionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var priority: Int = 1
    @State private var selectedLabels: [String] = []
    @State private var isSaving = false
    @FocusState private var isContentFocused: Bool

    let prompt: NextActionPrompt
    let repository: TaskRepositoryProtocol
    let availableLabels: [TaskLabel]
    var onCreated: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                Divider()
                contentSection
                Divider()
                labelsSection
                Divider()
                prioritySection
                Spacer()
            }
            .navigationTitle(prompt.isSubtask ? "Next Action" : "Follow Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                selectedLabels = prompt.completedTaskLabels
                isContentFocused = true
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: prompt.isSubtask ? "arrow.turn.down.right" : "arrow.uturn.forward")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.isSubtask ? "Next action for" : "Follow up to")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(prompt.isSubtask ? prompt.parentContent : prompt.completedTaskContent)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var contentSection: some View {
        TextField("Task name...", text: $content, axis: .vertical)
            .font(.title3)
            .focused($isContentFocused)
            .padding()
            .submitLabel(.done)
            .onSubmit { save() }
    }

    private var labelsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(availableLabels) { taskLabel in
                    let isSelected = selectedLabels.contains(taskLabel.name)
                    Button {
                        toggleLabel(taskLabel.name)
                    } label: {
                        Text(taskLabel.name)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var prioritySection: some View {
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
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func toggleLabel(_ name: String) {
        if let index = selectedLabels.firstIndex(of: name) {
            selectedLabels.remove(at: index)
        } else {
            selectedLabels.append(name)
        }
    }

    private func save() {
        guard isValid, !isSaving else { return }
        isSaving = true

        let taskContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let labels = selectedLabels
        let pri = priority
        let parentId = prompt.parentId

        let request = CreateTaskRequest(
            content: taskContent,
            labels: labels,
            priority: pri,
            parentId: parentId
        )

        dismiss()

        Task {
            _ = try? await repository.createTask(request)
            onCreated?()
        }
    }

    private var priorityOptions: [NextActionPriorityOption] {
        [
            NextActionPriorityOption(value: 4, label: "P1", color: .red),
            NextActionPriorityOption(value: 3, label: "P2", color: .orange),
            NextActionPriorityOption(value: 2, label: "P3", color: .blue),
            NextActionPriorityOption(value: 1, label: "P4", color: .secondary),
        ]
    }
}

private struct NextActionPriorityOption {
    let value: Int
    let label: String
    let color: Color
}
