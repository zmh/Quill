//
//  Models.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Post {
    var id: UUID
    var remoteID: Int?
    var title: String
    var content: String
    var excerpt: String
    var status: PostStatus
    var slug: String
    var wordCount: Int
    var createdDate: Date
    var modifiedDate: Date
    var publishedDate: Date?
    var syncStatus: SyncStatus
    var lastSyncedHash: String = ""
    
    init(title: String = "", content: String = "", status: PostStatus = .draft) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.excerpt = "" // Will be set by updateExcerpt()
        self.status = status
        self.slug = title.lowercased().replacingOccurrences(of: " ", with: "-")
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(content)
        self.wordCount = plainTextContent.split(separator: " ").count
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.syncStatus = .local
        self.lastSyncedHash = ""
        self.updateExcerpt()
    }
    
    init() {
        self.id = UUID()
        self.title = ""
        self.content = ""
        self.excerpt = ""
        self.status = .draft
        self.slug = ""
        self.wordCount = 0
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.syncStatus = .local
        self.lastSyncedHash = ""
    }
    
    // Computed property to get the most relevant date for display
    @Transient var displayDate: Date {
        // For published posts, use published date if available
        if status == .published || status == .scheduled {
            return publishedDate ?? createdDate
        }
        // For drafts, use created date
        return createdDate
    }
    
    // Computed property for clean text without HTML
    @Transient var contentPlainText: String {
        get {
            return HTMLHandler.shared.htmlToPlainText(content)
        }
        set {
            content = HTMLHandler.shared.plainTextToHTML(newValue)
            updateExcerpt()
        }
    }
    
    // Computed property for clean title without HTML
    @Transient var titlePlainText: String {
        get {
            return HTMLHandler.shared.htmlToPlainText(title)
        }
        set {
            title = newValue // Titles usually don't need HTML conversion
        }
    }
    
    // Content hash for change detection
    @Transient var contentHash: String {
        // Normalize content to ignore formatting differences
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = HTMLHandler.shared.normalizeHTML(content)
        let combinedContent = "\(normalizedTitle)|\(normalizedContent)|\(status.rawValue)|\(slug)"
        
        // Use SHA256 for stable hashing
        return combinedContent.data(using: .utf8)?.base64EncodedString() ?? ""
    }
    
    // Check if content has changed since last sync
    @Transient var hasUnsavedChanges: Bool {
        // New posts always have changes to save
        if remoteID == nil {
            return true
        }
        
        // If we don't have a baseline hash yet, consider it changed
        if lastSyncedHash.isEmpty {
            return true
        }
        
        // Check if current content hash differs from last synced hash
        return contentHash != lastSyncedHash
    }
    
    // Update the baseline hash after successful sync
    func markAsSynced() {
        lastSyncedHash = contentHash
        syncStatus = .synced
    }
    
    // Update excerpt from current content
    func updateExcerpt() {
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(content)
        self.excerpt = String(plainTextContent.prefix(150))
    }
}

enum PostStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case published = "publish"
    case scheduled = "future"
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .published: return "Published"
        case .scheduled: return "Scheduled"
        }
    }
    
    var color: Color {
        switch self {
        case .draft: return .secondary
        case .published: return .green
        case .scheduled: return .blue
        }
    }
}

enum SyncStatus: String, Codable {
    case local = "local"
    case synced = "synced"
    case pendingUpload = "pending_upload"
    case pendingUpdate = "pending_update"
    case conflict = "conflict"
}

// MARK: - WordPress API Extensions

extension PostStatus {
    var wordPressStatus: String {
        switch self {
        case .draft: return "draft"
        case .published: return "publish"
        case .scheduled: return "future"
        }
    }
    
    static func from(wordPressStatus: String) -> PostStatus {
        switch wordPressStatus {
        case "publish": return .published
        case "future": return .scheduled
        case "draft": return .draft
        default: return .draft
        }
    }
}

extension Date {
    func toWordPressDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter.string(from: self)
    }
}