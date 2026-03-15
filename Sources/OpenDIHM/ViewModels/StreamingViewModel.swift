/// StreamingViewModel.swift
/// Manages lifecycle of the Pi preview stream and feeds data to AVSampleBufferDisplayLayer.

import AVFoundation
import Foundation
import Network

@MainActor
final class StreamingViewModel: ObservableObject {
    // MARK: - Output State

    @Published private(set) var isConnecting: Bool = false
    @Published private(set) var isConnected: Bool = false

    /// The display layer that receives decoded frames.
    let displayLayer = AVSampleBufferDisplayLayer()

    // MARK: - Private

    private let host: String
    private let port: Int
    private let apiClient = MicroscopeAPIClient()

    /// Network framework TCP connection to the raw H.264 stream.
    private var connection: NWConnection?

    /// Low-latency H.264 Annex-B parser.
    private let parser = H264StreamParser()

    init(host: String, port: Int) {
        self.host = host
        self.port = port
        displayLayer.videoGravity = .resizeAspect

        // Wire the parser to the hardware display layer
        parser.onFrameReady = { [weak self] sampleBuffer in
            self?.displayLayer.enqueue(sampleBuffer)
        }
    }

    // MARK: - Public API

    /// Asks the firmware to start streaming, then connects to the TCP port.
    func startPreview() async {
        isConnecting = true
        do {
            _ = try await apiClient.startPreview()
            connectTCPStream()
        } catch {
            isConnecting = false
        }
    }

    /// Stops the TCP connection and tells the firmware to stop streaming.
    func stopPreview() async {
        connection?.cancel()
        connection = nil
        isConnected = false
        _ = try? await apiClient.stopPreview()
    }

    // MARK: - TCP Stream

    private func connectTCPStream() {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        let params = NWParameters.tcp
        let newConnection = NWConnection(to: endpoint, using: params)
        connection = newConnection

        newConnection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    isConnecting = false
                    isConnected = true
                    receiveData()
                case .failed, .cancelled:
                    isConnected = false
                    isConnecting = false
                default:
                    break
                }
            }
        }
        newConnection.start(queue: .global(qos: .userInteractive))
    }

    /// Recursively reads Annex-B H.264 data from the TCP connection and
    /// forwards it to the H264StreamParser.
    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 128) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                // Pass the raw chunk of bytes to our parser.
                // It will find NALU boundaries and call onFrameReady.
                Task { @MainActor in
                    self.parser.process(data: data)
                }
            }
            if !isComplete && error == nil {
                self.receiveData()
            } else {
                Task { @MainActor in self.isConnected = false }
            }
        }
    }
}
