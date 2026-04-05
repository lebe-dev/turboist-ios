import SwiftUI

struct BacklogPanelView: View {
    @Bindable var viewModel: PlanningViewModel
    let availableLabels: [TaskLabel]
    let isAtLimit: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            acceptAllBar
            taskList
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search backlog...", text: $viewModel.searchText)
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
    private var acceptAllBar: some View {
        if !viewModel.filteredBacklogTasks.isEmpty {
            HStack {
                Text("\(viewModel.filteredBacklogTasks.count) tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Task { await viewModel.acceptAll() }
                } label: {
                    Label("Accept All", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .disabled(isAtLimit || viewModel.isAcceptingAll)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var taskList: some View {
        List {
            ForEach(viewModel.filteredBacklogTasks) { task in
                backlogTaskRow(task)
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.filteredBacklogTasks.isEmpty {
                ContentUnavailableView(
                    viewModel.searchText.isEmpty ? "No backlog tasks" : "No matches",
                    systemImage: "archivebox",
                    description: Text(viewModel.searchText.isEmpty ? "Backlog is empty" : "Try a different search")
                )
            }
        }
    }

    private func backlogTaskRow(_ task: TaskItem) -> some View {
        HStack(spacing: 8) {
            Button {
                Task { await viewModel.completeTask(task) }
            } label: {
                Image(systemName: "circle")
                    .foregroundStyle(Priority(rawPriority: task.priority).color)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.content)
                    .lineLimit(2)
                if !task.labels.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(task.labels, id: \.self) { label in
                            LabelBadge(name: label, availableLabels: availableLabels)
                        }
                    }
                }
                if let due = task.due {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                        Text(DueDateHelper.displayLabel(for: due.date))
                    }
                    .font(.caption)
                    .foregroundStyle(DueDateHelper.status(for: due.date).color)
                }
            }

            Spacer()

            Button {
                Task { await viewModel.moveToWeekly(task) }
            } label: {
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
                    .foregroundStyle(isAtLimit ? Color.secondary : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(isAtLimit)
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await viewModel.moveToWeekly(task) }
            } label: {
                Label("To Weekly", systemImage: "arrow.right")
            }
            .tint(.blue)
            .disabled(isAtLimit)
        }
        .swipeActions(edge: .trailing) {
            Button {
                Task { await viewModel.completeTask(task) }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }
}
