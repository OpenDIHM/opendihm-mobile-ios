/// AppRouter.swift
/// Central navigation state for the OpenDIHM app.
///
/// Drives the root view between the BLE connection/onboarding flow
/// and the main microscope control screen.

import SwiftUI

/// Represents the high-level screen states of the application.
enum AppScreen {
    /// Initial greeting screen
    case welcome
    /// BLE pairing and Wi-Fi provisioning screen.
    case connection
    /// Direct IP address entry screen (when microscope is already connected).
    case directConnect
    /// Main microscope control screen (shown after successful pairing).
    case control
}

/// Observable router that drives top-level navigation.
@MainActor
final class AppRouter: ObservableObject {
    /// The currently presented top-level screen.
    @Published var currentScreen: AppScreen = .welcome
    
    /// Advance past the welcome screen to setup
    func beginSetup() {
        currentScreen = .connection
    }

    /// Called when BLE provisioning completes and the Pi has joined Wi-Fi.
    /// - Parameter host: IP address of the Pi on the local network.
    func didConnect(host: String) {
        MicroscopeConfig.shared.host = host
        currentScreen = .control
    }

    /// Resets the app back to the onboarding/connection screen.
    func disconnect() {
        currentScreen = .welcome
    }
}
