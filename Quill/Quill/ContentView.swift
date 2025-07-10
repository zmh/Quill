//
//  ContentView.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var posts: [Post]
    @Query private var siteConfigs: [SiteConfiguration]
    
    @State private var selectedPost: Post?
    @State private var searchText = ""
    @State private var filterStatus: PostStatus? = nil
    @State private var showingCompose = false
    @State private var showingSettings = false
    
    @StateObject private var syncManager = SyncManager.shared
    @AppStorage("matchSystemAppearance") private var matchSystemAppearance = true
    @AppStorage("preferredAppearance") private var preferredAppearance = "light"
    
    var body: some View {
        NavigationSplitView {
            // Posts List
            PostsListView(
                posts: posts,
                selectedPost: $selectedPost,
                searchText: $searchText,
                filterStatus: $filterStatus,
                syncManager: syncManager,
                modelContext: modelContext,
                siteConfig: siteConfigs.first
            )
            .alert("Sync Error", isPresented: .constant(syncManager.lastError != nil)) {
                Button("OK") {
                    syncManager.lastError = nil
                }
            } message: {
                Text(syncManager.lastError?.localizedDescription ?? "Unknown error")
            }
        } detail: {
            // Editor
            if let post = selectedPost {
                PostEditorView(post: post)
            } else {
                Text("Select a post to edit")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingCompose) {
            QuickComposeView(isPresented: $showingCompose) { title, content in
                createPost(title: title, content: content)
            }
        }
        .onAppear {
            // Show settings on first run
            if siteConfigs.isEmpty {
                showingSettings = true
            } else if let siteConfig = siteConfigs.first {
                // Sync posts from WordPress
                Task { @MainActor in
                    await syncManager.syncPosts(siteConfig: siteConfig, modelContext: modelContext)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .modelContainer(for: [SiteConfiguration.self, Post.self])
        }
        .preferredColorScheme(getColorScheme())
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
    }
    
    private func getColorScheme() -> ColorScheme? {
        if matchSystemAppearance {
            return nil // Use system default
        } else {
            return preferredAppearance == "dark" ? .dark : .light
        }
    }
    
    private func createPost(title: String, content: String) {
        let post = Post(
            title: title,
            content: content,
            status: .draft
        )
        
        modelContext.insert(post)
        selectedPost = post
    }
}

struct PostsListView: View {
    let posts: [Post]
    @Binding var selectedPost: Post?
    @Binding var searchText: String
    @Binding var filterStatus: PostStatus?
    let syncManager: SyncManager
    let modelContext: ModelContext
    let siteConfig: SiteConfiguration?
    @State private var showingCompose = false
    
    var filteredPosts: [Post] {
        posts
            .filter { post in
                (filterStatus == nil || post.status == filterStatus) &&
                (searchText.isEmpty || 
                 post.title.localizedCaseInsensitiveContains(searchText) ||
                 HTMLHandler.shared.htmlToPlainText(post.content).localizedCaseInsensitiveContains(searchText))
            }
            .sorted { post1, post2 in
                // Sort by display date (published date for published posts, created date for drafts)
                return post1.displayDate > post2.displayDate
            }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Filter Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search posts", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Status Filter
            Picker("", selection: $filterStatus) {
                Text("All").tag(PostStatus?.none)
                ForEach(PostStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(PostStatus?.some(status))
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .padding(.bottom, 4)
            
            // Posts List
            List(selection: $selectedPost) {
                ForEach(filteredPosts) { post in
                    PostRowView(post: post)
                        .tag(post)
                        .contextMenu {
                            Button(action: {
                                deletePost(post)
                            }) {
                                Label("Delete Post", systemImage: "trash")
                            }
                            .foregroundColor(.red)
                        }
                }
                .onDelete(perform: deletePosts)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .background(.ultraThinMaterial)
        .navigationSplitViewColumnWidth(300)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if syncManager.isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        if let siteConfig = siteConfig {
                            Task { @MainActor in
                                await syncManager.syncPosts(siteConfig: siteConfig, modelContext: modelContext)
                            }
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            
            ToolbarItem {
                Button(action: { showingCompose = true }) {
                    Label("New Post", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $showingCompose) {
            QuickComposeView(isPresented: $showingCompose) { title, content in
                let post = Post(
                    title: title,
                    content: content,
                    status: .draft
                )
                
                modelContext.insert(post)
                selectedPost = post
            }
        }
    }
    
    private func deletePosts(at offsets: IndexSet) {
        for index in offsets {
            let postToDelete = filteredPosts[index]
            deletePost(postToDelete)
        }
    }
    
    private func deletePost(_ post: Post) {
        // Clear selection if we're deleting the currently selected post
        if selectedPost?.id == post.id {
            selectedPost = nil
        }
        
        // If post has a remote ID, delete from server first
        if let remoteID = post.remoteID, let siteConfig = siteConfig {
            Task { @MainActor in
                do {
                    // Get password from keychain
                    if let password = try KeychainManager.shared.retrieve(for: siteConfig.keychainIdentifier) {
                        try await WordPressAPI.shared.deletePost(
                            siteURL: siteConfig.siteURL,
                            username: siteConfig.username,
                            password: password,
                            postID: remoteID
                        )
                        DebugLogger.shared.log("Successfully deleted post from server: \(remoteID)", level: .info, source: "ContentView")
                    }
                } catch {
                    DebugLogger.shared.log("Failed to delete post from server: \(error)", level: .error, source: "ContentView")
                    // Continue with local deletion even if server deletion fails
                }
                
                // Delete locally after server deletion (or if it fails)
                modelContext.delete(post)
            }
        } else {
            // No remote ID, just delete locally
            modelContext.delete(post)
        }
    }
}

struct PostRowView: View {
    let post: Post
    @AppStorage("showAbsoluteDates") private var showAbsoluteDates = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(post.titlePlainText.isEmpty ? "Untitled" : post.titlePlainText)
                    .font(.headline)
                    .lineLimit(2)
                
                Spacer()
                
                Text(post.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(post.status.color.opacity(0.2))
                    .foregroundColor(post.status.color)
                    .cornerRadius(4)
            }
            
            Text(post.excerpt)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            HStack {
                if showAbsoluteDates {
                    Text(post.displayDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(post.displayDate.simplifiedRelativeString())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(post.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

struct PostEditorView: View {
    @Bindable var post: Post
    @State private var showMetadata = false
    @State private var currentPostID: UUID?
    @AppStorage("showWordCount") private var showWordCount = true
    @AppStorage("editorTypeface") private var editorTypeface = "system"
    @AppStorage("editorFontSize") private var editorFontSize = 16
    @State private var webViewKey = UUID() // Force WebView refresh when settings change
    @Query private var siteConfigs: [SiteConfiguration]
    
    // Publish workflow state
    @State private var isPublishing = false
    @State private var publishError: Error?
    @State private var showPublishError = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title field
            TextField("Title", text: $post.titlePlainText)
                .font(.title)
                .textFieldStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 40)
            
            // Gutenberg WebView editor
            GutenbergWebView(
                post: post,
                typeface: editorTypeface,
                fontSize: editorFontSize,
                siteConfig: siteConfigs.first
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(webViewKey) // Force recreation when key changes
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if showWordCount {
                    Text("\(post.wordCount) words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                if siteConfigs.first != nil, post.status == .published {
                    Button(action: { openPostOnSite() }) {
                        Image(systemName: "arrow.up.right.square")
                    }
                    .help("View on Site")
                }
                
                Button(action: { showMetadata.toggle() }) {
                    Image(systemName: "info.circle")
                }
                .popover(isPresented: $showMetadata) {
                    PostMetadataView(post: post)
                        .frame(width: 360, height: 280)
                }
                
                Button(action: { publishPost() }) {
                    Text(isPublishing ? "Publishing..." : getButtonText())
                }
                .buttonStyle(QuillButtonStyle())
                .disabled(isPublishing || post.title.isEmpty || post.content.isEmpty || siteConfigs.isEmpty || !post.hasUnsavedChanges)
                .onAppear {
                    DebugLogger.shared.log("Button state - disabled: \(isPublishing || post.title.isEmpty || post.content.isEmpty || siteConfigs.isEmpty || !post.hasUnsavedChanges), hasUnsavedChanges: \(post.hasUnsavedChanges)", level: .debug, source: "ContentView")
                }
                .onChange(of: post.hasUnsavedChanges) { oldValue, newValue in
                    DebugLogger.shared.log("hasUnsavedChanges changed from \(oldValue) to \(newValue)", level: .debug, source: "ContentView")
                }
                .onChange(of: post.contentHash) { oldValue, newValue in
                    DebugLogger.shared.log("contentHash changed from \(oldValue) to \(newValue), hasUnsavedChanges: \(post.hasUnsavedChanges), lastSyncedHash: \(post.lastSyncedHash)", level: .debug, source: "ContentView")
                }
            }
        }
        .onChange(of: post.title) { _, _ in updatePost() }
        .onChange(of: post.content) { _, _ in updatePost() }
        .onChange(of: post.syncStatus) { oldStatus, newStatus in
            DebugLogger.shared.log("Sync status changed from \(oldStatus) to \(newStatus), hasUnsavedChanges: \(post.hasUnsavedChanges)", level: .debug, source: "ContentView")
        }
        .onChange(of: post.id) { _, newPostID in
            if currentPostID != newPostID {
                currentPostID = newPostID
                // Force WebView to update when switching posts
                webViewKey = UUID()
            }
        }
        .onChange(of: editorTypeface) { _, _ in 
            webViewKey = UUID() // Force WebView recreation
        }
        .onChange(of: editorFontSize) { _, _ in 
            webViewKey = UUID() // Force WebView recreation
        }
        .onAppear {
            currentPostID = post.id
            // Don't initialize hash here - let WebView handle it after content is processed
        }
        .alert("Publish Error", isPresented: $showPublishError) {
            Button("OK") {
                publishError = nil
            }
        } message: {
            Text(publishError?.localizedDescription ?? "Unknown error occurred while publishing")
        }
    }
    
    private func getButtonText() -> String {
        if post.remoteID == nil {
            // New post - button text depends on status
            return post.status == .published ? "Publish" : "Save as \(post.status.displayName)"
        } else {
            // Existing post - always "Update"
            return "Update"
        }
    }
    
    private func publishPost() {
        guard let siteConfig = siteConfigs.first else {
            publishError = PublishError.noSiteConfiguration
            showPublishError = true
            return
        }
        
        // Validate post before publishing
        guard !post.title.isEmpty else {
            publishError = PublishError.emptyTitle
            showPublishError = true
            return
        }
        
        guard !post.content.isEmpty else {
            publishError = PublishError.emptyContent
            showPublishError = true
            return
        }
        
        Task { @MainActor in
            isPublishing = true
            publishError = nil
            
            do {
                // Update post metadata before publishing
                updatePost()
                
                // Set status to published only for new posts that are drafts
                if post.remoteID == nil && post.status == .draft {
                    post.status = .published
                    post.publishedDate = Date()
                }
                
                // Generate slug if empty (but keep any manual changes)
                if post.slug.isEmpty {
                    post.slug = post.title
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "-")
                        .components(separatedBy: CharacterSet.alphanumerics.inverted)
                        .joined(separator: "-")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
                }
                
                let wordPressPost: WordPressPost
                
                // Get password from keychain
                guard let password = try KeychainManager.shared.retrieve(for: siteConfig.keychainIdentifier) else {
                    throw PublishError.noPassword
                }
                
                if post.remoteID == nil {
                    // Create new post
                    wordPressPost = try await WordPressAPI.shared.createPost(
                        siteURL: siteConfig.siteURL,
                        username: siteConfig.username,
                        password: password,
                        post: post
                    )
                } else {
                    // Update existing post
                    wordPressPost = try await WordPressAPI.shared.updatePost(
                        siteURL: siteConfig.siteURL,
                        username: siteConfig.username,
                        password: password,
                        post: post
                    )
                }
                
                // Update local post with remote data
                post.remoteID = wordPressPost.id
                post.modifiedDate = Date()
                
                // Update post status from WordPress response
                post.status = PostStatus.from(wordPressStatus: wordPressPost.status)
                
                // Mark as synced and update baseline hash
                post.markAsSynced()
                
                DebugLogger.shared.log("Post successfully published: \(wordPressPost.id)", level: .info, source: "ContentView")
                
            } catch {
                publishError = error
                showPublishError = true
                DebugLogger.shared.log("Failed to publish post: \(error)", level: .error, source: "ContentView")
                
                // Revert status if publication failed
                if post.remoteID == nil {
                    post.status = .draft
                    post.publishedDate = nil
                }
            }
            
            isPublishing = false
        }
    }
    
    private func updatePost() {
        post.modifiedDate = Date()
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(post.content)
        post.wordCount = plainTextContent.split(separator: " ").count
        post.excerpt = String(plainTextContent.prefix(150))
        
        // Only generate slug if it's empty (don't overwrite manual changes)
        if post.slug.isEmpty {
            post.slug = post.title.lowercased().replacingOccurrences(of: " ", with: "-")
        }
        
        DebugLogger.shared.log("UpdatePost called - remoteID: \(post.remoteID != nil ? "exists" : "nil"), contentHash: \(post.contentHash), lastSyncedHash: \(post.lastSyncedHash), hasUnsavedChanges: \(post.hasUnsavedChanges)", level: .debug, source: "ContentView")
    }
    
    private func openPostOnSite() {
        guard let siteConfig = siteConfigs.first else { return }
        
        // Construct the post URL
        var siteURL = siteConfig.siteURL
        if !siteURL.hasSuffix("/") {
            siteURL += "/"
        }
        
        // Use slug if available, otherwise use post ID
        let postIdentifier = post.slug.isEmpty ? String(post.remoteID ?? 0) : post.slug
        let postURL = siteURL + postIdentifier
        
        // Open in default browser
        if let url = URL(string: postURL) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }
}

struct QuickComposeView: View {
    @Binding var isPresented: Bool
    let onCompose: (String, String) -> Void
    
    @State private var composeText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Post")
                    .font(.headline)
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                
                Button("Create") {
                    let lines = composeText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                    let title = String(lines.first ?? "")
                    let content = lines.count > 1 ? String(lines[1]) : ""
                    
                    onCompose(title, content)
                    isPresented = false
                }
                .buttonStyle(QuillButtonStyle())
                .disabled(composeText.isEmpty)
            }
            .padding()
            
            Divider()
            
            // Compose Field
            VStack(alignment: .leading, spacing: 8) {
                Text("What would you like to say?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextEditor(text: $composeText)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 150)
                
                Text("First line becomes the title")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .onAppear {
            isFocused = true
        }
    }
}

struct PostMetadataView: View {
    @Bindable var post: Post
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title field
            HStack {
                Text("Title:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                TextField("", text: $post.title)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Slug field
            HStack {
                Text("Slug:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                TextField("", text: $post.slug)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Status picker
            HStack {
                Text("Status:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                Picker("", selection: $post.status) {
                    ForEach(PostStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120, alignment: .leading)
                Spacer()
            }
            
            // Publish date (if scheduled)
            if post.status == .scheduled {
                HStack {
                    Text("Publish:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(.primary)
                    DatePicker("", selection: Binding(
                        get: { post.publishedDate ?? Date() },
                        set: { post.publishedDate = $0 }
                    ))
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    Spacer()
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Statistics
            HStack {
                Text("Words:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                Text("\(post.wordCount)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            HStack {
                Text("Created:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                Text(post.createdDate, format: .dateTime)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                Spacer()
            }
            
            HStack {
                Text("Modified:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                Text(post.modifiedDate, format: .dateTime)
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                Spacer()
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: post.status) { oldStatus, newStatus in
            handleStatusChange(from: oldStatus, to: newStatus)
        }
    }
    
    private func handleStatusChange(from oldStatus: PostStatus, to newStatus: PostStatus) {
        // Set published date when changing to published
        if newStatus == .published && oldStatus != .published {
            if post.publishedDate == nil {
                post.publishedDate = Date()
            }
        }
        
        // Set published date when changing to scheduled
        if newStatus == .scheduled && post.publishedDate == nil {
            post.publishedDate = Date().addingTimeInterval(3600) // Default to 1 hour from now
        }
        
        // Clear published date when changing to draft
        if newStatus == .draft && oldStatus != .draft {
            post.publishedDate = nil
        }
        
        post.modifiedDate = Date()
    }
}

// MARK: - Publish Errors

enum PublishError: LocalizedError {
    case noSiteConfiguration
    case emptyTitle
    case emptyContent
    case noPassword
    
    var errorDescription: String? {
        switch self {
        case .noSiteConfiguration:
            return "No WordPress site configured. Please set up your site in Settings."
        case .emptyTitle:
            return "Post title cannot be empty"
        case .emptyContent:
            return "Post content cannot be empty"
        case .noPassword:
            return "WordPress password not found. Please check your site settings."
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Post.self, SiteConfiguration.self], inMemory: true)
}