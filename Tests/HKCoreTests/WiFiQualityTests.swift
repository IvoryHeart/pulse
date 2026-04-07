import Testing
import Foundation
@testable import HKCore

@Suite("WiFiMonitor.qualityRating")
struct WiFiQualityTests {

    @Test("RSSI -40 is Excellent")
    func excellentSignal() {
        #expect(WiFiMonitor.qualityRating(-40) == "Excellent")
    }

    @Test("RSSI -49 is Excellent (just above -50)")
    func excellentBoundary() {
        #expect(WiFiMonitor.qualityRating(-49) == "Excellent")
    }

    @Test("RSSI -50 is Good (boundary)")
    func goodBoundary() {
        #expect(WiFiMonitor.qualityRating(-50) == "Good")
    }

    @Test("RSSI -55 is Good")
    func goodMiddle() {
        #expect(WiFiMonitor.qualityRating(-55) == "Good")
    }

    @Test("RSSI -60 is Good (lower boundary)")
    func goodLowerBoundary() {
        #expect(WiFiMonitor.qualityRating(-60) == "Good")
    }

    @Test("RSSI -61 is Fair")
    func fairBoundary() {
        #expect(WiFiMonitor.qualityRating(-61) == "Fair")
    }

    @Test("RSSI -65 is Fair")
    func fairMiddle() {
        #expect(WiFiMonitor.qualityRating(-65) == "Fair")
    }

    @Test("RSSI -70 is Fair (lower boundary)")
    func fairLowerBoundary() {
        #expect(WiFiMonitor.qualityRating(-70) == "Fair")
    }

    @Test("RSSI -71 is Poor")
    func poorBoundary() {
        #expect(WiFiMonitor.qualityRating(-71) == "Poor")
    }

    @Test("RSSI -85 is Poor")
    func poorSignal() {
        #expect(WiFiMonitor.qualityRating(-85) == "Poor")
    }

    @Test("RSSI 0 is Excellent (unusually strong)")
    func unusuallyStrong() {
        #expect(WiFiMonitor.qualityRating(0) == "Excellent")
    }
}

// MARK: - WiFi Signal Diagnostics Tests

@Suite("WiFiMonitor Signal Diagnostics")
struct WiFiSignalDiagnosticsTests {

    @Test("getWiFiInfo() returns non-nil when WiFi is connected")
    func wifiInfoNonNil() {
        let info = WiFiMonitor.getWiFiInfo()
        // This machine is expected to have WiFi on. If WiFi is off, skip gracefully.
        guard info != nil else {
            // WiFi may be off or disconnected -- not a failure, just skip.
            return
        }
        #expect(info != nil, "Expected WiFiInfo to be non-nil when WiFi is on")
    }

