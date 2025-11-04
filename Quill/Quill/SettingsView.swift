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
#elseif os(iOS)
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
    @AppStorage("writingGoalEnabled") private var writingGoalEnabled = false
    @AppStorage("writingGoalTarget") private var writingGoalTarget = 500
    @AppStorage("writingGoalPeriod") private var writingGoalPeriod = "daily"
    
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
            .background(platformBackgroundColor)
            
            Divider()
            
            // Content area
            Group {
                switch selectedTab {
                case "general":
                    #if os(iOS)
                    NavigationView {
                        GeneralSettingsView(
                            matchSystemAppearance: $matchSystemAppearance,
                            preferredAppearance: $preferredAppearance,
                            showWordCount: $showWordCount,
                            enableAutoSave: $enableAutoSave,
                            showAbsoluteDates: $showAbsoluteDates,
                            editorTypeface: $editorTypeface,
                            editorFontSize: $editorFontSize,
                            writingGoalEnabled: $writingGoalEnabled,
                            writingGoalTarget: $writingGoalTarget,
                            writingGoalPeriod: $writingGoalPeriod
                        )
                        .navigationBarHidden(true)
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    #else
                    ScrollView {
                        GeneralSettingsView(
                            matchSystemAppearance: $matchSystemAppearance,
                            preferredAppearance: $preferredAppearance,
                            showWordCount: $showWordCount,
                            enableAutoSave: $enableAutoSave,
                            showAbsoluteDates: $showAbsoluteDates,
                            editorTypeface: $editorTypeface,
                            editorFontSize: $editorFontSize,
                            writingGoalEnabled: $writingGoalEnabled,
                            writingGoalTarget: $writingGoalTarget,
                            writingGoalPeriod: $writingGoalPeriod
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(platformBackgroundColor))
                    #endif
                case "accounts":
                    ScrollView {
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
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(platformBackgroundColor))
                case "debug":
                    ScrollView {
                        DebugView()
                            .modelContainer(for: [SiteConfiguration.self])
                            .frame(maxWidth: .infinity)
                    }
                    .background(Color(platformBackgroundColor))
                default:
                    EmptyView()
                }
            }
            .background(platformBackgroundColor)
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
    @Binding var writingGoalEnabled: Bool
    @Binding var writingGoalTarget: Int
    @Binding var writingGoalPeriod: String
    
    private var typefaceDisplayName: String {
        switch editorTypeface {
        case "system": return "San Francisco"
        case "sf-mono": return "SF Mono"
        case "georgia": return "Georgia"
        case "verdana": return "Verdana"
        case "arial": return "Arial"
        default: return "San Francisco"
        }
    }
    
    var body: some View {
        #if os(iOS)
        Form {
            Section {
                Toggle("Match System Appearance", isOn: $matchSystemAppearance)
                
                if !matchSystemAppearance {
                    HStack {
                        Text("Theme")
                        Spacer()
                        Picker("Theme", selection: $preferredAppearance) {
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                
                NavigationLink {
                    TypefacePickerView(selection: $editorTypeface)
                } label: {
                    HStack {
                        Text("Typeface")
                        Spacer()
                        Text(typefaceDisplayName)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(editorFontSize) pt")
                        .foregroundColor(.secondary)
                    Stepper("", value: $editorFontSize, in: 12...24)
                        .labelsHidden()
                }
            } header: {
                Text("APPEARANCE")
            }
            
            Section {
                Toggle("Show Word Count", isOn: $showWordCount)
                Toggle("Enable Auto-save", isOn: $enableAutoSave)
                Toggle("Show Absolute Dates", isOn: $showAbsoluteDates)
            } header: {
                Text("EDITOR")
            }

            Section {
                Toggle("Enable Writing Goal", isOn: $writingGoalEnabled)

                if writingGoalEnabled {
                    HStack {
                        Text("Goal Period")
                        Spacer()
                        Picker("Goal Period", selection: $writingGoalPeriod) {
                            Text("Daily").tag("daily")
                            Text("Weekly").tag("weekly")
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }

                    HStack {
                        Text("Target Words")
                        Spacer()
                        TextField("500", value: $writingGoalTarget, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("words")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("WRITING GOALS")
            }
        }
        #else
        VStack(alignment: .leading, spacing: 25) {
            // Appearance section
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Appearance:") {
                    HStack(spacing: 15) {
                        Toggle("Match system appearance", isOn: $matchSystemAppearance)
                            .toggleStyle(.checkbox)
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
                            .toggleStyle(.checkbox)
                        Spacer()
                    }
                }
                
                SettingsRow(label: "") {
                    HStack {
                        Toggle("Enable auto-save", isOn: $enableAutoSave)
                            .toggleStyle(.checkbox)
                        Spacer()
                    }
                }
                
                SettingsRow(label: "") {
                    HStack {
                        Toggle("Show absolute dates", isOn: $showAbsoluteDates)
                            .toggleStyle(.checkbox)
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

            // Writing Goals section
            VStack(alignment: .leading, spacing: 12) {
                SettingsRow(label: "Writing goals:") {
                    HStack {
                        Toggle("Enable writing goal", isOn: $writingGoalEnabled)
                            .toggleStyle(.checkbox)
                        Spacer()
                    }
                }

                if writingGoalEnabled {
                    SettingsRow(label: "Goal period:") {
                        HStack {
                            Picker("", selection: $writingGoalPeriod) {
                                Text("Daily").tag("daily")
                                Text("Weekly").tag("weekly")
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 150)
                            Spacer()
                        }
                    }

                    SettingsRow(label: "Target words:") {
                        HStack {
                            TextField("500", value: $writingGoalTarget, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Text("words")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #endif
    }
}

// MARK: - Typeface Picker View

struct TypefacePickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    
    let typefaces = [
        ("system", "San Francisco"),
        ("sf-mono", "SF Mono"),
        ("georgia", "Georgia"),
        ("verdana", "Verdana"),
        ("arial", "Arial")
    ]
    
    var body: some View {
        Form {
            ForEach(typefaces, id: \.0) { id, name in
                HStack {
                    Text(name)
                    Spacer()
                    if selection == id {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = id
                    dismiss()
                }
            }
        }
        .navigationTitle("Typeface")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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

    @Environment(\.modelContext) private var modelContext
    @State private var isSyncing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsRow(label: "Site URL:") {
                HStack {
                    #if os(iOS)
                    SiteURLTextField(text: $siteURL, isDisabled: isTestingConnection)
                        .frame(maxWidth: 300)
                    #else
                    TextField("https://example.com", text: $siteURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isTestingConnection)
                        .frame(maxWidth: 300)
                    #endif
                    Spacer()
                }
            }
            
            SettingsRow(label: "") {
                HStack {
                    Toggle("WordPress.com site", isOn: $isWordPressCom)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
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

                    Button(action: {
                        refreshPosts()
                    }) {
                        HStack(spacing: 4) {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text("Refresh Posts")
                        }
                    }
                    .disabled(isSyncing)
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

    private func refreshPosts() {
        guard let siteConfig = currentSite else { return }

        isSyncing = true

        Task { @MainActor in
            await SyncManager.shared.syncPosts(siteConfig: siteConfig, modelContext: modelContext)
            isSyncing = false
        }
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
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(logger.exportLogs(), forType: .string)
                    #elseif os(iOS)
                    UIPasteboard.general.string = logger.exportLogs()
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

// MARK: - Custom TextField for iOS with proper placeholder color

#if os(iOS)
struct SiteURLTextField: UIViewRepresentable {
    @Binding var text: String
    let isDisabled: Bool
    
    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "https://example.com"
        
        // Set placeholder color to system gray
        textField.attributedPlaceholder = NSAttributedString(
            string: "https://example.com",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.placeholderText]
        )
        
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textFieldDidChange(_:)), for: .editingChanged)
        return textField
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        uiView.text = text
        uiView.isEnabled = !isDisabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        let parent: SiteURLTextField
        
        init(_ parent: SiteURLTextField) {
            self.parent = parent
        }
        
        @objc func textFieldDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
#endif

#Preview {
    SettingsView()
        .modelContainer(for: [SiteConfiguration.self], inMemory: true)
}