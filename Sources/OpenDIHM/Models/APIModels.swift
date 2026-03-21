/// CaptureResponse.swift
/// Data models for the OpenDIHM HTTP REST API responses.

import Foundation

/// Response body from POST /capture.
/// The actual DNG payload is delivered as raw bytes (application/octet-stream),
/// not JSON, so this model is used for error reporting.
struct CaptureErrorResponse: Decodable {
    let detail: String
}

/// Response body from POST /preview/start and POST /preview/stop.
struct PreviewStatusResponse: Decodable {
    let status: String
    let port: String?
}

/// Response body from GET /
struct ServerStatusResponse: Decodable {
    let status: String
    let microscope: String
}

/// A structure representing the hardware and system status returned by the OpenDIHM API.
struct SystemStatusResponse: Decodable {
    /// Internal CPU temperature in Celsius.
    let temperatureC: Double
    
    /// Wi-Fi signal strength in dBm.
    let wifiSignalDbm: Double
    
    /// Indicates whether the imaging laser is currently pulsed on.
    let laserOn: Bool
    
    /// Configured camera shutter exposure time in microseconds.
    let exposureTimeUs: Int
    
    /// Estimated internal disk storage space remaining in bytes.
    let storageLeftBytes: Int
    
    /// Total system RAM remaining available in bytes.
    let memoryLeftBytes: Int
    
    enum CodingKeys: String, CodingKey {
        case temperatureC = "temperature_c"
        case wifiSignalDbm = "wifi_signal_dbm"
        case laserOn = "laser_on"
        case exposureTimeUs = "exposure_time_us"
        case storageLeftBytes = "storage_left_bytes"
        case memoryLeftBytes = "memory_left_bytes"
    }
    
    /// Human-readable format of the estimated storage space left (e.g., "1.2 GB").
    var storageLeftFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(storageLeftBytes), countStyle: .file)
    }
    
    /// Human-readable format of the total system RAM remaining (e.g., "250 MB").
    var memoryLeftFormatted: String {
        ByteCountFormatter.string(fromByteCount: Int64(memoryLeftBytes), countStyle: .memory)
    }
}
