import Testing
import Foundation
@testable import PulseCore

// MARK: - BluetoothMonitor Tests

@Suite("BluetoothMonitor")
struct BluetoothMonitorTests {

    @Test("getBluetoothInfo() returns a BluetoothInfo struct")
    func bluetoothInfoReturns() {
        let info = BluetoothMonitor.getBluetoothInfo()
        // Just verify we get a struct back without crashing.
        // isAvailable will be true on a Mac with Bluetooth hardware.
        _ = info.isAvailable
        _ = info.isPoweredOn
        _ = info.pairedDevices
        _ = info.connectedCount
    }

    @Test("isAvailable is a valid boolean (true or false)")
    func isAvailableReturnsBool() {
        let info = BluetoothMonitor.getBluetoothInfo()
        // On most Macs, Bluetooth hardware is present, so isAvailable should be true.
        // We don't assert which value, just that it returns without error.
        #expect(info.isAvailable == true || info.isAvailable == false)
    }

    @Test("pairedDevices is an array (may be empty)")
    func pairedDevicesIsArray() {
        let info = BluetoothMonitor.getBluetoothInfo()
        #expect(info.pairedDevices.count >= 0,
                "pairedDevices should be a non-negative count array")
    }

    @Test("connectedCount is non-negative and <= pairedDevices.count")
    func connectedCountConsistency() {
        let info = BluetoothMonitor.getBluetoothInfo()
        #expect(info.connectedCount >= 0,
                "connectedCount should be non-negative")
        #expect(info.connectedCount <= info.pairedDevices.count,
                "connectedCount (\(info.connectedCount)) should not exceed pairedDevices count (\(info.pairedDevices.count))")
    }

    @Test("If there are paired devices, each has a non-empty name or address")
    func pairedDevicesHaveIdentifiers() {
        let info = BluetoothMonitor.getBluetoothInfo()
        guard !info.pairedDevices.isEmpty else {
            // No paired devices -- nothing to check.
            return
        }
        for device in info.pairedDevices {
            let hasIdentifier = !device.name.isEmpty || !device.address.isEmpty
            #expect(hasIdentifier,
                    "Each paired device should have a non-empty name or address, got name='\(device.name)' address='\(device.address)'")
        }
    }

    @Test("If there are paired devices, each has a valid deviceType string")
    func pairedDevicesHaveValidType() {
        let validTypes: Set<String> = [
            "Audio", "Computer", "Phone", "Input", "Wearable",
            "Network", "Imaging", "Toy", "Health", "Unknown"
        ]
        let info = BluetoothMonitor.getBluetoothInfo()
        guard !info.pairedDevices.isEmpty else { return }
        for device in info.pairedDevices {
            #expect(validTypes.contains(device.deviceType),
                    "deviceType '\(device.deviceType)' is not a known classification")
        }
    }

    @Test("Connected devices are sorted before disconnected devices")
    func connectedDevicesSortedFirst() {
        let info = BluetoothMonitor.getBluetoothInfo()
        let devices = info.pairedDevices
        guard devices.count > 1 else { return }

        // Find the last connected device index and the first disconnected device index.
        var lastConnectedIdx: Int?
        var firstDisconnectedIdx: Int?
        for (i, device) in devices.enumerated() {
            if device.isConnected {
                lastConnectedIdx = i
            }
            if !device.isConnected && firstDisconnectedIdx == nil {
                firstDisconnectedIdx = i
            }
        }

        if let lastConn = lastConnectedIdx, let firstDisconn = firstDisconnectedIdx {
            #expect(lastConn < firstDisconn,
                    "Connected devices should be sorted before disconnected devices")
        }
    }

    @Test("If a device is connected and has rssi, rssi is in valid dBm range")
    func connectedDeviceRssiValid() {
        let info = BluetoothMonitor.getBluetoothInfo()
        for device in info.pairedDevices where device.isConnected {
            if let rssi = device.rssi {
                // Bluetooth RSSI is typically negative (dBm), but 0 is valid for very close devices
                #expect(rssi <= 0 && rssi >= -127,
                        "Connected device RSSI should be in range -127...0 dBm, got \(rssi) for '\(device.name)'")
            }
            // rssi being nil is also valid (e.g., RSSI unavailable)
        }
    }

    @Test("Disconnected devices have nil rssi")
    func disconnectedDeviceRssiNil() {
        let info = BluetoothMonitor.getBluetoothInfo()
        for device in info.pairedDevices where !device.isConnected {
            #expect(device.rssi == nil,
                    "Disconnected device should have nil rssi, got \(String(describing: device.rssi)) for '\(device.name)'")
        }
    }
}

// MARK: - BTDevice Codable Tests

