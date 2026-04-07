import Testing
import Foundation
@testable import PulseCore

// MARK: - Test Helpers

private func makeCPU(
    userPercent: Double = 10,
    systemPercent: Double = 5,
    idlePercent: Double = 85,
    loadAverage: (Double, Double, Double) = (1.0, 1.0, 1.0),
    coreCount: Int = 8,
    modelName: String = "Apple M1"
) -> CPUInfo {
    CPUInfo(userPercent: userPercent, systemPercent: systemPercent,
            idlePercent: idlePercent, loadAverage: loadAverage,
            coreCount: coreCount, modelName: modelName)
}

private func makeMemory(
    totalBytes: UInt64 = 16_000_000_000,
    usedBytes: UInt64 = 4_000_000_000,
    wiredBytes: UInt64 = 1_000_000_000,
    compressedBytes: UInt64 = 500_000_000,
    swapUsedBytes: UInt64 = 0,
    swapTotalBytes: UInt64 = 4_000_000_000
) -> MemoryInfo {
    MemoryInfo(totalBytes: totalBytes, usedBytes: usedBytes,
               wiredBytes: wiredBytes, compressedBytes: compressedBytes,
               swapUsedBytes: swapUsedBytes, swapTotalBytes: swapTotalBytes)
}

private func makeDisk(
    totalBytes: UInt64 = 500_000_000_000,
    usedBytes: UInt64 = 200_000_000_000,
    availableBytes: UInt64 = 300_000_000_000
) -> DiskInfo {
    DiskInfo(totalBytes: totalBytes, usedBytes: usedBytes, availableBytes: availableBytes)
}

private func makeBattery(
    percentage: Int = 80,
    isCharging: Bool = false,
    isPluggedIn: Bool = false,
    cycleCount: Int = 100,
    health: String = "100%",
    available: Bool = true
) -> BatteryInfo {
    BatteryInfo(percentage: percentage, isCharging: isCharging, isPluggedIn: isPluggedIn,
                cycleCount: cycleCount, health: health, available: available)
}

private func makeThermal(state: ThermalInfo.State = .nominal) -> ThermalInfo {
    ThermalInfo(state: state)
}

private func makeProcess(
    pid: Int32 = 1,
    name: String = "/usr/sbin/test",
    cpuPercent: Double = 1.0,
    memPercent: Double = 0.5,
    rssBytes: UInt64 = 50_000_000
) -> PulseProcessInfo {
    PulseProcessInfo(pid: pid, name: name, cpuPercent: cpuPercent,
                  memPercent: memPercent, rssBytes: rssBytes)
}

private func calculateScore(
    cpu: CPUInfo? = nil,
    memory: MemoryInfo? = nil,
    disk: DiskInfo? = nil,
    thermal: ThermalInfo? = nil,
    battery: BatteryInfo? = nil,
    topProcesses: [PulseProcessInfo]? = nil
) -> HealthScore {
    HealthScoreCalculator.calculate(
        cpu: cpu ?? makeCPU(),
        memory: memory ?? makeMemory(),
        disk: disk ?? makeDisk(),
        thermal: thermal ?? makeThermal(),
        battery: battery ?? makeBattery(),
        topProcesses: topProcesses ?? []
    )
}

// MARK: - HealthScoreCalculator Tests

@Suite("HealthScoreCalculator")
struct HealthScoreCalculatorTests {

    @Test("Perfect system scores near 100")
    func perfectSystem() {
        // Low CPU (load 1.0 on 8 cores = 0.125 ratio), 25% memory, 40% disk,
        // nominal thermal, healthy battery, no heavy processes
        let score = calculateScore()
        #expect(score.score >= 95)
        #expect(score.score <= 100)
        #expect(score.deductions.isEmpty)
    }