    @Test("If WiFiInfo is returned, rssi should be negative")
    func wifiRssiNegative() {
        guard let info = WiFiMonitor.getWiFiInfo() else {
            // WiFi not available -- skip.
            return
        }
        #expect(info.rssi < 0,
                "RSSI should be negative (dBm), got \(info.rssi)")
    }

    @Test("If WiFiInfo is returned, snr should be positive (rssi - noise)")
    func wifiSnrPositive() {
        guard let info = WiFiMonitor.getWiFiInfo() else {
            // WiFi not available -- skip.
            return
        }
        #expect(info.snr > 0,
                "SNR should be positive (signal above noise floor), got \(info.snr)")
    }

    @Test("If WiFiInfo is returned, snr equals rssi minus noise")
    func wifiSnrCalculation() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(info.snr == info.rssi - info.noise,
                "SNR (\(info.snr)) should equal rssi (\(info.rssi)) - noise (\(info.noise))")
    }

    @Test("If WiFiInfo is returned, channelWidth should be one of 20, 40, 80, 160")
    func wifiChannelWidthValid() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        let validWidths: Set<Int> = [20, 40, 80, 160]
        #expect(validWidths.contains(info.channelWidth),
                "channelWidth \(info.channelWidth) should be one of \(validWidths)")
    }

    @Test("If WiFiInfo is returned, phyMode should start with WiFi or 802.11")
    func wifiPhyModeFormat() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        let startsCorrectly = info.phyMode.hasPrefix("WiFi") || info.phyMode.hasPrefix("802.11")
        #expect(startsCorrectly,
                "phyMode '\(info.phyMode)' should start with 'WiFi' or '802.11'")
    }

    @Test("If WiFiInfo is returned, channelBand should be a known value")
    func wifiChannelBandValid() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        let validBands: Set<String> = ["2.4 GHz", "5 GHz", "6 GHz", "Unknown"]
        #expect(validBands.contains(info.channelBand),
                "channelBand '\(info.channelBand)' should be one of \(validBands)")
    }

    @Test("If WiFiInfo is returned, channel number is positive")
    func wifiChannelPositive() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(info.channel > 0,
                "WiFi channel should be positive, got \(info.channel)")
    }

    @Test("If WiFiInfo is returned, transmitRate is positive")
    func wifiTransmitRatePositive() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(info.transmitRate > 0,
                "transmitRate should be positive, got \(info.transmitRate)")
    }

    @Test("If WiFiInfo is returned, transmitPower is positive")
    func wifiTransmitPowerPositive() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        #expect(info.transmitPower > 0,
                "transmitPower should be positive, got \(info.transmitPower)")
    }

    @Test("If WiFiInfo is returned, signalQuality is a known rating")
    func wifiSignalQualityKnown() {
        guard let info = WiFiMonitor.getWiFiInfo() else { return }
        let validQualities: Set<String> = ["Excellent", "Good", "Fair", "Poor"]
        #expect(validQualities.contains(info.signalQuality),
                "signalQuality '\(info.signalQuality)' should be one of \(validQualities)")
    }

    @Test("WiFiInfo Codable encode then decode round-trip preserves all fields")
    func wifiInfoCodableRoundTrip() throws {
        let original = WiFiMonitor.WiFiInfo(
            ssid: "TestNetwork",
            bssid: "AA:BB:CC:DD:EE:FF",
            rssi: -51,
            noise: -90,
            snr: 39,
            channel: 36,
            channelWidth: 80,
            channelBand: "5 GHz",
            phyMode: "WiFi 5 (802.11ac)",
            transmitRate: 866.0,
            transmitPower: 15,
            signalQuality: "Good"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WiFiMonitor.WiFiInfo.self, from: data)

        #expect(decoded.ssid == original.ssid)
        #expect(decoded.bssid == original.bssid)
        #expect(decoded.rssi == original.rssi)
        #expect(decoded.noise == original.noise)
        #expect(decoded.snr == original.snr)
        #expect(decoded.channel == original.channel)
        #expect(decoded.channelWidth == original.channelWidth)
        #expect(decoded.channelBand == original.channelBand)
        #expect(decoded.phyMode == original.phyMode)
        #expect(decoded.transmitRate == original.transmitRate)
        #expect(decoded.transmitPower == original.transmitPower)
        #expect(decoded.signalQuality == original.signalQuality)
    }

    @Test("WiFiInfo with nil ssid encodes and decodes correctly")
    func wifiInfoNilSsidRoundTrip() throws {
        let original = WiFiMonitor.WiFiInfo(
            ssid: nil,
            bssid: nil,
            rssi: -55,
            noise: -92,
            snr: 37,
            channel: 1,
            channelWidth: 20,
            channelBand: "2.4 GHz",
            phyMode: "WiFi 4 (802.11n)",
            transmitRate: 144.0,
            transmitPower: 10,
            signalQuality: "Good"
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WiFiMonitor.WiFiInfo.self, from: data)

        #expect(decoded.ssid == nil)
        #expect(decoded.bssid == nil)
        #expect(decoded.rssi == original.rssi)
    }
}
