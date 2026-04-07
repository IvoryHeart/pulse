import Foundation
import CoreWLAN

/// WiFi signal quality and diagnostics via CoreWLAN framework.
public enum WiFiMonitor {

    public struct WiFiInfo: Sendable, Codable {
        public let ssid: String?
        public let bssid: String?
        public let rssi: Int
        public let noise: Int
        public let snr: Int
        public let channel: Int
        public let channelWidth: Int
        public let channelBand: String
        public let phyMode: String
        public let transmitRate: Double
        public let transmitPower: Int
        public let signalQuality: String

        public init(ssid: String?, bssid: String?, rssi: Int, noise: Int,
                    snr: Int, channel: Int, channelWidth: Int, channelBand: String,
                    phyMode: String, transmitRate: Double, transmitPower: Int,
                    signalQuality: String) {
            self.ssid = ssid
            self.bssid = bssid
            self.rssi = rssi
            self.noise = noise
            self.snr = snr
            self.channel = channel
            self.channelWidth = channelWidth
            self.channelBand = channelBand
            self.phyMode = phyMode
            self.transmitRate = transmitRate
            self.transmitPower = transmitPower
            self.signalQuality = signalQuality
        }
    }

    /// Get current WiFi diagnostics. Returns nil if WiFi hardware is off.
    /// Note: SSID may be nil on macOS 15+ without Location Services permission,
    /// but RSSI, channel, PHY mode, and other diagnostics still work.
    public static func getWiFiInfo() -> WiFiInfo? {
        let client = CWWiFiClient.shared()
        guard let iface = client.interface() else { return nil }
        guard iface.powerOn() else { return nil }

        let rssi = iface.rssiValue()
        // Use RSSI as connection indicator — SSID requires Location Services on macOS 15+
        // RSSI of 0 means no WiFi connection
        guard rssi != 0 else { return nil }

        let ssid = iface.ssid()
        let noise = iface.noiseMeasurement()
        let snr = rssi - noise

        let wlanChannel = iface.wlanChannel()
        let channelNum = wlanChannel?.channelNumber ?? 0

        let channelWidth: Int = {
            guard let cw = wlanChannel?.channelWidth else { return 20 }
            switch cw {
            case .width20MHz: return 20
            case .width40MHz: return 40
            case .width80MHz: return 80
            case .width160MHz: return 160
            @unknown default: return 20
            }
        }()

        let channelBand: String = {
            guard let band = wlanChannel?.channelBand else { return "Unknown" }
            switch band {
            case .band2GHz: return "2.4 GHz"
            case .band5GHz: return "5 GHz"
            case .band6GHz: return "6 GHz"
            @unknown default: return "Unknown"
            }
        }()

        let phyMode: String = {
            let mode = iface.activePHYMode()
            switch mode {
            case .mode11a:  return "802.11a"
            case .mode11b:  return "802.11b"
            case .mode11g:  return "802.11g"
            case .mode11n:  return "WiFi 4 (802.11n)"
            case .mode11ac: return "WiFi 5 (802.11ac)"
            case .mode11ax: return "WiFi 6 (802.11ax)"
            @unknown default: return "Unknown"
            }
        }()

        let transmitRate = iface.transmitRate()
        let transmitPower = iface.transmitPower()

        let signalQuality = qualityRating(rssi)

        return WiFiInfo(
            ssid: ssid,
            bssid: iface.bssid(),
            rssi: rssi,
            noise: noise,
            snr: snr,
            channel: channelNum,
            channelWidth: channelWidth,
            channelBand: channelBand,
            phyMode: phyMode,
            transmitRate: transmitRate,
            transmitPower: transmitPower,
            signalQuality: signalQuality
        )
    }

    public static func qualityRating(_ rssi: Int) -> String {
        switch rssi {
        case _ where rssi > -50:  return "Excellent"
        case -60 ... -50:         return "Good"
        case -70 ... -61:         return "Fair"
        default:                  return "Poor"
        }
    }
}
