//
//  AppUpdater.swift
//  Quill
//
//  Handles automatic updates via Sparkle framework
//

#if os(macOS)
import Foundation
import Sparkle

/// Manages automatic app updates using Sparkle
@MainActor
final class AppUpdater: ObservableObject {
    /// Shared instance for app-wide update management
    static let shared = AppUpdater()

    /// The Sparkle updater controller
    private let updaterController: SPUStandardUpdaterController

    /// Whether updates can be checked (Sparkle available)
    var canCheckForUpdates: Bool {
        return true
    }

    private init() {
        // Initialize Sparkle with automatic update checks
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// Check for updates manually
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#endif
