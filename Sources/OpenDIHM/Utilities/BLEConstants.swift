/// BLEConstants.swift
/// UUIDs and constants shared between the BLE service and CoreBluetooth client.
///
/// These must match the UUIDs defined in the Pi firmware's ble_server.py exactly.

@preconcurrency import CoreBluetooth

@MainActor
enum BLEConstants {
    /// OpenDIHM primary GATT service UUID.
    static let serviceUUID = CBUUID(string: "cd1dd15c-3cda-48eb-bbd9-93ef640fe50b")

    /// Write-only characteristic that accepts JSON Wi-Fi credentials.
    /// Payload format: {"ssid": "NetworkName", "pwd": "password"}
    static let wifiCharUUID = CBUUID(string: "cd1dd15d-3cda-48eb-bbd9-93ef640fe50b")

    /// Read/Notify characteristic broadcasting Pi connection status strings.
    /// e.g. "Ready", "Connecting to X...", "Connected", "Failed to connect"
    static let statusCharUUID = CBUUID(string: "cd1dd15e-3cda-48eb-bbd9-93ef640fe50b")

    /// Advertised local name of the Pi peripheral.
    static let deviceName = "OpenDIHM"
}
