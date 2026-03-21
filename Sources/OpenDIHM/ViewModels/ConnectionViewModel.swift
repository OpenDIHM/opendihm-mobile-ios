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

    /// Progress steps for the pairing UI
    @Published private(set) var currentStep: Int = 0
    let totalSteps: Int = 4

    /// IP of the Pi resolved after successful provisioning.
    /// Defaulting to opendihm.local per user requirement.
    private(set) var resolvedHost: String = "opendihm.local"

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
                    currentStep = 0
                case .scanning:
                    statusMessage = "Scanning for OpenDIHM device..."
                    currentStep = 1
                case .connecting:
                    statusMessage = "Found it! Connecting..."
                    currentStep = 2
                case .connected:
                    statusMessage = "Connected. Sending Wi-Fi credentials..."
                    currentStep = 2
                case .sendingCredentials:
                    statusMessage = "Sending credentials..."
                    currentStep = 3
                case .waitingForWiFi:
                    statusMessage = bleManager.statusMessage
                    currentStep = 3
                case .provisioned:
                    statusMessage = "✓ Connected to Wi-Fi!"
                    isConnecting = false
                    isProvisioned = true
                    currentStep = 4
                    resolvedHost = "opendihm.local"
                case .failed(let reason):
                    statusMessage = reason
                    isError = true
                    isConnecting = false
                    currentStep = 0
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
