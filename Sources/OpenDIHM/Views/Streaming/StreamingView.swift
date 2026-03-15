/// StreamingView.swift
/// Displays the live H.264 TCP stream from libcamera-vid.
///
/// Since AVPlayer natively handles HLS and RTSP but not a raw TCP H.264 stream,
/// this view uses AVSampleBufferDisplayLayer fed by a custom TCP reader
/// that wraps the raw Annex-B H.264 stream into CMSampleBuffers.
///
/// This is the same approach used by professional broadcast apps on iOS.

import AVFoundation
import SwiftUI
import UIKit

/// SwiftUI wrapper for the streaming display.
struct StreamingView: View {
    let host: String
    let port: Int

    @StateObject private var viewModel: StreamingViewModel

    init(host: String, port: Int) {
        self.host = host
        self.port = port
        _viewModel = StateObject(wrappedValue: StreamingViewModel(host: host, port: port))
    }

    var body: some View {
        ZStack {
            Color.black

            if viewModel.isConnected {
                StreamDisplayView(displayLayer: viewModel.displayLayer)
            } else {
                VStack(spacing: 12) {
                    if viewModel.isConnecting {
                        ProgressView()
                            .tint(.white)
                        Text("Connecting to preview stream...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Image(systemName: "video.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("Preview not available")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                        Button("Start Preview") {
                            Task { await viewModel.startPreview() }
                        }
                        .buttonStyle(.bordered)
                        .tint(.teal)
                    }
                }
            }
        }
        .task { await viewModel.startPreview() }
        .onDisappear { Task { await viewModel.stopPreview() } }
    }
}

// MARK: - UIKit Layer Bridge

/// `UIViewRepresentable` that hosts an `AVSampleBufferDisplayLayer`.
private struct StreamDisplayView: UIViewRepresentable {
    let displayLayer: AVSampleBufferDisplayLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.addSublayer(displayLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        displayLayer.frame = uiView.bounds
    }
}
