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
    func checkForRemoteChanges(post: Post, siteConfig: SiteConfiguration) async {
        // Only check posts that have been synced to WordPress
        guard let remoteID = post.remoteID else {
            DebugLogger.shared.log("Skipping remote check for post without remoteID", level: .debug, source: "SyncManager")
            return
        }

        do {
            // Get credentials
            let keychainIdentifier = siteConfig.keychainIdentifier
            let siteURL = siteConfig.siteURL
            let username = siteConfig.username

            guard let password = try KeychainManager.shared.retrieve(for: keychainIdentifier) else {
                DebugLogger.shared.log("No password found for remote check", level: .warning, source: "SyncManager")
                return
            }

            // Fetch lightweight post metadata from WordPress
            let remotePost = try await WordPressAPI.shared.fetchSinglePost(
                siteURL: siteURL,
                username: username,
                password: password,
                postID: remoteID
            )

            // Update tracking fields
            post.lastRemoteModifiedDate = remotePost.modifiedAsDate
            post.lastCheckedDate = Date()

            DebugLogger.shared.log(
                "Remote check complete for post \(post.title): baseline \(post.lastSyncedModifiedDate?.description ?? "none"), local modified \(post.modifiedDate), remote modified \(remotePost.modifiedAsDate), hasRemoteChanges: \(post.hasRemoteChanges)",
                level: .debug,
                source: "SyncManager"
            )

        } catch {
            DebugLogger.shared.log("Failed to check for remote changes: \(error)", level: .error, source: "SyncManager")
        }
    }

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
                let enrichedPost = await self.postWithLatestAutosaveIfNeeded(
                    wpPost,
                    siteURL: siteURL,
                    username: username,
                    password: password
                )
                // Check if post already exists
                let wpPostID = enrichedPost.id
                let postDescriptor = FetchDescriptor<Post>(
                    predicate: #Predicate { post in
                        post.remoteID == wpPostID
                    }
                )
                
                do {
                    let existingPosts = try modelContext.fetch(postDescriptor)
                    
                    if let existingPost = existingPosts.first {
                        // Update existing post
                        updatePost(existingPost, from: enrichedPost)
                    } else {
                        // Create new post
                        let newPost = createPost(from: enrichedPost)
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
        
        // Prefer raw block content when available so we keep Gutenberg structure intact
        let rawContent = wpPost.content.raw
        let renderedContent = wpPost.content.rendered
        let contentToStore: String
        
        if let rawContent, !rawContent.isEmpty {
            contentToStore = rawContent
            DebugLogger.shared.log("Using raw WordPress content for post \(wpPost.id)", level: .debug, source: "SyncManager")
        } else {
            // Fallback to rendered HTML and decode entities for consistency
            let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(renderedContent)
            contentToStore = decodedContent
            
            let hasHTMLEntities = renderedContent.contains("&#") || renderedContent.contains("&amp;") || renderedContent.contains("&lt;") || renderedContent.contains("&gt;") || renderedContent.contains("&quot;")
            if hasHTMLEntities {
                DebugLogger.shared.log("=== HTML Entity Decoding Debug (rendered fallback) ===", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Post title: \(wpPost.title.rendered)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Rendered content: \(String(renderedContent.prefix(200)))", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Decoded content: \(String(decodedContent.prefix(200)))", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Content changed: \(renderedContent != decodedContent)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Rendered length: \(renderedContent.count), Decoded length: \(decodedContent.count)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("=== End Debug ===", level: .debug, source: "SyncManager")
            }
        }
        
        post.content = contentToStore
        post.updateExcerpt() // Generate excerpt from decoded content
        post.slug = wpPost.slug
        post.permalink = wpPost.link
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
        
        let rawContent = wpPost.content.raw
        let renderedContent = wpPost.content.rendered
        let contentToStore: String
        
        if let rawContent, !rawContent.isEmpty {
            contentToStore = rawContent
            DebugLogger.shared.log("Using raw WordPress content for new post \(wpPost.id)", level: .debug, source: "SyncManager")
        } else {
            let decodedContent = HTMLHandler.shared.decodeHTMLEntitiesManually(renderedContent)
            contentToStore = decodedContent
            
            let hasHTMLEntities = renderedContent.contains("&#") || renderedContent.contains("&amp;") || renderedContent.contains("&lt;") || renderedContent.contains("&gt;") || renderedContent.contains("&quot;")
            if hasHTMLEntities {
                DebugLogger.shared.log("=== CREATE HTML Entity Decoding Debug (rendered fallback) ===", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Post title: \(wpPost.title.rendered)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Rendered content: \(String(renderedContent.prefix(200)))", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Decoded content: \(String(decodedContent.prefix(200)))", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Content changed: \(renderedContent != decodedContent)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("Rendered length: \(renderedContent.count), Decoded length: \(decodedContent.count)", level: .debug, source: "SyncManager")
                DebugLogger.shared.log("=== End CREATE Debug ===", level: .debug, source: "SyncManager")
            }
        }
        
        post.content = contentToStore
        post.updateExcerpt() // Generate excerpt from decoded content
        post.slug = wpPost.slug
        post.permalink = wpPost.link
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

    private func postWithLatestAutosaveIfNeeded(
        _ post: WordPressPost,
        siteURL: String,
        username: String,
        password: String
    ) async -> WordPressPost {
        // Check autosaves and revisions for all posts to catch draft changes to published posts
        var latestPost = post
        var latestSource: String = "canonical"
        var latestModifiedDate = post.modifiedAsDate

        do {
            if let autosave = try await WordPressAPI.shared.fetchLatestAutosave(
                siteURL: siteURL,
                username: username,
                password: password,
                postID: post.id
            ) {
                let autosaveHasContent = !(autosave.content.raw?.isEmpty ?? autosave.content.rendered.isEmpty)
                if autosaveHasContent && autosave.modifiedAsDate > latestModifiedDate {
                    DebugLogger.shared.log(
                        "Using autosave for post \(post.id) (autosave modified: \(autosave.modified), post modified: \(post.modified))",
                        level: .info,
                        source: "SyncManager"
                    )
                    latestPost = WordPressPost(
                        id: post.id,
                        date: post.date,
                        dateGmt: post.dateGmt,
                        modified: autosave.modified,
                        modifiedGmt: autosave.modifiedGmt,
                        slug: post.slug,
                        status: post.status,
                        link: post.link,
                        title: post.title,
                        content: autosave.content,
                        excerpt: post.excerpt
                    )
                    latestModifiedDate = autosave.modifiedAsDate
                    latestSource = "autosave \(autosave.id)"
                } else {
                    DebugLogger.shared.log(
                        "Autosave for post \(post.id) ignored (hasContent: \(autosaveHasContent), autosave modified: \(autosave.modified), baseline modified: \(latestModifiedDate))",
                        level: .debug,
                        source: "SyncManager"
                    )
                }
            }
        } catch {
            DebugLogger.shared.log("Failed to fetch autosave for post \(post.id): \(error)", level: .debug, source: "SyncManager")
        }

        do {
            if let revision = try await WordPressAPI.shared.fetchLatestRevision(
                siteURL: siteURL,
                username: username,
                password: password,
                postID: post.id
            ) {
                let revisionHasContent = !(revision.content.raw?.isEmpty ?? revision.content.rendered.isEmpty)
                if revisionHasContent && revision.modifiedAsDate > latestModifiedDate {
                    DebugLogger.shared.log(
                        "Using revision \(revision.id) for post \(post.id) (revision modified: \(revision.modified), baseline modified: \(latestModifiedDate))",
                        level: .info,
                        source: "SyncManager"
                    )
                    latestPost = WordPressPost(
                        id: post.id,
                        date: post.date,
                        dateGmt: post.dateGmt,
                        modified: revision.modified,
                        modifiedGmt: revision.modifiedGmt,
                        slug: post.slug,
                        status: post.status,
                        link: post.link,
                        title: revision.title ?? post.title,
                        content: revision.content,
                        excerpt: revision.excerpt ?? post.excerpt
                    )
                    latestModifiedDate = revision.modifiedAsDate
                    latestSource = "revision \(revision.id)"
                } else {
                    DebugLogger.shared.log(
                        "Revision for post \(post.id) ignored (hasContent: \(revisionHasContent), revision modified: \(revision.modified), baseline modified: \(latestModifiedDate))",
                        level: .debug,
                        source: "SyncManager"
                    )
                }
            }
        } catch {
            DebugLogger.shared.log("Failed to fetch revision for post \(post.id): \(error)", level: .debug, source: "SyncManager")
        }

        if latestSource != "canonical" {
            DebugLogger.shared.log(
                "Post \(post.id) content sourced from \(latestSource)",
                level: .debug,
                source: "SyncManager"
            )
        }

        return latestPost
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
