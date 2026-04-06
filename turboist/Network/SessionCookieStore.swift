import Foundation
import Security

/// Persists the `turboist_token` session cookie across app launches.
///
/// The backend sets the cookie without `Expires`/`Max-Age`, so iOS treats it
/// as a session cookie and `HTTPCookieStorage.shared` discards it on relaunch.
/// We mirror its value into the Keychain after login and restore it as a
/// long-lived cookie on cold start.
enum SessionCookieStore {
    static let cookieName = "turboist_token"
    private static let keychainAccount = "turboist.session.token"
    private static let keychainService = "turboist"

    /// Persists the current session cookie (if any) for the given host.
    static func persistCurrentCookie(baseURL: String) {
        guard let url = URL(string: baseURL),
              let cookies = HTTPCookieStorage.shared.cookies(for: url),
              let cookie = cookies.first(where: { $0.name == cookieName }) else {
            return
        }
        save(token: cookie.value)
    }

    /// Restores a previously-persisted cookie into `HTTPCookieStorage.shared`
    /// so the next request includes it. Safe to call multiple times.
    static func restoreCookieIfNeeded(baseURL: String) {
        guard let url = URL(string: baseURL),
              let host = url.host else { return }

        // If a cookie is already present (e.g. just-logged-in flow), do nothing.
        if let existing = HTTPCookieStorage.shared.cookies(for: url),
           existing.contains(where: { $0.name == cookieName }) {
            return
        }

        guard let token = loadToken() else { return }

        let isSecure = url.scheme == "https"
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: cookieName,
            .value: token,
            .domain: host,
            .path: "/",
            .expires: Date().addingTimeInterval(60 * 60 * 24 * 365), // 1 year
        ]
        if isSecure {
            properties[.secure] = "TRUE"
        }
        if let cookie = HTTPCookie(properties: properties) {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
    }

    /// Removes the persisted token and any matching cookie in the shared store.
    static func clear(baseURL: String) {
        deleteToken()
        if let url = URL(string: baseURL),
           let cookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in cookies where cookie.name == cookieName {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    // MARK: - Keychain primitives

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private static func save(token: String) {
        guard let data = token.data(using: .utf8) else { return }
        var query = baseQuery()
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadToken() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private static func deleteToken() {
        SecItemDelete(baseQuery() as CFDictionary)
    }
}
