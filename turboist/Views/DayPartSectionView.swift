import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DayPartSectionView: View {
    let section: DayPartSection
    let collapsedIds: Set<String>
    let availableLabels: [TaskLabel]
    let dayPartLabels: Set<String>
    let isActivePhase: Bool
    let dimTasks: Bool
    var onComplete: (TaskItem) -> Void
    var onToggleCollapse: (String) -> Void
    var onNoteChanged: (String, String) -> Void
    var onLongPress: ((TaskItem) -> Void)?
    var onCreateForPhase: ((String) -> Void)?

    @State private var noteText: String
    @State private var isEditingNote = false

    init(
        section: DayPartSection,
        collapsedIds: Set<String>,
        availableLabels: [TaskLabel],
        dayPartLabels: Set<String> = [],
        isActivePhase: Bool = false,
        dimTasks: Bool = false,
        onComplete: @escaping (TaskItem) -> Void,
        onToggleCollapse: @escaping (String) -> Void,
        onNoteChanged: @escaping (String, String) -> Void,
        onLongPress: ((TaskItem) -> Void)? = nil,
        onCreateForPhase: ((String) -> Void)? = nil
    ) {
        self.section = section
        self.collapsedIds = collapsedIds
        self.availableLabels = availableLabels
        self.dayPartLabels = dayPartLabels
        self.isActivePhase = isActivePhase
        self.dimTasks = dimTasks
        self.onComplete = onComplete
        self.onToggleCollapse = onToggleCollapse
        self.onNoteChanged = onNoteChanged
        self.onLongPress = onLongPress
        self.onCreateForPhase = onCreateForPhase
        self._noteText = State(initialValue: section.note)
    }

    var body: some View {
        Section {
            if !noteText.isEmpty || isEditingNote {
                noteField
                    .listRowBackground(activePhaseRowBackground)
            }

            let displayTasks = flattenForDisplay(section.tasks, collapsedIds: collapsedIds)
            ForEach(displayTasks) { displayTask in
                NavigationLink(value: displayTask.task) {
                    TaskRowView(
                        task: displayTask.task,
                        depth: displayTask.depth,
                        hasChildren: displayTask.hasChildren,
                        isCollapsed: collapsedIds.contains(displayTask.task.id),
                        availableLabels: availableLabels,
                        hiddenLabels: dayPartLabels,
                        onComplete: { onComplete(displayTask.task) },
                        onToggleCollapse: { onToggleCollapse(displayTask.task.id) }
                    )
                }
                .opacity(dimTasks ? 0.45 : 1)
                .onLongPressGesture(minimumDuration: 0.4) {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    onLongPress?(displayTask.task)
                }
                .listRowBackground(activePhaseRowBackground)
            }
        } header: {
            sectionHeader
        }
        .listSectionSeparator(.hidden, edges: isActivePhase ? .all : [])
        .onChange(of: section.note) { _, newValue in
            if !isEditingNote {
                noteText = newValue
            }
        }
    }

    private var sectionHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: section.icon)
                .font(isActivePhase ? .body : .caption)
            Text(section.label.uppercased())
                .font(isActivePhase ? .body : .caption)
                .fontWeight(.semibold)
            if section.start > 0 || section.end > 0 {
                Text(section.timeRange)
                    .font(isActivePhase ? .caption : .caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(section.tasks.count)")
                .font(isActivePhase ? .caption : .caption2)
                .foregroundStyle(.secondary)
            Button {
                isEditingNote.toggle()
                if !isEditingNote && noteText != section.note {
                    onNoteChanged(section.id, noteText)
                }
            } label: {
                Image(systemName: isEditingNote ? "note.text.badge.plus" : "note.text")
                    .font(isActivePhase ? .body : .caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, isActivePhase ? 6 : 0)
        .padding(.horizontal, isActivePhase ? 4 : 0)
        .background {
            if isActivePhase {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            }
        }
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0.5) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            onCreateForPhase?(section.id)
        }
    }

    @ViewBuilder
    private var activePhaseRowBackground: some View {
        if isActivePhase {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3)
                Color.primary.opacity(0.04)
            }
        }
    }

    private var noteField: some View {
        TextField("Note...", text: $noteText, axis: .vertical)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1...3)
            .onSubmit {
                isEditingNote = false
                if noteText != section.note {
                    onNoteChanged(section.id, noteText)
                }
            }
    }
}
