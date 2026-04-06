import Foundation

@Observable
final class BrowseViewModel {
    var searchText = ""
    var allTasks: [TaskItem] = []
    var completedTasks: [TaskItem] = []
    var isLoadingAll = false
    var isLoadingCompleted = false
    var completedLoaded = false
    var error: String?

    let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    var searchResults: [DisplayTask] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        let filtered = filterBySearch(allTasks, query: query)
        return flattenForDisplay(filtered, collapsedIds: [])
    }

    var isSearching: Bool { !searchText.isEmpty }

    @MainActor
    func loadAllIfNeeded() async {
        guard allTasks.isEmpty, !isLoadingAll else { return }
        isLoadingAll = true
        error = nil
        do {
            let response = try await repository.fetchTasks(view: .all, context: nil)
            allTasks = response.tasks
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingAll = false
    }

    @MainActor
    func loadCompleted() async {
        guard !isLoadingCompleted else { return }
        isLoadingCompleted = true
        error = nil
        do {
            let response = try await repository.fetchTasks(view: .completed, context: nil)
            completedTasks = response.tasks
            completedLoaded = true
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingCompleted = false
    }

    private func filterBySearch(_ tasks: [TaskItem], query: String) -> [TaskItem] {
        tasks.compactMap { task in
            let filteredChildren = filterBySearch(task.children, query: query)
            if task.content.lowercased().contains(query) || !filteredChildren.isEmpty {
                var filtered = task
                filtered.children = filteredChildren
                return filtered
            }
            return nil
        }
    }
}
