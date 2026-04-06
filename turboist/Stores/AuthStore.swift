import Foundation

@Observable
final class AuthStore {
    enum State {
        case unknown
        case authenticated
        case unauthenticated
    }

    var state: State = .unknown
    var isLoggingIn = false
    var loginError: String?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func checkAuth() async {
        // Restore the persisted session cookie before the first request — the
        // backend issues a session-only cookie which HTTPCookieStorage drops on
        // relaunch, so we keep it in the Keychain via SessionCookieStore.
        SessionCookieStore.restoreCookieIfNeeded(baseURL: apiClient.baseURL)
        do {
            let authenticated = try await apiClient.checkAuth()
            state = authenticated ? .authenticated : .unauthenticated
            if !authenticated {
                SessionCookieStore.clear(baseURL: apiClient.baseURL)
            }
        } catch APIError.unauthorized {
            SessionCookieStore.clear(baseURL: apiClient.baseURL)
            state = .unauthenticated
        } catch {
            // Network error on cold start: fall back to unauthenticated so the
            // user can retry via the login screen rather than being stuck.
            state = .unauthenticated
        }
    }

    func login(password: String) async {
        guard !password.isEmpty else {
            loginError = "Password is required"
            return
        }
        isLoggingIn = true
        loginError = nil
        defer { isLoggingIn = false }
        do {
            try await apiClient.login(password: password)
            SessionCookieStore.persistCurrentCookie(baseURL: apiClient.baseURL)
            state = .authenticated
        } catch APIError.unauthorized {
            loginError = "Incorrect password"
        } catch {
            loginError = error.localizedDescription
        }
    }

    func markUnauthenticated() {
        state = .unauthenticated
    }

    func logout() {
        SessionCookieStore.clear(baseURL: apiClient.baseURL)
        state = .unauthenticated
    }
}
