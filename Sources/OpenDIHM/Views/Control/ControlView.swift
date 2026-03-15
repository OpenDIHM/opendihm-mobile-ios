/// ControlView.swift
/// Main microscope control screen shown after successful BLE provisioning.

import SwiftUI

struct ControlView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ControlViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.6, saturation: 0.05, brightness: 0.07)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Live preview panel
                    StreamingView(host: MicroscopeConfig.shared.host,
                                  port: MicroscopeConfig.shared.streamPort)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Controls panel
                    ScrollView {
                        VStack(spacing: 20) {
                            // Z-distance picker
                            ZDistancePicker(selectedZ: $viewModel.selectedZ)

                            // Capture button
                            CaptureButton(
                                isCapturing: viewModel.isCapturing,
                                action: { Task { await viewModel.capture() } }
                            )

                            // Status / error banner
                            if let message = viewModel.lastMessage {
                                StatusBanner(message: message, isError: viewModel.lastMessageIsError)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("OpenDIHM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Disconnect", role: .destructive) {
                        router.disconnect()
                    }
                    .font(.footnote)
                }
            }
        }
    }
}

// MARK: - Sub-components

private struct ZDistancePicker: View {
    @Binding var selectedZ: Double

    private let configurations: [(label: String, z: Double)] = [
        ("5× — Tissue sections", 5.0),
        ("15× — Single cells",  15.0),
        ("30× — Sub-cellular",  30.0),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Magnification (Z-distance)")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(configurations, id: \.label) { config in
                Button(action: { selectedZ = config.z }) {
                    HStack {
                        Text(config.label)
                            .foregroundStyle(.white)
                        Spacer()
                        if selectedZ == config.z {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(selectedZ == config.z ? Color.teal.opacity(0.15) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedZ == config.z ? Color.teal.opacity(0.5) : Color.white.opacity(0.08),
                                    lineWidth: 1)
                    )
                }
            }
        }
    }
}

private struct CaptureButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if isCapturing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Label("Capture RAW Hologram", systemImage: "camera.aperture")
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isCapturing ? Color.gray : Color.teal)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .disabled(isCapturing)
        .animation(.easeInOut(duration: 0.2), value: isCapturing)
    }
}

private struct StatusBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(message)
                .font(.footnote)
        }
        .foregroundStyle(isError ? .red : .green)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.red : Color.green).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