    @Test("High CPU load causes penalty")
    func highCPULoad() {
        // loadAvg 8.0 on 8 cores = ratio 1.0, which is > 0.7
        let cpu = makeCPU(loadAverage: (8.0, 6.0, 5.0), coreCount: 8)
        let score = calculateScore(cpu: cpu)
        let cpuDeductions = score.deductions.filter { $0.category == "CPU" }
        #expect(!cpuDeductions.isEmpty)
        #expect(cpuDeductions[0].penalty >= 1)
        #expect(cpuDeductions[0].penalty <= 15)
        #expect(score.score < 100)
    }

    @Test("CPU penalty maxes at 15")
    func cpuPenaltyMax() {
        // Extremely high load: 40.0 on 8 cores = ratio 5.0
        let cpu = makeCPU(loadAverage: (40.0, 30.0, 20.0), coreCount: 8)
        let score = calculateScore(cpu: cpu)
        let cpuDeductions = score.deductions.filter { $0.category == "CPU" }
        #expect(cpuDeductions.count == 1)
        #expect(cpuDeductions[0].penalty == 15)
    }

    @Test("No CPU penalty when load ratio <= 0.7")
    func noCPUPenalty() {
        // loadAvg 5.6 on 8 cores = ratio 0.7, exactly at boundary (not >0.7)
        let cpu = makeCPU(loadAverage: (5.6, 4.0, 3.0), coreCount: 8)
        let score = calculateScore(cpu: cpu)
        let cpuDeductions = score.deductions.filter { $0.category == "CPU" }
        #expect(cpuDeductions.isEmpty)
    }

    @Test("Memory penalty at 65% usage")
    func memoryPenalty65() {
        // 65% used: 10.4GB of 16GB
        let mem = makeMemory(totalBytes: 16_000_000_000, usedBytes: 10_400_000_000)
        let score = calculateScore(memory: mem)
        let memDeductions = score.deductions.filter { $0.category == "Memory" && $0.label == "High memory usage" }
        #expect(!memDeductions.isEmpty)
        #expect(memDeductions[0].penalty >= 1)
    }

    @Test("Memory penalty scales at 80% usage")
    func memoryPenalty80() {
        // 80% used: 12.8GB of 16GB
        let mem = makeMemory(totalBytes: 16_000_000_000, usedBytes: 12_800_000_000)
        let score = calculateScore(memory: mem)
        let memDeductions = score.deductions.filter { $0.category == "Memory" && $0.label == "High memory usage" }
        #expect(!memDeductions.isEmpty)
        // (80 - 60) / 35 * 15 = 8.57 -> penalty 8
        #expect(memDeductions[0].penalty >= 8)
    }

    @Test("Memory penalty scales at 95% usage")
    func memoryPenalty95() {
        // 95% used: 15.2GB of 16GB
        let mem = makeMemory(totalBytes: 16_000_000_000, usedBytes: 15_200_000_000)
        let score = calculateScore(memory: mem)
        let memDeductions = score.deductions.filter { $0.category == "Memory" && $0.label == "High memory usage" }
        #expect(!memDeductions.isEmpty)
        // (95 - 60) / 35 * 15 = 15.0 -> penalty 15
        #expect(memDeductions[0].penalty == 15)
    }

    @Test("No memory penalty when usage <= 60%")
    func noMemoryPenalty() {
        // 25% usage
        let mem = makeMemory(totalBytes: 16_000_000_000, usedBytes: 4_000_000_000)
        let score = calculateScore(memory: mem)
        let memDeductions = score.deductions.filter { $0.category == "Memory" && $0.label == "High memory usage" }
        #expect(memDeductions.isEmpty)
    }

    @Test("Heavy swap causes penalty")
    func heavySwapPenalty() {
        // 3GB swap (> 2GB threshold)
        let swapBytes: UInt64 = 3 * 1024 * 1024 * 1024
        let mem = makeMemory(swapUsedBytes: swapBytes, swapTotalBytes: 8_000_000_000)
        let score = calculateScore(memory: mem)
        let swapDeductions = score.deductions.filter { $0.label == "Heavy swap usage" }
        #expect(!swapDeductions.isEmpty)
        // penalty = min(Int(3.0 - 1.0), 5) = min(2, 5) = 2
        #expect(swapDeductions[0].penalty == 2)
    }

