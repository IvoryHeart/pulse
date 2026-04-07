import Foundation
import Darwin

public struct ThermalMonitor {

    // MARK: - Public API

    public static func getThermalInfo() -> ThermalInfo {
        let state: ThermalInfo.State = switch Foundation.ProcessInfo.processInfo.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .unknown
        }

        return ThermalInfo(state: state)
    }
}
