//
//  SyncManager.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import Darwin
import SwiftData

class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @MainActor @Published var isSyncing = false
    @MainActor @Published var lastError: Error?
    
    private init() {}
    
    @MainActor
    func syncLocalChanges(siteConfig: SiteConfiguration, modelContext: ModelContext) async {
        DebugLogger.shared.log("Starting upload of local changes...", level: .info, source: "SyncManager")
        
        do {
            // Find posts that need to be uploaded
            let allPosts = try modelContext.fetch(FetchDescriptor<Post>())
            let pendingPosts = allPosts.filter { post in
                post.syncStatus == .pendingUpload || post.syncStatus == .pendingUpdate
            }
            
            if pendingPosts.isEmpty {
                DebugLogger.shared.log("No local changes to sync", level: .info, source: "SyncManager")
                return
            }
            
            // Get credentials
            let keychainIdentifier = siteConfig.keychainIdentifier
            let siteURL = siteConfig.siteURL
            let username = siteConfig.username
            
            guard let password = try KeychainManager.shared.retrieve(for: keychainIdentifier) else {
                throw SyncError.noPasswordFound
            }
            
            for post in pendingPosts {
                do {
                    if post.syncStatus == .pendingUpload {
                        // Create new post
                        DebugLogger.shared.log("Creating new post: \(post.title)", level: .info, source: "SyncManager")
                        let wordPressPost = try await WordPressAPI.shared.createPost(
                            siteURL: siteURL,
                            username: username,
                            password: password,
                            post: post
                        )
                        
                        post.remoteID = wordPressPost.id
                        post.markAsSynced()
                        
                    } else if post.syncStatus == .pendingUpdate, post.remoteID != nil {
                        // Update existing post
                        DebugLogger.shared.log("Updating existing post: \(post.title)", level: .info, source: "SyncManager")
                        let wordPressPost = try await WordPressAPI.shared.updatePost(
                            siteURL: siteURL,
                            username: username,
                            password: password,
                            post: post
                        )
                        
                        post.status = PostStatus.from(wordPressStatus: wordPressPost.status)
                        post.markAsSynced()
                    }
                } catch {
                    DebugLogger.shared.log("Failed to sync post \(post.title): \(error)", level: .error, source: "SyncManager")
                    // Continue with other posts
                }
            }
            
            try modelContext.save()
            DebugLogger.shared.log("Local changes sync completed", level: .info, source: "SyncManager")
            
        } catch {
            DebugLogger.shared.log("Failed to sync local changes: \(error)", level: .error, source: "SyncManager")
            lastError = error
        }
    }
    
    @MainActor
    func syncPosts(siteConfig: SiteConfiguration, modelContext: ModelContext) async {
        isSyncing = true
        lastError = nil
        
        DebugLogger.shared.log("Starting WordPress sync for site: \(siteConfig.siteURL)", level: .info, source: "SyncManager")
        
        // Capture necessary values while on MainActor
        let keychainIdentifier = siteConfig.keychainIdentifier
        let siteURL = siteConfig.siteURL
        let username = siteConfig.username
        
        do {
            // Get password from keychain (can be done off main thread)
            let password: String
            if let retrievedPassword = try KeychainManager.shared.retrieve(for: keychainIdentifier) {
                password = retrievedPassword
            } else {
                throw SyncError.noPasswordFound
            }
            
            DebugLogger.shared.log("Retrieved password length: \(password.count) characters", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Fetching posts from WordPress API...", level: .info, source: "SyncManager")
            let startTime = Date()
            
            // Fetch posts from WordPress (network call, off main thread)
            let wpPosts = try await WordPressAPI.shared.fetchPosts(
                siteURL: siteURL,
                username: username,
                password: password
            )
            
            let fetchDuration = Date().timeIntervalSince(startTime)
            DebugLogger.shared.log("WordPress API fetch completed in \(String(format: "%.1f", fetchDuration)) seconds, got \(wpPosts.count) posts", level: .info, source: "SyncManager")
            
            // Update local posts (all SwiftData operations on MainActor)
            for wpPost in wpPosts {
                // Check if post already exists
                let wpPostID = wpPost.id
                let postDescriptor = FetchDescriptor<Post>(
                    predicate: #Predicate { post in
                        post.remoteID == wpPostID
                    }
                )
                
                do {
                    let existingPosts = try modelContext.fetch(postDescriptor)
                    
                    if let existingPost = existingPosts.first {
                        // Update existing post
                        updatePost(existingPost, from: wpPost)
                    } else {
                        // Create new post
                        let newPost = createPost(from: wpPost)
                        modelContext.insert(newPost)
                    }
                } catch {
                    // Handle individual post errors without stopping the whole sync
                    DebugLogger.shared.log("Failed to process post \(wpPost.id): \(error)", level: .error, source: "SyncManager")
                }
            }
            
            // Update last sync date and save changes
            siteConfig.lastSyncDate = Date()
            do {
                try modelContext.save()
                DebugLogger.shared.log("WordPress sync completed successfully", level: .info, source: "SyncManager")
            } catch {
                lastError = error
                DebugLogger.shared.log("Failed to save sync results: \(error)", level: .error, source: "SyncManager")
            }
            isSyncing = false
            
        } catch {
            let nsError = error as NSError
            DebugLogger.shared.log("WordPress sync failed: \(error.localizedDescription) (domain: \(nsError.domain), code: \(nsError.code))", level: .error, source: "SyncManager")
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == POSIXErrorCode.EMSGSIZE.rawValue {
                DebugLogger.shared.log("Received message-too-long error while syncing. Retrying with smaller fetch size may be necessary.", level: .warning, source: "SyncManager")
                lastError = SyncError.http3MessageTooLong
            } else {
                lastError = error
            }
            isSyncing = false
        }
    }
    
    private func updatePost(_ post: Post, from wpPost: WordPressPost) {
        post.title = cleanHTML(wpPost.title.rendered)
        
        // Log the original content to see what entities we're dealing with
        let originalContent = wpPost.content.rendered
        let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(originalContent)
        
        // Check if content contains HTML entities
        let hasHTMLEntities = originalContent.contains("&#") || originalContent.contains("&amp;") || originalContent.contains("&lt;") || originalContent.contains("&gt;") || originalContent.contains("&quot;")
        
        // Log for any post with HTML entities, not just those with "Formats" in title
        if hasHTMLEntities {
            DebugLogger.shared.log("=== HTML Entity Decoding Debug ===", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Post title: \(wpPost.title.rendered)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Original content: \(String(originalContent.prefix(200)))", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Decoded content: \(String(decodedContent.prefix(200)))", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Content changed: \(originalContent != decodedContent)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Original length: \(originalContent.count), Decoded length: \(decodedContent.count)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("=== End Debug ===", level: .debug, source: "SyncManager")
        }
        
        post.content = HTMLHandler.shared.decodeHTMLEntitiesManually(wpPost.content.rendered)
        post.updateExcerpt() // Generate excerpt from decoded content
        post.slug = wpPost.slug
        post.createdDate = wpPost.dateAsDate
        post.modifiedDate = wpPost.modifiedAsDate
        
        // Map WordPress status to our PostStatus
        switch wpPost.status {
        case "publish":
            post.status = .published
            post.publishedDate = wpPost.dateAsDate
        case "future":
            post.status = .scheduled
            post.publishedDate = wpPost.dateAsDate
        default:
            post.status = .draft
            post.publishedDate = nil
        }
        
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(post.content)
        post.wordCount = plainTextContent.split(separator: " ").count
        
        // Mark as synced with the current content hash
        post.syncStatus = .synced
        post.markAsSynced() // This sets lastSyncedHash = contentHash
    }
    
    private func createPost(from wpPost: WordPressPost) -> Post {
        let post = Post()
        post.remoteID = wpPost.id
        post.title = cleanHTML(wpPost.title.rendered)
        
        // Log the original content to see what entities we're dealing with
        let originalContent = wpPost.content.rendered
        let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(originalContent)
        
        // Check if content contains HTML entities
        let hasHTMLEntities = originalContent.contains("&#") || originalContent.contains("&amp;") || originalContent.contains("&lt;") || originalContent.contains("&gt;") || originalContent.contains("&quot;")
        
        // Log for any post with HTML entities, not just those with "Formats" in title
        if hasHTMLEntities {
            DebugLogger.shared.log("=== CREATE HTML Entity Decoding Debug ===", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Post title: \(wpPost.title.rendered)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Original content: \(String(originalContent.prefix(200)))", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Decoded content: \(String(decodedContent.prefix(200)))", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Content changed: \(originalContent != decodedContent)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("Original length: \(originalContent.count), Decoded length: \(decodedContent.count)", level: .debug, source: "SyncManager")
            DebugLogger.shared.log("=== End CREATE Debug ===", level: .debug, source: "SyncManager")
        }
        
        post.content = HTMLHandler.shared.decodeHTMLEntitiesManually(wpPost.content.rendered)
        post.updateExcerpt() // Generate excerpt from decoded content
        post.slug = wpPost.slug
        post.createdDate = wpPost.dateAsDate
        post.modifiedDate = wpPost.modifiedAsDate
        
        
        // Map WordPress status
        switch wpPost.status {
        case "publish":
            post.status = .published
            post.publishedDate = wpPost.dateAsDate
        case "future":
            post.status = .scheduled
            post.publishedDate = wpPost.dateAsDate
        default:
            post.status = .draft
        }
        
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(post.content)
        post.wordCount = plainTextContent.split(separator: " ").count
        
        // Mark as synced with the current content hash
        post.syncStatus = .synced
        post.markAsSynced() // This sets lastSyncedHash = contentHash
        
        return post
    }
    
    private func cleanHTML(_ html: String) -> String {
        // Use HTMLHandler for comprehensive HTML entity decoding and tag stripping
        return HTMLHandler.shared.htmlToPlainText(html)
    }
}

enum SyncError: LocalizedError {
    case noSiteConfigured
    case noPasswordFound
    case http3MessageTooLong
    
    var errorDescription: String? {
        switch self {
        case .noSiteConfigured:
            return "No WordPress site configured"
        case .noPasswordFound:
            return "No password found in Keychain"
        case .http3MessageTooLong:
            return """
            WordPress returned a response that was too large to deliver over HTTP/3/QUIC. \
            Disable HTTP/3 (with QUIC) in Cloudflare by opening Speed ▸ Settings and turning off “HTTP/3 (with QUIC)”, then try syncing again.
            """
        }
    }
}
