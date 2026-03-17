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

    /// Last successfully captured DNG data — consumers can observe this
    /// to trigger file saving, reconstruction pipeline, etc.
    @Published private(set) var capturedDNGData: Data?

    // MARK: - Dependencies

    private let apiClient = MicroscopeAPIClient()

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
}
