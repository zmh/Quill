//
//  QuillApp.swift
//  Quill
//
//  Created by Zachary Hamed on 5/31/25.
//

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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

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
    }
}
