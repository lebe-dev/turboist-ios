import SwiftUI

struct PinnedTasksView: View {
    var pinnedTasks: [PinnedTask]
    var onTapTask: (String) -> Void
    var onUnpin: ((String) -> Void)?

    var body: some View {
        if !pinnedTasks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(pinnedTasks) { pinned in
                        Button {
                            onTapTask(pinned.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                Text(pinned.content)
                                    .lineLimit(1)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.fill.tertiary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onUnpin?(pinned.id)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
    }
}
