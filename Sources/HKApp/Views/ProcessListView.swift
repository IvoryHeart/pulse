import SwiftUI
import HKCore

struct ProcessListView: View {
    let processes: [HKProcessInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Process")
                    .frame(width: 180, alignment: .leading)
                Text("CPU")
                    .frame(width: 60, alignment: .trailing)
                Text("Memory")
                    .frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()

            ForEach(Array(processes.enumerated()), id: \.offset) { index, proc in
                HStack {
                    Text(proc.shortName)
                        .lineLimit(1)
                        .frame(width: 180, alignment: .leading)

                    Text(String(format: "%.1f%%", proc.cpuPercent))
                        .frame(width: 60, alignment: .trailing)
                        .foregroundColor(cpuColor(proc.cpuPercent))

                    Text(proc.rssFormatted)
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(.secondary)
                }
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
            }
        }
    }

    private func cpuColor(_ percent: Double) -> Color {
        if percent > 50 { return .red }
        if percent > 20 { return .orange }
        return .primary
    }
}
