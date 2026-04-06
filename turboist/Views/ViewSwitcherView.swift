import SwiftUI

/// Floating bottom navigation island — primary view switcher.
/// Shows the four main views (Today / Tomorrow / Weekly / Inbox) as a single
/// rounded capsule that hovers above the task list.
struct ViewSwitcherView: View {
    let currentView: TaskView
    let isBrowseActive: Bool
    let onSelect: (TaskView) -> Void
    let onAdd: () -> Void
    let onBrowse: () -> Void

    private static let primaryViews: [TaskView] = [.today, .tomorrow, .weekly, .inbox]

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // FAB row — sits fully above the pill
            HStack {
                Spacer()
                fab
                    .padding(.trailing, DS.Spacing.xl + 4)
            }

            // Pill
            HStack(spacing: 2) {
                ForEach(Self.primaryViews, id: \.self) { view in
                    tabButton(view)
                }
                browseTabButton
            }
            .padding(4)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(DS.Palette.hairline, lineWidth: DS.Spacing.hairline)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, 4)
        }
    }

    private var fab: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            onAdd()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(DS.Palette.accent)
                )
                .shadow(color: DS.Palette.accent.opacity(0.45), radius: 14, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func tabButton(_ view: TaskView) -> some View {
        let isActive = view == currentView
        return Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            onSelect(view)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: view.icon)
                    .font(.system(size: 15, weight: isActive ? .semibold : .medium))
                Text(shortName(view))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? DS.Palette.textPrimary : DS.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Capsule())
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isActive)
        }
        .buttonStyle(.plain)
    }

    private var browseTabButton: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
            onBrowse()
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: isBrowseActive ? .semibold : .medium))
                Text("Брууз")
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isBrowseActive ? DS.Palette.textPrimary : DS.Palette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(isBrowseActive ? Color.primary.opacity(0.10) : Color.clear)
            )
            .contentShape(Capsule())
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isBrowseActive)
        }
        .buttonStyle(.plain)
    }

    private func shortName(_ view: TaskView) -> String {
        switch view {
        case .today: return "Today"
        case .tomorrow: return "Tomorrow"
        case .weekly: return "Week"
        case .inbox: return "Inbox"
        default: return view.displayName
        }
    }
}
