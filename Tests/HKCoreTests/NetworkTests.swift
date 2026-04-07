import Testing
@testable import HKCore

// MARK: - NetworkInfo Tests

@Suite("NetworkInfo")
struct NetworkInfoTests {

    @Test("getInterfaces() returns non-empty array")
    func interfacesNonEmpty() {
        let interfaces = NetworkInfo.getInterfaces()
        #expect(!interfaces.isEmpty, "Expected at least one network interface (loopback, en0, etc.)")
    }

    @Test("getInterfaces() contains at least one interface with a non-empty name")
    func interfacesHaveNames() {
        let interfaces = NetworkInfo.getInterfaces()
        let hasName = interfaces.contains { !$0.name.isEmpty }
        #expect(hasName, "Expected at least one interface with a non-empty name")
    }

    @Test("getInterfaces() contains at least one interface that is up")
    func interfacesHaveUp() {
        let interfaces = NetworkInfo.getInterfaces()
        let hasUp = interfaces.contains { $0.isUp }
        #expect(hasUp, "Expected at least one interface to be up (loopback is always up)")
    }

    // This test assumes the machine is online. May fail if network is disconnected.
    @Test("getDNSServers() returns non-empty array when online")
    func dnsServersNonEmpty() {
        let servers = NetworkInfo.getDNSServers()
        #expect(!servers.isEmpty, "Expected at least one DNS server (machine is assumed online)")
    }

    // This test assumes the machine is online. May fail if network is disconnected.
    @Test("getGateway() returns non-nil when online")
    func gatewayNonNil() {
        let gateway = NetworkInfo.getGateway()
        #expect(gateway != nil, "Expected a default gateway (machine is assumed online)")
    }

    // This test assumes the machine has sent/received data since boot.
    // May return zeros if en0 is not the active interface (e.g. Ethernet-only or VPN).
    @Test("getTrafficStats() returns non-zero bytesIn for default interface")
    func trafficStatsNonZero() {
        let stats = NetworkInfo.getTrafficStats()
        // On a machine that has been running and is online, there should be some traffic.
        // This can fail if en0 has never been used (e.g. Ethernet-only setup).
        #expect(stats.bytesIn > 0 || stats.bytesOut > 0,
                "Expected some traffic on en0; may fail if en0 is unused (Ethernet-only or VPN)")
    }

    @Test("getTrafficStats(interface: en0) returns a TrafficStats struct")
    func trafficStatsForEn0() {
        // Should return a valid struct even if values happen to be zero (e.g. WiFi off).
        let stats = NetworkInfo.getTrafficStats(interface: "en0")
        // Just verify we got a struct back -- values may be zero if WiFi is off.
        #expect(stats.bytesIn >= 0 && stats.bytesOut >= 0)
        #expect(stats.packetsIn >= 0 && stats.packetsOut >= 0)
    }

    @Test("getTrafficStats(interface: nonexistent99) returns zeros gracefully")
    func trafficStatsNonexistentInterface() {
        let stats = NetworkInfo.getTrafficStats(interface: "nonexistent99")
        #expect(stats.bytesIn == 0)
        #expect(stats.bytesOut == 0)
        #expect(stats.packetsIn == 0)
        #expect(stats.packetsOut == 0)
    }
}

// MARK: - ConnectionMonitor Tests

@Suite("ConnectionMonitor")
struct ConnectionMonitorTests {

    // This test assumes the machine is online and has at least one established TCP connection.
    // Typical: SSH, DNS-over-HTTPS, browser, IDE telemetry, etc.
    @Test("getConnections() returns non-empty array when online")
    func connectionsNonEmpty() {
        let connections = ConnectionMonitor.getConnections(includeListening: true)
        #expect(!connections.isEmpty,
                "Expected at least one TCP connection (machine is assumed online)")
    }

    @Test("Connections have non-empty local or remote addresses")
    func connectionsHaveAddresses() {
        let connections = ConnectionMonitor.getConnections(includeListening: true)
        // Skip if no connections (already covered above)
        guard !connections.isEmpty else { return }

        for conn in connections {
            let hasAddress = !conn.localAddress.isEmpty || !conn.remoteAddress.isEmpty
            #expect(hasAddress, "Connection should have at least one non-empty address")
        }
    }

    @Test("Each connection has a valid state string")
    func connectionsHaveValidState() {
        let validStates: Set<String> = [
            "ESTABLISHED", "SYN_SENT", "SYN_RECEIVED", "SYN_RCVD",
            "FIN_WAIT_1", "FIN_WAIT_2", "TIME_WAIT",
            "CLOSE_WAIT", "LAST_ACK", "LISTEN", "CLOSING", "CLOSED",
            ""  // netstat sometimes omits state for some entries
        ]
        let connections = ConnectionMonitor.getConnections(includeListening: true)
        guard !connections.isEmpty else { return }

        for conn in connections {
            #expect(validStates.contains(conn.state),
                    "Unexpected TCP state '\(conn.state)' -- expected one of: \(validStates)")
        }
    }
}

// MARK: - WiFiMonitor Tests

@Suite("WiFiMonitor")
struct WiFiMonitorTests {

