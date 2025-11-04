//
//  QuillApp.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

import Foundation
import SwiftUI
import SwiftData

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

@main
struct QuillApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Post.self,
            SiteConfiguration.self,
            WritingSession.self,
        ])

        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let identifier = Bundle.main.bundleIdentifier ?? "QuillApp"
        let baseDirectory = appSupport.appendingPathComponent(identifier, isDirectory: true)

        let storeURL = baseDirectory.appendingPathComponent("default.store")
        DebugLogger.shared.log("SwiftData store URL: \(storeURL.path)", level: .info, source: "QuillApp")

        do {
            try FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        } catch {
            fatalError("Failed to prepare Application Support directory: \(error)")
        }

        do {
            let configuration = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Load custom fonts on app launch
        FontLoader.shared.loadFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        #endif
        .modelContainer(sharedModelContainer)
        .commands {
            // Replace the default Settings command in the app menu
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    // Post notification to open settings
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        #if os(macOS)
        Window("New Post", id: "compose") {
            ComposeWindow()
                .modelContainer(sharedModelContainer)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 300)
        #endif
    }
}
