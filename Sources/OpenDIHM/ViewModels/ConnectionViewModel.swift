/// ConnectionViewModel.swift
/// Business logic and state for the BLE onboarding flow.

import Foundation
import Combine

@MainActor
final class ConnectionViewModel: ObservableObject {
    // MARK: - Input Bindings

    @Published var ssid: String = ""
    @Published var password: String = ""

    // MARK: - Output State

    @Published private(set) var statusMessage: String = ""
    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var isProvisioned: Bool = false
    @Published private(set) var isError: Bool = false

    /// IP of the Pi resolved after successful provisioning.
    /// Currently derived from the BLE status message; a more robust
    /// implementation would use mDNS (Bonjour) discovery post-connection.
    private(set) var resolvedHost: String = ""

    // MARK: - Dependencies

    private let bleManager = BLEManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        bindBLEManager()
    }

    // MARK: - Public API

    /// Kick off the BLE scan and credential provisioning flow.
    func connect() {
        isConnecting = true
        isError = false
        statusMessage = "Scanning for OpenDIHM..."
        bleManager.startScanning()
        bleManager.provisionWiFi(ssid: ssid, password: password)
    }

    // MARK: - Private

    private func bindBLEManager() {
        bleManager.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .idle:
                    isConnecting = false
                case .scanning:
                    statusMessage = "Scanning for OpenDIHM device..."
                case .connecting:
                    statusMessage = "Found it! Connecting..."
                case .connected:
                    statusMessage = "Connected. Sending Wi-Fi credentials..."
                case .sendingCredentials:
                    statusMessage = "Sending credentials..."
                case .waitingForWiFi:
                    statusMessage = bleManager.statusMessage
                case .provisioned:
                    statusMessage = "✓ Connected to Wi-Fi!"
                    isConnecting = false
                    isProvisioned = true
                    // TODO: Replace with mDNS resolution when implemented
                    resolvedHost = "opendihm.local"
                case .failed(let reason):
                    statusMessage = reason
                    isError = true
                    isConnecting = false
                }
            }
            .store(in: &cancellables)

        bleManager.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] message in
                guard let self, !message.isEmpty else { return }
                if case .waitingForWiFi = bleManager.state {
                    statusMessage = message
                }
            }
            .store(in: &cancellables)
    }
}