@Suite("BTDevice Codable")
struct BTDeviceCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("BTDevice encode then decode round-trip preserves all fields")
    func btDeviceRoundTrip() throws {
        let original = BluetoothMonitor.BTDevice(
            name: "AirPods Pro",
            address: "AA:BB:CC:DD:EE:FF",
            isConnected: true,
            deviceType: "Audio",
            rssi: -45
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BluetoothMonitor.BTDevice.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.address == original.address)
        #expect(decoded.isConnected == original.isConnected)
        #expect(decoded.deviceType == original.deviceType)
        #expect(decoded.rssi == original.rssi)
    }

    @Test("BTDevice with nil rssi encodes and decodes correctly")
    func btDeviceNilRssiRoundTrip() throws {
        let original = BluetoothMonitor.BTDevice(
            name: "Magic Keyboard",
            address: "11:22:33:44:55:66",
            isConnected: false,
            deviceType: "Input",
            rssi: nil
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BluetoothMonitor.BTDevice.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.address == original.address)
        #expect(decoded.isConnected == original.isConnected)
        #expect(decoded.deviceType == original.deviceType)
        #expect(decoded.rssi == nil)
    }

    @Test("BTDevice JSON contains expected keys")
    func btDeviceJSONKeys() throws {
        let device = BluetoothMonitor.BTDevice(
            name: "Test Device",
            address: "AA:BB:CC:DD:EE:FF",
            isConnected: true,
            deviceType: "Audio",
            rssi: -50
        )
        let data = try encoder.encode(device)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["name"] as? String == "Test Device")
        #expect(json["address"] as? String == "AA:BB:CC:DD:EE:FF")
        #expect(json["isConnected"] as? Bool == true)
        #expect(json["deviceType"] as? String == "Audio")
        #expect(json["rssi"] as? Int == -50)
    }
}

// MARK: - BluetoothInfo Codable Tests

@Suite("BluetoothInfo Codable")
struct BluetoothInfoCodableTests {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    @Test("BluetoothInfo encode then decode round-trip preserves all fields")
    func bluetoothInfoRoundTrip() throws {
        let devices = [
            BluetoothMonitor.BTDevice(
                name: "AirPods Pro",
                address: "AA:BB:CC:DD:EE:FF",
                isConnected: true,
                deviceType: "Audio",
                rssi: -45
            ),
            BluetoothMonitor.BTDevice(
                name: "Magic Mouse",
                address: "11:22:33:44:55:66",
                isConnected: false,
                deviceType: "Input",
                rssi: nil
            ),
        ]
        let original = BluetoothMonitor.BluetoothInfo(
            isAvailable: true,
            isPoweredOn: true,
            pairedDevices: devices,
            connectedCount: 1
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BluetoothMonitor.BluetoothInfo.self, from: data)

        #expect(decoded.isAvailable == original.isAvailable)
        #expect(decoded.isPoweredOn == original.isPoweredOn)
        #expect(decoded.pairedDevices.count == original.pairedDevices.count)
        #expect(decoded.connectedCount == original.connectedCount)

        #expect(decoded.pairedDevices[0].name == "AirPods Pro")
        #expect(decoded.pairedDevices[0].isConnected == true)
        #expect(decoded.pairedDevices[0].rssi == -45)
        #expect(decoded.pairedDevices[1].name == "Magic Mouse")
        #expect(decoded.pairedDevices[1].isConnected == false)
        #expect(decoded.pairedDevices[1].rssi == nil)
    }

    @Test("BluetoothInfo with empty pairedDevices round-trips correctly")
    func bluetoothInfoEmptyDevicesRoundTrip() throws {
        let original = BluetoothMonitor.BluetoothInfo(
            isAvailable: true,
            isPoweredOn: false,
            pairedDevices: [],
            connectedCount: 0
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BluetoothMonitor.BluetoothInfo.self, from: data)

        #expect(decoded.isAvailable == true)
        #expect(decoded.isPoweredOn == false)
        #expect(decoded.pairedDevices.isEmpty)
        #expect(decoded.connectedCount == 0)
    }

    @Test("BluetoothInfo unavailable state round-trips correctly")
    func bluetoothInfoUnavailableRoundTrip() throws {
        let original = BluetoothMonitor.BluetoothInfo(
            isAvailable: false,
            isPoweredOn: false,
            pairedDevices: [],
            connectedCount: 0
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(BluetoothMonitor.BluetoothInfo.self, from: data)

        #expect(decoded.isAvailable == false)
        #expect(decoded.isPoweredOn == false)
        #expect(decoded.pairedDevices.isEmpty)
        #expect(decoded.connectedCount == 0)
    }

    @Test("BluetoothInfo JSON contains expected top-level keys")
    func bluetoothInfoJSONKeys() throws {
        let original = BluetoothMonitor.BluetoothInfo(
            isAvailable: true,
            isPoweredOn: true,
            pairedDevices: [],
            connectedCount: 0
        )
        let data = try encoder.encode(original)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["isAvailable"] as? Bool == true)
        #expect(json["isPoweredOn"] as? Bool == true)
        #expect(json["pairedDevices"] is [Any])
        #expect(json["connectedCount"] as? Int == 0)
    }
}
