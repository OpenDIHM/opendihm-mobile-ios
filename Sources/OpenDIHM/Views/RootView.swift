/// RootView.swift
/// Top-level router view that switches between the connection and control screens.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            switch router.currentScreen {
            case .welcome:
                WelcomeView()
                    .onAppear {
                        AppDelegate.lockOrientation(.portrait, andRotateTo: .portrait)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .connection:
                ConnectionView()
                    .onAppear {
                        AppDelegate.lockOrientation(.portrait, andRotateTo: .portrait)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .control:
                ControlView()
                    .onAppear {
                        AppDelegate.lockOrientation(.landscapeRight, andRotateTo: .landscapeRight)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.4), value: router.currentScreen)
    }
}
