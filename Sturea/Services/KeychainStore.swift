import Foundation
import Security

/// Guarda el token personal en el Keychain del iPhone (nunca en el repo ni en UserDefaults).
enum KeychainStore {
    private static let service = "com.draxxd.sturea.api"
    private static let account = "personal-api-token"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    @discardableResult
    static func saveToken(_ token: String) -> Bool {
        let data = Data(token.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        SecItemDelete(baseQuery as CFDictionary)
        var query = baseQuery
        query[kSecValueData as String] = data
        // AfterFirstUnlock: Siri puede ejecutar el intent con el iPhone bloqueado (tras el primer desbloqueo).
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func loadToken() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8), !token.isEmpty
        else { return nil }
        return token
    }

    @discardableResult
    static func deleteToken() -> Bool {
        let status = SecItemDelete(baseQuery as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
