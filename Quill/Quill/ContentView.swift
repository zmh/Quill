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

    @State private var selectedPostIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var filterStatus: PostStatus? = nil
    @State private var showingCompose = false
    @State private var showingSettings = false
    @State private var selectedTab = 0
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @Environment(\.openWindow) private var openWindow

    @StateObject private var syncManager = SyncManager.shared
    @AppStorage("matchSystemAppearance") private var matchSystemAppearance = true
    @AppStorage("preferredAppearance") private var preferredAppearance = "light"

    // Computed property to get the currently selected post
    private var selectedPost: Post? {
        guard let firstID = selectedPostIDs.first else { return nil }
        return posts.first(where: { $0.id == firstID })
    }
    
    var body: some View {
        #if os(iOS)
        TabView(selection: $selectedTab) {
            // Posts Tab
            NavigationView {
                PostsListView(
                    posts: posts,
                    selectedPostIDs: $selectedPostIDs,
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
                .navigationTitle("Posts")
                .navigationBarTitleDisplayMode(.large)
            }
            .tabItem {
                Image(systemName: "doc.text")
                Text("Posts")
            }
            .tag(0)

            // Create Post Tab
            NavigationView {
                CreatePostTabView(
                    selectedPostIDs: $selectedPostIDs,
                    modelContext: modelContext,
                    selectedTab: $selectedTab
                )
            }
            .tabItem {
                Image(systemName: "plus.circle.fill")
                Text("Create")
            }
            .tag(1)
            
            // Settings Tab
            SettingsView()
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
            .tag(2)
        }
        .onAppear {
            // Show settings on first run
            if siteConfigs.isEmpty {
                selectedTab = 2
            } else if let siteConfig = siteConfigs.first {
                // Sync posts from WordPress
                Task { @MainActor in
                    await syncManager.syncPosts(siteConfig: siteConfig, modelContext: modelContext)
                }
            }
        }
        .preferredColorScheme(getColorScheme())
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            selectedTab = 2
        }
        #else
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Posts List
            PostsListView(
                posts: posts,
                selectedPostIDs: $selectedPostIDs,
                searchText: $searchText,
                filterStatus: $filterStatus,
                syncManager: syncManager,
                modelContext: modelContext,
                siteConfig: siteConfigs.first,
                isSidebarVisible: columnVisibility == .all
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
                WriterQuoteEmptyStateView()
            }
        }
        .navigationTitle("")
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
                #if os(iOS)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                #endif
        }
        .preferredColorScheme(getColorScheme())
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("selectPost"))) { notification in
            if let userInfo = notification.userInfo,
               let postID = userInfo["postID"] as? UUID {
                selectedPostIDs = [postID]
            }
        }
        #endif
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
        selectedPostIDs = [post.id]
    }
}

struct PostsListView: View {
    let posts: [Post]
    @Binding var selectedPostIDs: Set<UUID>
    @Binding var searchText: String
    @Binding var filterStatus: PostStatus?
    let syncManager: SyncManager
    let modelContext: ModelContext
    let siteConfig: SiteConfiguration?
    var isSidebarVisible: Bool = true
    @State private var showingCompose = false
    @State private var showGoalProgress = false
    @AppStorage("writingGoalEnabled") private var writingGoalEnabled = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    
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
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .padding(.bottom, 4)
            
