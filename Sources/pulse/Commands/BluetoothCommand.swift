import Foundation
import PulseCore

enum BluetoothCommand {
    static func run(json: Bool = false) {
        let info = BluetoothMonitor.getBluetoothInfo()

        if json {
            showJSON(info)
        } else {
            showFormatted(info)
        }
    }

    // MARK: - Formatted Output

    private static func showFormatted(_ info: BluetoothMonitor.BluetoothInfo) {
        let statusStr: String
        let statusColor: Color
        if !info.isAvailable {
            statusStr = "Unavailable"
            statusColor = .boldRed
        } else if info.isPoweredOn {
            statusStr = "On"
            statusColor = .boldGreen
        } else {
            statusStr = "Off"
            statusColor = .boldYellow
        }

        // Build sections for the box
        var statusSection: [String] = []
        statusSection.append("\(TerminalUI.colored("Bluetooth:", .boldWhite))  \(TerminalUI.colored(statusStr, statusColor))")
        statusSection.append("\(TerminalUI.colored("Paired:", .boldWhite))     \(TerminalUI.colored("\(info.pairedDevices.count) devices", .white))")
        statusSection.append("\(TerminalUI.colored("Connected:", .boldWhite))  \(TerminalUI.colored("\(info.connectedCount)", .cyan))")

        guard info.isPoweredOn else {
            print(TerminalUI.box(width: 50, title: "BLUETOOTH", sections: [statusSection]))
            print()
            return
        }

        // Connected devices section
        let connected = info.pairedDevices.filter(\.isConnected)
        var connectedSection: [String] = []
        if connected.isEmpty {
            connectedSection.append(TerminalUI.colored("No devices connected", .gray))
        } else {
            connectedSection.append(TerminalUI.colored("Connected Devices:", .boldWhite))
            for dev in connected {
                let icon = deviceIcon(dev.deviceType)
                let rssiStr: String
                if let rssi = dev.rssi {
                    let rssiColor = rssiColor(rssi)
                    rssiStr = "  \(TerminalUI.colored("\(rssi) dBm", rssiColor))"
                } else {
                    rssiStr = ""
                }
                let typeStr = TerminalUI.colored("[\(dev.deviceType)]", .gray)
                connectedSection.append("\(TerminalUI.colored(icon, .green)) \(TerminalUI.colored(dev.name, .white)) \(typeStr)\(rssiStr)")
            }
        }

        // All paired devices section
        let disconnected = info.pairedDevices.filter { !$0.isConnected }
        var pairedSection: [String] = []
        if !disconnected.isEmpty {
            pairedSection.append(TerminalUI.colored("Other Paired Devices:", .boldWhite))
            for dev in disconnected {
                let icon = deviceIcon(dev.deviceType)
                let typeStr = TerminalUI.colored("[\(dev.deviceType)]", .gray)
                let addrStr = TerminalUI.colored(dev.address, .gray)
                pairedSection.append("\(TerminalUI.colored(icon, .gray)) \(TerminalUI.colored(dev.name, .gray)) \(typeStr) \(addrStr)")
            }
        }

        var sections = [statusSection, connectedSection]
        if !pairedSection.isEmpty {
            sections.append(pairedSection)
        }

        print(TerminalUI.box(width: 56, title: "BLUETOOTH", sections: sections))
        print()
    }

    // MARK: - JSON Output

    private static func showJSON(_ info: BluetoothMonitor.BluetoothInfo) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(info),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    // MARK: - Helpers

    private static func deviceIcon(_ type: String) -> String {
        switch type {
        case "Audio":    return "♪"
        case "Computer": return "◻"
        case "Phone":    return "◆"
        case "Input":    return "⌨"
        case "Wearable": return "⌚"
        case "Network":  return "◎"
        case "Imaging":  return "◈"
        default:         return "●"
        }
    }

    private static func rssiColor(_ rssi: Int) -> Color {
        switch rssi {
        case _ where rssi > -50: return .boldGreen
        case -60 ... -50:        return .green
        case -70 ... -61:        return .boldYellow
        default:                 return .boldRed
        }
    }
}