    @Test("No swap penalty when swap <= 2GB")
    func noSwapPenalty() {
        let swapBytes: UInt64 = 1 * 1024 * 1024 * 1024
        let mem = makeMemory(swapUsedBytes: swapBytes, swapTotalBytes: 8_000_000_000)
        let score = calculateScore(memory: mem)
        let swapDeductions = score.deductions.filter { $0.label == "Heavy swap usage" }
        #expect(swapDeductions.isEmpty)
    }

    @Test("Disk penalty at 75% usage")
    func diskPenalty75() {
        // 75% used
        let disk = makeDisk(totalBytes: 500_000_000_000, usedBytes: 375_000_000_000, availableBytes: 125_000_000_000)
        let score = calculateScore(disk: disk)
        let diskDeductions = score.deductions.filter { $0.category == "Disk" }
        #expect(!diskDeductions.isEmpty)
        // (75 - 70) / 25 * 15 = 3 -> penalty 3
        #expect(diskDeductions[0].penalty >= 1)
    }

    @Test("Disk penalty at 90% usage")
    func diskPenalty90() {
        let disk = makeDisk(totalBytes: 500_000_000_000, usedBytes: 450_000_000_000, availableBytes: 50_000_000_000)
        let score = calculateScore(disk: disk)
        let diskDeductions = score.deductions.filter { $0.category == "Disk" }
        #expect(!diskDeductions.isEmpty)
        // (90 - 70) / 25 * 15 = 12 -> penalty 12
        #expect(diskDeductions[0].penalty == 12)
    }

    @Test("No disk penalty when usage <= 70%")
    func noDiskPenalty() {
        let disk = makeDisk(totalBytes: 500_000_000_000, usedBytes: 300_000_000_000, availableBytes: 200_000_000_000)
        let score = calculateScore(disk: disk)
        let diskDeductions = score.deductions.filter { $0.category == "Disk" }
        #expect(diskDeductions.isEmpty)
    }

    @Test("Thermal nominal causes no penalty")
    func thermalNominal() {
        let score = calculateScore(thermal: makeThermal(state: .nominal))
        let thermalDeductions = score.deductions.filter { $0.category == "Thermal" }
        #expect(thermalDeductions.isEmpty)
    }

    @Test("Thermal fair causes -5 penalty")
    func thermalFair() {
        let score = calculateScore(thermal: makeThermal(state: .fair))
        let thermalDeductions = score.deductions.filter { $0.category == "Thermal" }
        #expect(thermalDeductions.count == 1)
        #expect(thermalDeductions[0].penalty == 5)
    }

    @Test("Thermal serious causes -12 penalty")
    func thermalSerious() {
        let score = calculateScore(thermal: makeThermal(state: .serious))
        let thermalDeductions = score.deductions.filter { $0.category == "Thermal" }
        #expect(thermalDeductions.count == 1)
        #expect(thermalDeductions[0].penalty == 12)
    }

    @Test("Thermal critical causes -15 penalty")
    func thermalCritical() {
        let score = calculateScore(thermal: makeThermal(state: .critical))
        let thermalDeductions = score.deductions.filter { $0.category == "Thermal" }
        #expect(thermalDeductions.count == 1)
        #expect(thermalDeductions[0].penalty == 15)
    }

    @Test("Battery wear with high cycles")
    func batteryHighCycles() {
        let battery = makeBattery(cycleCount: 800, health: "100%", available: true)
        let score = calculateScore(battery: battery)
        let batteryDeductions = score.deductions.filter { $0.category == "Battery" }
        #expect(!batteryDeductions.isEmpty)
        // (800 - 500) / 100 = 3 -> cyclePenalty = 3
        #expect(batteryDeductions[0].penalty >= 3)
    }

