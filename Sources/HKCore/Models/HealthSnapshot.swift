import Foundation

public struct HealthSnapshot: Sendable, Codable {
    public let timestamp: Date
    public let cpu: CPUInfo
    public let memory: MemoryInfo
    public let disk: DiskInfo
    public let battery: BatteryInfo
    public let thermal: ThermalInfo
    public let topProcesses: [HKProcessInfo]

    public init(
        timestamp: Date = Date(),
        cpu: CPUInfo,
        memory: MemoryInfo,
        disk: DiskInfo,
        battery: BatteryInfo,
        thermal: ThermalInfo,
        topProcesses: [HKProcessInfo]
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
        self.disk = disk
        self.battery = battery
        self.thermal = thermal
        self.topProcesses = topProcesses
    }
}

public struct CPUInfo: Sendable, Codable {
    public let userPercent: Double
    public let systemPercent: Double
    public let idlePercent: Double
    public let loadAverage: (Double, Double, Double)
    public let coreCount: Int
    public let modelName: String

    public var usagePercent: Double { userPercent + systemPercent }

    public init(userPercent: Double, systemPercent: Double, idlePercent: Double,
                loadAverage: (Double, Double, Double), coreCount: Int, modelName: String) {
        self.userPercent = userPercent
        self.systemPercent = systemPercent
        self.idlePercent = idlePercent
        self.loadAverage = loadAverage
        self.coreCount = coreCount
        self.modelName = modelName
    }

    // Custom Codable because tuples are not Codable
    enum CodingKeys: String, CodingKey {
        case userPercent, systemPercent, idlePercent
        case loadAvg1m, loadAvg5m, loadAvg15m
        case coreCount, modelName, usagePercent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userPercent, forKey: .userPercent)
        try container.encode(systemPercent, forKey: .systemPercent)
        try container.encode(idlePercent, forKey: .idlePercent)
        try container.encode(loadAverage.0, forKey: .loadAvg1m)
        try container.encode(loadAverage.1, forKey: .loadAvg5m)
        try container.encode(loadAverage.2, forKey: .loadAvg15m)
        try container.encode(coreCount, forKey: .coreCount)
        try container.encode(modelName, forKey: .modelName)
        try container.encode(usagePercent, forKey: .usagePercent)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userPercent = try container.decode(Double.self, forKey: .userPercent)
        systemPercent = try container.decode(Double.self, forKey: .systemPercent)
        idlePercent = try container.decode(Double.self, forKey: .idlePercent)
        let l1 = try container.decode(Double.self, forKey: .loadAvg1m)
        let l5 = try container.decode(Double.self, forKey: .loadAvg5m)
        let l15 = try container.decode(Double.self, forKey: .loadAvg15m)
        loadAverage = (l1, l5, l15)
        coreCount = try container.decode(Int.self, forKey: .coreCount)
        modelName = try container.decode(String.self, forKey: .modelName)
    }
}

public struct MemoryInfo: Sendable, Codable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let wiredBytes: UInt64
    public let compressedBytes: UInt64
    public let swapUsedBytes: UInt64
    public let swapTotalBytes: UInt64

    public var usagePercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }

    public var swapPercent: Double {
        swapTotalBytes > 0 ? Double(swapUsedBytes) / Double(swapTotalBytes) * 100 : 0
    }

    public var isSwapHeavy: Bool { swapUsedBytes > 4 * 1024 * 1024 * 1024 }
    public var isPressureHigh: Bool { usagePercent > 85 }

    public init(totalBytes: UInt64, usedBytes: UInt64, wiredBytes: UInt64,
                compressedBytes: UInt64, swapUsedBytes: UInt64, swapTotalBytes: UInt64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.wiredBytes = wiredBytes
        self.compressedBytes = compressedBytes
        self.swapUsedBytes = swapUsedBytes
        self.swapTotalBytes = swapTotalBytes
    }

    enum CodingKeys: String, CodingKey {
        case totalBytes, usedBytes, wiredBytes, compressedBytes
        case swapUsedBytes, swapTotalBytes
        case usagePercent, swapPercent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalBytes, forKey: .totalBytes)
        try container.encode(usedBytes, forKey: .usedBytes)
        try container.encode(wiredBytes, forKey: .wiredBytes)
        try container.encode(compressedBytes, forKey: .compressedBytes)
        try container.encode(swapUsedBytes, forKey: .swapUsedBytes)
        try container.encode(swapTotalBytes, forKey: .swapTotalBytes)
        try container.encode(usagePercent, forKey: .usagePercent)
        try container.encode(swapPercent, forKey: .swapPercent)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalBytes = try container.decode(UInt64.self, forKey: .totalBytes)
        usedBytes = try container.decode(UInt64.self, forKey: .usedBytes)
        wiredBytes = try container.decode(UInt64.self, forKey: .wiredBytes)
        compressedBytes = try container.decode(UInt64.self, forKey: .compressedBytes)
        swapUsedBytes = try container.decode(UInt64.self, forKey: .swapUsedBytes)
        swapTotalBytes = try container.decode(UInt64.self, forKey: .swapTotalBytes)
    }
}

public struct DiskInfo: Sendable, Codable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let availableBytes: UInt64

    public var usagePercent: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
    }

    public init(totalBytes: UInt64, usedBytes: UInt64, availableBytes: UInt64) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
    }

    enum CodingKeys: String, CodingKey {
        case totalBytes, usedBytes, availableBytes, usagePercent
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalBytes, forKey: .totalBytes)
        try container.encode(usedBytes, forKey: .usedBytes)
        try container.encode(availableBytes, forKey: .availableBytes)
        try container.encode(usagePercent, forKey: .usagePercent)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalBytes = try container.decode(UInt64.self, forKey: .totalBytes)
        usedBytes = try container.decode(UInt64.self, forKey: .usedBytes)
        availableBytes = try container.decode(UInt64.self, forKey: .availableBytes)
    }
}

public struct BatteryInfo: Sendable, Codable {
    public let percentage: Int
    public let isCharging: Bool
    public let isPluggedIn: Bool
    public let cycleCount: Int
    public let health: String
    public let available: Bool

    public init(percentage: Int = 0, isCharging: Bool = false, isPluggedIn: Bool = false,
                cycleCount: Int = 0, health: String = "Unknown", available: Bool = false) {
        self.percentage = percentage
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
        self.cycleCount = cycleCount
        self.health = health
        self.available = available
    }
}

public struct ThermalInfo: Sendable, Codable {
    public enum State: String, Sendable, Codable {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
        case unknown = "Unknown"
    }
    public let state: State

    public init(state: State) {
        self.state = state
    }
}
