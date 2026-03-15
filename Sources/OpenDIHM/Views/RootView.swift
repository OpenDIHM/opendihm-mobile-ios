/// RootView.swift
/// Top-level router view that switches between the connection and control screens.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch router.currentScreen {
        case .connection:
            ConnectionView()
        case .control:
            ControlView()
        }
    }
}
