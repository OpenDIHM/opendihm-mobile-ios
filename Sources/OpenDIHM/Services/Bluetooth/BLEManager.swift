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
            withServices: [CBUUID(string: BLEConstants.serviceUUIDString)],
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
        struct UnsafeCentral: @unchecked Sendable { let central: CBCentralManager }
        let wrapper = UnsafeCentral(central: central)
        
        MainActor.assumeIsolated {
            if wrapper.central.state == .poweredOn {
                startScanning()
            } else if wrapper.central.state != .unknown && wrapper.central.state != .resetting {
                state = .failed("Bluetooth unavailable: \(wrapper.central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        struct UnsafeDiscovery: @unchecked Sendable {
            let central: CBCentralManager
            let peripheral: CBPeripheral
            let advertisementData: [String: Any]
        }
        let wrapper = UnsafeDiscovery(central: central, peripheral: peripheral, advertisementData: advertisementData)
        
        MainActor.assumeIsolated {
            let name = wrapper.advertisementData[CBAdvertisementDataLocalNameKey] as? String
                ?? wrapper.peripheral.name
                ?? ""
            guard name == BLEConstants.deviceName else { return }

            wrapper.central.stopScan()
            self.peripheral = wrapper.peripheral
            state = .connecting
            wrapper.central.connect(wrapper.peripheral, options: nil)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        struct UnsafeConnection: @unchecked Sendable { let peripheral: CBPeripheral }
        let wrapper = UnsafeConnection(peripheral: peripheral)
        
        MainActor.assumeIsolated {
            state = .connected
            wrapper.peripheral.delegate = self
            wrapper.peripheral.discoverServices([CBUUID(string: BLEConstants.serviceUUIDString)])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        MainActor.assumeIsolated {
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
        struct UnsafePeripheral: @unchecked Sendable { let peripheral: CBPeripheral }
        let wrapper = UnsafePeripheral(peripheral: peripheral)
        
        MainActor.assumeIsolated {
            guard let services = wrapper.peripheral.services else { return }
            for service in services where service.uuid == CBUUID(string: BLEConstants.serviceUUIDString) {
                wrapper.peripheral.discoverCharacteristics(
                    [CBUUID(string: BLEConstants.wifiCharUUIDString), CBUUID(string: BLEConstants.statusCharUUIDString)],
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
        struct UnsafeService: @unchecked Sendable {
            let peripheral: CBPeripheral
            let service: CBService
        }
        let wrapper = UnsafeService(peripheral: peripheral, service: service)
        
        MainActor.assumeIsolated {
            for characteristic in wrapper.service.characteristics ?? [] {
                switch characteristic.uuid {
                case CBUUID(string: BLEConstants.wifiCharUUIDString):
                    wifiChar = characteristic
                    // Send queued credentials if any
                    if !pendingSSID.isEmpty {
                        sendCredentials(
                            ssid: pendingSSID,
                            password: pendingPassword,
                            to: wrapper.peripheral,
                            via: characteristic
                        )
                    }
                case CBUUID(string: BLEConstants.statusCharUUIDString):
                    statusChar = characteristic
                    // Subscribe to status notifications from the Pi
                    wrapper.peripheral.setNotifyValue(true, for: characteristic)
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
        struct UnsafeCharacteristic: @unchecked Sendable { let characteristic: CBCharacteristic }
        let wrapper = UnsafeCharacteristic(characteristic: characteristic)
        
        MainActor.assumeIsolated {
            guard wrapper.characteristic.uuid == CBUUID(string: BLEConstants.statusCharUUIDString),
                  let data = wrapper.characteristic.value,
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
