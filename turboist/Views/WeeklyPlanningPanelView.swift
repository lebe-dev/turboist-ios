import SwiftUI

struct WeeklyPlanningPanelView: View {
    @Bindable var viewModel: PlanningViewModel
    let availableLabels: [TaskLabel]

    var body: some View {
        List {
            ForEach(viewModel.weeklyTasks) { task in
                weeklyTaskRow(task)
            }
        }
        .listStyle(.plain)
        .overlay {
            if viewModel.weeklyTasks.isEmpty {
                ContentUnavailableView(
                    "No weekly tasks",
                    systemImage: "calendar.badge.clock",
                    description: Text("Move tasks from Backlog to start planning")
                )
            }
        }
    }

    private func weeklyTaskRow(_ task: TaskItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                }
                Spacer()
            }

            HStack(spacing: 0) {
                priorityButtons(for: task)
                Spacer()
                dateButtons(for: task)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button {
                Task { await viewModel.completeTask(task) }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
    }

    private func priorityButtons(for task: TaskItem) -> some View {
        HStack(spacing: 4) {
            ForEach(Priority.allCases.reversed()) { priority in
                Button {
                    Task { await viewModel.updateWeeklyTaskPriority(task, priority: priority.rawValue) }
                } label: {
                    Text(priority.shortLabel)
                        .font(.caption2)
                        .fontWeight(task.priority == priority.rawValue ? .bold : .regular)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(task.priority == priority.rawValue ? priority.color.opacity(0.2) : Color.clear)
                        .foregroundStyle(task.priority == priority.rawValue ? priority.color : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dateButtons(for task: TaskItem) -> some View {
        HStack(spacing: 4) {
            quickDateButton(
                label: "Today",
                icon: "calendar",
                color: .green,
                date: DueDateHelper.todayString(),
                task: task
            )
            quickDateButton(
                label: "Tmrw",
                icon: "sun.max",
                color: .orange,
                date: DueDateHelper.tomorrowString(),
                task: task
            )

            Menu {
                ForEach(DueDateHelper.weekDays(), id: \.date) { day in
                    Button(day.label) {
                        Task { await viewModel.updateWeeklyTaskDueDate(task, dueDate: day.date) }
                    }
                }
                if task.due != nil {
                    Divider()
                    Button("Clear", role: .destructive) {
                        Task { await viewModel.updateWeeklyTaskDueDate(task, dueDate: "") }
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
            }

            if let due = task.due {
                Text(DueDateHelper.displayLabel(for: due.date))
                    .font(.caption2)
                    .foregroundStyle(DueDateHelper.status(for: due.date).color)
                    .padding(.leading, 4)
            }
        }
    }

    private func quickDateButton(label: String, icon: String, color: Color, date: String, task: TaskItem) -> some View {
        let isActive = task.due?.date == date
        return Button {
            Task { await viewModel.updateWeeklyTaskDueDate(task, dueDate: date) }
        } label: {
            Image(systemName: icon)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isActive ? color.opacity(0.2) : Color.clear)
                .foregroundStyle(isActive ? color : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
