//
//  SettingsView.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var siteConfigs: [SiteConfiguration]
    
    @State private var selectedTab = "accounts"
    @State private var siteURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isWordPressCom = false
    @State private var isTestingConnection = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // General settings state
    @AppStorage("matchSystemAppearance") private var matchSystemAppearance = true
    @AppStorage("preferredAppearance") private var preferredAppearance = "light"
    @AppStorage("showWordCount") private var showWordCount = true
    @AppStorage("enableAutoSave") private var enableAutoSave = true
    @AppStorage("showAbsoluteDates") private var showAbsoluteDates = false
    @AppStorage("editorTypeface") private var editorTypeface = "system"
    @AppStorage("editorFontSize") private var editorFontSize = 16
    
    private var platformBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var currentSite: SiteConfiguration? {
        siteConfigs.first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            // Add spacing on iOS to avoid drag handle
            Color(platformBackgroundColor)
                .frame(height: 20)
            #endif
            
            // Top tab bar - matching iA Writer style
            HStack(spacing: 2) {
                Spacer()
                TabButton(title: "General", icon: "gear", isSelected: selectedTab == "general") {
                    selectedTab = "general"
                }
                TabButton(title: "Accounts", icon: "at", isSelected: selectedTab == "accounts") {
                    selectedTab = "accounts"
                }
                TabButton(title: "Debug", icon: "ladybug", isSelected: selectedTab == "debug") {
                    selectedTab = "debug"
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(platformBackgroundColor))
            
            Divider()
            
            // Content area
            ScrollView {
                Group {
                    switch selectedTab {
                    case "general":
                        GeneralSettingsView(
                            matchSystemAppearance: $matchSystemAppearance,
                            preferredAppearance: $preferredAppearance,
                            showWordCount: $showWordCount,
                            enableAutoSave: $enableAutoSave,
                            showAbsoluteDates: $showAbsoluteDates,
                            editorTypeface: $editorTypeface,
                            editorFontSize: $editorFontSize
                        )
                    case "accounts":
                        AccountsSettingsView(
                            siteURL: $siteURL,
                            username: $username,
                            password: $password,
                            isWordPressCom: $isWordPressCom,
                            isTestingConnection: $isTestingConnection,
                            showingError: $showingError,
                            errorMessage: $errorMessage,
                            currentSite: currentSite,
                            testAndSaveConnection: testAndSaveConnection,
                            disconnectSite: disconnectSite
                        )
                        .onAppear {
                            if let site = currentSite {
                                siteURL = site.siteURL
                                username = site.username
                                isWordPressCom = site.isWordPressCom
                                
                                // Try to retrieve password
                                if let savedPassword = try? KeychainManager.shared.retrieve(for: site.keychainIdentifier) {
                                    password = savedPassword
                                }
                            }
                        }
                    case "debug":
                        DebugView()
                            .modelContainer(for: [SiteConfiguration.self])
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(platformBackgroundColor))
        }
        .background(Color(platformBackgroundColor))
        #if os(macOS)
        .frame(width: 500, height: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
        #endif
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func testAndSaveConnection() {
        isTestingConnection = true
        
        Task {
            do {
                // Test the connection
                let success = try await WordPressAPI.shared.testConnection(
                    siteURL: siteURL,
                    username: username,
                    password: password
                )
                
                if success {
                    await MainActor.run {
                        saveConfiguration()
                        isTestingConnection = false
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func saveConfiguration() {
        // Delete existing configuration if any
        for config in siteConfigs {
            modelContext.delete(config)
        }
        
        // Create new configuration
        let config = SiteConfiguration(
            siteURL: siteURL,
            username: username,
            isWordPressCom: isWordPressCom
        )
        
        // Save password to Keychain
        do {
            // Generate keychain identifier manually to avoid SwiftData access issues
            let keychainIdentifier = "\(Bundle.main.bundleIdentifier ?? "Quill").site.\(config.id.uuidString)"
            try KeychainManager.shared.save(password: password, for: keychainIdentifier)
            modelContext.insert(config)
            
            // Clear ALL existing posts to get fresh data with proper encoding
            clearAllPosts()
            
            // Save context first to ensure config is persisted
            try modelContext.save()
            
            // Capture references before the async task to avoid deallocation issues
            let syncContainer = modelContext.container
            let configId = config.id
            
            // Trigger sync with a fresh context to avoid threading issues
            Task { @MainActor in
                // Small delay to ensure SwiftData context is fully updated
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                // Create a fresh context from the captured container
                let syncContext = ModelContext(syncContainer)
                
                // Refetch the config with the fresh context
                let configDescriptor = FetchDescriptor<SiteConfiguration>(
                    predicate: #Predicate { $0.id == configId }
                )
                
                if let freshConfig = try? syncContext.fetch(configDescriptor).first {
                    await SyncManager.shared.syncPosts(siteConfig: freshConfig, modelContext: syncContext)
                } else {
                    DebugLogger.shared.log("Error: Could not refetch configuration for sync", level: .error, source: "SettingsView")
                }
            }
            
        } catch {
            errorMessage = "Failed to save password: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func disconnectSite() {
        guard let site = currentSite else { return }
        
        // Delete password from Keychain
        try? KeychainManager.shared.delete(for: site.keychainIdentifier)
        
        // Delete configuration
        modelContext.delete(site)
        
        // Clear ALL posts (both mock and WordPress posts)
        clearAllPosts()
        
        // Clear form
        siteURL = ""
        username = ""
        password = ""
        isWordPressCom = false
    }
    
    private func clearAllPosts() {
        do {
            let descriptor = FetchDescriptor<Post>()
            let allPosts = try modelContext.fetch(descriptor)
            for post in allPosts {
                modelContext.delete(post)
            }
            try modelContext.save()
        } catch {
            DebugLogger.shared.log("Failed to clear all posts: \(error)", level: .error, source: "SettingsView")
        }
    }
    
    private func clearMockPosts() {
        // Delete all posts without a remote ID (mock posts)
        do {
            let descriptor = FetchDescriptor<Post>(
                predicate: #Predicate { post in
                    post.remoteID == nil
                }
            )
            let mockPosts = try modelContext.fetch(descriptor)
            for post in mockPosts {
                modelContext.delete(post)
            }
            try modelContext.save()
        } catch {
            DebugLogger.shared.log("Failed to clear mock posts: \(error)", level: .error, source: "SettingsView")
        }
    }
}

// MARK: - General Settings View

struct GeneralSettingsView: View {
    @Binding var matchSystemAppearance: Bool
    @Binding var preferredAppearance: String
    @Binding var showWordCount: Bool
    @Binding var enableAutoSave: Bool
    @Binding var showAbsoluteDates: Bool
    @Binding var editorTypeface: String
    @Binding var editorFontSize: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            // Appearance section
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Appearance:") {
                    HStack(spacing: 15) {
                        Toggle("Match system appearance", isOn: $matchSystemAppearance)
                            #if os(macOS)
                            #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                            #else
                            .toggleStyle(.switch)
                            #endif
                        Spacer()
                    }
                }
                
                if !matchSystemAppearance {
                    SettingsRow(label: "") {
                        HStack(spacing: 12) {
                            Button("Light") {
                                preferredAppearance = "light"
                            }
                            .buttonStyle(SettingsRadioButtonStyle(isSelected: preferredAppearance == "light"))
                            Button("Dark") {
                                preferredAppearance = "dark"
                            }
                            .buttonStyle(SettingsRadioButtonStyle(isSelected: preferredAppearance == "dark"))
                            Spacer()
                        }
                        .padding(.leading, 20)
                    }
                }
            }
            
            // Editor section
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Editor:") {
                    HStack {
                        Toggle("Show word count", isOn: $showWordCount)
                            #if os(macOS)
                            #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                            #else
                            .toggleStyle(.switch)
                            #endif
                        Spacer()
                    }
                }
                
                SettingsRow(label: "") {
                    HStack {
                        Toggle("Enable auto-save", isOn: $enableAutoSave)
                            #if os(macOS)
                            #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                            #else
                            .toggleStyle(.switch)
                            #endif
                        Spacer()
                    }
                }
                
                SettingsRow(label: "") {
                    HStack {
                        Toggle("Show absolute dates", isOn: $showAbsoluteDates)
                            #if os(macOS)
                            #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                            #else
                            .toggleStyle(.switch)
                            #endif
                        Spacer()
                    }
                }
            }
            
            // Typeface section
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Typeface:") {
                    HStack {
                        Picker("", selection: $editorTypeface) {
                            Text("San Francisco").tag("system")
                            Text("SF Mono").tag("sf-mono")
                            Text("Georgia").tag("georgia")
                            Text("Verdana").tag("verdana")
                            Text("Arial").tag("arial")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                        Spacer()
                    }
                }
                
                SettingsRow(label: "Font size:") {
                    HStack {
                        Stepper("\(editorFontSize) pt", value: $editorFontSize, in: 12...24)
                            .frame(width: 100)
                        Spacer()
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Accounts Settings View

struct AccountsSettingsView: View {
    @Binding var siteURL: String
    @Binding var username: String
    @Binding var password: String
    @Binding var isWordPressCom: Bool
    @Binding var isTestingConnection: Bool
    @Binding var showingError: Bool
    @Binding var errorMessage: String
    let currentSite: SiteConfiguration?
    let testAndSaveConnection: () -> Void
    let disconnectSite: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsRow(label: "Site URL:") {
                HStack {
                    TextField("", text: $siteURL, prompt: Text("https://example.com").foregroundColor(.secondary))
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTestingConnection)
                        .frame(maxWidth: 300)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            
            SettingsRow(label: "") {
                HStack {
                    Toggle("WordPress.com site", isOn: $isWordPressCom)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #else
                        .toggleStyle(.switch)
                        #endif
                        .disabled(isTestingConnection)
                    Spacer()
                }
            }
            
            if !isWordPressCom {
                SettingsRow(label: "Username:") {
                    HStack {
                        TextField("admin", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isTestingConnection)
                            .frame(maxWidth: 200)
                        Spacer()
                    }
                }
                
                SettingsRow(label: "Password:") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            SecureField("Application Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .disabled(isTestingConnection)
                                .frame(maxWidth: 250)
                            Spacer()
                        }
                        Text("Create an Application Password in WordPress admin → Users → Profile")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                SettingsRow(label: "") {
                    Text("WordPress.com authentication coming soon")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .padding(.vertical, 10)
            
            HStack {
                if currentSite != nil {
                    Button("Disconnect") {
                        disconnectSite()
                    }
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                if isTestingConnection {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    Button(currentSite == nil ? "Connect" : "Update Connection") {
                        testAndSaveConnection()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(siteURL.isEmpty || (!isWordPressCom && (username.isEmpty || password.isEmpty)))
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Supporting Views

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .frame(width: 70, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .frame(width: 120, alignment: .trailing)
                .foregroundColor(.primary)
            
            content
        }
    }
}

struct SettingsRadioButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.secondary, lineWidth: 1)
                )
            
            configuration.label
                .font(.system(size: 13))
        }
        .foregroundColor(.primary)
        .opacity(configuration.isPressed ? 0.7 : 1.0)
        .contentShape(Rectangle()) // Make the entire HStack clickable
    }
}

// MARK: - Debug Log View

struct DebugLogView: View {
    @StateObject private var logger = DebugLogger.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText = ""
    
    var filteredLogs: [LogEntry] {
        logger.logs
            .filter { log in
                (selectedLevel == nil || log.level == selectedLevel) &&
                (searchText.isEmpty || log.message.localizedCaseInsensitiveContains(searchText) || log.source.localizedCaseInsensitiveContains(searchText))
            }
            .suffix(500) // Show last 500 entries for performance
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with controls
            HStack {
                Text("Debug Logs")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Clear") {
                    logger.clear()
                }
                .foregroundColor(.red)
                
                Button("Copy All") {
                    let logs = logger.exportLogs()
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logs, forType: .string)
                    #else
                    UIPasteboard.general.string = logs
                    #endif
                }
            }
            
            // Filter controls
            HStack {
                // Level filter
                Picker("Level", selection: $selectedLevel) {
                    Text("All Levels").tag(LogLevel?.none)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(LogLevel?.some(level))
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                
                Spacer()
                
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search logs...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .frame(width: 200)
            }
            
            // Log entries
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(filteredLogs) { log in
                        LogEntryView(entry: log)
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 250)
            .background(Color.black.opacity(0.05))
            .cornerRadius(8)
            
            Text("\(filteredLogs.count) of \(logger.logs.count) entries shown")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            // Timestamp
            Text(entry.timestamp, format: .dateTime.hour().minute().second())
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(minWidth: 50)
            
            // Level badge
            Text(entry.level.rawValue)
                .font(.system(size: 8, weight: .semibold))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(levelColor(entry.level))
                .foregroundColor(.white)
                .cornerRadius(2)
                .frame(minWidth: 35)
            
            // Source
            if !entry.source.isEmpty {
                Text(entry.source)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 60)
                    .lineLimit(1)
            }
            
            // Message
            Text(entry.message)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(entry.level == .error ? Color.red.opacity(0.1) : Color.clear)
    }
    
    private func levelColor(_ level: LogLevel) -> Color {
        switch level {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [SiteConfiguration.self], inMemory: true)
}