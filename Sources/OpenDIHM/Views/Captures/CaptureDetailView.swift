import SwiftUI

struct CaptureDetailView: View {
    let record: CaptureRecord
    let captureManager: CaptureManager

    @State private var selectedMode: CaptureMode = .twoD
    @State private var show3DUnsupported = false
    @State private var image: UIImage?

    private enum CaptureMode: String {
        case twoD = "2D"
        case threeD = "3D"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                Spacer()
                metadataOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                modeToggle
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareCapture()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.25)))
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("3D View", isPresented: $show3DUnsupported) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("3D reconstruction is not yet supported. Check back in a future update.")
        }
        .task {
            image = DNGRenderer.fullImage(at: record.fileURL)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button {
                selectedMode = .twoD
            } label: {
                Text("2D")
                    .font(Theme.Typography.mono(size: 13))
                    .frame(width: 40, height: 28)
                    .background(selectedMode == .twoD ? Color.white.opacity(0.9) : Color.clear)
                    .foregroundStyle(selectedMode == .twoD ? .black : .white)
            }

            Button {
                if selectedMode == .threeD {
                    selectedMode = .twoD
                } else {
                    show3DUnsupported = true
                }
            } label: {
                Text("3D")
                    .font(Theme.Typography.mono(size: 13))
                    .frame(width: 40, height: 28)
                    .background(selectedMode == .threeD ? Color.white.opacity(0.9) : Color.clear)
                    .foregroundStyle(selectedMode == .threeD ? .black : .white)
            }
        }
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
        )
    }

    private var metadataOverlay: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .frame(width: 16, alignment: .center)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 16, alignment: .center)
                    Text("\(Int(record.zMetadata))x zoom")
                }
                HStack(spacing: 6) {
                    Image(systemName: "thermometer")
                        .frame(width: 16, alignment: .center)
                    Text("\(String(format: "%.1f", record.temperatureC))°C")
                }
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch")
                        .frame(width: 16, alignment: .center)
                    Text("\(record.exposureTimeUs / 1000)ms")
                }
            }
            .font(Theme.Typography.mono(size: 11))
            .foregroundStyle(.white)
            .padding(10)
            .background(Color.black.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()
        }
        .padding(.leading, 12)
        .padding(.bottom, 20)
    }

    private func shareCapture() {
        guard let jpegData = image?.jpegData(compressionQuality: 0.9) else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(record.displayName)
            .appendingPathExtension("jpg")
        try? jpegData.write(to: tempURL)

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        activityVC.completionWithItemsHandler = { _, _, _, _ in
            try? FileManager.default.removeItem(at: tempURL)
        }

        guard let top = UIApplication.shared.topMostViewController() else { return }
        top.present(activityVC, animated: true)
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        let window = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
