//
//  SiteConfiguration.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import SwiftData

@Model
final class SiteConfiguration {
    var id: UUID
    var siteURL: String
    var username: String
    var isWordPressCom: Bool
    var createdDate: Date
    var lastSyncDate: Date?
    
    // We'll store the actual password/token in Keychain
    var keychainIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "Quill").site.\(id.uuidString)"
    }
    
    init(siteURL: String, username: String, isWordPressCom: Bool = false) {
        self.id = UUID()
        self.siteURL = siteURL
        self.username = username
        self.isWordPressCom = isWordPressCom
        self.createdDate = Date()
    }
}

// Cross-platform Keychain wrapper
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func save(password: String, for identifier: String) throws {
        guard let data = password.data(using: .utf8) else {
            throw KeychainError.unableToSave
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KeychainError.unableToSave
        }
    }
    
    func retrieve(for identifier: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            if let data = result as? Data,
               let password = String(data: data, encoding: .utf8) {
                return password
            }
        } else if status == errSecItemNotFound {
            return nil
        }
        
        throw KeychainError.unableToRetrieve
    }
    
    func delete(for identifier: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: identifier
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainError.unableToDelete
        }
    }
}

enum KeychainError: LocalizedError {
    case unableToSave
    case unableToRetrieve
    case unableToDelete
    
    var errorDescription: String? {
        switch self {
        case .unableToSave:
            return "Unable to save password to Keychain"
        case .unableToRetrieve:
            return "Unable to retrieve password from Keychain"
        case .unableToDelete:
            return "Unable to delete password from Keychain"
        }
    }
}