    @Test("Battery wear with low health")
    func batteryLowHealth() {
        let battery = makeBattery(cycleCount: 100, health: "75%", available: true)
        let score = calculateScore(battery: battery)
        let batteryDeductions = score.deductions.filter { $0.category == "Battery" }
        #expect(!batteryDeductions.isEmpty)
        // healthPct = 75, (90 - 75) / 5 = 3
        #expect(batteryDeductions[0].penalty == 3)
    }

    @Test("Battery high cycles and low health combined")
    func batteryCombinedWear() {
        let battery = makeBattery(cycleCount: 900, health: "70%", available: true)
        let score = calculateScore(battery: battery)
        let batteryDeductions = score.deductions.filter { $0.category == "Battery" }
        #expect(!batteryDeductions.isEmpty)
        // cyclePenalty = min(Int((900-500)/100), 5) = min(4, 5) = 4
        // healthPenalty = min((90-70)/5, 5) = min(4, 5) = 4
        // total = min(4 + 4, 10) = 8
        #expect(batteryDeductions[0].penalty == 8)
    }

    @Test("No battery penalty when not available")
    func batteryNotAvailable() {
        let battery = makeBattery(cycleCount: 900, health: "70%", available: false)
        let score = calculateScore(battery: battery)
        let batteryDeductions = score.deductions.filter { $0.category == "Battery" }
        #expect(batteryDeductions.isEmpty)
    }

    @Test("No battery penalty with healthy battery")
    func batteryHealthy() {
        let battery = makeBattery(cycleCount: 100, health: "100%", available: true)
        let score = calculateScore(battery: battery)
        let batteryDeductions = score.deductions.filter { $0.category == "Battery" }
        #expect(batteryDeductions.isEmpty)
    }

    @Test("Process outlier with >50% CPU causes penalty")
    func processOutlierCPU() {
        let procs = [
            makeProcess(name: "/Applications/Safari.app/Contents/MacOS/Safari", cpuPercent: 75.0)
        ]
        let score = calculateScore(topProcesses: procs)
        let procDeductions = score.deductions.filter { $0.category == "Processes" }
        #expect(!procDeductions.isEmpty)
        // 1 issue * 3 = 3
        #expect(procDeductions[0].penalty == 3)
    }

    @Test("Process outlier with >3GB RAM causes penalty")
    func processOutlierRAM() {
        let bigRSS: UInt64 = 4 * 1024 * 1024 * 1024  // 4 GB
        let procs = [
            makeProcess(name: "/usr/sbin/heavy", cpuPercent: 5.0, rssBytes: bigRSS)
        ]
        let score = calculateScore(topProcesses: procs)
        let procDeductions = score.deductions.filter { $0.category == "Processes" }
        #expect(!procDeductions.isEmpty)
        #expect(procDeductions[0].penalty == 3)
    }

    @Test("Multiple process issues capped at 10")
    func processIssuesCapped() {
        // 5 processes each with >50% CPU and >3GB RAM -> 10 issues, penalty = min(10*3, 10) = 10
        let procs = (0..<5).map { i in
            makeProcess(pid: Int32(i), name: "/usr/sbin/heavy\(i)",
                        cpuPercent: 80.0, rssBytes: 4 * 1024 * 1024 * 1024)
        }
        let score = calculateScore(topProcesses: procs)
        let procDeductions = score.deductions.filter { $0.category == "Processes" }
        #expect(!procDeductions.isEmpty)
        #expect(procDeductions[0].penalty == 10)
    }

