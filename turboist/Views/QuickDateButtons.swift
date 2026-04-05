import SwiftUI

struct QuickDateButtons: View {
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickButton("Today", icon: "calendar", color: .green) {
                    onSelect(DueDateHelper.todayString())
                }
                quickButton("Tomorrow", icon: "sun.max", color: .orange) {
                    onSelect(DueDateHelper.tomorrowString())
                }
                ForEach(DueDateHelper.weekDays(), id: \.date) { day in
                    quickButton(day.label, icon: "calendar.badge.clock", color: .blue) {
                        onSelect(day.date)
                    }
                }
            }
        }
    }

    private func quickButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(color.opacity(0.12))
                .foregroundStyle(color)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
