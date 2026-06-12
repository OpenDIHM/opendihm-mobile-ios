import SwiftUI

struct DirectConnectView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var address: String = ""
    @State private var showError: Bool = false
    @AppStorage("savedDevices") private var savedDevicesData: Data = Data()

    private var savedDevices: [String] {
        (try? JSONDecoder().decode([String].self, from: savedDevicesData)) ?? []
    }

    private let defaults = ["raspberrypi.local", "opendihm.local"]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image("LogoHorizontal")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 50)
                        .padding(.top, 10)

                    VStack(spacing: 24) {
                        VStack(spacing: 16) {
                            Text("Connect to Microscope")
                                .font(Theme.Typography.heading(size: 18))
                                .foregroundStyle(Theme.primary)
                                .padding(.top, 10)

                            Text("Enter the IP address or hostname of your microscope.")
                                .font(Theme.Typography.body(size: 14))
                                .foregroundStyle(Theme.neutral)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)

                            HStack(spacing: 10) {
                                ForEach(defaults, id: \.self) { entry in
                                    Button(entry) {
                                        address = entry
                                    }
                                    .font(Theme.Typography.body(size: 13))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Theme.secondary.opacity(0.15))
                                    .foregroundStyle(Theme.secondary)
                                    .clipShape(Capsule())
                                }
                            }

                            HStack(spacing: 8) {
                                GlassTextField(
                                    placeholder: "IP or hostname",
                                    text: $address,
                                    icon: "network"
                                )

                                Button(action: saveDevice) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundStyle(address.isEmpty ? Theme.neutral.opacity(0.3) : Theme.primary)
                                }
                                .disabled(address.isEmpty)
                            }

                            if !savedDevices.isEmpty {
                                VStack(spacing: 6) {
                                    ForEach(savedDevices, id: \.self) { device in
                                        HStack {
                                            Button(device) {
                                                address = device
                                            }
                                            .font(Theme.Typography.body(size: 14))
                                            .foregroundStyle(Theme.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                            Button {
                                                removeDevice(device)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 16))
                                                    .foregroundStyle(.red.opacity(0.6))
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.9))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Theme.neutral.opacity(0.1), lineWidth: 1)
                                        )
                                    }
                                }
                            }

                            if showError {
                                Text("Please enter a valid address.")
                                    .font(Theme.Typography.body(size: 12))
                                    .foregroundStyle(.red)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            Button(action: connect) {
                                Text("Connect")
                                    .font(Theme.Typography.heading(size: 16))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(address.isEmpty ? Theme.neutral.opacity(0.1) : Theme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(address.isEmpty ? Theme.neutral.opacity(0.5) : .white)
                            }
                            .disabled(address.isEmpty)
                        }
                    }
                    .padding(.horizontal, 30)
                }

                Spacer().frame(height: 40)
            }
        }
    }

    private func connect() {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError = true
            return
        }
        showError = false
        router.didConnect(host: trimmed)
    }

    private func saveDevice() {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var devices = savedDevices
        if !devices.contains(trimmed) {
            devices.append(trimmed)
            savedDevicesData = (try? JSONEncoder().encode(devices)) ?? Data()
        }
    }

    private func removeDevice(_ device: String) {
        var devices = savedDevices
        devices.removeAll { $0 == device }
        savedDevicesData = (try? JSONEncoder().encode(devices)) ?? Data()
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
                    .keyboardType(.URL)
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
