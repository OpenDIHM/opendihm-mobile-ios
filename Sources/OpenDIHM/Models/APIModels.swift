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
