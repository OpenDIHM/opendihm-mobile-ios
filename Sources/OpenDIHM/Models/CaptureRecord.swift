import Foundation

struct CaptureRecord: Identifiable, Codable {
    let id: UUID
    let filename: String
    var displayName: String
    let createdAt: Date
    let zMetadata: Double
    let temperatureC: Double
    let exposureTimeUs: Int

    var fileURL: URL {
        CaptureRecord.capturesDir.appendingPathComponent(filename)
    }

    static let capturesDir: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("Captures", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    init(data: Data, zMetadata: Double, systemStatus: SystemStatusResponse?) throws {
        self.id = UUID()
        self.filename = "\(id.uuidString).dng"
        self.displayName = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        self.createdAt = Date()
        self.zMetadata = zMetadata
        self.temperatureC = systemStatus?.temperatureC ?? 0
        self.exposureTimeUs = systemStatus?.exposureTimeUs ?? 0
    }

    init(id: UUID, filename: String, displayName: String, createdAt: Date, zMetadata: Double, temperatureC: Double, exposureTimeUs: Int) {
        self.id = id
        self.filename = filename
        self.displayName = displayName
        self.createdAt = createdAt
        self.zMetadata = zMetadata
        self.temperatureC = temperatureC
        self.exposureTimeUs = exposureTimeUs
    }
}
