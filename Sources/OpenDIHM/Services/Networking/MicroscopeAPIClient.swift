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

@MainActor
final class MicroscopeAPIClient {
    private let session: URLSession
    private let config: MicroscopeConfig

    /// Initializes the client.
    /// - Parameters:
    ///   - config: Shared microscope configuration (defaults to `.shared`).
    ///   - session: URL Session (default: `.shared`, override for testing).
    init(config: MicroscopeConfig? = nil, session: URLSession = .shared) {
        self.config = config ?? .shared
        self.session = session
    }

    // MARK: - Endpoints

    /// Checks whether the firmware API is running.
    /// - Returns: `ServerStatusResponse` from GET /
    func getServerStatus() async throws -> ServerStatusResponse {
        let url = try resolve("/")
        return try await get(url: url)
    }

    /// Retrieves the current hardware and system telemetry from the microscope.
    /// - Returns: `SystemStatusResponse` containing temperatures, storage, memory, and laser state.
    func getSystemStatus() async throws -> SystemStatusResponse {
        let url = try resolve("/system/status")
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
        guard let base = config.apiBaseURL else { throw APIError.invalidURL }

        let resolvedHost = ipv4Address(for: config.host)
        let resolvedBaseString = base.absoluteString.replacingOccurrences(of: config.host, with: resolvedHost)
        
        guard let resolvedBase = URL(string: resolvedBaseString),
              let url = URL(string: path, relativeTo: resolvedBase) else {
            throw APIError.invalidURL
        }
        return url
    }
    
    /// Low-level resolver to prefer IPv4 (AF_INET) for a given hostname.
    private func ipv4Address(for host: String) -> String {
        // If it's already an IP, return it
        if host.range(of: "^[0-9.]+$", options: .regularExpression) != nil { return host }
        
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_INET, // Force IPv4 (AF_INET)
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &res)
        defer { if res != nil { freeaddrinfo(res) } }
        
        if status == 0, let first = res {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(first.pointee.ai_addr, first.pointee.ai_addrlen, &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                return String(cString: hostname)
            }
        }
        
        return host // Fallback to original hostname if resolution fails
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
