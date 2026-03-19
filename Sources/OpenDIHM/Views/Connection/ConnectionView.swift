/// ConnectionView.swift
/// BLE scanning + Wi-Fi provisioning UI with an introduction-like sequence.
/// Guides the user through:
///   1. Wi-Fi credentials entry
///   2. Bluetooth connection progress
///   3. Success & automatic transition

import SwiftUI

struct ConnectionView: View {
    @StateObject private var viewModel = ConnectionViewModel()
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header (Skip button is removed from here)
                Spacer() // This pushes everything down comfortably
                
                VStack(spacing: 20) {
                    // Logo
                    if let uiImage = UIImage(contentsOfFile: "/Users/gokhankocmarli/Projects/opendihm/opendihm-branding/logos/opendihm-horizontal.jpeg") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 50)
                            .padding(.top, 10)
                    } else {
                        Image(systemName: "microscope")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.primary)
                            .padding(.top, 10)
                    }
                    
                    Text("Device Setup")
                        .font(Theme.Typography.heading(size: 24))
                        .foregroundStyle(Theme.primary)
                        .padding(.bottom, 10)
                    
                    // Main Setup Panel
                    VStack(spacing: 24) {
                        if viewModel.currentStep == 0 {
                            // Step 0: Entry
                            VStack(spacing: 16) {
                                Text("Connect to Wi-Fi")
                                    .font(Theme.Typography.heading(size: 18))
                                    .foregroundStyle(Theme.primary)
                                    .padding(.top, 10)
                                
                                Text("Enter your Wi-Fi details so the microscope can join your network.")
                                    .font(Theme.Typography.body(size: 14))
                                    .foregroundStyle(Theme.neutral)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)
                                
                                GlassTextField(
                                    placeholder: "Wi-Fi Network Name",
                                    text: $viewModel.ssid,
                                    icon: "wifi"
                                )
                                GlassTextField(
                                    placeholder: "Wi-Fi Password",
                                    text: $viewModel.password,
                                    icon: "lock",
                                    isSecure: true
                                )
                                
                                if !viewModel.statusMessage.isEmpty {
                                    statusText(viewModel.statusMessage, isError: viewModel.isError)
                                }
                                
                                actionButton(
                                    title: "Continue",
                                    icon: "arrow.right.circle.fill",
                                    isLoading: viewModel.isConnecting,
                                    disabled: viewModel.ssid.isEmpty || viewModel.password.isEmpty
                                ) {
                                    withAnimation {
                                        viewModel.connect()
                                    }
                                }
                                
                                // Skip Bluetooth moved beneath
                                Button(action: {
                                    router.didConnect(host: "opendihm")
                                }) {
                                    Text("Skip Bluetooth")
                                        .font(Theme.Typography.heading(size: 16))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Theme.background) // match native background
                                        .foregroundStyle(Theme.primary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.primary, lineWidth: 1.5)
                                        )
                                }
                                .padding(.top, 4)
                            }
                        } else {
                            // Progress Steps (1-4)
                            VStack(spacing: 30) {
                                ZStack {
                                    Circle()
                                        .stroke(Theme.secondary.opacity(0.2), lineWidth: 8)
                                        .frame(width: 120, height: 120)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(viewModel.currentStep) / CGFloat(viewModel.totalSteps))
                                        .stroke(Theme.secondary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.currentStep)
                                        
                                    Image(systemName: stepIcon(for: viewModel.currentStep))
                                        .font(.system(size: 40))
                                        .foregroundStyle(Theme.primary)
                                        .contentTransition(.symbolEffect(.replace))
                                }
                                
                                VStack(spacing: 8) {
                                    Text(viewModel.statusMessage)
                                        .font(Theme.Typography.heading(size: 16))
                                        .foregroundStyle(Theme.primary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                    
                                    if viewModel.isError {
                                        Button("Try Again") {
                                            viewModel.connect()
                                        }
                                        .font(Theme.Typography.body(size: 14))
                                        .foregroundStyle(.blue)
                                        .padding(.top, 10)
                                        
                                        Button(action: {
                                            router.didConnect(host: "opendihm")
                                        }) {
                                            Text("Skip Bluetooth")
                                                .font(Theme.Typography.heading(size: 16))
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(Theme.background) // match native background
                                                .foregroundStyle(Theme.primary)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Theme.primary, lineWidth: 1.5)
                                                )
                                        }
                                        .padding(.horizontal, 30)
                                        .padding(.top, 8)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .padding(.horizontal, 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.currentStep)
                    
                    Spacer().frame(height: 40)
                    
                    // Progress Bar at bottom
                    ContinuousProgressBar(currentStep: viewModel.currentStep, totalSteps: viewModel.totalSteps)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 60)
                }
            }
        }
        .onChange(of: viewModel.isProvisioned) {
            if viewModel.isProvisioned {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    router.didConnect(host: viewModel.resolvedHost)
                }
            }
        }
    }
    
    private func stepIcon(for step: Int) -> String {
        switch step {
        case 0, 1: return "magnifyingglass"
        case 2:    return "bluetooth"
        case 3:    return "wifi"
        case 4:    return "checkmark.circle.fill"
        default:   return "exclamationmark.triangle"
        }
    }
}

// MARK: - Components

private struct ContinuousProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Theme.neutral.opacity(0.15))
                    .frame(height: 8)
                
                // Progress fill
                Capsule()
                    .fill(Theme.secondary)
                    .frame(width: geometry.size.width * CGFloat(currentStep) / CGFloat(totalSteps), height: 8)
                    .animation(.easeInOut(duration: 0.4), value: currentStep)
            }
        }
        .frame(height: 8)
    }
}

@MainActor
private func statusText(_ message: String, isError: Bool) -> some View {
    Text(message)
        .font(Theme.Typography.body(size: 12))
        .foregroundStyle(isError ? .red : .gray)
        .multilineTextAlignment(.center)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
}

@MainActor
private func actionButton(
    title: String,
    icon: String,
    isLoading: Bool,
    disabled: Bool,
    action: @escaping () -> Void
) -> some View {
    Group {
        if isLoading {
            ProgressView()
                .tint(Theme.secondary)
                .scaleEffect(1.2)
                .padding(.vertical, 16)
        } else {
            Button(action: action) {
                Label {
                    Text(title)
                        .font(Theme.Typography.heading(size: 16))
                } icon: {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(disabled ? Theme.neutral.opacity(0.1) : Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(disabled ? Theme.neutral.opacity(0.5) : .white)
            }
            .disabled(disabled)
        }
    }
}

private struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)
                .frame(width: 20)

            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).font(Theme.Typography.body(size: 16)).foregroundStyle(Theme.neutral.opacity(0.4)))
                    .font(Theme.Typography.body(size: 16))
                    .foregroundStyle(Theme.primary)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).font(Theme.Typography.body(size: 16)).foregroundStyle(Theme.neutral.opacity(0.4)))
                    .font(Theme.Typography.body(size: 16))
                    .foregroundStyle(Theme.primary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.neutral.opacity(0.1), lineWidth: 1)
        )
    }
}
