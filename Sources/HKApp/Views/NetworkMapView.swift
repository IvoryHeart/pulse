import SwiftUI
import HKCore

struct NetworkMapView: View {
    @ObservedObject var viewModel: SystemViewModel

    private let deviceIconSize: CGFloat = 28
    private let minRingRadius: CGFloat = 60

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 40

            ZStack {
                // Distance rings
                distanceRings(center: center, maxRadius: maxRadius)

                // Connection lines + nodes (drawn in order: lines first, nodes on top)
                let gatewayPos = gatewayPos(center: center, maxRadius: maxRadius)
                let btDevices = connectedBTDevices()
                let arpDevs = viewModel.arpDevices

                // Lines: Mac → gateway
                if viewModel.wifiInfo != nil {
                    connectionLine(from: center, to: gatewayPos, color: .blue.opacity(0.3))
                }

                // Lines: Mac → BT devices
                ForEach(Array(btDevices.enumerated()), id: \.offset) { index, device in
                    let pos = btPosition(device: device, index: index, total: btDevices.count,
                                         center: center, maxRadius: maxRadius)
                    connectionLine(from: center, to: pos, color: .cyan.opacity(0.2))
                }

                // Lines: gateway → ARP devices
                ForEach(Array(arpDevs.prefix(20).enumerated()), id: \.offset) { index, _ in
                    let pos = outerRingPosition(index: index, total: min(arpDevs.count, 20),
                                                center: center, maxRadius: maxRadius)
                    if viewModel.wifiInfo != nil {
                        connectionLine(from: gatewayPos, to: pos, color: .gray.opacity(0.1))
                    }
                }

                // Gateway node
                if let wifi = viewModel.wifiInfo {
                    deviceNode(
                        at: gatewayPos,
                        icon: "wifi.router",
                        label: wifi.ssid ?? "Gateway",
                        detail: "\(wifi.rssi) dBm",
                        color: wifiColor(wifi.rssi),
                        size: 14
                    )
                }

                // BT device nodes
                ForEach(Array(btDevices.enumerated()), id: \.offset) { index, device in
                    let pos = btPosition(device: device, index: index, total: btDevices.count,
                                         center: center, maxRadius: maxRadius)
                    deviceNode(
                        at: pos,
                        icon: btDeviceIcon(device.deviceType),
                        label: device.name,
                        detail: device.rssi.map { "\($0) dBm" } ?? "",
                        color: .cyan,
                        size: 12
                    )
                }

                // ARP device nodes
                ForEach(Array(arpDevs.prefix(20).enumerated()), id: \.offset) { index, device in
                    let pos = outerRingPosition(index: index, total: min(arpDevs.count, 20),
                                                center: center, maxRadius: maxRadius)
                    deviceNode(
                        at: pos,
                        icon: arpDeviceIcon(device),
                        label: shortLabel(device),
                        detail: device.ipAddress,
                        color: .gray,
                        size: 10
                    )
                }

                // Mac at center
                VStack(spacing: 2) {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                    Text("This Mac")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .position(center)
            }
        }
    }

    // MARK: - Positioning

    private func gatewayPos(center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        guard let wifi = viewModel.wifiInfo else {
            return CGPoint(x: center.x, y: center.y - minRingRadius)
        }
        // Map RSSI -30 (close) to -90 (far) → ring distance
        let normalized = min(max(Double(wifi.rssi), -90), -30)
        let fraction = (normalized + 90) / 60.0  // 0 = far, 1 = close
        let radius = minRingRadius + (maxRadius * 0.5 - minRingRadius) * (1.0 - fraction)
        // Place at top
        return CGPoint(x: center.x, y: center.y - radius)
    }

    private func btPosition(device: BluetoothMonitor.BTDevice, index: Int, total: Int,
                             center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        let rssi = device.rssi ?? -70
        let txPower: Double = -59
        let n: Double = 2.0
        let estimatedMeters = pow(10.0, (txPower - Double(rssi)) / (10.0 * n))

        let clampedDist = min(max(estimatedMeters, 0.5), 10.0)
        let radius = minRingRadius + CGFloat(clampedDist / 10.0) * (maxRadius * 0.6 - minRingRadius)

        // Spread in right semicircle (top-right to bottom-right)
        let startAngle: CGFloat = -.pi / 3
        let endAngle: CGFloat = .pi / 3
        let angle: CGFloat
        if total <= 1 {
            angle = 0 // directly right
        } else {
            angle = startAngle + (endAngle - startAngle) * CGFloat(index) / CGFloat(total - 1)
        }

        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    private func outerRingPosition(index: Int, total: Int,
                                    center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        guard total > 0 else { return center }
        let radius = maxRadius * 0.85
        // Spread around the bottom and left (avoid the top where gateway sits)
        let startAngle: CGFloat = .pi * 0.4
        let endAngle: CGFloat = .pi * 1.9
        let angle: CGFloat
        if total == 1 {
            angle = .pi  // left
        } else {
            angle = startAngle + (endAngle - startAngle) * CGFloat(index) / CGFloat(total)
        }

        return CGPoint(
            x: center.x + radius * cos(angle),
            y: center.y + radius * sin(angle)
        )
    }

    // MARK: - Drawing

    private func distanceRings(center: CGPoint, maxRadius: CGFloat) -> some View {
        ZStack {
            ForEach([0.3, 0.55, 0.85], id: \.self) { fraction in
                Circle()
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    .frame(width: maxRadius * 2 * fraction, height: maxRadius * 2 * fraction)
                    .position(center)
            }
        }
    }

    private func connectionLine(from start: CGPoint, to end: CGPoint, color: Color) -> some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
    }

    private func deviceNode(at position: CGPoint, icon: String, label: String,
                            detail: String, color: Color, size: CGFloat) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(color)
                .frame(width: deviceIconSize, height: deviceIconSize)
                .background(Circle().fill(color.opacity(0.08)))
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .lineLimit(1)
                .frame(maxWidth: 65)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 6))
                    .foregroundColor(.secondary)
            }
        }
        .position(position)
    }

    // MARK: - Helpers

    private func connectedBTDevices() -> [BluetoothMonitor.BTDevice] {
        viewModel.bluetoothInfo?.pairedDevices.filter { $0.isConnected } ?? []
    }

    private func wifiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -60 { return .blue }
        if rssi > -70 { return .orange }
        return .red
    }

    private func btDeviceIcon(_ type: String) -> String {
        switch type {
        case "Audio": return "headphones"
        case "Input": return "keyboard"
        case "Phone": return "iphone"
        case "Computer": return "laptopcomputer"
        case "Wearable": return "applewatch"
        default: return "wave.3.right"
        }
    }

    private func arpDeviceIcon(_ device: NetworkScanner.Device) -> String {
        if let hostname = device.hostname?.lowercased() {
            if hostname.contains("iphone") || hostname.contains("ipad") { return "iphone" }
            if hostname.contains("macbook") || hostname.contains("imac") { return "laptopcomputer" }
            if hostname.contains("apple-tv") || hostname.contains("appletv") { return "appletv" }
            if hostname.contains("homepod") { return "homepod" }
        }
        return "desktopcomputer"
    }

    private func shortLabel(_ device: NetworkScanner.Device) -> String {
        if let hostname = device.hostname, hostname != "?" {
            // Truncate long hostnames
            let name = hostname.replacingOccurrences(of: ".local", with: "")
            if name.count > 12 {
                return String(name.prefix(10)) + ".."
            }
            return name
        }
        return device.ipAddress
    }
}
