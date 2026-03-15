/// MicroscopeAPIClient.swift
/// HTTP REST client for the OpenDIHM firmware API.
///
/// Communicates with the FastAPI server running on the Raspberry Pi.

import Foundation

/// Errors that can arise from the microscope API.
enum APIError: LocalizedError {
    case invalidURL
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL."
        case .httpError(let code, let detail): return "HTTP \(code): \(detail)"
        case .decodingError(let err): return "Decoding failed: \(err.localizedDescription)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

/// Async/await HTTP client for the OpenDIHM firmware REST API.
final class MicroscopeAPIClient {
    private let session: URLSession
    private let config: MicroscopeConfig

    /// Initializes the client.
    /// - Parameters:
    ///   - config: Shared microscope configuration (default: `.shared`).
    ///   - session: URL Session (default: `.shared`, override for testing).
    init(config: MicroscopeConfig = .shared, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - Endpoints

    /// Checks whether the firmware API is running.
    /// - Returns: `ServerStatusResponse` from GET /
    func getServerStatus() async throws -> ServerStatusResponse {
        let url = try resolve("/")
        return try await get(url: url)
    }

    /// Triggers a RAW DNG hologram capture.
    /// - Parameter zMetadata: Z-distance metadata in microns.
    /// - Returns: Raw DNG `Data` (application/octet-stream).
    func captureHologram(zMetadata: Double) async throws -> Data {
        let url = try resolve("/capture")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["z_metadata": zMetadata]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    /// Starts the live preview TCP stream on the Pi.
    /// - Returns: `PreviewStatusResponse` with the streaming port.
    func startPreview() async throws -> PreviewStatusResponse {
        let url = try resolve("/preview/start")
        return try await post(url: url)
    }

    /// Stops the live preview TCP stream on the Pi.
    /// - Returns: `PreviewStatusResponse` confirming stop.
    func stopPreview() async throws -> PreviewStatusResponse {
        let url = try resolve("/preview/stop")
        return try await post(url: url)
    }

    // MARK: - Private Helpers

    private func resolve(_ path: String) throws -> URL {
        guard let base = config.apiBaseURL,
              let url = URL(string: path, relativeTo: base)
        else {
            throw APIError.invalidURL
        }
        return url
    }

    private func get<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func post<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(http.statusCode, detail)
        }
    }
}