    // getWiFiInfo() may return nil if WiFi is off or disconnected.
    // These tests handle both cases gracefully.
    @Test("getWiFiInfo() returns nil or a valid WiFiInfo")
    func wifiInfoNilOrValid() {
        let info = WiFiMonitor.getWiFiInfo()
        if let info = info {
            // If we got info, it should have meaningful values.
            #expect(info.rssi < 0, "RSSI should be negative (dBm)")
            #expect(info.channel > 0, "Channel should be positive")
        }
        // nil is also acceptable -- WiFi may be off.
    }

    // May fail if WiFi is off or disconnected.
    @Test("If WiFiInfo is returned, RSSI is in range -100...0")
    func wifiRssiRange() {
        guard let info = WiFiMonitor.getWiFiInfo() else {
            // WiFi is off or disconnected -- skip.
            return
        }
        #expect((-100...0).contains(info.rssi),
                "RSSI \(info.rssi) should be between -100 and 0 dBm")
    }

    // May fail if WiFi is off or disconnected.
    @Test("If WiFiInfo is returned, channel is > 0")
    func wifiChannelPositive() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(info.channel > 0, "WiFi channel should be positive, got \(info.channel)")
    }

    // May fail if WiFi is off or disconnected.
    @Test("If WiFiInfo is returned, signalQuality is one of the known ratings")
    func wifiSignalQualityValid() {
        let validQualities: Set<String> = ["Excellent", "Good", "Fair", "Poor"]
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(validQualities.contains(info.signalQuality),
                "signalQuality '\(info.signalQuality)' is not a known rating")
    }

    // Pure function tests for qualityRating -- these don't depend on machine state.
    @Test("qualityRating(-30) returns Excellent")
    func qualityExcellent() {
        #expect(WiFiMonitor.qualityRating(-30) == "Excellent")
    }

    @Test("qualityRating(-50) returns Good (boundary: -60...-50)")
    func qualityGoodBoundary() {
        #expect(WiFiMonitor.qualityRating(-50) == "Good")
    }

    @Test("qualityRating(-55) returns Good")
    func qualityGoodMid() {
        #expect(WiFiMonitor.qualityRating(-55) == "Good")
    }

    @Test("qualityRating(-65) returns Fair")
    func qualityFair() {
        #expect(WiFiMonitor.qualityRating(-65) == "Fair")
    }

    @Test("qualityRating(-75) returns Poor")
    func qualityPoor() {
        #expect(WiFiMonitor.qualityRating(-75) == "Poor")
    }
}

// MARK: - NetworkScanner Tests

@Suite("NetworkScanner")
struct NetworkScannerTests {

    // This test assumes the machine is on a local network with at least one other device
    // (or the gateway) visible in the ARP table. May fail on an isolated machine.
    @Test("getARPDevices() returns non-empty array when on a network")
    func arpDevicesNonEmpty() {
        let devices = NetworkScanner.getARPDevices()
        #expect(!devices.isEmpty,
                "Expected at least one device in ARP table (gateway, etc.)")
    }

    @Test("ARP devices have non-empty IP addresses")
    func arpDevicesHaveIPs() {
        let devices = NetworkScanner.getARPDevices()
        guard !devices.isEmpty else { return }

        for device in devices {
            #expect(!device.ipAddress.isEmpty,
                    "Each ARP device should have a non-empty IP address")
        }
    }

    @Test("ARP devices have MAC addresses in expected format")
    func arpDevicesHaveMACFormat() {
        let devices = NetworkScanner.getARPDevices()
        guard !devices.isEmpty else { return }

        // MAC address should be in XX:XX:XX:XX:XX:XX format (with single or double hex digits)
        // or "(incomplete)" for unresolved entries (though the parser filters those out).
        let macPattern = #/^([0-9a-fA-F]{1,2}:){5}[0-9a-fA-F]{1,2}$/#

        for device in devices {
            let isValidMAC = device.macAddress.wholeMatch(of: macPattern) != nil
            let isIncomplete = device.macAddress == "(incomplete)"
            #expect(isValidMAC || isIncomplete,
                    "MAC '\(device.macAddress)' should be in XX:XX:XX:XX:XX:XX format or '(incomplete)'")
        }
    }
}

// MARK: - HealthStore Device History Tests

// HealthStore.shared is a singleton with mutable SQLite state. Tests must run
// serially to avoid concurrent open()/query races on the shared db pointer.
@Suite("HealthStore", .serialized)
struct HealthStoreTests {

    @Test("HealthStore.shared can be opened")
    func healthStoreCanOpen() throws {
        try HealthStore.shared.open()
        // If we got here without throwing, the store opened successfully.
    }

    @Test("getSnapshotCount() returns >= 0")
    func snapshotCountNonNegative() throws {
        try HealthStore.shared.open()
        let count = try HealthStore.shared.getSnapshotCount()
        #expect(count >= 0, "Snapshot count should be non-negative, got \(count)")
    }

    @Test("getDeviceHistory(limit: 10) returns an array (may be empty)")
    func deviceHistoryReturnsArray() throws {
        try HealthStore.shared.open()
        let history = try HealthStore.shared.getDeviceHistory(limit: 10)
        // Just verify it returns without crashing -- may be empty on a fresh install.
        #expect(history.count >= 0)
    }
}
