/// ConnectionView.swift
/// BLE scanning + Wi-Fi provisioning UI, with an optional Direct Connect
/// bypass for development and ethernet-connected setups.
///
/// Guides the user through:
///   1. BLE mode: Enter Wi-Fi credentials → scan → provision Pi.
///   2. Direct Connect mode: Enter Pi IP/hostname directly → verify API → proceed.

import SwiftUI

/// Selects which connection path the user wants.
private enum ConnectionMode: String, CaseIterable {
    case bluetooth = "Bluetooth"
    case direct = "Direct IP"

    var icon: String {
        switch self {
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .direct:    return "network"
        }
    }
}

struct ConnectionView: View {
    // @StateObject private var bleViewModel  = ConnectionViewModel()
    @StateObject private var directViewModel = DirectConnectViewModel()
    @EnvironmentObject private var router: AppRouter

    @State private var mode: ConnectionMode = .direct   // default to Direct for dev convenience

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Theme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    // Logo only
                    if let uiImage = UIImage(contentsOfFile: "/Users/gokhankocmarli/Projects/opendihm/opendihm-branding/logos/opendihm-horizontal.jpeg") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                            .padding(.top, 40)
                    } else {
                        Image(systemName: "microscope")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.primary)
                            .padding(.top, 40)
                    }

                    // Mode picker - closer to the panel
                    Picker("Connection Mode", selection: $mode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { m in
                            Label(m.rawValue, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 400)
                    .tint(Theme.secondary)

                    // Panel for selected mode - Wider and simpler for Landscape
                    Group {
                        switch mode {
                        case .bluetooth:
                            VStack(spacing: 8) {
                                Image(systemName: "bluetooth")
                                    .font(.title2)
                                    .foregroundStyle(Theme.secondary)
                                Text("Bluetooth Provisioning")
                                    .font(Theme.Typography.heading(size: 14))
                                Text("Scanning for nearby devices...")
                                    .font(Theme.Typography.body(size: 11))
                                    .foregroundStyle(Theme.neutral)
                            }
                        case .direct:
                            DirectConnectPanel(viewModel: directViewModel)
                        }
                    }
                    .padding(32)
                    .frame(maxWidth: 500)
                    .background(Color.white.opacity(0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.spring(), value: mode)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $directViewModel.lastMessageIsError, actions: {
                Button("OK", role: .cancel) { directViewModel.clearMessage() }
            }, message: {
                if !directViewModel.statusMessage.isEmpty {
                    Text(directViewModel.statusMessage)
                }
            })
            /*
            .onChange(of: bleViewModel.isProvisioned) {
                if bleViewModel.isProvisioned {
                    router.didConnect(host: bleViewModel.resolvedHost)
                }
            }
            */
            .onChange(of: directViewModel.isConnected) {
                if directViewModel.isConnected {
                    router.didConnect(host: directViewModel.host)
                }
            }
        }
    }
}

// MARK: - BLE Panel

private struct BLEConnectionPanel: View {
    @ObservedObject var viewModel: ConnectionViewModel

    var body: some View {
        VStack(spacing: 16) {
            GlassTextField(
                placeholder: "Wi-Fi Network Name (SSID)",
                text: $viewModel.ssid,
                icon: "wifi"
            )
            GlassTextField(
                placeholder: "Wi-Fi Password",
                text: $viewModel.password,
                icon: "lock",
                isSecure: true
            )

            if !viewModel.statusMessage.isEmpty {
                statusText(viewModel.statusMessage, isError: viewModel.isError)
            }

            actionButton(
                title: "Connect via Bluetooth",
                icon: "dot.radiowaves.left.and.right",
                isLoading: viewModel.isConnecting,
                disabled: viewModel.ssid.isEmpty || viewModel.password.isEmpty
            ) {
                viewModel.connect()
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Direct Connect Panel

private struct DirectConnectPanel: View {
    @ObservedObject var viewModel: DirectConnectViewModel

    var body: some View {
        VStack(spacing: 16) {
            GlassTextField(
                placeholder: "IP or hostname",
                text: $viewModel.host,
                icon: "network"
            )

            actionButton(
                title: "Connect Directly",
                icon: "arrow.right.circle.fill",
                isLoading: viewModel.isConnecting,
                disabled: viewModel.host.isEmpty
            ) {
                Task { await viewModel.connect() }
            }
        }
    }
}
// MARK: - Shared helper views

/// Compact status text used by both panels.
@MainActor
private func statusText(_ message: String, isError: Bool) -> some View {
    Text(message)
        .font(.footnote)
        .foregroundStyle(isError ? .red : .white.opacity(0.8))
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
}

/// Shared connect button with loading state.
@MainActor
private func actionButton(
    title: String,
    icon: String,
    isLoading: Bool,
    disabled: Bool,
    action: @escaping () -> Void
) -> some View {
    Group {
        if isLoading {
            ProgressView()
                .tint(Theme.secondary)
                .scaleEffect(1.2)
                .padding(.vertical, 16)
        } else {
            Button(action: action) {
                Label(title, systemImage: icon)
                    .font(Theme.Typography.heading(size: 16))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(disabled ? Theme.neutral.opacity(0.1) : Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .disabled(disabled)
        }
    }
}

// MARK: - Reusable Glassmorphism TextField

private struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.neutral.opacity(0.4)))
                    .foregroundStyle(Theme.primary)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.neutral.opacity(0.4)))
                    .foregroundStyle(Theme.primary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.neutral.opacity(0.1), lineWidth: 1)
        )
    }
}
