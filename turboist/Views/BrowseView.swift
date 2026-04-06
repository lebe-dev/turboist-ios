import SwiftUI

struct BrowseView: View {
    @Bindable var viewModel: BrowseViewModel
    let configStore: AppConfigStore
    let onOpenTask: (TaskItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()

            if viewModel.isSearching {
                searchResultsList
            } else {
                browseContent
            }
        }
        .navigationTitle("Брууз")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAllIfNeeded()
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Поиск задач...", text: $viewModel.searchText)
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
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var searchResultsList: some View {
        if viewModel.isLoadingAll && viewModel.allTasks.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.searchResults.isEmpty {
            ContentUnavailableView(
                "Нет результатов",
                systemImage: "magnifyingglass",
                description: Text("Попробуйте другой запрос")
            )
        } else {
            List(viewModel.searchResults) { displayTask in
                Button {
                    onOpenTask(displayTask.task)
                } label: {
                    TaskRowView(
                        task: displayTask.task,
                        depth: displayTask.depth,
                        hasChildren: displayTask.hasChildren,
                        availableLabels: configStore.labels,
                        onComplete: {}
                    )
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private var browseContent: some View {
        List {
            projectsSection
            completedSection
        }
        .listStyle(.insetGrouped)
    }

    private var projectsSection: some View {
        Section("Проекты") {
            let projects = configStore.config?.projects ?? []
            if projects.isEmpty {
                Text("Нет проектов")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(projects) { project in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(projectColor(project))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                        Spacer()
                        if !project.sections.isEmpty {
                            Text("\(project.sections.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    @ViewBuilder
    private var completedSection: some View {
        Section("Выполненные задачи") {
            if viewModel.isLoadingCompleted {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if viewModel.completedLoaded {
                if viewModel.completedTasks.isEmpty {
                    Text("Нет выполненных задач")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(flattenForDisplay(viewModel.completedTasks, collapsedIds: [])) { displayTask in
                        Button {
                            onOpenTask(displayTask.task)
                        } label: {
                            TaskRowView(
                                task: displayTask.task,
                                depth: displayTask.depth,
                                hasChildren: displayTask.hasChildren,
                                availableLabels: configStore.labels,
                                onComplete: {}
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Button("Загрузить выполненные") {
                    Task { await viewModel.loadCompleted() }
                }
            }
        }
    }

    private func projectColor(_ project: Project) -> Color {
        guard let hex = project.color, let color = Color(hex: hex) else {
            return .secondary
        }
        return color
    }
}
