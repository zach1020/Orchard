import Foundation
import Security

enum Keychain {
  static func read(_ account: String) -> String {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "local.orchard",
      kSecAttrAccount as String: account, kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let data = item as? Data
    else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
  }
  static func save(_ value: String, account: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "local.orchard",
      kSecAttrAccount as String: account,
    ]
    if value.isEmpty {
      let status = SecItemDelete(query as CFDictionary)
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw OrchardError(message: "Could not remove key from Keychain (\(status)).")
      }
      return
    }
    let attributes = [kSecValueData as String: Data(value.utf8)]
    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item.merge(attributes) { _, new in new }
      let added = SecItemAdd(item as CFDictionary, nil)
      guard added == errSecSuccess else {
        throw OrchardError(message: "Could not save key to Keychain (\(added)).")
      }
    } else if status != errSecSuccess {
      throw OrchardError(message: "Could not update Keychain (\(status)).")
    }
  }
}
