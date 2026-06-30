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
            guard let self = self else { return }
            if self.displayLayer.isReadyForMoreMediaData {
                self.displayLayer.enqueue(sampleBuffer)
            } else if self.displayLayer.status == .failed {
                print("Display Layer FAILED: \(String(describing: self.displayLayer.error))")
            }
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
        
        // Force IPv4 if we are seeing IPv6 connection issues on the Pi
        if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }
        
        let newConnection = NWConnection(to: endpoint, using: params)
        connection = newConnection

        newConnection.stateUpdateHandler = { [weak self] state in
            print("NWConnection State: \(state)")
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    print("TCP Stream Ready")
                    self.isConnecting = false
                    self.isConnected = true
                   self.receiveData()
                case .failed(let error):
                    print("TCP Stream Failed: \(error)")
                    self.isConnected = false
                    self.isConnecting = false
                case .cancelled:
                    self.isConnected = false
                    self.isConnecting = false
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
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            
            if let error = error {
                print("TCP Stream Receive Error: \(error)")
            }

            if let data, !data.isEmpty {
                Task { @MainActor in
                    self.parser.process(data: data)
                    
                    // Periodically check layer status
                    if self.displayLayer.status == .failed {
                        print("Display Layer FAILED: \(String(describing: self.displayLayer.error))")
                    }
                }
            }
            if !isComplete && error == nil {
                Task { @MainActor in self.receiveData() }
            } else {
                print("TCP Stream Closed (Complete: \(isComplete))")
                Task { @MainActor in self.isConnected = false }
            }
        }
    }
}