            // Posts List
            List(selection: $selectedPostIDs) {
                ForEach(filteredPosts) { post in
                    #if os(iOS)
                    NavigationLink(destination: PostEditorView(post: post)) {
                        PostRowView(post: post)
                    }
                    .contextMenu {
                        Button(action: {
                            deletePost(post)
                        }) {
                            Label("Delete Post", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    }
                    #else
                    PostRowView(post: post)
                        .tag(post.id)
                        .contextMenu {
                            if selectedPostIDs.count > 1 {
                                Button(action: {
                                    deleteSelectedPosts()
                                }) {
                                    Label("Delete \(selectedPostIDs.count) Posts", systemImage: "trash")
                                }
                                .foregroundColor(.red)
                            } else {
                                Button(action: {
                                    deletePost(post)
                                }) {
                                    Label("Delete Post", systemImage: "trash")
                                }
                                .foregroundColor(.red)
                            }
                        }
                    #endif
                }
                .onDelete(perform: deletePosts)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(.clear)

            // Sync status indicator at bottom (like Mail app)
            if syncManager.isSyncing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text("Syncing posts...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
            }
        }
        .background(.ultraThinMaterial)
        #if !os(iOS)
        .navigationSplitViewColumnWidth(300)
        #endif
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if writingGoalEnabled {
                    GoalProgressButton(showGoalProgress: $showGoalProgress)
                        .popover(isPresented: $showGoalProgress, arrowEdge: .bottom) {
                            GoalProgressPopover()
                        }
                }
            }

            if isSidebarVisible {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    }) {
                        Image(systemName: "gear")
                            .font(.system(size: 17))
                    }
                    .buttonStyle(.borderless)
                    .help("Settings")
                    .keyboardShortcut(",", modifiers: .command)
                }

                ToolbarItem(placement: .primaryAction) {
                    Spacer()
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        #if os(macOS)
                        openWindow(id: "compose")
                        #else
                        showingCompose = true
                        #endif
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.borderless)
                    .help("New Post")
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showingCompose) {
            QuickComposeView(isPresented: $showingCompose) { title, content in
                let post = Post(
                    title: title,
                    content: content,
                    status: .draft
                )

                modelContext.insert(post)
                selectedPostIDs = [post.id]
            }
        }
        #endif
    }
    
    private func deletePosts(at offsets: IndexSet) {
        for index in offsets {
            let postToDelete = filteredPosts[index]
            deletePost(postToDelete)
        }
    }
    
    private func deletePost(_ post: Post) {
        // Clear selection if we're deleting the currently selected post
        if selectedPostIDs.contains(post.id) {
            selectedPostIDs.remove(post.id)
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

    private func deleteSelectedPosts() {
        // Get all posts that are currently selected
        let postsToDelete = posts.filter { selectedPostIDs.contains($0.id) }

        // Clear selection
        selectedPostIDs.removeAll()

        // Delete each selected post
        for post in postsToDelete {
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
}

struct PostRowView: View {
    let post: Post
    @AppStorage("showAbsoluteDates") private var showAbsoluteDates = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(post.titlePlainText.isEmpty ? "Untitled" : post.titlePlainText)
                    .font(.body)
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
    @Environment(\.modelContext) private var modelContext
    @State private var showMetadata = false
    @State private var showStatistics = false
    @State private var showGoalProgress = false
    @State private var isTitleHovered = false
    @State private var currentPostID: UUID?
    @State private var sessionStartWordCount: Int = 0
    @State private var lastRecordedSessionWords: Int = 0
    @AppStorage("showWordCount") private var showWordCount = true
    @AppStorage("editorTypeface") private var editorTypeface = "system"
    @AppStorage("editorFontSize") private var editorFontSize = 16
    @AppStorage("writingGoalEnabled") private var writingGoalEnabled = false
    @State private var webViewKey = UUID() // Force WebView refresh when settings change
    @Query private var siteConfigs: [SiteConfiguration]
    @Query private var sessions: [WritingSession]
    @State private var lastLoadedPostID: UUID?

    // Publish workflow state
    @State private var isPublishing = false
    @State private var publishError: Error?
    @State private var showPublishError = false

    // Sync state
    @State private var showConflictResolution = false
    @State private var showPullWarning = false
    @State private var isPulling = false
    
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            ToolbarItem(placement: .navigation) {
                if showWordCount {
                    Button(action: { showStatistics.toggle() }) {
                        Text("\(post.wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showStatistics, arrowEdge: .bottom) {
                        let statistics = TextStatisticsCalculator.calculate(from: post.content)
                        TextStatisticsPopover(statistics: statistics)
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                Button(action: { showMetadata.toggle() }) {
                    Text(post.title.isEmpty ? "Untitled" : post.title)
                        .font(.body)
                        .lineLimit(1)
                        .overlay(alignment: .trailing) {
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .opacity(isTitleHovered ? 1 : 0)
                                .offset(x: 16)
                        }
                }
                .buttonStyle(.plain)
                .onHover { isHovered in
                    isTitleHovered = isHovered
                }
                .popover(isPresented: $showMetadata, arrowEdge: .bottom) {
                    PostMetadataView(post: post)
                        .frame(width: 360, height: 300)
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {

                syncButton
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
        .onChange(of: post.title) { oldTitle, newTitle in 
            // Only update if we're editing the same post
            if currentPostID == post.id && oldTitle != newTitle {
                updatePost()
            }
        }
        .onChange(of: post.content) { oldContent, newContent in 
            // Only update if we're editing the same post
            if currentPostID == post.id && oldContent != newContent {
                updatePost()
            }
        }
        .onChange(of: post.syncStatus) { oldStatus, newStatus in
            DebugLogger.shared.log("Sync status changed from \(oldStatus) to \(newStatus), hasUnsavedChanges: \(post.hasUnsavedChanges)", level: .debug, source: "ContentView")
        }
        .onChange(of: post.id) { _, newPostID in
            if currentPostID != newPostID {
                currentPostID = newPostID
                sessionStartWordCount = post.wordCount
                lastRecordedSessionWords = 0 // Reset for new post
                // Force WebView recreation to ensure clean state
                if lastLoadedPostID != newPostID {
                    lastLoadedPostID = newPostID
                    webViewKey = UUID()
                }

                // Check for remote changes when post is selected
                if let siteConfig = siteConfigs.first {
                    Task { @MainActor in
                        await SyncManager.shared.checkForRemoteChanges(post: post, siteConfig: siteConfig)
                    }
                }
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
            sessionStartWordCount = post.wordCount
            lastRecordedSessionWords = 0 // Reset for new editing session
            // Don't initialize hash here - let WebView handle it after content is processed
        }
        .alert("Publish Error", isPresented: $showPublishError) {
            Button("OK") {
                publishError = nil
            }
        } message: {
            Text(publishError?.localizedDescription ?? "Unknown error occurred while publishing")
        }
        .alert("Sync Conflict", isPresented: $showConflictResolution) {
            Button("Cancel", role: .cancel) { }
            Button("Save Local Changes to Server") {
                publishPost()
            }
            Button("Discard Local Changes & Pull", role: .destructive) {
                pullLatest()
            }
        } message: {
            Text("You have unsaved local changes, but this post was also modified on your WordPress site.\n\nWhich version would you like to keep?")
        }
        .alert("Discard Local Changes?", isPresented: $showPullWarning) {
            Button("Cancel", role: .cancel) { }
            Button("Discard & Pull", role: .destructive) {
                pullLatest()
            }
        } message: {
            Text("You have unsaved local changes that will be permanently lost.\n\nPulling will replace your local version with the server version.")
        }
    }

    @ViewBuilder
    private var syncButton: some View {
        let currentState = post.syncState
        let _ = DebugLogger.shared.log("Rendering syncButton with state: \(currentState)", level: .debug, source: "ContentView")

        switch currentState {
        case .upToDate:
            // Grey/disabled upload button (no changes)
            Button(action: {}) {
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .disabled(true)
            .foregroundStyle(.secondary)
            .help("No changes to upload")

        case .updateAvailable:
            // Blue/enabled upload button (local changes to push)
            Button(action: { publishPost() }) {
                Image(systemName: isPublishing ? "arrow.up.circle.fill" : "arrow.up.circle")
                    .font(.system(size: 20))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: isPublishing)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
            .disabled(isPublishing || post.title.isEmpty || post.content.isEmpty || siteConfigs.isEmpty)
            .keyboardShortcut("s", modifiers: .command)
            .help("Upload changes to server")

        case .pullAvailable:
            // Blue/enabled download button (remote changes to pull)
            Button(action: { pullLatest() }) {
                Image(systemName: isPulling ? "arrow.down.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 20))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: isPulling)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
            .disabled(isPulling || siteConfigs.isEmpty)
            .keyboardShortcut("s", modifiers: .command)
            .help("Download changes from server")

        case .conflict:
            // Blue/enabled sync warning button (conflict)
            Button(action: { showConflictResolution = true }) {
                Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.blue)
            .keyboardShortcut("s", modifiers: .command)
            .help("Sync conflict - resolve changes")
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

    private func getProgressButtonText() -> String {
        let buttonText = getButtonText()
        if buttonText == "Update" {
            return "Updating..."
        }
        return "Publishing..."
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
                
                // Only set published date when status is published
                if post.status == .published && post.publishedDate == nil {
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
                post.modifiedDate = wordPressPost.modifiedAsDate  // Use server's modified date as baseline

                // Update post status from WordPress response
                post.status = PostStatus.from(wordPressStatus: wordPressPost.status)

                // Mark as synced and update baseline hash
                post.markAsSynced()
                
                // SwiftData will handle saving when autosave is disabled
                
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

    private func pullLatest() {
        guard let siteConfig = siteConfigs.first else {
            publishError = PublishError.noSiteConfiguration
            showPublishError = true
            return
        }

        Task { @MainActor in
            isPulling = true

            do {
                // Get password from keychain
                guard let password = try KeychainManager.shared.retrieve(for: siteConfig.keychainIdentifier) else {
                    throw PublishError.noPassword
                }

                guard let remoteID = post.remoteID else {
                    throw PublishError.noRemoteID
                }

                // Fetch latest post from WordPress
                let remotePost = try await WordPressAPI.shared.fetchSinglePost(
                    siteURL: siteConfig.siteURL,
                    username: siteConfig.username,
                    password: password,
                    postID: remoteID
                )

                // Update local post with remote content
                post.title = HTMLHandler.shared.htmlToPlainText(remotePost.title.rendered)

                // Prefer raw content when available
                let contentToStore: String
                if let rawContent = remotePost.content.raw, !rawContent.isEmpty {
                    contentToStore = rawContent
                } else {
                    contentToStore = HTMLHandler.shared.decodeHTMLEntitiesManually(remotePost.content.rendered)
                }

                post.content = contentToStore
                post.updateExcerpt()
                post.slug = remotePost.slug
                post.modifiedDate = remotePost.modifiedAsDate
                post.status = PostStatus.from(wordPressStatus: remotePost.status)

                if remotePost.status == "publish" || remotePost.status == "future" {
                    post.publishedDate = remotePost.dateAsDate
                }

                let plainTextContent = HTMLHandler.shared.htmlToPlainText(post.content)
                post.wordCount = plainTextContent.split(separator: " ").count

                // Mark as synced
                post.markAsSynced()
                post.lastRemoteModifiedDate = remotePost.modifiedAsDate
                post.lastCheckedDate = Date()

                // Force WebView refresh to show pulled content
                webViewKey = UUID()

                DebugLogger.shared.log("Successfully pulled latest changes for post \(post.title)", level: .info, source: "ContentView")

            } catch {
                publishError = error
                showPublishError = true
                DebugLogger.shared.log("Failed to pull latest: \(error)", level: .error, source: "ContentView")
            }

            isPulling = false
        }
    }

    private func updatePost() {
        // Update immediately without deferring
        post.modifiedDate = Date()
        let plainTextContent = HTMLHandler.shared.htmlToPlainText(post.content)
        // Split by any whitespace (spaces, newlines, tabs, etc.) to count words correctly
        let newWordCount = plainTextContent.split(whereSeparator: \.isWhitespace).count

        // Track word count changes for writing goals
        if writingGoalEnabled {
            let wordsWrittenInSession = max(0, newWordCount - sessionStartWordCount)
            DebugLogger.shared.log("Goal tracking - newWordCount: \(newWordCount), sessionStart: \(sessionStartWordCount), wordsWrittenInSession: \(wordsWrittenInSession), lastRecorded: \(lastRecordedSessionWords)", level: .info, source: "ContentView")
            if wordsWrittenInSession > 0 {
                updateWritingSession(wordsWritten: wordsWrittenInSession)
            }
        }

        post.wordCount = newWordCount
        post.excerpt = String(plainTextContent.prefix(150))

        // Only generate slug if it's empty (don't overwrite manual changes)
        if post.slug.isEmpty {
            post.slug = post.title.lowercased().replacingOccurrences(of: " ", with: "-")
        }

        DebugLogger.shared.log("UpdatePost called - remoteID: \(post.remoteID != nil ? "exists" : "nil"), contentHash: \(post.contentHash), lastSyncedHash: \(post.lastSyncedHash), hasUnsavedChanges: \(post.hasUnsavedChanges)", level: .debug, source: "ContentView")
    }

    private func updateWritingSession(wordsWritten: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Calculate the delta from last update
        let delta = wordsWritten - lastRecordedSessionWords
        DebugLogger.shared.log("updateWritingSession - wordsWritten: \(wordsWritten), delta: \(delta)", level: .info, source: "ContentView")

        if delta <= 0 {
            DebugLogger.shared.log("Delta is <= 0, skipping update", level: .info, source: "ContentView")
            return // No new words or words were deleted
        }

        // Find or create today's session
        if let todaySession = sessions.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            // Accumulate the delta
            let oldWords = todaySession.wordsWritten
            todaySession.wordsWritten += delta
            todaySession.modifiedDate = Date()
            DebugLogger.shared.log("Updated existing session: \(oldWords) -> \(todaySession.wordsWritten)", level: .info, source: "ContentView")
        } else {
            let newSession = WritingSession(date: today, wordsWritten: delta)
            modelContext.insert(newSession)
            DebugLogger.shared.log("Created new session with \(delta) words", level: .info, source: "ContentView")
        }

        lastRecordedSessionWords = wordsWritten
        do {
            try modelContext.save()
            DebugLogger.shared.log("✅ Session saved successfully", level: .info, source: "ContentView")
        } catch {
            DebugLogger.shared.log("❌ Failed to save session: \(error)", level: .error, source: "ContentView")
        }
    }
    
    private func openPostOnSite() {
        guard let siteConfig = siteConfigs.first else { return }
        
        // Construct the post URL
        var siteURL = siteConfig.siteURL
        if !siteURL.hasSuffix("/") {
            siteURL += "/"
        }
        
        // For drafts, use WordPress admin edit URL
        let postURL: String
        if post.status == .draft, let remoteID = post.remoteID {
            postURL = siteURL + "wp-admin/post.php?post=\(remoteID)&action=edit"
        } else {
            // For published posts, use slug if available, otherwise use post ID
            let postIdentifier = post.slug.isEmpty ? String(post.remoteID ?? 0) : post.slug
            postURL = siteURL + postIdentifier
        }
        
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
    @Query private var siteConfigs: [SiteConfiguration]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .padding(.vertical, 2)

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

            // View/Edit on Site buttons
            if siteConfigs.first != nil, post.remoteID != nil {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 6) {
                    Button(action: { previewPostInWordPress() }) {
                        HStack {
                            Image(systemName: "eye")
                            Text("Preview in WordPress")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: { openPostOnSite() }) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text(post.status == .published ? "View on Site" : "Edit in WordPress")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

            Spacer()
        }
        .padding(16)
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
    }

    private func previewPostInWordPress() {
        guard let siteConfig = siteConfigs.first,
              let remoteID = post.remoteID else { return }

        // Use the permalink from WordPress if available, otherwise construct preview URL
        let previewURL: String
        if let permalink = post.permalink {
            previewURL = permalink
        } else {
            // Fallback: Extract base domain and use ?p={postID} format
            guard let url = URL(string: siteConfig.siteURL),
                  let scheme = url.scheme,
                  let host = url.host else { return }

            let baseURL = "\(scheme)://\(host)"
            previewURL = "\(baseURL)/?p=\(remoteID)"
        }

        #if os(macOS)
        if let url = URL(string: previewURL) {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: previewURL) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    private func openPostOnSite() {
        guard let siteConfig = siteConfigs.first else { return }

        // Construct the post URL
        var siteURL = siteConfig.siteURL
        if !siteURL.hasSuffix("/") {
            siteURL += "/"
        }

        // For drafts, use WordPress admin edit URL
        let postURL: String
        if post.status == .draft, let remoteID = post.remoteID {
            postURL = siteURL + "wp-admin/post.php?post=\(remoteID)&action=edit"
        } else {
            // For published posts, use slug if available, otherwise use post ID
            let postIdentifier = post.slug.isEmpty ? String(post.remoteID ?? 0) : post.slug
            postURL = siteURL + postIdentifier
        }

        #if os(macOS)
        if let url = URL(string: postURL) {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: postURL) {
            UIApplication.shared.open(url)
        }
        #endif

        post.modifiedDate = Date()
    }
}

// MARK: - Publish Errors

enum PublishError: LocalizedError {
    case noSiteConfiguration
    case emptyTitle
    case emptyContent
    case noPassword
    case noRemoteID

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
        case .noRemoteID:
            return "This post has not been synced to WordPress yet."
        }
    }
}

struct CreatePostTabView: View {
    @Binding var selectedPostIDs: Set<UUID>
    let modelContext: ModelContext
    @Binding var selectedTab: Int
    @State private var postTitle = ""
    @State private var postContent = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isContentFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            TextField("Post title", text: $postTitle)
                .textFieldStyle(.plain)
                .font(.title)
                .fontWeight(.semibold)
                .focused($isTitleFocused)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
            
            Divider()
                .padding(.horizontal, 16)
            
            TextEditor(text: $postContent)
                .font(.body)
                .focused($isContentFocused)
                .padding(.horizontal, 16)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if postContent.isEmpty && !isContentFocused {
                        Text("Start writing...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
            
            Spacer()
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: createPost) {
                    Text("Create")
                        .fontWeight(.semibold)
                }
                .disabled(postTitle.isEmpty)
            }
        }
        .onAppear {
            // Clear fields when tab is shown
            postTitle = ""
            postContent = ""
        }
    }
    
    private func createPost() {
        let post = Post(
            title: postTitle,
            content: postContent.isEmpty ? "<p></p>" : "<p>\(postContent)</p>",
            status: .draft
        )

        modelContext.insert(post)
        selectedPostIDs = [post.id]

        // Clear the form
        postTitle = ""
        postContent = ""

        // Switch to posts tab to show the new post
        selectedTab = 0
    }
}

// MARK: - Compose Window (macOS)

#if os(macOS)
struct ComposeWindow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var posts: [Post]

    @State private var composeText = ""
    @State private var postStatus: PostStatus = .draft
    @State private var showMetadata = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $composeText)
                .font(.body)
                .scrollContentBackground(.hidden)
                .focused($isFocused)
                .padding()

            // Placeholder text
            if composeText.isEmpty {
                Text("Just start typing! First line becomes the title.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.leading, 21)
                    .padding(.top, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 500, height: 300)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Spacer()
            }

            ToolbarItem(placement: .automatic) {
                Button(action: { createPost() }) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 20))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(composeText.isEmpty ? Color.secondary : Color.blue)
                .disabled(composeText.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .help("Create post")
            }
        }
        .onAppear {
            // Clear the text and reset state when the window appears
            composeText = ""
            postStatus = .draft
            isFocused = true
        }
    }

    private func createPost() {
        let lines = composeText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let title = String(lines.first ?? "")
        let content = lines.count > 1 ? String(lines[1]) : ""

        let post = Post(
            title: title,
            content: content,
            status: postStatus
        )

        modelContext.insert(post)

        // Post notification to select the new post in the main window
        NotificationCenter.default.post(
            name: Notification.Name("selectPost"),
            object: nil,
            userInfo: ["postID": post.id]
        )

        dismiss()
    }
}

struct ComposeMetadataView: View {
    @Binding var status: PostStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status picker
            HStack {
                Text("Status:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.primary)
                Picker("", selection: $status) {
                    ForEach(PostStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120, alignment: .leading)
                Spacer()
            }

            Divider()
                .padding(.vertical, 4)

            Text("You can edit more metadata after creating the post")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [Post.self, SiteConfiguration.self], inMemory: true)
}
