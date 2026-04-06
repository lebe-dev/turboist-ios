import SwiftUI

struct LabelsListView: View {
    let labels: [TaskLabel]
    let labelConfigs: [LabelConfig]
    let tasks: [TaskItem]

    private var labelCounts: [(label: TaskLabel, count: Int)] {
        labels.map { label in
            let count = countTasks(withLabel: label.name, in: tasks)
            return (label: label, count: count)
        }
    }

    var body: some View {
        List {
            ForEach(labelCounts, id: \.label.id) { item in
                HStack {
                    if let hex = item.label.color, let color = Color(hex: hex) {
                        Circle()
                            .fill(color)
                            .frame(width: 12, height: 12)
                    }
                    Text(item.label.name)
                    Spacer()
                    if inheritToSubtasks(item.label.name) {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .help("Inherits to subtasks")
                    }
                    Text("\(item.count)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
        }
        .navigationTitle("All Labels")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func countTasks(withLabel label: String, in tasks: [TaskItem]) -> Int {
        var count = 0
        for task in tasks {
            if task.labels.contains(label) { count += 1 }
            count += countTasks(withLabel: label, in: task.children)
        }
        return count
    }

    private func inheritToSubtasks(_ name: String) -> Bool {
        labelConfigs.first(where: { $0.name == name })?.inheritToSubtasks ?? false
    }
}
