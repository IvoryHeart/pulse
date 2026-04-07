import SwiftUI
import Charts
import HKCore

struct DashboardView: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        TabView {
            SystemTab(viewModel: viewModel)
                .tabItem {
                    Label("System", systemImage: "heart.fill")
                }

            NetworkTab(viewModel: viewModel)
                .tabItem {
                    Label("Network", systemImage: "wifi")
                }

            DevicesTab(viewModel: viewModel)
                .tabItem {
                    Label("Devices", systemImage: "laptopcomputer.and.iphone")
                }

            InsightsTab(viewModel: viewModel)
                .tabItem {
                    Label("Insights", systemImage: "lightbulb")
                }
        }
        .tabViewStyle(.automatic)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.startMonitoring(interval: 3.0)
        }
    }
}

// MARK: - Tab 1: System

private struct SystemTab: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with score badge
                headerSection

                // Gauges row
                gaugesSection

                // Charts
                HStack(spacing: 16) {
                    chartCard("CPU Usage", values: viewModel.cpuHistory, color: .blue, suffix: "%")
                    chartCard("Memory Usage", values: viewModel.memHistory, color: .purple, suffix: "%")
                }
                .padding(.horizontal)

                // Swap & System Info
                systemInfoSection

                // Storage & Cleanup
                storageCleanupSection

                // Process list
                VStack(alignment: .leading) {
                    Text("Top Processes")
                        .font(.headline)
                        .padding(.horizontal)
                    ProcessListView(processes: viewModel.topProcesses)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                        .shadow(color: .black.opacity(0.05), radius: 4)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundColor(scoreHeaderColor)
                .font(.title2)
            Text("Housekeeping")
                .font(.title2.bold())
            Spacer()

            if let score = viewModel.healthScore {
                HStack(spacing: 4) {
                    Text("\(score.score)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(scoreHeaderColor)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("/100")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(score.rating)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(scoreHeaderColor)
                    }
                }
            }

            if let thermal = viewModel.thermal {
                thermalBadge(thermal)
            }
            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Gauges

    @ViewBuilder
    private var gaugesSection: some View {
        if let cpu = viewModel.cpu, let memory = viewModel.memory,
           let disk = viewModel.disk {
            HStack(spacing: 24) {
                CircularGaugeView(
                    title: "CPU",
                    value: cpu.usagePercent,
                    maxValue: 100,
                    detail: String(format: "%.0f%% user, %.0f%% sys", cpu.userPercent, cpu.systemPercent)
                )
                CircularGaugeView(
                    title: "Memory",
                    value: memory.usagePercent,
                    maxValue: 100,
                    detail: "\(ByteFormatter.format(memory.usedBytes)) / \(ByteFormatter.format(memory.totalBytes))",
                    warnAt: 80, critAt: 95
                )
                CircularGaugeView(
                    title: "Disk",
                    value: disk.usagePercent,
                    maxValue: 100,
                    detail: "\(ByteFormatter.format(disk.usedBytes)) / \(ByteFormatter.format(disk.totalBytes))",
                    warnAt: 80, critAt: 95
                )
                if let battery = viewModel.battery, battery.available {
                    CircularGaugeView(
                        title: "Battery",
                        value: Double(battery.percentage),
                        maxValue: 100,
                        detail: battery.isPluggedIn ? "Plugged In" : "Battery",
                        warnAt: 999, critAt: 999
                    )
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .shadow(color: .black.opacity(0.05), radius: 4)
        }
    }

    // MARK: - System Info

    @ViewBuilder
    private var systemInfoSection: some View {
        if let memory = viewModel.memory, let cpu = viewModel.cpu {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("System Info")
                        .font(.headline)
                    infoRow("CPU", cpu.modelName)
                    infoRow("Cores", "\(cpu.coreCount)")
                    infoRow("Load Avg", String(format: "%.1f  %.1f  %.1f", cpu.loadAverage.0, cpu.loadAverage.1, cpu.loadAverage.2))
                    infoRow("Wired Mem", ByteFormatter.format(memory.wiredBytes))
                    infoRow("Compressed", ByteFormatter.format(memory.compressedBytes))
                    if memory.swapUsedBytes > 0 {
                        infoRow("Swap", "\(ByteFormatter.format(memory.swapUsedBytes)) / \(ByteFormatter.format(memory.swapTotalBytes))")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(.background))
                .shadow(color: .black.opacity(0.05), radius: 4)

                warningsCard(memory: memory)
            }
            .padding(.horizontal)
        }
    }

    private func warningsCard(memory: MemoryInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Warnings")
                .font(.headline)

            if memory.isSwapHeavy {
                warningRow("Swap is heavy: \(ByteFormatter.format(memory.swapUsedBytes))", .orange)
            }
            if memory.isPressureHigh {
                warningRow("Memory pressure HIGH", .red)
            }
            if let thermal = viewModel.thermal,
               thermal.state == .serious || thermal.state == .critical {
                warningRow("Thermal: \(thermal.state.rawValue)", .red)
            }

            let heavyCpuProcs = viewModel.topProcesses.prefix(2).filter { $0.cpuPercent > 80 }
            ForEach(Array(heavyCpuProcs.enumerated()), id: \.offset) { _, proc in
                warningRow("\(proc.shortName): \(Int(proc.cpuPercent))% CPU", .orange)
            }

            if !memory.isSwapHeavy && !memory.isPressureHigh {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("System looks healthy")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }

    // MARK: - Storage & Cleanup

    @ViewBuilder
    private var storageCleanupSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.orange)
                    Text("Storage & Cleanup")
                        .font(.headline)
                    Spacer()

                    if viewModel.isScanning {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Button(action: { viewModel.scanCleanup() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Disk usage bar
                if let disk = viewModel.disk {
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            let usedFraction = disk.usagePercent / 100.0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.15))
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(diskBarColor(disk.usagePercent))
                                    .frame(width: geo.size.width * usedFraction)
                            }
                        }
                        .frame(height: 12)

                        HStack {
                            Text("\(ByteFormatter.format(disk.usedBytes)) used")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(ByteFormatter.format(disk.availableBytes)) available")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Divider()

                // Cleanup results
                if let report = viewModel.cleanupReport {
                    if report.items.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Nothing significant to clean up")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Text("Reclaimable Space")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            Text(ByteFormatter.format(report.totalReclaimableBytes))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }

                        ForEach(Array(report.items.enumerated()), id: \.offset) { _, item in
                            HStack {
                                categoryIcon(item.category)
                                    .frame(width: 14)
                                Text(item.description)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Spacer()
                                Text(ByteFormatter.format(item.sizeBytes))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(
                                        item.sizeBytes > 1_073_741_824 ? .red :
                                        item.sizeBytes > 104_857_600 ? .orange : .secondary
                                    )
                            }
                            .padding(.vertical, 1)
                        }

                        Divider()

                        HStack(spacing: 4) {
                            Image(systemName: "terminal")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("Run")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text("hk clean --confirm")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(.blue)
                            Text("in Terminal to clean")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                } else if !viewModel.isScanning {
                    Button("Scan for Cleanup") {
                        viewModel.scanCleanup()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 4)
        .padding(.horizontal)
        .onAppear {
            if viewModel.cleanupReport == nil {
                viewModel.scanCleanup()
            }
        }
    }

    private func categoryIcon(_ category: String) -> some View {
        let (icon, color): (String, Color) = switch category {
            case "Caches": ("folder.badge.gearshape", .blue)
            case "Logs": ("doc.text", .purple)
            case "Dev": ("hammer", .orange)
            case "Downloads": ("arrow.down.circle", .green)
            case "Trash": ("trash", .red)
            default: ("folder", .gray)
        }
        return Image(systemName: icon)
            .font(.system(size: 10))
            .foregroundColor(color)
    }

    private func diskBarColor(_ percent: Double) -> Color {
        if percent >= 90 { return .red }
        if percent >= 75 { return .orange }
        return .blue
    }

    // MARK: - Helpers

    private var scoreHeaderColor: Color {
        guard let score = viewModel.healthScore else { return .green }
        if score.score >= 75 { return .green }
        if score.score >= 50 { return .orange }
        return .red
    }

    private func thermalBadge(_ thermal: ThermalInfo) -> some View {
        let color: Color = switch thermal.state {
            case .nominal: .green
            case .fair: .orange
            case .serious: .red
            case .critical: .red
            case .unknown: .gray
        }
        return Text(thermal.state.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func chartCard(_ title: String, values: [Double], color: Color, suffix: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let last = values.last {
                    Text(String(format: "%.0f%@", last, suffix))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }

            if values.count > 2 {
                Chart {
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        LineMark(
                            x: .value("Time", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(color.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Value", value)
                        )
                        .foregroundStyle(color.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 8))
                        }
                    }
                }
                .frame(height: 80)
            } else {
                Text("Collecting data...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 80)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Tab 2: Network

private struct NetworkTab: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // WiFi Signal + Throughput side by side
                HStack(alignment: .top, spacing: 16) {
                    wifiSignalCard
                    throughputCard
                }
                .padding(.horizontal)

                // Active connections + Interfaces side by side
                HStack(alignment: .top, spacing: 16) {
                    activeConnectionsCard
                    interfacesCard
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - WiFi Signal Card

    private var wifiSignalCard: some View {
        CardView {
            if let wifi = viewModel.wifiInfo {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "wifi")
                            .foregroundColor(wifiColor(wifi.rssi))
                        Text("WiFi Signal")
                            .font(.headline)
                        Spacer()
                        signalQualityBadge(wifi.signalQuality)
                    }

                    // Large circular gauge for signal quality
                    let signalPercent = wifiSignalPercent(wifi.rssi)
                    CircularGaugeView(
                        title: wifi.ssid ?? "Connected",
                        value: signalPercent,
                        maxValue: 100,
                        detail: "\(wifi.rssi) dBm",
                        warnAt: 999, critAt: 999
                    )

                    // Detail rows below the gauge
                    VStack(alignment: .leading, spacing: 4) {
                        detailRow("SNR", value: "\(wifi.snr) dB", barValue: Double(wifi.snr), barMax: 50, barColor: snrColor(wifi.snr))
                        detailRow("Channel", value: "\(wifi.channel) (\(wifi.channelBand))")
                        detailRow("Width", value: "\(wifi.channelWidth) MHz")
                        detailRow("PHY", value: wifi.phyMode)
                        detailRow("Tx Rate", value: String(format: "%.0f Mbps", wifi.transmitRate))
                    }

                    // Signal history sparkline
                    if viewModel.rssiHistory.count > 2 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signal History")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            SparklineView(values: viewModel.rssiHistory, color: wifiColor(wifi.rssi))
                                .frame(height: 30)
                        }
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "wifi.slash")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("WiFi Disconnected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("No WiFi connection detected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
            }
        }
    }

    // MARK: - Throughput Card

    private var throughputCard: some View {
        CardView {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.blue)
                    Text("Throughput")
                        .font(.headline)
                    Spacer()
                }

                // Large speed numbers
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text(formatSpeed(viewModel.bytesInPerSec))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Text("Download")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                        Text(formatSpeed(viewModel.bytesOutPerSec))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                        Text("Upload")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Area chart with download/upload overlaid
                if viewModel.downloadHistory.count > 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(.blue).frame(width: 6, height: 6)
                                Text("Down").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(.orange).frame(width: 6, height: 6)
                                Text("Up").font(.system(size: 9)).foregroundColor(.secondary)
                            }
                        }

                        Chart {
                            ForEach(Array(viewModel.downloadHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("Bytes", value)
                                )
                                .foregroundStyle(.blue.opacity(0.2))
                                .interpolationMethod(.catmullRom)

                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("Bytes", value)
                                )
                                .foregroundStyle(.blue)
                                .interpolationMethod(.catmullRom)
                            }

                            ForEach(Array(viewModel.uploadHistory.enumerated()), id: \.offset) { index, value in
                                AreaMark(
                                    x: .value("Time", index),
                                    y: .value("Bytes", value)
                                )
                                .foregroundStyle(.orange.opacity(0.15))
                                .interpolationMethod(.catmullRom)

                                LineMark(
                                    x: .value("Time", index),
                                    y: .value("Bytes", value)
                                )
                                .foregroundStyle(.orange)
                                .interpolationMethod(.catmullRom)
                            }
                        }
                        .chartXAxis(.hidden)
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisValueLabel {
                                    if let v = value.as(Double.self) {
                                        Text(formatSpeedShort(v))
                                            .font(.system(size: 8))
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                } else {
                    Text("Collecting data...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(height: 120)
                }

                // Total traffic since boot
                if let stats = viewModel.lastTrafficStatsPublic {
                    Divider()
                    HStack {
                        Text("Total since boot:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(formatBytes(stats.bytesIn)) in / \(formatBytes(stats.bytesOut)) out")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Active Connections Card

    private var activeConnectionsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "link")
                        .foregroundColor(.purple)
                    Text("Active Connections")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.connectionCount)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.purple)
                }

                if !viewModel.connections.isEmpty {
                    // Group by service type
                    let serviceGroups = connectionServiceGroups(viewModel.connections)

                    // Bar chart of services
                    if !serviceGroups.isEmpty {
                        Chart {
                            ForEach(serviceGroups.prefix(8), id: \.service) { group in
                                BarMark(
                                    x: .value("Count", group.count),
                                    y: .value("Service", group.service)
                                )
                                .foregroundStyle(serviceColor(group.service).gradient)
                                .cornerRadius(4)
                            }
                        }
                        .chartXAxis {
                            AxisMarks(position: .bottom) { value in
                                AxisValueLabel {
                                    if let v = value.as(Int.self) {
                                        Text("\(v)")
                                            .font(.system(size: 8))
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks { value in
                                AxisValueLabel {
                                    if let v = value.as(String.self) {
                                        Text(v)
                                            .font(.system(size: 9))
                                    }
                                }
                            }
                        }
                        .frame(height: max(CGFloat(min(serviceGroups.count, 8)) * 24, 80))
                    }

                    Divider()

                    // Top remote hosts
                    let topHosts = topRemoteHosts(viewModel.connections)
                    if !topHosts.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Top Remote Hosts")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.secondary)

                            ForEach(topHosts.prefix(5), id: \.host) { entry in
                                HStack {
                                    Text(entry.host)
                                        .font(.system(size: 10, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(entry.count)")
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundColor(.purple)
                                }
                            }
                        }
                    }
                } else {
                    VStack {
                        Text("No active connections")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Data refreshes every 5 cycles")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
        }
    }

    // MARK: - Interfaces Card

    private var interfacesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "network")
                        .foregroundColor(.green)
                    Text("Network Interfaces")
                        .font(.headline)
                    Spacer()
                }

                if viewModel.interfaces.isEmpty {
                    Text("No interfaces found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(Array(viewModel.interfaces.enumerated()), id: \.offset) { index, iface in
                        HStack(spacing: 8) {
                            Image(systemName: interfaceIcon(iface.type))
                                .font(.system(size: 12))
                                .foregroundColor(iface.isUp ? .green : .gray)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 6) {
                                    Text(iface.name)
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    Text(iface.type)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Capsule())

                                    if isPrimaryInterface(iface) {
                                        Text("Primary")
                                            .font(.system(size: 8, weight: .semibold))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }

                                Text(iface.address)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Circle()
                                .fill(iface.isUp ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                        }
                        .padding(.vertical, 4)

                        if index < viewModel.interfaces.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Connection Helpers

    private struct ServiceGroup: Identifiable {
        let service: String
        let count: Int
        var id: String { service }
    }

    private struct HostEntry: Identifiable {
        let host: String
        let count: Int
        var id: String { host }
    }

    private func connectionServiceGroups(_ connections: [ConnectionMonitor.Connection]) -> [ServiceGroup] {
        var groups: [String: Int] = [:]
        for conn in connections {
            let service = portToService(conn.remotePort)
            groups[service, default: 0] += 1
        }
        return groups.map { ServiceGroup(service: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func topRemoteHosts(_ connections: [ConnectionMonitor.Connection]) -> [HostEntry] {
        var groups: [String: Int] = [:]
        for conn in connections {
            let host = conn.remoteAddress
            if host != "*" && host != "127.0.0.1" && host != "::1" {
                groups[host, default: 0] += 1
            }
        }
        return groups.map { HostEntry(host: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    private func portToService(_ port: String) -> String {
        switch port {
        case "443": return "HTTPS"
        case "80": return "HTTP"
        case "22": return "SSH"
        case "53": return "DNS"
        case "993": return "IMAP/S"
        case "587": return "SMTP"
        case "5223": return "Apple Push"
        case "3478", "3479": return "STUN/TURN"
        case "8080": return "HTTP Alt"
        case "*": return "Listening"
        default:
            if let p = Int(port), p >= 49152 {
                return "Ephemeral"
            }
            return "Port \(port)"
        }
    }

    private func serviceColor(_ service: String) -> Color {
        switch service {
        case "HTTPS": return .blue
        case "HTTP": return .cyan
        case "SSH": return .green
        case "DNS": return .orange
        case "Apple Push": return .pink
        case "IMAP/S", "SMTP": return .indigo
        default: return .purple
        }
    }

    private func interfaceIcon(_ type: String) -> String {
        switch type {
        case "Wi-Fi": return "wifi"
        case "Ethernet": return "cable.connector"
        case "Loopback": return "arrow.triangle.2.circlepath"
        case "VPN/Tunnel": return "lock.shield"
        case "AirDrop": return "antenna.radiowaves.left.and.right"
        case "Bridge": return "point.3.connected.trianglepath.dotted"
        default: return "network"
        }
    }

    private func isPrimaryInterface(_ iface: NetworkInfo.Interface) -> Bool {
        return iface.isUp && (iface.name == "en0" || iface.name == "en1") && iface.type == "Wi-Fi"
    }

    // MARK: - WiFi Helpers

    private func wifiSignalPercent(_ rssi: Int) -> Double {
        // Map RSSI from -90...-30 to 0...100
        let clamped = min(max(Double(rssi), -90), -30)
        return ((clamped + 90) / 60.0) * 100.0
    }

    private func wifiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -60 { return .blue }
        if rssi > -70 { return .orange }
        return .red
    }

    private func snrColor(_ snr: Int) -> Color {
        if snr >= 40 { return .green }
        if snr >= 25 { return .blue }
        if snr >= 15 { return .orange }
        return .red
    }

    private func signalQualityBadge(_ quality: String) -> some View {
        let color: Color = switch quality {
            case "Excellent": .green
            case "Good": .blue
            case "Fair": .orange
            default: .red
        }
        return Text(quality)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private func detailRow(_ label: String, value: String, barValue: Double? = nil, barMax: Double = 50, barColor: Color = .blue) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            if let barValue {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor)
                            .frame(width: geo.size.width * min(barValue / barMax, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
            }

            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .frame(minWidth: 50, alignment: .trailing)
        }
    }

    // MARK: - Format Helpers

    private func formatSpeed(_ bytesPerSec: UInt64) -> String {
        if bytesPerSec > 1_000_000 {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / 1_000_000.0)
        } else if bytesPerSec > 1_000 {
            return String(format: "%.0f KB/s", Double(bytesPerSec) / 1_000.0)
        }
        return "\(bytesPerSec) B/s"
    }

    private func formatSpeedShort(_ bytesPerSec: Double) -> String {
        if bytesPerSec > 1_000_000 {
            return String(format: "%.0fM", bytesPerSec / 1_000_000.0)
        } else if bytesPerSec > 1_000 {
            return String(format: "%.0fK", bytesPerSec / 1_000.0)
        }
        return String(format: "%.0f", bytesPerSec)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        if bytes > 1_000_000_000 {
            return String(format: "%.1f GB", Double(bytes) / 1_000_000_000.0)
        } else if bytes > 1_000_000 {
            return String(format: "%.0f MB", Double(bytes) / 1_000_000.0)
        }
        return String(format: "%.0f KB", Double(bytes) / 1_000.0)
    }
}

// MARK: - Tab 3: Devices

private struct DevicesTab: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                networkMapCard
                homeNetworkCard
                bluetoothCard
            }
            .padding(.vertical)
        }
    }

    // MARK: - Network Map

    private var networkMapCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundColor(.blue)
                    Text("Network Map")
                        .font(.headline)
                    Spacer()

                    HStack(spacing: 8) {
                        mapLegendItem(color: .green, label: "WiFi")
                        mapLegendItem(color: .cyan, label: "Bluetooth")
                        mapLegendItem(color: .gray, label: "Network")
                    }
                }

                NetworkMapView(viewModel: viewModel)
                    .frame(height: 320)
            }
        }
        .padding(.horizontal)
    }

    private func mapLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 8)).foregroundColor(.secondary)
        }
    }

    // MARK: - Home Network Card

    private var homeNetworkCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "house")
                        .foregroundColor(.blue)
                    Text("Home Network")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.arpDevices.count) device\(viewModel.arpDevices.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.blue)
                }

                if viewModel.arpDevices.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "network.slash")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("No devices discovered yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Devices appear as they communicate on the network")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    // Header row
                    HStack {
                        Text("IP Address")
                            .frame(width: 130, alignment: .leading)
                        Text("MAC Address")
                            .frame(width: 140, alignment: .leading)
                        Text("Vendor")
                            .frame(width: 100, alignment: .leading)
                        Text("Hostname")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                    Divider()

                    ForEach(Array(viewModel.arpDevices.enumerated()), id: \.offset) { index, device in
                        HStack {
                            Text(device.ipAddress)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(width: 130, alignment: .leading)

                            Text(device.macAddress)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 140, alignment: .leading)

                            let vendor = macVendor(device.macAddress)
                            Text(vendor)
                                .font(.system(size: 10))
                                .foregroundColor(vendor == "Unknown" ? .secondary.opacity(0.5) : .primary)
                                .frame(width: 100, alignment: .leading)

                            Text(device.hostname ?? "-")
                                .font(.system(size: 10))
                                .foregroundColor(device.hostname != nil ? .primary : .secondary.opacity(0.5))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Bluetooth Card

    private var bluetoothCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bluetooth")
                        .foregroundColor(.blue)
                    Text("Bluetooth")
                        .font(.headline)
                    Spacer()

                    if let bt = viewModel.bluetoothInfo {
                        bluetoothStatusBadge(bt)
                    }
                }

                if let bt = viewModel.bluetoothInfo {
                    if bt.pairedDevices.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "bluetooth")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("No paired devices")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 60)
                    } else {
                        // Connected devices first, then disconnected
                        ForEach(Array(bt.pairedDevices.enumerated()), id: \.offset) { index, device in
                            HStack(spacing: 10) {
                                Image(systemName: btDeviceIcon(device.deviceType))
                                    .font(.system(size: 14))
                                    .foregroundColor(device.isConnected ? .blue : .gray)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(device.name)
                                        .font(.system(size: 11, weight: device.isConnected ? .semibold : .regular))
                                    HStack(spacing: 4) {
                                        Text(device.deviceType)
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                        if let rssi = device.rssi {
                                            Text("\(rssi) dBm")
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                if viewModel.btConnectingAddresses.contains(device.address) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 70)
                                } else if device.isConnected {
                                    Button(action: {
                                        viewModel.disconnectBluetoothDevice(address: device.address)
                                    }) {
                                        Text("Disconnect")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.red)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.red.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: {
                                        viewModel.connectBluetoothDevice(address: device.address)
                                    }) {
                                        Text("Connect")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .background(device.isConnected ? Color.blue.opacity(0.03) : Color.clear)
                            .cornerRadius(6)

                            if index < bt.pairedDevices.count - 1 {
                                Divider()
                            }
                        }
                    }
                } else {
                    VStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading Bluetooth info...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Bluetooth Helpers

    private func bluetoothStatusBadge(_ bt: BluetoothMonitor.BluetoothInfo) -> some View {
        let isOn = bt.isPoweredOn
        return HStack(spacing: 4) {
            Circle()
                .fill(isOn ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
            Text(isOn ? "On" : "Off")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(isOn ? .green : .gray)
            if bt.connectedCount > 0 {
                Text("\(bt.connectedCount) connected")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isOn ? Color.green : Color.gray).opacity(0.1))
        .clipShape(Capsule())
    }

    private func btDeviceIcon(_ type: String) -> String {
        switch type {
        case "Audio": return "headphones"
        case "Input": return "keyboard"
        case "Phone": return "iphone"
        case "Computer": return "laptopcomputer"
        case "Wearable": return "applewatch"
        case "Network": return "network"
        case "Imaging": return "printer"
        case "Health": return "heart"
        default: return "wave.3.right"
        }
    }

    // MARK: - MAC Vendor Lookup

    private func macVendor(_ mac: String) -> String {
        let prefix = mac.uppercased().replacingOccurrences(of: ":", with: "").prefix(6)
        let prefixStr = String(prefix)
        return Self.vendorMap[prefixStr] ?? "Unknown"
    }

    private static let vendorMap: [String: String] = [
        // Apple
        "000A27": "Apple", "000A95": "Apple", "000D93": "Apple",
        "001CB3": "Apple", "0021E9": "Apple", "002312": "Apple",
        "002500": "Apple", "0025BC": "Apple", "002608": "Apple",
        "003065": "Apple", "003EE1": "Apple", "0050E4": "Apple",
        "00A040": "Apple", "00B362": "Apple", "00C610": "Apple",
        "00CDFE": "Apple", "041E64": "Apple", "04489A": "Apple",
        "04DB56": "Apple", "04F13E": "Apple", "04F7E4": "Apple",
        "080007": "Apple", "0C4DE9": "Apple", "0CD746": "Apple",
        "10DDB1": "Apple", "1402EC": "Apple", "14109F": "Apple",
        "18AF8F": "Apple", "1C1AC0": "Apple", "2029FB": "Apple",
        "24A074": "Apple", "28A02B": "Apple", "28CF3C": "Apple",
        "28CFE9": "Apple", "3010E4": "Apple", "34363B": "Apple",
        "38C986": "Apple", "3C0754": "Apple", "3CE072": "Apple",
        "403004": "Apple", "4C3275": "Apple", "4C8D79": "Apple",
        "50EAD6": "Apple", "542696": "Apple", "54724F": "Apple",
        "54AE27": "Apple", "58B035": "Apple", "5C5948": "Apple",
        "5CF7E6": "Apple", "60C547": "Apple", "60D9C7": "Apple",
        "60FACD": "Apple", "64200C": "Apple", "64A3CB": "Apple",
        "6C3E6D": "Apple", "6C4008": "Apple", "6C709F": "Apple",
        "6C94F8": "Apple", "6CC26B": "Apple", "703EAC": "Apple",
        "70480F": "Apple", "708B4E": "Apple", "70DEE2": "Apple",
        "7831C1": "Apple", "7C6D62": "Apple", "7CC3A1": "Apple",
        "7CD1C3": "Apple", "80006E": "Apple", "8463D6": "Apple",
        "84788B": "Apple", "848506": "Apple", "84FCAC": "Apple",
        "8866A5": "Apple", "8C5877": "Apple", "8C8590": "Apple",
        "8C8FE9": "Apple", "9027E4": "Apple", "90840D": "Apple",
        "949426": "Apple", "9C207B": "Apple", "9C35EB": "Apple",
        "9CF387": "Apple", "A02195": "Apple", "A46706": "Apple",
        "A4B197": "Apple", "A4D1D2": "Apple", "A82066": "Apple",
        "A860B6": "Apple", "A8667F": "Apple", "A886DD": "Apple",
        "A88808": "Apple", "AC293A": "Apple", "ACBC32": "Apple",
        "B03495": "Apple", "B44BD2": "Apple", "B8098A": "Apple",
        "B817C2": "Apple", "B844D9": "Apple", "B8C111": "Apple",
        "B8E856": "Apple", "B8F6B1": "Apple", "BC3BAF": "Apple",
        "BC5436": "Apple", "BC6778": "Apple", "C01ADA": "Apple",
        "C0847A": "Apple", "C0CECD": "Apple", "C42C03": "Apple",
        "C81EE7": "Apple", "C82A14": "Apple", "CC4463": "Apple",
        "CC785F": "Apple", "D023DB": "Apple", "D02598": "Apple",
        "D03311": "Apple", "D49A20": "Apple", "D4F46F": "Apple",
        "D8004D": "Apple", "D89695": "Apple", "D8CF9C": "Apple",
        "DC2B2A": "Apple", "DC3714": "Apple", "E05F45": "Apple",
        "E0B52D": "Apple", "E0C767": "Apple", "E4C63D": "Apple",
        "E8040B": "Apple", "E80688": "Apple", "E89120": "Apple",
        "F02475": "Apple", "F0B479": "Apple", "F0C1F1": "Apple",
        "F0D1A9": "Apple", "F0DCE2": "Apple", "F40F24": "Apple",
        "F45C89": "Apple", "F4F15A": "Apple", "F81EDF": "Apple",
        "FC253F": "Apple", "FCE998": "Apple",
        // Google / Nest
        "1861C9": "Google", "54607D": "Google", "F4F5D8": "Google",
        "F4F5E8": "Google", "A47733": "Google", "6C5AB5": "Google",
        "D8EB46": "Google", "30FD38": "Google",
        // Samsung
        "0000F0": "Samsung", "002119": "Samsung", "0007AB": "Samsung",
        "001247": "Samsung", "001377": "Samsung", "0015B9": "Samsung",
        "001632": "Samsung", "001856": "Samsung", "001A8A": "Samsung",
        "001EE1": "Samsung", "0021D1": "Samsung", "0023D6": "Samsung",
        "0024E9": "Samsung", "0026E2": "Samsung", "1C62B8": "Samsung",
        "2CFDA1": "Samsung", "4844F7": "Samsung", "50F520": "Samsung",
        "549F13": "Samsung", "5CE0C5": "Samsung", "6077E2": "Samsung",
        "6C2F2C": "Samsung", "843835": "Samsung", "8C771A": "Samsung",
        "9C02B1": "Samsung", "9CA3BA": "Samsung",
        // Amazon / Ring / Echo
        "0C47C9": "Amazon", "18742E": "Amazon", "347E5C": "Amazon",
        "44D9E7": "Amazon", "50DCE7": "Amazon", "68542B": "Amazon",
        "6854FD": "Amazon", "747548": "Amazon", "84D6D0": "Amazon",
        "A002DC": "Amazon", "B47C9C": "Amazon", "FC65DE": "Amazon",
        // Microsoft / Xbox
        "001DD8": "Microsoft", "0050F2": "Microsoft", "7CB27D": "Microsoft",
        // Intel
        "001517": "Intel", "00AA00": "Intel", "001B21": "Intel",
        "4CEB42": "Intel", "A4BADB": "Intel",
        // TP-Link
        "001327": "TP-Link", "0019E0": "TP-Link", "1C3BF3": "TP-Link",
        "503EAA": "TP-Link", "542233": "TP-Link",
        // Netgear
        "0024B2": "Netgear", "00146C": "Netgear", "008EF2": "Netgear",
        "204E7F": "Netgear", "C03F0E": "Netgear",
        // Sonos
        "000E58": "Sonos", "5CAAFD": "Sonos", "7828CA": "Sonos",
        "B8E937": "Sonos",
        // Roku
        "D83134": "Roku", "B0A737": "Roku", "AC3A7A": "Roku",
        // Raspberry Pi
        "B827EB": "Raspberry Pi", "DC26B3": "Raspberry Pi",
        "E45F01": "Raspberry Pi",
    ]
}

// MARK: - Shared Components

private struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background))
        .shadow(color: .black.opacity(0.05), radius: 4)
    }
}

// MARK: - Shared Helper Functions

private func infoRow(_ label: String, _ value: String) -> some View {
    HStack {
        Text(label)
            .foregroundColor(.secondary)
            .font(.system(size: 11))
            .frame(width: 80, alignment: .leading)
        Text(value)
            .font(.system(size: 11))
    }
}

private func warningRow(_ text: String, _ color: Color) -> some View {
    HStack {
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(color)
            .font(.system(size: 10))
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(color)
    }
}
