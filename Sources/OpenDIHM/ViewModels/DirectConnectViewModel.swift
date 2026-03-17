/// DirectConnectViewModel.swift
/// ViewModel for the Direct Connect mode — lets the user skip BLE entirely
/// and connect to the Pi directly by entering its IP address or hostname.
///
/// Useful when the Pi is on the same network via Ethernet or already on Wi-Fi,
/// so BLE provisioning is not needed.

import Foundation

@MainActor
final class DirectConnectViewModel: ObservableObject {
    // MARK: - Input

    /// Host entered by the user (IP address or mDNS hostname like `localserver.local`).
    @Published var host: String = ""

    // MARK: - Output State

    @Published var lastMessageIsError: Bool = false
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var isConnected: Bool = false

    // MARK: - Dependencies

    private let apiClient = MicroscopeAPIClient()

    // MARK: - Public API

    /// Validates the entered host by hitting the `GET /` health endpoint.
    /// On success, populates `MicroscopeConfig` and sets `isConnected = true`.
    func connect() async {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isConnecting = true
        lastMessageIsError = false
        statusMessage = "Connecting to \(trimmed)..."

        MicroscopeConfig.shared.host = trimmed

        do {
            let status = try await apiClient.getServerStatus()
            statusMessage = "✓ Connected — \(status.microscope) is \(status.status)"
            isConnected = true
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            lastMessageIsError = true
            MicroscopeConfig.shared.host = ""
        }

        isConnecting = false
    }

    /// Resets the error status and message.
    func clearMessage() {
        statusMessage = ""
        lastMessageIsError = false
    }
}
