import Foundation

@Observable
final class CreateTaskViewModel {
    var content: String = ""
    var description: String = ""
    var priority: Int = 1
    var labels: [String] = []
    var dueDate: String?
    var dueString: String?
    var parentId: String?
    var isSaving = false
    var error: String?

    var removedAutoLabels: Set<String> = []
    var contextLabels: [String] = []

    private let repository: TaskRepositoryProtocol
    private var compiledAutoLabels: [CompiledAutoLabel] = []

    init(repository: TaskRepositoryProtocol) {
        self.repository = repository
    }

    var isValid: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var matchedAutoLabels: [String] {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return AutoLabelMatcher.match(title: content, compiled: compiledAutoLabels)
            .filter { !removedAutoLabels.contains($0) }
    }

    var allLabels: [String] {
        var result = Set(labels)
        for label in matchedAutoLabels {
            result.insert(label)
        }
        for label in contextLabels {
            result.insert(label)
        }
        return Array(result)
    }

    func configure(compiledAutoLabels: [CompiledAutoLabel], contextLabels: [String]) {
        self.compiledAutoLabels = compiledAutoLabels
        self.contextLabels = contextLabels
    }

    func dismissAutoLabel(_ label: String) {
        removedAutoLabels.insert(label)
    }

    @MainActor
    func createTask() async -> Bool {
        guard isValid else { return false }
        isSaving = true
        error = nil
        let request = CreateTaskRequest(
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description,
            labels: allLabels,
            priority: priority,
            parentId: parentId,
            dueDate: dueDate,
            dueString: dueString
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
        dueString = nil
        parentId = nil
        error = nil
        removedAutoLabels = []
    }
}
