/// ControlViewModel.swift
/// Business logic for the microscope control screen.

import Foundation

@MainActor
final class ControlViewModel: ObservableObject {
    // MARK: - Input

    /// Currently selected Z-distance configuration (controls magnification).
    @Published var selectedZ: Double = 5.0

    // MARK: - Output State

    @Published private(set) var isCapturing: Bool = false
    @Published private(set) var lastMessage: String?
    @Published var lastMessageIsError: Bool = false

    /// Real-time metrics fetched from the firmware API
    @Published var systemStatus: SystemStatusResponse?

    /// Last successfully captured DNG data — consumers can observe this
    /// to trigger file saving, reconstruction pipeline, etc.
    @Published private(set) var capturedDNGData: Data?

    // MARK: - Dependencies

    private let apiClient = MicroscopeAPIClient()
    private var pollingTask: Task<Void, Never>?

    // MARK: - Public API

    /// Triggers a RAW DNG capture on the Pi and stores the result.
    func capture() async {
        isCapturing = true
        lastMessage = nil
        defer { isCapturing = false }

        do {
            let data = try await apiClient.captureHologram(zMetadata: selectedZ)
            capturedDNGData = data
            lastMessageIsError = false
            lastMessage = "Captured \(data.count / 1024) KB of RAW data"
        } catch {
            lastMessageIsError = true
            lastMessage = error.localizedDescription
        }
    }

    /// Resets the last status message and error state.
    func clearMessage() {
        lastMessage = nil
        lastMessageIsError = false
    }

    /// Spawns a background task to constantly poll the hardware for live telemetry.
    func startStatusPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                do {
                    let status = try await apiClient.getSystemStatus()
                    print("OpenDIHM Polling Status: \(status)")
                    self.systemStatus = status
                } catch {
                    print("OpenDIHM Polling Error: \(error)")
                }
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }

    /// Terminates the background polling task.
    func stopStatusPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
