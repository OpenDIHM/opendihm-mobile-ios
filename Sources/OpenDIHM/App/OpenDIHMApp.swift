/// OpenDIHMApp.swift
/// Application entry point for the OpenDIHM iOS client.

import SwiftUI

@main
struct OpenDIHMApp: App {
    @StateObject private var appRouter = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appRouter)
        }
    }
}
