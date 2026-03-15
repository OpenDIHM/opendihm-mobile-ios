/// MicroscopeConfig.swift
/// Shared runtime configuration for the connected OpenDIHM microscope.

import Foundation

/// Singleton holding the resolved network addresses for the connected Pi.
final class MicroscopeConfig {
    /// Shared instance accessed across the application.
    static let shared = MicroscopeConfig()

    /// IP address or hostname of the Raspberry Pi.
    var host: String = ""

    /// HTTP API port on the Pi (default: 8000).
    var apiPort: Int = 8000

    /// TCP stream port for the libcamera-vid preview (default: 8888).
    var streamPort: Int = 8888

    /// Base URL for the HTTP REST API.
    var apiBaseURL: URL? {
        URL(string: "http://\(host):\(apiPort)")
    }

    private init() {}
}
