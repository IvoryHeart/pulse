import Foundation
import IOBluetooth

/// Bluetooth device discovery and status via IOBluetooth framework.
public enum BluetoothMonitor {

    public struct BTDevice: Sendable, Codable {
        public let name: String
        public let address: String
        public let isConnected: Bool
        public let deviceType: String  // "Audio", "Input", "Phone", "Computer", "Unknown"
        public let rssi: Int?  // signal strength if connected, nil if not

        public init(name: String, address: String, isConnected: Bool,
                    deviceType: String, rssi: Int?) {
            self.name = name
            self.address = address
            self.isConnected = isConnected
            self.deviceType = deviceType
            self.rssi = rssi
        }
    }

    public struct BluetoothInfo: Sendable, Codable {
        public let isAvailable: Bool
        public let isPoweredOn: Bool
        public let pairedDevices: [BTDevice]
        public let connectedCount: Int

        public init(isAvailable: Bool, isPoweredOn: Bool,
                    pairedDevices: [BTDevice], connectedCount: Int) {
            self.isAvailable = isAvailable
            self.isPoweredOn = isPoweredOn
            self.pairedDevices = pairedDevices
            self.connectedCount = connectedCount
        }
    }

    /// Get current Bluetooth status and all paired devices.
    public static func getBluetoothInfo() -> BluetoothInfo {
        let controller = IOBluetoothHostController.default()

        let isAvailable = controller != nil
        let isPoweredOn: Bool = {
            guard let ctrl = controller else { return false }
            // powerState: 0 = off, 1 = on/active
            return ctrl.powerState == kBluetoothHCIPowerStateON
        }()

        guard let rawDevices = IOBluetoothDevice.pairedDevices() else {
            return BluetoothInfo(
                isAvailable: isAvailable,
                isPoweredOn: isPoweredOn,
                pairedDevices: [],
                connectedCount: 0
            )
        }

        // Deduplicate by address
        var seen = Set<String>()
        var devices: [BTDevice] = []

        for case let dev as IOBluetoothDevice in rawDevices {
            guard let address = dev.addressString?.uppercased() else { continue }
            guard !seen.contains(address) else { continue }
            seen.insert(address)

            let name = dev.name ?? "Unknown"
            let connected = dev.isConnected()
            let deviceType = classifyDevice(major: dev.deviceClassMajor, minor: dev.deviceClassMinor)

            let rssi: Int? = {
                guard connected else { return nil }
                let raw = dev.rawRSSI()
                // BluetoothHCIRSSIValue is Int8; 127 means unavailable
                guard raw != 127 else { return nil }
                return Int(raw)
            }()

            devices.append(BTDevice(
                name: name,
                address: address,
                isConnected: connected,
                deviceType: deviceType,
                rssi: rssi
            ))
        }

        // Sort: connected first, then alphabetical by name
        devices.sort { lhs, rhs in
            if lhs.isConnected != rhs.isConnected {
                return lhs.isConnected
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let connectedCount = devices.filter(\.isConnected).count

        return BluetoothInfo(
            isAvailable: isAvailable,
            isPoweredOn: isPoweredOn,
            pairedDevices: devices,
            connectedCount: connectedCount
        )
    }

    // MARK: - Connection Control

    public enum ConnectionResult: Sendable {
        case success
        case failure(String)
    }

    /// Connect to a paired Bluetooth device by address.
    /// Runs synchronously — call from a background thread.
    public static func connectDevice(address: String) -> ConnectionResult {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return .failure("Device not found: \(address)")
        }

        for attempt in 0..<3 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 0.5) }
            let result = device.openConnection()
            if result == kIOReturnSuccess {
                return .success
            }
        }

        return .failure("Connection failed")
    }

    /// Disconnect a connected Bluetooth device by address.
    /// Runs synchronously — call from a background thread.
    public static func disconnectDevice(address: String) -> ConnectionResult {
        guard let device = IOBluetoothDevice(addressString: address) else {
            return .failure("Device not found: \(address)")
        }

        for attempt in 0..<5 {
            if attempt > 0 { Thread.sleep(forTimeInterval: 0.5) }
            let result = device.closeConnection()
            if result == kIOReturnSuccess {
                return .success
            }
        }

        return .failure("Disconnect failed")
    }

    // MARK: - Private

    /// Classify a Bluetooth device based on its major/minor device class.
    private static func classifyDevice(major: BluetoothDeviceClassMajor, minor: BluetoothDeviceClassMinor) -> String {
        switch major {
        case 1:  return "Computer"
        case 2:  return "Phone"
        case 4:  // Audio/Video
            // Minor class hints: 1=headset, 2=hands-free, 4=microphone, 6=headphones, 7=speaker
            return "Audio"
        case 5:  // Peripheral (keyboard, mouse, gamepad)
            return "Input"
        case 7:  return "Wearable"
        case 3:  return "Network"    // LAN/Network Access Point
        case 6:  return "Imaging"    // Printer, scanner, camera
        case 8:  return "Toy"
        case 9:  return "Health"
        default: return "Unknown"
        }
    }
}
