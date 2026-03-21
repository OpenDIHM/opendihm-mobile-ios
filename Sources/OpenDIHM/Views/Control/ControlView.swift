/// ControlView.swift
/// Main microscope control screen shown after successful BLE provisioning.

import SwiftUI

struct ControlView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ControlViewModel()

    @State private var isInfoPaneExpanded: Bool = true

    var body: some View {
        ZStack {
            // Base background ensures no white gaps during transitions
            Theme.background.ignoresSafeArea()

            HStack(spacing: 0) {
                // Left Column: Navigation & Controls
                VStack(spacing: 24) {
                    brandingHeader
                    
                    Spacer()
                    
                    zLevelMenu
                    
                    CaptureButton(
                        isCapturing: viewModel.isCapturing,
                        action: { Task { await viewModel.capture() } }
                    )
                    
                    Spacer()
                    
                    disconnectButton
                }
                .padding(.vertical, 32)
                .frame(width: 65)
                .background(Theme.primary.ignoresSafeArea(edges: .vertical))
                .foregroundStyle(.white)

                // Center Column: Live Video Feed
                StreamingView(host: MicroscopeConfig.shared.host,
                              port: MicroscopeConfig.shared.streamPort)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)

                // Right Column: Information Panel
                VStack(spacing: 16) {
                    toggleInfoButton
                    
                    if isInfoPaneExpanded {
                        StatusPanel(status: viewModel.systemStatus)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        CompactStatusPanel()
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 32)
                .padding(.horizontal, isInfoPaneExpanded ? 12 : 8)
                .frame(width: isInfoPaneExpanded ? 150 : 65)
                .background(Theme.background.ignoresSafeArea(edges: .vertical))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isInfoPaneExpanded)
            }
        }
        .ignoresSafeArea()
        .navigationBarHidden(true)
        .onAppear {
            viewModel.startStatusPolling()
        }
        .onDisappear {
            viewModel.stopStatusPolling()
        }
        .alert("Error", isPresented: $viewModel.lastMessageIsError, actions: {
            Button("OK", role: .cancel) { viewModel.clearMessage() }
        }, message: {
            if let message = viewModel.lastMessage {
                Text(message)
            }
        })
    }

    private var brandingHeader: some View {
        Image("LogoVertical")
            .resizable()
            .scaledToFit()
            .frame(width: 44, height: 44)
            .padding(.top, 8)
    }

    private var zLevelMenu: some View {
        Menu {
            Button("5x (5μm)") { viewModel.selectedZ = 5.0 }
            Button("15x (15μm)") { viewModel.selectedZ = 15.0 }
            Button("30x (30μm)") { viewModel.selectedZ = 30.0 }
        } label: {
            zLevelLabel
        }
    }

    private var zLevelLabel: some View {
        HStack(spacing: 1) {
            Text("\(Int(viewModel.selectedZ))")
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

    private var toggleInfoButton: some View {
        Button(action: { isInfoPaneExpanded.toggle() }) {
            Image(systemName: isInfoPaneExpanded ? "xmark.circle" : "info.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.primary)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.6))
                .clipShape(Circle())
        }
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
            StatusItem(icon: "thermometer.medium", label: "Pi Temp", value: status.map { String(format: "%.1f°C", $0.temperatureC) } ?? "--", color: .orange)
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
