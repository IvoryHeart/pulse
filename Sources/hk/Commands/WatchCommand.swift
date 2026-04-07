import Foundation
import HKCore
#if canImport(Darwin)
import Darwin
#endif

enum WatchCommand {
    private static var sortByMemory = false
    private static var processLimit = 8
    private static var running = true
    private static var originalTermios = termios()

    static func run(args: [String]) {
        // Parse interval
        var interval: TimeInterval = 2.0
        if let idx = args.firstIndex(of: "-i"), idx + 1 < args.count,
           let val = Double(args[idx + 1]), val >= 0.5 {
            interval = val
        }

        // Set up terminal
        setupTerminal()
        defer { restoreTerminal() }

        // Track throughput deltas
        var lastTraffic = NetworkInfo.getTrafficStats()
        var lastTrafficTime = Date()

        // Main loop
        while running {
            let cpu = CPUMonitor.getCPUInfo()
            let memory = MemoryMonitor.getMemoryInfo()
            let disk = DiskMonitor.getDiskInfo()
            let battery = BatteryMonitor.getBatteryInfo()
            let thermal = ThermalMonitor.getThermalInfo()
            let sortBy: ProcessMonitor.SortCriteria = sortByMemory ? .memory : .cpu
            let procs = ProcessMonitor.getTopProcesses(sortBy: sortBy, limit: processLimit)
            let wifi = WiFiMonitor.getWiFiInfo()
            let traffic = NetworkInfo.getTrafficStats()
            let score = HealthScoreCalculator.calculate(
                cpu: cpu, memory: memory, disk: disk,
                thermal: thermal, battery: battery,
                topProcesses: procs
            )

            // Compute throughput
            let now = Date()
            let elapsed = now.timeIntervalSince(lastTrafficTime)
            var downPerSec: UInt64 = 0
            var upPerSec: UInt64 = 0
            if elapsed > 0 {
                let dIn = traffic.bytesIn > lastTraffic.bytesIn ? traffic.bytesIn - lastTraffic.bytesIn : 0
                let dOut = traffic.bytesOut > lastTraffic.bytesOut ? traffic.bytesOut - lastTraffic.bytesOut : 0
                downPerSec = UInt64(Double(dIn) / elapsed)
                upPerSec = UInt64(Double(dOut) / elapsed)
            }
            lastTraffic = traffic
            lastTrafficTime = now

            // Render frame
            let frame = renderFrame(
                cpu: cpu, memory: memory, disk: disk,
                battery: battery, thermal: thermal,
                score: score, procs: procs, wifi: wifi,
                downPerSec: downPerSec, upPerSec: upPerSec
            )

            // Clear screen and print
            print("\u{1B}[H\u{1B}[2J", terminator: "")
            print(frame, terminator: "")
            fflush(stdout)

            // Wait for interval, checking for keypress
            let deadline = Date().addingTimeInterval(interval)
            while Date() < deadline && running {
                if let key = checkKeypress() {
                    switch key {
                    case UInt8(ascii: "q"), 3: // q or Ctrl-C
                        running = false
                        return
                    case UInt8(ascii: "r"):
                        break // force refresh
                    case UInt8(ascii: "s"):
                        sortByMemory.toggle()
                        break
                    case UInt8(ascii: "p"):
                        processLimit = processLimit >= 15 ? 5 : processLimit + 5
                        break
                    default:
                        break
                    }
                    if key == UInt8(ascii: "r") || key == UInt8(ascii: "s") || key == UInt8(ascii: "p") {
                        break // break inner loop to refresh immediately
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    // MARK: - Rendering

    private static func renderFrame(
        cpu: CPUInfo, memory: MemoryInfo, disk: DiskInfo,
        battery: BatteryInfo, thermal: ThermalInfo,
        score: HealthScore, procs: [HKProcessInfo],
        wifi: WiFiMonitor.WiFiInfo?,
        downPerSec: UInt64, upPerSec: UInt64
    ) -> String {
        let w = getTerminalWidth()
        let inner = w - 4

        var lines: [String] = []

        // Header
        let scoreColor = score.score >= 75 ? Color.boldGreen : score.score >= 50 ? Color.boldYellow : Color.boldRed
        let scoreBar = miniGauge(percent: Double(score.score), width: 10)
        let header = "  \(TerminalUI.colored("hk watch", .boldCyan))  Health: \(TerminalUI.colored("\(score.score)/100", scoreColor)) \(scoreBar) \(TerminalUI.colored(score.rating, scoreColor))"
        lines.append(header)
        lines.append("")

        // System gauges row 1
        let cpuGauge = inlineGauge("CPU", cpu.usagePercent, width: 16)
        let memGauge = inlineGauge("Mem", memory.usagePercent, width: 16)
        lines.append("  \(cpuGauge)    \(memGauge)")

        // System gauges row 2
        let diskGauge = inlineGauge("Disk", disk.usagePercent, width: 16)
        let swapStr = "\(TerminalUI.colored("Swap", .boldWhite))  \(ByteFormatter.format(Int64(memory.swapUsedBytes))) / \(ByteFormatter.format(Int64(memory.swapTotalBytes)))"
        lines.append("  \(diskGauge)    \(swapStr)")

        // Battery & Thermal row
        var btLine = "  "
        let batPercent = battery.percentage
        let charging = battery.isCharging ? " \(TerminalUI.colored("⚡charging", .boldGreen))" : ""
        btLine += "\(TerminalUI.colored("Battery:", .boldWhite)) \(batPercent)%\(charging)"
        let thermalColor: Color = thermal.state == .critical ? .boldRed : thermal.state == .serious ? .boldRed : thermal.state == .fair ? .boldYellow : .green
        btLine += "    \(TerminalUI.colored("Thermal:", .boldWhite)) \(TerminalUI.colored(thermal.state.rawValue.capitalized, thermalColor))"
        lines.append(btLine)
        lines.append("")

        // Network row
        let downStr = "\(TerminalUI.colored("↓", .boldGreen)) \(formatSpeed(downPerSec))"
        let upStr = "\(TerminalUI.colored("↑", .boldCyan)) \(formatSpeed(upPerSec))"
        var netLine = "  \(downStr)  \(upStr)"
        if let wifi = wifi {
            let sigColor: Color = wifi.rssi > -50 ? .boldGreen : wifi.rssi > -60 ? .green : wifi.rssi > -70 ? .boldYellow : .boldRed
            let ssidStr = wifi.ssid ?? "WiFi"
            netLine += "    \(TerminalUI.colored(ssidStr, .cyan)): \(TerminalUI.colored("\(wifi.rssi) dBm", sigColor)) (\(wifi.signalQuality)) ch\(wifi.channel) \(wifi.channelBand)"
        }
        lines.append(netLine)
        lines.append("")

        // Separator
        let sep = "  " + TerminalUI.colored(String(repeating: "─", count: min(inner, 72)), .gray)
        lines.append(sep)

        // Process header
        let sortLabel = sortByMemory ? "Memory ↓" : "CPU ↓"
        let procHeader = "  \(TerminalUI.colored("PID", .gray))    \(TerminalUI.colored("Name", .gray))\(String(repeating: " ", count: 22))\(TerminalUI.colored(sortLabel == "CPU ↓" ? "CPU% ↓" : "CPU%", .gray))    \(TerminalUI.colored(sortLabel == "Memory ↓" ? "Memory ↓" : "Memory", .gray))"
        lines.append(procHeader)
        lines.append(sep)

        // Process rows
        for proc in procs {
            let pid = String(proc.pid).padding(toLength: 7, withPad: " ", startingAt: 0)
            let name = proc.shortName.padding(toLength: 26, withPad: " ", startingAt: 0)
            let cpuStr = String(format: "%5.1f%%", proc.cpuPercent)
            let cpuColor: Color = proc.cpuPercent > 50 ? .boldRed : proc.cpuPercent > 20 ? .boldYellow : .white
            let memStr = ByteFormatter.format(proc.rssBytes)
            let memColor: Color = proc.rssBytes > 2_000_000_000 ? .boldRed : proc.rssBytes > 500_000_000 ? .boldYellow : .white
            lines.append("  \(TerminalUI.colored(pid, .gray))\(TerminalUI.colored(name, .white))  \(TerminalUI.colored(cpuStr, cpuColor))    \(TerminalUI.colored(memStr.padding(toLength: 8, withPad: " ", startingAt: 0), memColor))")
        }

        lines.append(sep)

        // Footer
        let loadStr = String(format: "Load: %.2f %.2f %.2f", cpu.loadAverage.0, cpu.loadAverage.1, cpu.loadAverage.2)
        let coresStr = "Cores: \(cpu.coreCount)"
        lines.append("  \(TerminalUI.colored(loadStr, .gray))  │  \(TerminalUI.colored(coresStr, .gray))")
        lines.append("  \(TerminalUI.colored("q", .boldWhite))=quit  \(TerminalUI.colored("r", .boldWhite))=refresh  \(TerminalUI.colored("s", .boldWhite))=sort(\(sortByMemory ? "mem" : "cpu"))  \(TerminalUI.colored("p", .boldWhite))=procs(\(processLimit))")

        return lines.joined(separator: "\n")
    }

    // MARK: - Terminal Setup

    private static func setupTerminal() {
        // Save original terminal settings
        tcgetattr(STDIN_FILENO, &originalTermios)

        // Set raw mode (no echo, no canonical)
        var raw = originalTermios
        raw.c_lflag &= ~UInt(ECHO | ICANON)
        // VMIN=0, VTIME=0 for non-blocking reads
        // c_cc is a tuple in Swift; indices 16=VMIN, 17=VTIME
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            ptr.withMemoryRebound(to: UInt8.self, capacity: 20) { cc in
                cc[16] = 0  // VMIN
                cc[17] = 0  // VTIME
            }
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        // Hide cursor
        print("\u{1B}[?25l", terminator: "")
        fflush(stdout)

        // Handle SIGINT
        signal(SIGINT) { _ in
            WatchCommand.running = false
            WatchCommand.restoreTerminal()
            exit(0)
        }
    }

    private static func restoreTerminal() {
        // Show cursor
        print("\u{1B}[?25h", terminator: "")
        // Clear screen
        print("\u{1B}[2J\u{1B}[H", terminator: "")
        fflush(stdout)
        // Restore terminal settings
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &originalTermios)
    }

    private static func checkKeypress() -> UInt8? {
        var byte: UInt8 = 0
        let n = read(STDIN_FILENO, &byte, 1)
        return n > 0 ? byte : nil
    }

    private static func getTerminalWidth() -> Int {
        var ws = winsize()
        if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 {
            return Int(ws.ws_col)
        }
        return 80
    }

    // MARK: - Helpers

    private static func inlineGauge(_ label: String, _ percent: Double, width: Int) -> String {
        let filled = Int((percent / 100.0) * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: max(0, min(filled, width))) + String(repeating: "░", count: max(0, empty))
        let color: Color = percent >= 90 ? .boldRed : percent >= 70 ? .boldYellow : .boldGreen
        let pctStr = String(format: "%4.1f%%", percent)
        return "\(TerminalUI.colored(label.padding(toLength: 4, withPad: " ", startingAt: 0), .boldWhite)) \(TerminalUI.colored(bar, color)) \(TerminalUI.colored(pctStr, color))"
    }

    private static func miniGauge(percent: Double, width: Int) -> String {
        let filled = Int((percent / 100.0) * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: max(0, min(filled, width))) + String(repeating: "░", count: max(0, empty))
        let color: Color = percent >= 90 ? .boldRed : percent >= 70 ? .boldYellow : .boldGreen
        return "[\(TerminalUI.colored(bar, color))]"
    }

    private static func formatSpeed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec > 1_000_000 {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_000_000.0)
        } else if bytesPerSec > 1_000 {
            return String(format: "%.1f KB/s", Double(bytesPerSec) / 1_000.0)
        }
        return "\(bytesPerSec) B/s"
    }
}
