import SwiftUI

struct PlanningView: View {
    @Bindable var viewModel: PlanningViewModel
    var configStore: AppConfigStore
    var onExit: () -> Void

    @State private var showStartWeekConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            planningHeader
            tabPicker
            tabContent
        }
        .navigationTitle("Planning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { onExit() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showStartWeekConfirm = true
                } label: {
                    Image(systemName: "play.fill")
                }
                .disabled(viewModel.isStartingWeek || viewModel.weeklyTasks.isEmpty)
            }
        }
        .alert("Start Week?", isPresented: $showStartWeekConfirm) {
            Button("Start", role: .destructive) {
                Task { await viewModel.startWeek() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the \"\(configStore.settings?.weeklyLabel ?? "weekly")\" label from all tasks.")
        }
        .refreshable {
            await viewModel.refresh(contextId: configStore.activeContextId.isEmpty ? nil : configStore.activeContextId)
        }
    }

    private var planningHeader: some View {
        HStack(spacing: 12) {
            TaskLimitProgressView(
                count: viewModel.weeklyCount,
                limit: viewModel.weeklyLimitValue,
                label: "Weekly"
            )
            Spacer()
            TaskLimitProgressView(
                count: viewModel.backlogCount,
                limit: viewModel.backlogLimitValue,
                label: "Backlog"
            )
        }
        .padding(.horizontal, 4)
    }

    private var tabPicker: some View {
        Picker("Tab", selection: $viewModel.mobileTab) {
            ForEach(PlanningTab.allCases, id: \.self) { tab in
                Label(tab.displayName, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var tabContent: some View {
        if viewModel.isLoading && viewModel.backlogTasks.isEmpty && viewModel.weeklyTasks.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if let error = viewModel.error, viewModel.backlogTasks.isEmpty && viewModel.weeklyTasks.isEmpty {
            ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
        } else {
            switch viewModel.mobileTab {
            case .backlog:
                BacklogPanelView(
                    viewModel: viewModel,
                    availableLabels: configStore.labels,
                    isAtLimit: viewModel.isAtLimit
                )
            case .weekly:
                WeeklyPlanningPanelView(
                    viewModel: viewModel,
                    availableLabels: configStore.labels
                )
            }
        }
    }
}
