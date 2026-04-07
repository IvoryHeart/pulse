import Foundation
import Darwin
import IOKit

public struct BatteryMonitor {

    // MARK: - Public API

    public static func getBatteryInfo() -> BatteryInfo {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )

        guard service != 0 else {
            return BatteryInfo(available: false)
        }
        defer { IOObjectRelease(service) }

        let currentCapacity: Int = getProperty(service, "CurrentCapacity") ?? 0
        let maxCapacity: Int = getProperty(service, "MaxCapacity") ?? 100
        let isCharging: Bool = getProperty(service, "IsCharging") ?? false
        let externalConnected: Bool = getProperty(service, "ExternalConnected") ?? false
        let cycleCount: Int = getProperty(service, "CycleCount") ?? 0

        let percentage = maxCapacity > 0 ? (currentCapacity * 100) / maxCapacity : 0

        let designCapacity: Int = getProperty(service, "DesignCapacity") ?? maxCapacity
        let healthPercent = designCapacity > 0 ? (maxCapacity * 100) / designCapacity : 100
        let health: String
        switch healthPercent {
        case 80...: health = "Good (\(healthPercent)%)"
        case 50..<80: health = "Fair (\(healthPercent)%)"
        default: health = "Poor (\(healthPercent)%)"
        }

        return BatteryInfo(
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: externalConnected,
            cycleCount: cycleCount,
            health: health,
            available: true
        )
    }

    // MARK: - Private Helpers

    private static func getProperty<T>(_ service: io_service_t, _ key: String) -> T? {
        IORegistryEntryCreateCFProperty(
            service,
            key as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? T
    }
}
