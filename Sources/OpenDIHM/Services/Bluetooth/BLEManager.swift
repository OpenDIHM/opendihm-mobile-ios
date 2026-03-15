/// BLEManager.swift
/// CoreBluetooth central manager for discovering and provisioning the OpenDIHM Pi.
///
/// Responsibilities:
/// - Scan for the OpenDIHM BLE peripheral.
/// - Write Wi-Fi credentials to the WIFI characteristic.
/// - Subscribe to STATUS notifications to track provisioning progress.

import CoreBluetooth
import Combine
import Foundation

/// The provisioning lifecycle states.
enum BLEProvisioningState: Equatable {
    case idle
    case scanning
    case connecting
    case connected
    case sendingCredentials
    case waitingForWiFi
    case provisioned
    case failed(String)
}

/// Observable CoreBluetooth manager for the BLE onboarding flow.
@MainActor
final class BLEManager: NSObject, ObservableObject {
    // MARK: - Published State

    /// Current state of the provisioning lifecycle.
    @Published private(set) var state: BLEProvisioningState = .idle

    /// Status string received from the Pi STATUS characteristic.
    @Published private(set) var statusMessage: String = ""

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var wifiChar: CBCharacteristic?
    private var statusChar: CBCharacteristic?

    /// SSID and password queued for sending once connection is established.
    private var pendingSSID: String = ""
    private var pendingPassword: String = ""

    // MARK: - Lifecycle

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public API

    /// Begin scanning for the OpenDIHM peripheral.
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            state = .failed("Bluetooth is not enabled.")
            return
        }
        state = .scanning
        centralManager.scanForPeripherals(
            withServices: [BLEConstants.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    /// Stop active BLE scan.
    func stopScanning() {
        centralManager.stopScan()
        if case .scanning = state { state = .idle }
    }

    /// Provision the connected Pi with the given Wi-Fi credentials.
    /// - Parameters:
    ///   - ssid: Wi-Fi network name.
    ///   - password: Wi-Fi network password.
    func provisionWiFi(ssid: String, password: String) {
        pendingSSID = ssid
        pendingPassword = password

        if let characteristic = wifiChar, let peripheral = peripheral {
            sendCredentials(ssid: ssid, password: password, to: peripheral, via: characteristic)
        }
    }

    // MARK: - Private Helpers

    private func sendCredentials(
        ssid: String,
        password: String,
        to peripheral: CBPeripheral,
        via characteristic: CBCharacteristic
    ) {
        let payload: [String: String] = ["ssid": ssid, "pwd": password]
        guard let data = try? JSONEncoder().encode(payload) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        state = .sendingCredentials
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                startScanning()
            } else {
                state = .failed("Bluetooth unavailable: \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
                ?? peripheral.name
                ?? ""
            guard name == BLEConstants.deviceName else { return }

            central.stopScan()
            self.peripheral = peripheral
            state = .connecting
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        Task { @MainActor in
            state = .connected
            peripheral.delegate = self
            peripheral.discoverServices([BLEConstants.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            state = .failed(error?.localizedDescription ?? "Connection failed")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        Task { @MainActor in
            guard let services = peripheral.services else { return }
            for service in services where service.uuid == BLEConstants.serviceUUID {
                peripheral.discoverCharacteristics(
                    [BLEConstants.wifiCharUUID, BLEConstants.statusCharUUID],
                    for: service
                )
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            for characteristic in service.characteristics ?? [] {
                switch characteristic.uuid {
                case BLEConstants.wifiCharUUID:
                    wifiChar = characteristic
                    // Send queued credentials if any
                    if !pendingSSID.isEmpty {
                        sendCredentials(
                            ssid: pendingSSID,
                            password: pendingPassword,
                            to: peripheral,
                            via: characteristic
                        )
                    }
                case BLEConstants.statusCharUUID:
                    statusChar = characteristic
                    // Subscribe to status notifications from the Pi
                    peripheral.setNotifyValue(true, for: characteristic)
                default:
                    break
                }
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            guard characteristic.uuid == BLEConstants.statusCharUUID,
                  let data = characteristic.value,
                  let message = String(data: data, encoding: .utf8)
            else { return }

            statusMessage = message

            if message == "Connected" {
                state = .provisioned
            } else if message.hasPrefix("Error") || message == "Failed to connect" {
                state = .failed(message)
            } else {
                state = .waitingForWiFi
            }
        }
    }
}
