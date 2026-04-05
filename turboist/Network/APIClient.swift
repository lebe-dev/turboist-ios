import Foundation

enum APIError: Error, LocalizedError {
    case unauthorized
    case notFound
    case rateLimited
    case serverError(Int)
    case networkError(Error)
    case decodingError(Error)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Session expired"
        case .notFound: return "Not found"
        case .rateLimited: return "Rate limited"
        case .serverError(let code): return "Server error (\(code))"
        case .networkError(let error): return error.localizedDescription
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .invalidURL: return "Invalid URL"
        }
    }
}

@Observable
final class APIClient {
    var baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session

        self.decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Auth

    func login(password: String) async throws {
        let _: OkResponse = try await post("/api/auth/login", body: LoginRequest(password: password))
    }

    func checkAuth() async throws -> Bool {
        let response: AuthMeResponse = try await get("/api/auth/me")
        return response.authenticated
    }

    // MARK: - Config

    func fetchConfig() async throws -> AppConfig {
        try await get("/api/config")
    }

    // MARK: - Tasks

    func fetchTasks(view: TaskView, context: String? = nil) async throws -> TasksResponse {
        var params: [String: String] = ["view": view.rawValue]
        if let context { params["context"] = context }
        return try await get("/api/tasks", queryParams: params)
    }

    func createTask(_ request: CreateTaskRequest) async throws -> CreateTaskResponse {
        try await post("/api/tasks", body: request)
    }

    func updateTask(id: String, _ request: UpdateTaskRequest) async throws -> OkResponse {
        try await patch("/api/tasks/\(id)", body: request)
    }

    func deleteTask(id: String) async throws -> OkResponse {
        try await delete("/api/tasks/\(id)")
    }

    func completeTask(id: String) async throws -> OkResponse {
        try await post("/api/tasks/\(id)/complete")
    }

    func duplicateTask(id: String) async throws -> CreateTaskResponse {
        try await post("/api/tasks/\(id)/duplicate")
    }

    func decomposeTask(id: String, _ request: DecomposeRequest) async throws -> OkResponse {
        try await post("/api/tasks/\(id)/decompose", body: request)
    }

    func moveTask(id: String, _ request: MoveTaskRequest) async throws -> OkResponse {
        try await post("/api/tasks/\(id)/move", body: request)
    }

    func batchUpdateLabels(_ request: BatchUpdateLabelsRequest) async throws -> BatchUpdateLabelsResponse {
        try await post("/api/tasks/batch-update-labels", body: request)
    }

    func fetchCompletedSubtasks(id: String) async throws -> CompletedSubtasksResponse {
        try await get("/api/tasks/\(id)/completed-subtasks")
    }

    // MARK: - State

    func patchState(_ request: PatchStateRequest) async throws -> OkResponse {
        try await patch("/api/state", body: request)
    }

    // MARK: - Generic HTTP methods

    private func get<T: Decodable>(_ path: String, queryParams: [String: String] = [:]) async throws -> T {
        let url = try buildURL(path, queryParams: queryParams)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await perform(request)
    }

    private func post<T: Decodable>(_ path: String) async throws -> T {
        let url = try buildURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url = try buildURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let url = try buildURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await perform(request)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let url = try buildURL(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        return try await perform(request)
    }

    private func buildURL(_ path: String, queryParams: [String: String] = [:]) throws -> URL {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        if !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200...204:
            break
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
