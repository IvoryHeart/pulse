import Foundation
import Darwin

public struct CPUMonitor {

    public static func getCPUInfo() -> CPUInfo {
        let loadAvg = getLoadAverages()
        let modelName = runCommand("/usr/sbin/sysctl", arguments: ["-n", "machdep.cpu.brand_string"])
        let coreCountStr = runCommand("/usr/sbin/sysctl", arguments: ["-n", "hw.ncpu"])
        let coreCount = Int(coreCountStr) ?? 1

        let (user, system, idle) = getCPUUsageViaMach()

        return CPUInfo(
            userPercent: user,
            systemPercent: system,
            idlePercent: idle,
            loadAverage: loadAvg,
            coreCount: coreCount,
            modelName: modelName
        )
    }

    private static func getLoadAverages() -> (Double, Double, Double) {
        var loadavg: [Double] = [0, 0, 0]
        if getloadavg(&loadavg, 3) == 3 {
            return (loadavg[0], loadavg[1], loadavg[2])
        }
        return (0, 0, 0)
    }

    private static func getCPUUsageViaMach() -> (user: Double, system: Double, idle: Double) {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return (0, 0, 100)
        }

        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        for i in 0..<Int(cpuCount) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(info[offset + Int(CPU_STATE_USER)])
            let system = Double(info[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(info[offset + Int(CPU_STATE_NICE)])
            totalUser += user + nice
            totalSystem += system
            totalIdle += idle
        }

        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return (0, 0, 100) }

        // Deallocate
        let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)

        return (
            totalUser / total * 100,
            totalSystem / total * 100,
            totalIdle / total * 100
        )
    }

    private static func runCommand(_ command: String, arguments: [String] = []) -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
