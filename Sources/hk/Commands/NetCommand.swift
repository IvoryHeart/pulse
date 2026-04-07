import Foundation
import HKCore

enum NetCommand {
    static func run(args: [String], json: Bool = false) {
        let subcommand = args.first ?? "overview"

        switch subcommand {
        case "overview", "o":
            if json { showOverviewJSON() } else { showOverview() }
        case "topology", "topo", "t":
            showTopology()
        case "bandwidth", "bw":
            showBandwidth()
        case "connections", "conn", "c":
            showConnections()
        case "services", "svc", "s":
            showServices()
        case "home", "devices", "d":
            showHomeNetwork()
        case "wifi", "signal", "w":
            if json { showWiFiJSON() } else { showWiFi() }
        case "speed":
            showSpeed()
        default:
            if json { showOverviewJSON() } else { showOverview() }
        }
    }

    // MARK: - Overview

    private static func showOverview() {
        print(TerminalUI.colored("\n  NETWORK OVERVIEW\n", .boldCyan))

        // Gather data upfront
        let interfaces = NetworkInfo.getInterfaces().filter { $0.isUp && $0.type != "Loopback" }
        let gateway = NetworkInfo.getGateway()
        let devices = NetworkScanner.getARPDevices()
        let conns = ConnectionMonitor.getConnections()
        let established = conns.filter { $0.state == "ESTABLISHED" }
        let wifi = WiFiMonitor.getWiFiInfo()

        // --- Network Topology ---
        print(TerminalUI.colored("  NETWORK TOPOLOGY", .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))

        // Find the primary interface (prefer one with a gateway route)
        let primaryIface = interfaces.first(where: { $0.name == "en0" }) ?? interfaces.first
        let primaryName = primaryIface.map { "\($0.name) (\($0.type))" } ?? "unknown"
        let localIP = primaryIface?.address ?? "?.?.?.?"

        let gwStr = gateway ?? "unknown"
        print("  \(TerminalUI.colored("Internet", .boldCyan)) \(TerminalUI.colored("───", .gray)) \(TerminalUI.colored("Gateway", .boldWhite)) (\(TerminalUI.colored(gwStr, .cyan))) \(TerminalUI.colored("───", .gray)) \(TerminalUI.colored(primaryName, .green))")
        print("  \(TerminalUI.colored("              │", .gray))")
        print("  \(TerminalUI.colored("              ├── ", .gray))\(TerminalUI.colored("This Mac", .boldWhite)) (\(TerminalUI.colored(localIP, .cyan)))")

        let otherDeviceCount = max(0, devices.count - 1) // exclude this mac
        print("  \(TerminalUI.colored("              ├── ", .gray))\(TerminalUI.colored("\(otherDeviceCount) other device\(otherDeviceCount == 1 ? "" : "s") on LAN", .white))")
        print("  \(TerminalUI.colored("              └── ", .gray))\(TerminalUI.colored("\(established.count) active connection\(established.count == 1 ? "" : "s")", .white))")
        print()

        // --- WiFi Signal Quality Bar ---
        if let wifi = wifi {
            let signalPct = min(100, max(0, (Double(wifi.rssi) + 90) / 60 * 100))
            let ssidLabel: String
            if let ssid = wifi.ssid {
                ssidLabel = ssid
            } else {
                ssidLabel = "Connected (SSID requires Location Services)"
            }
            print("  \(TerminalUI.colored("WiFi:", .boldWhite)) \(TerminalUI.colored(ssidLabel, .cyan))")
            print("  " + TerminalUI.gauge(label: "Signal ", percent: signalPct, width: 20, warnAt: 40, critAt: 20) + "  \(TerminalUI.colored("\(wifi.rssi) dBm", .gray)) \(TerminalUI.colored(wifi.phyMode, .gray))")
            print()
        }

        // --- Active Interfaces ---
        print(TerminalUI.colored("  Active Interfaces:", .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))
        for iface in interfaces {
            let nameStr = "\(iface.name) (\(iface.type))".padding(toLength: 22, withPad: " ", startingAt: 0)
            print("  \(TerminalUI.colored("●", .green)) \(TerminalUI.colored(nameStr, .white)) \(TerminalUI.colored(iface.address, .gray))")
        }

        let dns = NetworkInfo.getDNSServers()
        if !dns.isEmpty {
            print("  \(TerminalUI.colored("DNS:", .boldWhite)) \(TerminalUI.colored(dns.prefix(3).joined(separator: ", "), .gray))")
        }
        print()

        // --- Quick Throughput Snapshot ---
        print(TerminalUI.colored("  Throughput (1s sample):", .boldWhite))
        let t1 = NetworkInfo.getTrafficStats(interface: "en0")
        Thread.sleep(forTimeInterval: 1.0)
        let t2 = NetworkInfo.getTrafficStats(interface: "en0")
        let downSpeed = ByteFormatter.format(t2.bytesIn - t1.bytesIn)
        let upSpeed = ByteFormatter.format(t2.bytesOut - t1.bytesOut)
        print("  \(TerminalUI.colored("↓", .green)) \(TerminalUI.colored("\(downSpeed)/s", .boldWhite)) down   \(TerminalUI.colored("↑", .cyan)) \(TerminalUI.colored("\(upSpeed)/s", .boldWhite)) up")
        print()

        // --- Top 3 Services by Connection Count ---
        var byService: [String: Int] = [:]
        for conn in established {
            let service = portName(conn.remotePort)
            byService[service, default: 0] += 1
        }
        let topServices = byService.sorted { $0.value > $1.value }.prefix(3)
        if !topServices.isEmpty {
            print(TerminalUI.colored("  Top Services:", .boldWhite))
            print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))
            for (service, count) in topServices {
                let svc = service.padding(toLength: 14, withPad: " ", startingAt: 0)
                let maxBar = 20
                let barLen = topServices.first.map { min(maxBar, count * maxBar / $0.value) } ?? 1
                let bar = String(repeating: "█", count: max(1, barLen))
                print("  \(TerminalUI.colored(svc, .cyan)) \(TerminalUI.colored(bar, .blue)) \(TerminalUI.colored("\(count)", .boldWhite)) conn")
            }
            print()
        }

        // --- Summary counts ---
        let summary = ConnectionMonitor.getConnectionSummary().prefix(5)
        if !summary.isEmpty {
            print(TerminalUI.colored("  Top Remote Hosts:", .boldWhite))
            print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))
            for item in summary {
                let host = item.host.padding(toLength: 28, withPad: " ", startingAt: 0)
                let countStr = "\(item.count) conn"
                print("  \(TerminalUI.colored(host, .white)) \(TerminalUI.colored(countStr, .gray))")
            }
        }

        print()
        print("  \(TerminalUI.colored("Devices on network:", .boldWhite)) \(TerminalUI.colored("\(devices.count)", .cyan))")

        print(TerminalUI.colored("\n  Use: hk net conn | services | home | wifi | speed | topology | bandwidth\n", .gray))
    }

    // MARK: - Topology

    private static func showTopology() {
        print(TerminalUI.colored("\n  NETWORK TOPOLOGY\n", .boldCyan))

        let interfaces = NetworkInfo.getInterfaces().filter { $0.isUp && $0.type != "Loopback" }
        let gateway = NetworkInfo.getGateway()
        let dns = NetworkInfo.getDNSServers()
        let devices = NetworkScanner.getARPDevices()
        let conns = ConnectionMonitor.getConnections()
        let established = conns.filter { $0.state == "ESTABLISHED" }

        // --- Gateway & DNS ---
        var configLines: [String] = []
        configLines.append("\(TerminalUI.colored("Gateway:", .boldWhite))  \(TerminalUI.colored(gateway ?? "not detected", .cyan))")
        if !dns.isEmpty {
            configLines.append("\(TerminalUI.colored("DNS:", .boldWhite))      \(TerminalUI.colored(dns.joined(separator: ", "), .cyan))")
        }
        print(TerminalUI.box(width: 58, title: "Configuration", sections: [configLines]))
        print()

        // --- Interfaces ---
        var ifaceLines: [String] = []
        for iface in interfaces {
            let typeIcon: String
            switch iface.type {
            case "Wi-Fi": typeIcon = TerminalUI.colored("~", .cyan)
            case "Ethernet": typeIcon = TerminalUI.colored("=", .green)
            case "VPN/Tunnel": typeIcon = TerminalUI.colored("*", .magenta)
            case "Bridge": typeIcon = TerminalUI.colored("#", .yellow)
            default: typeIcon = TerminalUI.colored("?", .gray)
            }
            let nameStr = "\(iface.name) (\(iface.type))".padding(toLength: 26, withPad: " ", startingAt: 0)
            ifaceLines.append("\(typeIcon) \(TerminalUI.colored(nameStr, .white)) \(TerminalUI.colored(iface.address, .cyan))")
        }
        if ifaceLines.isEmpty {
            ifaceLines.append(TerminalUI.colored("No active interfaces", .gray))
        }
        print(TerminalUI.box(width: 58, title: "Interfaces", sections: [ifaceLines]))
        print()

        // --- LAN Devices grouped by interface ---
        var devicesByIface: [String: [NetworkScanner.Device]] = [:]
        for device in devices {
            devicesByIface[device.interface, default: []].append(device)
        }

        var deviceSections: [[String]] = []
        for ifaceName in devicesByIface.keys.sorted() {
            guard let ifaceDevices = devicesByIface[ifaceName] else { continue }
            var section: [String] = []
            let ifaceType = interfaces.first(where: { $0.name == ifaceName })?.type ?? "Unknown"
            section.append(TerminalUI.colored("\(ifaceName) (\(ifaceType)) - \(ifaceDevices.count) device\(ifaceDevices.count == 1 ? "" : "s")", .boldWhite))
            for device in ifaceDevices {
                let ip = device.ipAddress.padding(toLength: 16, withPad: " ", startingAt: 0)
                let mac = device.macAddress.padding(toLength: 18, withPad: " ", startingAt: 0)
                let host = device.hostname ?? ""
                let vendor = macVendorHint(device.macAddress)
                var info = host
                if !vendor.isEmpty {
                    info += info.isEmpty ? vendor : " \(TerminalUI.colored("(\(vendor))", .gray))"
                }
                section.append("  \(TerminalUI.colored(ip, .white)) \(TerminalUI.colored(mac, .gray)) \(info)")
            }
            deviceSections.append(section)
        }
        if deviceSections.isEmpty {
            deviceSections.append([TerminalUI.colored("No devices in ARP table", .gray)])
        }
        print(TerminalUI.box(width: 58, title: "LAN Devices (\(devices.count) total)", sections: deviceSections))
        print()

        // --- Connection Summary by Service Type ---
        var byService: [String: Int] = [:]
        for conn in established {
            let service = portName(conn.remotePort)
            byService[service, default: 0] += 1
        }
        let sortedServices = byService.sorted { $0.value > $1.value }

        var connLines: [String] = []
        connLines.append("\(TerminalUI.colored("Total established:", .boldWhite)) \(TerminalUI.colored("\(established.count)", .cyan))")
        connLines.append("")
        if sortedServices.isEmpty {
            connLines.append(TerminalUI.colored("No active connections", .gray))
        } else {
            connLines.append(TerminalUI.colored("Service".padding(toLength: 16, withPad: " ", startingAt: 0) + "Connections", .boldWhite))
            connLines.append(TerminalUI.colored(String(repeating: "─", count: 30), .gray))
            for (service, count) in sortedServices {
                let svc = service.padding(toLength: 16, withPad: " ", startingAt: 0)
                connLines.append("\(TerminalUI.colored(svc, .cyan)) \(TerminalUI.colored("\(count)", .boldWhite))")
            }
        }
        print(TerminalUI.box(width: 58, title: "Active Connections", sections: [connLines]))
        print()
    }

    // MARK: - Bandwidth

    private static func showBandwidth() {
        print(TerminalUI.colored("\n  NETWORK BANDWIDTH\n", .boldCyan))
        print(TerminalUI.colored("  Sampling throughput over 3 seconds...\n", .gray))

        let sample1 = NetworkInfo.getTrafficStats(interface: "en0")
        Thread.sleep(forTimeInterval: 3.0)
        let sample2 = NetworkInfo.getTrafficStats(interface: "en0")

        let bytesInPerSec = (sample2.bytesIn - sample1.bytesIn) / 3
        let bytesOutPerSec = (sample2.bytesOut - sample1.bytesOut) / 3
        let totalBytesIn = sample2.bytesIn - sample1.bytesIn
        let totalBytesOut = sample2.bytesOut - sample1.bytesOut

        // --- Current Throughput ---
        var throughputLines: [String] = []
        throughputLines.append("\(TerminalUI.colored("↓ Download:", .boldWhite))  \(TerminalUI.colored("\(ByteFormatter.format(bytesInPerSec))/s", .green))")
        throughputLines.append("\(TerminalUI.colored("↑ Upload:", .boldWhite))    \(TerminalUI.colored("\(ByteFormatter.format(bytesOutPerSec))/s", .cyan))")
        throughputLines.append("")
        throughputLines.append("\(TerminalUI.colored("3s totals:", .gray)) \(ByteFormatter.format(totalBytesIn)) in, \(ByteFormatter.format(totalBytesOut)) out")
        print(TerminalUI.box(width: 58, title: "Current Throughput (3s avg)", sections: [throughputLines]))
        print()

        // --- Cumulative since boot ---
        var cumulativeLines: [String] = []
        cumulativeLines.append("\(TerminalUI.colored("Total In:", .boldWhite))   \(ByteFormatter.format(sample2.bytesIn))  (\(sample2.packetsIn) packets)")
        cumulativeLines.append("\(TerminalUI.colored("Total Out:", .boldWhite))  \(ByteFormatter.format(sample2.bytesOut))  (\(sample2.packetsOut) packets)")
        print(TerminalUI.box(width: 58, title: "Cumulative (since boot)", sections: [cumulativeLines]))
        print()

        // --- Service Bandwidth Estimate ---
        let conns = ConnectionMonitor.getConnections()
        let established = conns.filter { $0.state == "ESTABLISHED" }

        var byService: [String: Int] = [:]
        for conn in established {
            let service = portName(conn.remotePort)
            byService[service, default: 0] += 1
        }
        let sorted = byService.sorted { $0.value > $1.value }

        if sorted.isEmpty {
            print(TerminalUI.colored("  No active connections for service breakdown.\n", .gray))
            return
        }

        let totalConns = established.count
        let maxBarWidth = 24

        print(TerminalUI.colored("  SERVICE BREAKDOWN (by connection count)\n", .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 52), .gray))

        let maxCount = sorted.first?.value ?? 1
        for (service, count) in sorted {
            let svc = service.padding(toLength: 12, withPad: " ", startingAt: 0)
            let barLen = max(1, count * maxBarWidth / maxCount)
            let bar = String(repeating: "█", count: barLen)
            let pct = totalConns > 0 ? String(format: "%4.0f%%", Double(count) / Double(totalConns) * 100) : "  0%"

            // Estimate bandwidth share proportionally
            let estDown = totalConns > 0 ? bytesInPerSec * UInt64(count) / UInt64(totalConns) : 0
            let estStr = "\(ByteFormatter.format(estDown))/s"

            print("  \(TerminalUI.colored(svc, .cyan)) \(TerminalUI.colored(bar, .blue))\(String(repeating: " ", count: max(0, maxBarWidth - barLen + 1)))\(TerminalUI.colored("\(count)", .boldWhite)) conn  \(TerminalUI.colored(pct, .gray))  ~\(TerminalUI.colored(estStr, .gray))")
        }
        print()
    }

    // MARK: - WiFi Diagnostics

    private static func showWiFi() {
        print(TerminalUI.colored("\n  WIFI DIAGNOSTICS\n", .boldCyan))

        guard let wifi = WiFiMonitor.getWiFiInfo() else {
            print(TerminalUI.colored("  WiFi is not connected.\n", .yellow))
            return
        }

        let qualityColor: Color = switch wifi.signalQuality {
        case "Excellent": .boldGreen
        case "Good": .green
        case "Fair": .boldYellow
        default: .boldRed
        }

        let snrColor: Color = wifi.snr >= 25 ? .green : wifi.snr >= 15 ? .yellow : .boldRed

        // Handle SSID nil case for macOS 15+ Location Services restriction
        let ssidDisplay: String
        if let ssid = wifi.ssid {
            ssidDisplay = TerminalUI.colored(ssid, .cyan)
        } else {
            ssidDisplay = TerminalUI.colored("Connected", .cyan) + TerminalUI.colored(" (SSID requires Location Services)", .gray)
        }

        print("  \(TerminalUI.colored("SSID:", .boldWhite))        \(ssidDisplay)")
        print("  \(TerminalUI.colored("BSSID:", .boldWhite))       \(TerminalUI.colored(wifi.bssid ?? "Unknown", .gray))")
        print("  \(TerminalUI.colored("Signal:", .boldWhite))      \(TerminalUI.colored("\(wifi.rssi) dBm", qualityColor))  \(TerminalUI.colored(wifi.signalQuality, qualityColor))")
        print("  \(TerminalUI.colored("Noise:", .boldWhite))       \(TerminalUI.colored("\(wifi.noise) dBm", .gray))")
        print("  \(TerminalUI.colored("SNR:", .boldWhite))         \(TerminalUI.colored("\(wifi.snr) dB", snrColor))")
        print("  \(TerminalUI.colored("Channel:", .boldWhite))     \(wifi.channel) (\(wifi.channelBand), \(wifi.channelWidth) MHz)")
        print("  \(TerminalUI.colored("PHY Mode:", .boldWhite))    \(wifi.phyMode)")
        print("  \(TerminalUI.colored("Tx Rate:", .boldWhite))     \(String(format: "%.0f Mbps", wifi.transmitRate))")
        print("  \(TerminalUI.colored("Tx Power:", .boldWhite))    \(wifi.transmitPower) mW")
        print()

        // Signal quality gauge (map RSSI -90..-30 to 0..100)
        let signalPct = min(100, max(0, (Double(wifi.rssi) + 90) / 60 * 100))
        print("  " + TerminalUI.gauge(label: "Signal ", percent: signalPct, width: 20, warnAt: 40, critAt: 20))

        if wifi.ssid == nil {
            print()
            print("  \(TerminalUI.colored("Tip:", .boldYellow)) Grant Location Services to Terminal in")
            print("  \(TerminalUI.colored("     System Settings > Privacy & Security > Location Services", .gray))")
        }

        print()
    }

    // MARK: - Speed Test

    private static func showSpeed() {
        print(TerminalUI.colored("\n  NETWORK THROUGHPUT\n", .boldCyan))
        print(TerminalUI.colored("  Sampling over 2 seconds...\n", .gray))

        let sample1 = NetworkInfo.getTrafficStats(interface: "en0")
        Thread.sleep(forTimeInterval: 2.0)
        let sample2 = NetworkInfo.getTrafficStats(interface: "en0")

        let bytesInPerSec = (sample2.bytesIn - sample1.bytesIn) / 2
        let bytesOutPerSec = (sample2.bytesOut - sample1.bytesOut) / 2

        print("  \(TerminalUI.colored("Download:", .boldWhite)) \(ByteFormatter.format(bytesInPerSec))/s")
        print("  \(TerminalUI.colored("Upload:", .boldWhite))   \(ByteFormatter.format(bytesOutPerSec))/s")
        print()

        print(TerminalUI.colored("  Totals (since boot):", .gray))
        print("  In:  \(ByteFormatter.format(sample2.bytesIn))  (\(sample2.packetsIn) packets)")
        print("  Out: \(ByteFormatter.format(sample2.bytesOut))  (\(sample2.packetsOut) packets)")
        print()
    }

    // MARK: - Connections

    private static func showConnections() {
        print(TerminalUI.colored("\n  ACTIVE CONNECTIONS\n", .boldCyan))

        let conns = ConnectionMonitor.getConnections()
        let established = conns.filter { $0.state == "ESTABLISHED" }

        if established.isEmpty {
            print(TerminalUI.colored("  No established connections.\n", .gray))
            return
        }

        let header = "  \("Local Port".padding(toLength: 12, withPad: " ", startingAt: 0)) \("Remote Address".padding(toLength: 28, withPad: " ", startingAt: 0)) Port"
        print(TerminalUI.colored(header, .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 52), .gray))

        for conn in established.prefix(30) {
            let localPort = conn.localPort.padding(toLength: 12, withPad: " ", startingAt: 0)
            let remote = conn.remoteAddress.padding(toLength: 28, withPad: " ", startingAt: 0)
            let portColor: Color = isWellKnownPort(conn.remotePort) ? .cyan : .gray
            print("  \(TerminalUI.colored(localPort, .gray)) \(TerminalUI.colored(remote, .white)) \(TerminalUI.colored(portName(conn.remotePort), portColor))")
        }

        if established.count > 30 {
            print(TerminalUI.colored("  ... and \(established.count - 30) more", .gray))
        }

        print(TerminalUI.colored("\n  Total: \(established.count) established connections\n", .gray))
    }

    // MARK: - Services

    private static func showServices() {
        print(TerminalUI.colored("\n  NETWORK SERVICES\n", .boldCyan))

        let conns = ConnectionMonitor.getConnections()

        var byService: [String: Int] = [:]
        for conn in conns where conn.state == "ESTABLISHED" {
            let service = portName(conn.remotePort)
            byService[service, default: 0] += 1
        }

        let sorted = byService.sorted { $0.value > $1.value }

        if sorted.isEmpty {
            print(TerminalUI.colored("  No active services detected.\n", .gray))
            return
        }

        print(TerminalUI.colored("  Service breakdown (by connection count):", .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 48), .gray))

        for (service, count) in sorted {
            let bar = String(repeating: "█", count: min(count, 30))
            let svc = service.padding(toLength: 16, withPad: " ", startingAt: 0)
            print("  \(TerminalUI.colored(svc, .cyan)) \(TerminalUI.colored(bar, .blue)) \(count)")
        }
        print()
    }

    // MARK: - Home Network

    private static func showHomeNetwork() {
        print(TerminalUI.colored("\n  HOME NETWORK DEVICES\n", .boldCyan))

        if let ssid = NetworkInfo.getWiFiSSID() {
            print("  \(TerminalUI.colored("Network:", .boldWhite)) \(TerminalUI.colored(ssid, .cyan))")
        }
        if let gw = NetworkInfo.getGateway() {
            print("  \(TerminalUI.colored("Gateway:", .boldWhite)) \(TerminalUI.colored(gw, .gray))")
        }
        print()

        let devices = NetworkScanner.getARPDevices()

        if devices.isEmpty {
            print(TerminalUI.colored("  No devices found in ARP table.", .gray))
            print(TerminalUI.colored("  Try browsing your network first to populate the ARP cache.\n", .gray))
            return
        }

        // Log device sightings to SQLite
        var deviceHistory: [HealthStore.DeviceRecord] = []
        do {
            let store = HealthStore.shared
            try store.open()
            defer { store.close() }

            for device in devices {
                try store.logDeviceSighting(
                    macAddress: device.macAddress,
                    ipAddress: device.ipAddress,
                    hostname: device.hostname,
                    interface: device.interface
                )
            }
            deviceHistory = try store.getDeviceHistory()
        } catch {
            // Non-fatal
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d HH:mm"

        let header = "  \("IP Address".padding(toLength: 18, withPad: " ", startingAt: 0)) \("MAC Address".padding(toLength: 20, withPad: " ", startingAt: 0)) Info"
        print(TerminalUI.colored(header, .boldWhite))
        print(TerminalUI.colored("  " + String(repeating: "─", count: 56), .gray))

        for device in devices {
            let ip = device.ipAddress.padding(toLength: 18, withPad: " ", startingAt: 0)
            let mac = device.macAddress.padding(toLength: 20, withPad: " ", startingAt: 0)
            let host = device.hostname ?? "-"
            let vendor = macVendorHint(device.macAddress)
            let hostStr = vendor.isEmpty ? host : "\(host) \(TerminalUI.colored("(\(vendor))", .gray))"
            print("  \(TerminalUI.colored(ip, .white)) \(TerminalUI.colored(mac, .gray)) \(hostStr)")

            // Show first/last seen from history
            if let record = deviceHistory.first(where: { $0.macAddress == device.macAddress }) {
                let firstSeen = fmt.string(from: record.firstSeen)
                let lastSeen = fmt.string(from: record.lastSeen)
                print("  \(String(repeating: " ", count: 38))\(TerminalUI.colored("First: \(firstSeen)  Last: \(lastSeen)", .gray))")
            }
        }

        print(TerminalUI.colored("\n  \(devices.count) devices found (from ARP cache)\n", .gray))
    }

    // MARK: - JSON Output

    private static func showOverviewJSON() {
        struct NetOverview: Codable {
            let interfaces: [NetworkInfo.Interface]
            let wifiSSID: String?
            let wifi: WiFiMonitor.WiFiInfo?
            let gateway: String?
            let dns: [String]
            let connectionCount: Int
            let deviceCount: Int
            let trafficStats: NetworkInfo.TrafficStats
        }

        let interfaces = NetworkInfo.getInterfaces().filter { $0.isUp && $0.type != "Loopback" }
        let conns = ConnectionMonitor.getConnections()
        let devices = NetworkScanner.getARPDevices()

        let overview = NetOverview(
            interfaces: interfaces,
            wifiSSID: NetworkInfo.getWiFiSSID(),
            wifi: WiFiMonitor.getWiFiInfo(),
            gateway: NetworkInfo.getGateway(),
            dns: NetworkInfo.getDNSServers(),
            connectionCount: conns.filter { $0.state == "ESTABLISHED" }.count,
            deviceCount: devices.count,
            trafficStats: NetworkInfo.getTrafficStats()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(overview),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    private static func showWiFiJSON() {
        if let wifi = WiFiMonitor.getWiFiInfo() {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(wifi),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("{\"error\": \"WiFi not connected\"}")
        }
    }

    // MARK: - Helpers

    private static func portName(_ port: String) -> String {
        switch port {
        case "80": return "HTTP"
        case "443": return "HTTPS"
        case "22": return "SSH"
        case "53": return "DNS"
        case "993": return "IMAPS"
        case "587": return "SMTP"
        case "5228": return "Google"
        case "5223": return "Apple Push"
        case "3478", "3479": return "STUN/TURN"
        case "8080": return "HTTP-Alt"
        case "8443": return "HTTPS-Alt"
        default: return ":\(port)"
        }
    }

    private static func isWellKnownPort(_ port: String) -> Bool {
        guard let p = Int(port) else { return false }
        return p < 1024 || [5228, 5223, 8080, 8443].contains(p)
    }

    private static func macVendorHint(_ mac: String) -> String {
        let prefix = mac.prefix(8).uppercased()
        let vendors: [String: String] = [
            "F8:FF:C2": "Apple",
            "A4:83:E7": "Apple",
            "3C:22:FB": "Apple",
            "AC:DE:48": "Apple",
            "DC:A6:32": "Raspberry Pi",
            "B8:27:EB": "Raspberry Pi",
            "44:44:44": "Google Nest",
            "F4:F5:D8": "Google",
            "30:FD:38": "Google",
            "54:60:09": "Google",
            "18:B4:30": "Nest",
            "64:16:66": "Samsung",
            "FC:A1:83": "Amazon",
        ]
        return vendors[prefix] ?? ""
    }
}
