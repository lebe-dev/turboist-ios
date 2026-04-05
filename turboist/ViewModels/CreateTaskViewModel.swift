import Foundation

@Observable
final class CreateTaskViewModel {
    var content: String = ""
    var description: String = ""
    var priority: Int = 1
    var labels: [String] = []
    var dueDate: String?
    var parentId: String?
    var isSaving = false
    var error: String?

    private let repository: TaskRepositoryProtocol

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func createTask() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        error = nil
        let request = CreateTaskRequest(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            labels: labels,
            priority: priority,
            parentId: parentId,
            dueDate: dueDate
        )
        do {
            _ = try await repository.createTask(request)
            isSaving = false
            return true
        } catch let apiError as APIError {
            error = apiError.errorDescription
            isSaving = false
            return false
        } catch {
            self.error = error.localizedDescription
            isSaving = false
            return false
        }
    }

    func reset() {
        content = ""
        description = ""
        priority = 1
        labels = []
        dueDate = nil
        parentId = nil
        error = nil
    }
}
