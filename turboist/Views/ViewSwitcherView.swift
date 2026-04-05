import SwiftUI

struct ViewSwitcherView: View {
    let currentView: TaskView
    let onSelect: (TaskView) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(TaskView.allCases, id: \.self) { view in
                    viewButton(view)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
        }
    }

    private func viewButton(_ view: TaskView) -> some View {
        Button {
            onSelect(view)
        } label: {
            Label(view.displayName, systemImage: view.icon)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(view == currentView ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(view == currentView ? Color.accentColor : .secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
