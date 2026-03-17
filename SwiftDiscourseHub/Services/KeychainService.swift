import Foundation
import Security

protocol KeychainServiceProtocol: Sendable {
    func save(service: String, account: String, data: Data) throws
    func retrieve(service: String, account: String) -> Data?
    func delete(service: String, account: String)
}

extension KeychainServiceProtocol {
    func saveString(service: String, account: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }
        try save(service: service, account: account, data: data)
    }

    func retrieveString(service: String, account: String) -> String? {
        guard let data = retrieve(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct KeychainService: KeychainServiceProtocol {
    func save(service: String, account: String, data: Data) throws {
        // Delete any existing item first
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func retrieve(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func delete(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}

final class InMemoryKeychainService: KeychainServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: Data] = [:]

    private func key(service: String, account: String) -> String {
        "\(service)|\(account)"
    }

    func save(service: String, account: String, data: Data) throws {
        lock.lock()
        defer { lock.unlock() }
        store[key(service: service, account: account)] = data
    }

    func retrieve(service: String, account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return store[key(service: service, account: account)]
    }

    func delete(service: String, account: String) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key(service: service, account: account))
    }
}
