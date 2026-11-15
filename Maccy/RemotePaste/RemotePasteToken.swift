import Foundation
import Security

// The receiver token lives in the Keychain, not in UserDefaults, so it is not
// readable through `defaults read org.p0deje.Maccy`.
nonisolated enum RemotePasteToken {
  private static let service = "org.p0deje.Maccy.remotePaste"
  private static let account = "token"

  private static var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account
    ]
  }

  static func load() -> String? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }

  // Saves a trimmed token, or deletes it when empty. Returns whether the
  // Keychain accepted the change.
  @discardableResult
  static func save(_ token: String) -> Bool {
    let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      let status = SecItemDelete(baseQuery as CFDictionary)
      return status == errSecSuccess || status == errSecItemNotFound
    }

    let data = Data(trimmed.utf8)
    let status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
    guard status == errSecItemNotFound else {
      return status == errSecSuccess
    }

    var query = baseQuery
    query[kSecValueData as String] = data
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
  }
}
