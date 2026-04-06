import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Custom long-press dropdown menu mirroring the PWA's TaskDropdownMenu.
/// Presented as a floating card over a dimmed backdrop.
struct TaskContextMenuView: View {
    let task: TaskItem
    let isInBacklog: Bool
    let backlogLabel: String
    let isPinned: Bool
    let canPin: Bool
    let dayParts: [DayPart]
    let currentDayPartLabel: String?

    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onCopy: () -> Void
    let onToggleBacklog: () -> Void
    let onTogglePin: () -> Void
    let onDecompose: () -> Void
    let onSetDate: (String) -> Void
    let onClearDate: () -> Void
    let onPickDate: () -> Void
    let onSetPriority: (Int) -> Void
    let onMoveToPhase: ((String) -> Void)?
    let onDelete: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuItem(icon: "pencil", title: "Редактировать", action: { dismissThen(onEdit) })
            menuItem(icon: "plus.square.on.square", title: "Дублировать", action: { dismissThen(onDuplicate) })
            menuItem(icon: "doc.on.doc", title: "Копировать", action: { dismissThen(onCopy) })
            menuItem(icon: "list.bullet.indent", title: "Разбить на подзадачи", action: { dismissThen(onDecompose) })

            if canPin {
                menuItem(
                    icon: isPinned ? "pin.slash" : "pin",
                    title: isPinned ? "Открепить" : "Закрепить",
                    action: { dismissThen(onTogglePin) }
                )
            }

            if !backlogLabel.isEmpty {
                menuItem(
                    icon: isInBacklog ? "tray.and.arrow.up" : "tray.and.arrow.down",
                    title: isInBacklog ? "Из бэклога" : "В бэклог",
                    action: { dismissThen(onToggleBacklog) }
                )
            }

            Hairline().padding(.vertical, 4)

            dateSection

            if !dayParts.isEmpty {
                phaseSection
            }

            prioritySection

            Hairline().padding(.vertical, 4)

            menuItem(
                icon: "trash",
                title: "Удалить",
                tint: .red,
                action: { dismissThen(onDelete) }
            )
        }
        .padding(.vertical, 6)
        .frame(width: 280)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
    }

    // MARK: - Sections

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Дата")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            HStack(spacing: 6) {
                iconButton(
                    systemName: "calendar",
                    tint: .green,
                    selected: task.due?.date == DueDateHelper.todayString(),
                    action: { dismissThen { onSetDate(DueDateHelper.todayString()) } }
                )
                iconButton(
                    systemName: "sun.max.fill",
                    tint: .orange,
                    selected: task.due?.date == DueDateHelper.tomorrowString(),
                    action: { dismissThen { onSetDate(DueDateHelper.tomorrowString()) } }
                )
                iconButton(
                    systemName: "arrow.right",
                    tint: .purple,
                    selected: false,
                    action: { dismissThen(onPickDate) }
                )
                if task.due != nil {
                    iconButton(
                        systemName: "xmark",
                        tint: .secondary,
                        selected: false,
                        action: { dismissThen(onClearDate) }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 6)
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Приоритет")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            HStack(spacing: 6) {
                ForEach(Priority.allCases.reversed()) { p in
                    iconButton(
                        systemName: p.rawValue == 1 ? "flag" : "flag.fill",
                        tint: p.color,
                        selected: task.priority == p.rawValue,
                        action: { dismissThen { onSetPriority(p.rawValue) } }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 6)
    }

    private var phaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Фаза")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            HStack(spacing: 6) {
                ForEach(Array(dayParts.enumerated()), id: \.offset) { index, dp in
                    iconButton(
                        systemName: phaseIcon(at: index, of: dayParts.count),
                        tint: .blue,
                        selected: currentDayPartLabel == dp.label,
                        action: { dismissThen { onMoveToPhase?(dp.label) } }
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .padding(.vertical, 6)
    }

    private func phaseIcon(at index: Int, of total: Int) -> String {
        if index == 0 { return "sunrise" }
        if index == total - 1 { return "moon" }
        return "sun.max"
    }

    // MARK: - Building blocks

    private func menuItem(
        icon: String,
        title: String,
        tint: Color = .primary,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 15))
                Spacer()
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func iconButton(
        systemName: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? tint.opacity(0.18) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(selected ? tint.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func dismissThen(_ action: @escaping () -> Void) {
        onDismiss()
        action()
    }
}

/// Full-screen backdrop + centered menu card presentation wrapper.
struct TaskContextMenuOverlay<Menu: View>: View {
    let isPresented: Bool
    let onDismiss: () -> Void
    @ViewBuilder let menu: () -> Menu

    var body: some View {
        ZStack {
            if isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { onDismiss() }

                menu()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isPresented)
    }
}
