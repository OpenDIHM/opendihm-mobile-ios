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
        case .bluetooth: return "dot.radiowaves.left.andright"
        case .direct:    return "network"
        }
    }
}

struct ConnectionView: View {
    @StateObject private var bleViewModel  = ConnectionViewModel()
    @StateObject private var directViewModel = DirectConnectViewModel()
    @EnvironmentObject private var router: AppRouter

    @State private var mode: ConnectionMode = .direct   // default to Direct for dev convenience

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.15),
                             Color(hue: 0.58, saturation: 0.6, brightness: 0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Title
                    VStack(spacing: 8) {
                        Image(systemName: "microscope")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("OpenDIHM")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Connect your microscope")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.top, 48)

                    // Mode picker
                    Picker("Connection Mode", selection: $mode) {
                        ForEach(ConnectionMode.allCases, id: \.self) { m in
                            Label(m.rawValue, systemImage: m.icon).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    // Panel for selected mode
                    Group {
                        switch mode {
                        case .bluetooth:
                            BLEConnectionPanel(viewModel: bleViewModel)
                        case .direct:
                            DirectConnectPanel(viewModel: directViewModel)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .animation(.easeInOut(duration: 0.25), value: mode)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .onChange(of: bleViewModel.isProvisioned) {
                if bleViewModel.isProvisioned {
                    router.didConnect(host: bleViewModel.resolvedHost)
                }
            }
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
                icon: "dot.radiowaves.left.andright",
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
                placeholder: "Pi IP or hostname (e.g. 192.168.178.31)",
                text: $viewModel.host,
                icon: "network"
            )

            if !viewModel.statusMessage.isEmpty {
                statusText(viewModel.statusMessage, isError: viewModel.isError)
            }

            actionButton(
                title: "Connect Directly",
                icon: "arrow.right.circle.fill",
                isLoading: viewModel.isConnecting,
                disabled: viewModel.host.isEmpty
            ) {
                Task { await viewModel.connect() }
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Shared helper views

/// Compact status text used by both panels.
private func statusText(_ message: String, isError: Bool) -> some View {
    Text(message)
        .font(.footnote)
        .foregroundStyle(isError ? .red : .white.opacity(0.8))
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
}

/// Shared connect button with loading state.
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
                .tint(.white)
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        } else {
            Button(action: action) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
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
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                    .foregroundStyle(.white)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.5)))
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(16)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
    }
}
