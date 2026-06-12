import SwiftUI

struct CapturesListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var captureManager = CaptureManager()
    @State private var renameRecord: CaptureRecord?
    @State private var renameText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if captureManager.captures.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "camera.metering.unknown")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.neutral.opacity(0.4))
                        Text("No captures yet")
                            .font(Theme.Typography.heading(size: 18))
                            .foregroundStyle(Theme.neutral)
                        Text("Captured holograms will appear here.")
                            .font(Theme.Typography.body(size: 14))
                            .foregroundStyle(Theme.neutral.opacity(0.6))
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(captureManager.captures) { record in
                            ZStack(alignment: .bottom) {
                                NavigationLink {
                                    CaptureDetailView(record: record, captureManager: captureManager)
                                } label: {
                                    HStack(spacing: 12) {
                                        Group {
                                            if let image = DNGRenderer.thumbnail(at: record.fileURL) {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .scaledToFill()
                                            } else {
                                                Image(systemName: "photo.badge.arrow.down")
                                                    .font(.title2)
                                                    .foregroundStyle(Theme.secondary)
                                            }
                                        }
                                        .frame(width: 56, height: 56)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))

                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 6) {
                                                Text(record.displayName)
                                                    .font(Theme.Typography.heading(size: 14))
                                                    .foregroundStyle(Theme.primary)
                                                    .lineLimit(1)

                                                Button {
                                                    renameRecord = record
                                                    renameText = record.displayName
                                                } label: {
                                                    Image(systemName: "pencil")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(Theme.secondary)
                                                }
                                            }
                                            Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                .font(Theme.Typography.body(size: 11))
                                                .foregroundStyle(Theme.neutral)
                                            HStack(spacing: 12) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "magnifyingglass")
                                                        .frame(width: 12)
                                                    Text("\(Int(record.zMetadata))x")
                                                }
                                                .font(Theme.Typography.mono(size: 10))
                                                .foregroundStyle(Theme.secondary)

                                                HStack(spacing: 3) {
                                                    Image(systemName: "thermometer")
                                                        .frame(width: 12)
                                                    Text("\(String(format: "%.1f", record.temperatureC))°C")
                                                }
                                                .font(Theme.Typography.mono(size: 10))
                                                .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                }

                                Divider()
                                    .padding(.leading, 80)
                            }
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.85))
                            )
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.hidden)
                            .contextMenu {
                                Button {
                                    renameRecord = record
                                    renameText = record.displayName
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    captureManager.deleteCapture(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    captureManager.deleteCapture(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    renameRecord = record
                                    renameText = record.displayName
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(Theme.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Captures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .font(Theme.Typography.body(size: 16))
                        .foregroundStyle(Theme.primary)
                }
            }
            .alert("Rename", isPresented: .init(get: { renameRecord != nil }, set: { if !$0 { renameRecord = nil } })) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameRecord = nil }
                Button("Save") {
                    if let record = renameRecord {
                        captureManager.renameCapture(record, newName: renameText)
                    }
                    renameRecord = nil
                }
            } message: {
                Text("Enter a new name for this capture.")
            }
        }
    }
}
