import SwiftUI
import HKCore

struct MenuBarView: View {
    @ObservedObject var viewModel: SystemViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with health score
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(headerColor)
                Text("Housekeeping")
                    .font(.headline)
                Spacer()
                if let score = viewModel.healthScore {
                    Text("\(score.score)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor(score.score))
                    Text("/100")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                }
            }
            .padding(.bottom, 4)

            if let cpu = viewModel.cpu, let memory = viewModel.memory {
                // Gauges row
                HStack(spacing: 16) {
                    miniGauge("CPU", percent: cpu.usagePercent, color: gaugeColor(cpu.usagePercent))
                    miniGauge("Mem", percent: memory.usagePercent, color: gaugeColor(memory.usagePercent, warn: 80, crit: 95))
                    if let disk = viewModel.disk {
                        miniGauge("Disk", percent: disk.usagePercent, color: gaugeColor(disk.usagePercent, warn: 80, crit: 95))
                    }
                    if let battery = viewModel.battery, battery.available {
                        miniGauge("Batt", percent: Double(battery.percentage), color: batteryColor(battery.percentage))
                    }
                }

                // Sparklines
                if viewModel.cpuHistory.count > 2 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CPU")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        SparklineView(values: viewModel.cpuHistory, color: .blue)
                            .frame(height: 24)
                    }
                }

                // WiFi & Throughput section
                if let wifi = viewModel.wifiInfo {
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: wifiIcon(wifi.rssi))
                            .foregroundColor(wifiColor(wifi.rssi))
                            .font(.system(size: 12))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(wifi.ssid ?? "WiFi")
                                .font(.system(size: 11, weight: .medium))
                            Text("\(wifi.signalQuality) · \(wifi.channelBand) · Ch \(wifi.channel)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue)
                                Text(formatSpeed(viewModel.bytesInPerSec))
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                                Text(formatSpeed(viewModel.bytesOutPerSec))
                                    .font(.system(size: 10, design: .monospaced))
                            }
                        }
                    }
                }

                Divider()

                // Top processes
                VStack(alignment: .leading, spacing: 3) {
                    Text("Top Processes")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    ForEach(Array(viewModel.topProcesses.prefix(5).enumerated()), id: \.offset) { _, proc in
                        HStack {
                            Text(proc.shortName)
                                .lineLimit(1)
                                .font(.system(size: 11))
                            Spacer()
                            Text(String(format: "%.0f%%", proc.cpuPercent))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(proc.cpuPercent > 50 ? .red : proc.cpuPercent > 20 ? .orange : .secondary)
                            Text(proc.rssFormatted)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(width: 55, alignment: .trailing)
                        }
                    }
                }

                // Warnings
                if let memory = viewModel.memory, memory.isSwapHeavy {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text("Swap: \(ByteFormatter.format(memory.swapUsedBytes))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }

                if let thermal = viewModel.thermal,
                   thermal.state == .serious || thermal.state == .critical {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        Text("Thermal: \(thermal.state.rawValue)")
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }
            }

            Divider()

            // Actions
            Button("Open Dashboard") {
                openWindow(id: "dashboard")
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            viewModel.startMonitoring(interval: 3.0)
        }
    }

    // MARK: - Helpers

    private var headerColor: Color {
        if let score = viewModel.healthScore { return scoreColor(score.score) }
        guard let cpu = viewModel.cpu, let memory = viewModel.memory else { return .gray }
        if cpu.usagePercent > 80 || memory.usagePercent > 95 { return .red }
        if cpu.usagePercent > 50 || memory.usagePercent > 85 { return .orange }
        return .green
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func miniGauge(_ label: String, percent: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: min(percent / 100, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(percent))")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func gaugeColor(_ percent: Double, warn: Double = 70, crit: Double = 90) -> Color {
        if percent >= crit { return .red }
        if percent >= warn { return .orange }
        return .green
    }

    private func batteryColor(_ percent: Int) -> Color {
        if percent < 15 { return .red }
        if percent < 30 { return .orange }
        return .green
    }

    private func wifiIcon(_ rssi: Int) -> String {
        if rssi > -50 { return "wifi" }
        if rssi > -60 { return "wifi" }
        if rssi > -70 { return "wifi.exclamationmark" }
        return "wifi.slash"
    }

    private func wifiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -60 { return .blue }
        if rssi > -70 { return .orange }
        return .red
    }

    private func formatSpeed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec > 1_000_000 {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_000_000.0)
        } else if bytesPerSec > 1_000 {
            return String(format: "%.0f KB/s", Double(bytesPerSec) / 1_000.0)
        }
        return "\(bytesPerSec) B/s"
    }
}
