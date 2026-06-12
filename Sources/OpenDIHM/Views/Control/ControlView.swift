/// ControlView.swift
/// Main microscope control screen shown after successful BLE provisioning.

import SwiftUI

struct ControlView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var controlVM = ControlViewModel()
    @StateObject private var streamVM: StreamingViewModel
    @StateObject private var captureManager = CaptureManager()
    @State private var showCaptures = false

    init() {
        let config = MicroscopeConfig.shared
        _streamVM = StateObject(wrappedValue: StreamingViewModel(host: config.host, port: config.streamPort))
    }

    var body: some View {
        ZStack {
            // Base background ensures no white gaps during transitions
            Theme.background.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left Column: Navigation
                VStack(spacing: 12) {
                    brandingHeader

                    Spacer()

                    capturesButton

                    Spacer().frame(height: 8)

                    disconnectButton
                }
                .padding(.vertical, 24)
                .safeAreaPadding(.leading) 
                .frame(width: 70)
                .background(Theme.primary.ignoresSafeArea())
                .foregroundStyle(.white)

                // Center Column: Live Video Feed
                StreamingView(viewModel: streamVM)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Right Column: Information Panel
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        StatusPanel(status: controlVM.systemStatus)
                        Divider().background(Color.white.opacity(0.3))
                        HStack(spacing: 16) {
                            zLevelMenu
                            CaptureButton(
                                isCapturing: controlVM.isCapturing,
                                action: { Task { await didTapCapture() } }
                            )
                        }
                    }
            }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .safeAreaPadding(.trailing)
                .frame(width: 220)
                .background(Theme.background.ignoresSafeArea())
            }
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .onAppear {
            controlVM.startStatusPolling()
        }
        .onDisappear {
            controlVM.stopStatusPolling()
        }
        .alert("Error", isPresented: $controlVM.lastMessageIsError, actions: {
            Button("OK", role: .cancel) { controlVM.clearMessage() }
        }, message: {
            if let message = controlVM.lastMessage {
                Text(message)
            }
        })
        .sheet(isPresented: $showCaptures) {
            CapturesListView()
        }
    }

    private func didTapCapture() async {
        await controlVM.capture()
        if let data = controlVM.capturedDNGData {
            _ = try? captureManager.saveCapture(
                data: data,
                zMetadata: controlVM.selectedZ,
                systemStatus: controlVM.systemStatus
            )
        }
        await streamVM.stopPreview()
        await streamVM.startPreview()
    }

    private var brandingHeader: some View {
        Image("LogoSymbol")
            .resizable()
            .scaledToFit()
            .frame(width: 38, height: 38)
            .padding(.top, 8)
    }

    private var capturesButton: some View {
        Button(action: { showCaptures = true }) {
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                Text("Captures")
                    .font(Theme.Typography.mono(size: 8))
            }
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var zLevelMenu: some View {
        Menu {
            Button("5x (5μm)") { controlVM.selectedZ = 5.0 }
            Button("15x (15μm)") { controlVM.selectedZ = 15.0 }
            Button("30x (30μm)") { controlVM.selectedZ = 30.0 }
        } label: {
            zLevelLabel
        }
    }

    private var zLevelLabel: some View {
        HStack(spacing: 1) {
            Text("\(Int(controlVM.selectedZ))")
                .font(Theme.Typography.heading(size: 18))
            Text("x")
                .font(Theme.Typography.mono(size: 12))
                .baselineOffset(4)
                .opacity(0.8)
        }
        .frame(width: 50, height: 44)
        .background(Theme.secondary.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.secondary.opacity(0.4), lineWidth: 1)
        )
    }

    private var disconnectButton: some View {
        Button(action: { router.disconnect() }) {
            Image(systemName: "power")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

// MARK: - Sub-components

private struct StatusPanel: View {
    let status: SystemStatusResponse?

    var body: some View {
        VStack(spacing: 12) {
            StatusItem(icon: "thermometer.medium", label: "Temperature", value: status.map { String(format: "%.1f°C", $0.temperatureC) } ?? "--", color: .orange)
            StatusItem(icon: "antenna.radiowaves.left.and.right", label: "Signal", value: status.map { String(format: "%.0f dBm", $0.wifiSignalDbm) } ?? "--", color: Theme.secondary)
            StatusItem(icon: "bolt.fill", label: "Laser", value: status?.laserOn == true ? "ON" : "OFF", color: .red)
            StatusItem(icon: "stopwatch", label: "Exposure", value: status.map { "\($0.exposureTimeUs / 1000)ms" } ?? "--", color: .green)
            StatusItem(icon: "memorychip", label: "RAM", value: status?.memoryLeftFormatted ?? "--", color: .purple)
            StatusItem(icon: "sdcard", label: "Storage", value: status?.storageLeftFormatted ?? "--", color: Theme.neutral)
        }
        .padding(10)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct CompactStatusPanel: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "thermometer.medium").foregroundStyle(.orange)
            Image(systemName: "antenna.radiowaves.left.and.right").foregroundStyle(Theme.secondary)
            Image(systemName: "bolt.fill").foregroundStyle(.red)
            Image(systemName: "stopwatch").foregroundStyle(.green)
            Image(systemName: "memorychip").foregroundStyle(.purple)
            Image(systemName: "sdcard").foregroundStyle(Theme.neutral)
        }
        .font(.system(size: 16))
        .frame(width: 44)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

private struct StatusItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.neutral)
                Text(value)
                    .font(Theme.Typography.mono(size: 11))
                    .bold()
                    .foregroundStyle(Theme.neutral)
            }
            Spacer()
        }
    }
}

private struct CaptureButton: View {
    let isCapturing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isCapturing ? Theme.neutral : Theme.secondary)
                    .frame(width: 44, height: 44)
                
                if isCapturing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "camera.aperture")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
            }
            .shadow(color: Theme.secondary.opacity(0.3), radius: 5, x: 0, y: 3)
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
                .font(.caption2)
        }
        .foregroundStyle(isError ? .red : .green)
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.red : Color.green).opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