    @Test("Combined deductions don't go below 0")
    func combinedDeductionsBounded() {
        // Max everything bad
        let cpu = makeCPU(loadAverage: (40.0, 30.0, 20.0), coreCount: 8) // -15
        let mem = makeMemory(totalBytes: 16_000_000_000, usedBytes: 15_200_000_000,
                             swapUsedBytes: 8 * 1024 * 1024 * 1024, swapTotalBytes: 16_000_000_000) // -15 mem + -5 swap
        let disk = makeDisk(totalBytes: 500_000_000_000, usedBytes: 490_000_000_000,
                            availableBytes: 10_000_000_000) // -15
        let thermal = makeThermal(state: .critical) // -15
        let battery = makeBattery(cycleCount: 1200, health: "60%", available: true) // -10
        let procs = (0..<5).map { i in
            makeProcess(pid: Int32(i), name: "/usr/sbin/heavy\(i)",
                        cpuPercent: 90.0, rssBytes: 5 * 1024 * 1024 * 1024)
        } // -10

        let score = calculateScore(cpu: cpu, memory: mem, disk: disk,
                                   thermal: thermal, battery: battery, topProcesses: procs)
        #expect(score.score >= 0)
        #expect(score.score <= 100)
    }
}

// MARK: - HealthScore rating/color tests

@Suite("HealthScore rating and color")
struct HealthScoreRatingTests {

    @Test("Score 100 rating is Excellent")
    func rating100() {
        let score = HealthScore(score: 100, deductions: [])
        #expect(score.rating == "Excellent")
    }

    @Test("Score 95 rating is Excellent")
    func rating95() {
        let score = HealthScore(score: 95, deductions: [])
        #expect(score.rating == "Excellent")
    }

    @Test("Score 90 rating is Excellent")
    func rating90() {
        let score = HealthScore(score: 90, deductions: [])
        #expect(score.rating == "Excellent")
    }

    @Test("Score 89 rating is Good")
    func rating89() {
        let score = HealthScore(score: 89, deductions: [])
        #expect(score.rating == "Good")
    }

    @Test("Score 75 rating is Good")
    func rating75() {
        let score = HealthScore(score: 75, deductions: [])
        #expect(score.rating == "Good")
    }

    @Test("Score 74 rating is Fair")
    func rating74() {
        let score = HealthScore(score: 74, deductions: [])
        #expect(score.rating == "Fair")
    }

    @Test("Score 50 rating is Fair")
    func rating50() {
        let score = HealthScore(score: 50, deductions: [])
        #expect(score.rating == "Fair")
    }

    @Test("Score 49 rating is Poor")
    func rating49() {
        let score = HealthScore(score: 49, deductions: [])
        #expect(score.rating == "Poor")
    }

    @Test("Score 25 rating is Poor")
    func rating25() {
        let score = HealthScore(score: 25, deductions: [])
        #expect(score.rating == "Poor")
    }

    @Test("Score 24 rating is Critical")
    func rating24() {
        let score = HealthScore(score: 24, deductions: [])
        #expect(score.rating == "Critical")
    }

    @Test("Score 0 rating is Critical")
    func rating0() {
        let score = HealthScore(score: 0, deductions: [])
        #expect(score.rating == "Critical")
    }

    @Test("Score 100 color is green")
    func color100() {
        let score = HealthScore(score: 100, deductions: [])
        #expect(score.ratingColor == "green")
    }

    @Test("Score 75 color is green")
    func color75() {
        let score = HealthScore(score: 75, deductions: [])
        #expect(score.ratingColor == "green")
    }

    @Test("Score 74 color is orange")
    func color74() {
        let score = HealthScore(score: 74, deductions: [])
        #expect(score.ratingColor == "orange")
    }

    @Test("Score 50 color is orange")
    func color50() {
        let score = HealthScore(score: 50, deductions: [])
        #expect(score.ratingColor == "orange")
    }

    @Test("Score 49 color is red")
    func color49() {
        let score = HealthScore(score: 49, deductions: [])
        #expect(score.ratingColor == "red")
    }

    @Test("Score 0 color is red")
    func color0() {
        let score = HealthScore(score: 0, deductions: [])
        #expect(score.ratingColor == "red")
    }

    @Test("Score is clamped to max 100")
    func clampedMax() {
        let score = HealthScore(score: 150, deductions: [])
        #expect(score.score == 100)
    }

    @Test("Score is clamped to min 0")
    func clampedMin() {
        let score = HealthScore(score: -50, deductions: [])
        #expect(score.score == 0)
    }
}
