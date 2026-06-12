import Foundation

@MainActor
final class CaptureManager: ObservableObject {
    @Published private(set) var captures: [CaptureRecord] = []

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var capturesDir: URL { CaptureRecord.capturesDir }

    init() {
        loadCaptures()
    }

    func saveCapture(data: Data, zMetadata: Double, systemStatus: SystemStatusResponse?) throws -> CaptureRecord {
        let record = try CaptureRecord(data: data, zMetadata: zMetadata, systemStatus: systemStatus)
        try data.write(to: record.fileURL, options: .atomic)
        let metadataURL = metadataURL(for: record)
        let metadataData = try encoder.encode(record)
        try metadataData.write(to: metadataURL, options: .atomic)
        captures.append(record)
        captures.sort { $0.createdAt > $1.createdAt }
        return record
    }

    func loadCaptures() {
        guard let fileURLs = try? fileManager.contentsOfDirectory(at: capturesDir, includingPropertiesForKeys: nil) else {
            captures = []
            return
        }
        let metadataFiles = fileURLs.filter { $0.pathExtension == "json" }
        var loaded: [CaptureRecord] = []
        for url in metadataFiles {
            guard let data = try? Data(contentsOf: url),
                  let record = try? decoder.decode(CaptureRecord.self, from: data) else { continue }
            loaded.append(record)
        }
        loaded.sort { $0.createdAt > $1.createdAt }
        captures = loaded
    }

    func deleteCapture(_ record: CaptureRecord) {
        try? fileManager.removeItem(at: record.fileURL)
        try? fileManager.removeItem(at: metadataURL(for: record))
        captures.removeAll { $0.id == record.id }
    }

    func renameCapture(_ record: CaptureRecord, newName: String) {
        guard let index = captures.firstIndex(where: { $0.id == record.id }) else { return }
        captures[index].displayName = newName
        let updated = captures[index]
        if let data = try? encoder.encode(updated) {
            try? data.write(to: metadataURL(for: updated), options: .atomic)
        }
    }

    func fileURL(for record: CaptureRecord) -> URL {
        record.fileURL
    }

    private func metadataURL(for record: CaptureRecord) -> URL {
        let metaFilename = record.filename.replacingOccurrences(of: ".dng", with: ".json")
        return capturesDir.appendingPathComponent(metaFilename)
    }
}
