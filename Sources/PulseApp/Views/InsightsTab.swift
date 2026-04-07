import SwiftUI
import PulseCore

struct InsightsTab: View {
    @ObservedObject var viewModel: SystemViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !viewModel.insightsLoaded {
                    loadingView
                } else {
                    trendsCard
                    appProfilesCard
                    changelogCard
                    databaseCard
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading insights...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Predictive Trends

    private var trendsCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.orange)
                    Text("Predictive Trends")
                        .font(.headline)
                    Spacer()
                }

                if viewModel.trendPredictions.isEmpty {
                    emptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Not enough data yet",
                        detail: "Run `pulse log` regularly to build trend predictions"
                    )
                } else {
                    ForEach(Array(viewModel.trendPredictions.enumerated()), id: \.offset) { _, prediction in
                        trendRow(prediction)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func trendRow(_ p: TrendAnalyzer.Prediction) -> some View {
        HStack(spacing: 12) {
            // Trend arrow
            let icon = trendIcon(p.trend)
            Image(systemName: icon.name)
                .font(.system(size: 14))
                .foregroundColor(icon.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(p.metric.capitalized)
                        .font(.system(size: 12, weight: .semibold))

                    Text(String(format: "%.1f%@", p.currentValue, p.unit))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    if let days = p.daysUntilCritical {
                        Text("Critical in ~\(days) days")
                            .font(.system(size: 10))
                            .foregroundColor(days < 30 ? .red : days < 90 ? .orange : .secondary)
                    } else {
                        Text(p.trend == .stable ? "Stable" : "Improving")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }

                    let rate = String(format: "%.2f%@/day", abs(p.ratePerDay), p.unit)
                    Text(p.trend == .decreasing ? "-\(rate)" : "+\(rate)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    // Confidence badge
                    Text(String(format: "%.0f%%", p.confidence * 100))
                        .font(.system(size: 8, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.12))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func trendIcon(_ trend: TrendAnalyzer.Trend) -> (name: String, color: Color) {
        switch trend {
        case .increasing: return ("arrow.up.right", .red)
        case .decreasing: return ("arrow.down.right", .green)
        case .stable: return ("arrow.right", .blue)
        }
    }

    // MARK: - App Profiles

    private var appProfilesCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.purple)
                    Text("App Energy (7 Days)")
                        .font(.headline)
                    Spacer()
                    if !viewModel.appProfiles.isEmpty {
                        Text("\(viewModel.appProfiles.count) apps")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.appProfiles.isEmpty {
                    emptyState(
                        icon: "bolt.fill",
                        title: "No app data yet",
                        detail: "Run `pulse log` to start tracking app energy usage"
                    )
                } else {
                    // Header row
                    HStack {
                        Text("Grade")
                            .frame(width: 40, alignment: .leading)
                        Text("App")
                            .frame(width: 120, alignment: .leading)
                        Text("CPU-hrs")
                            .frame(width: 55, alignment: .trailing)
                        Text("Avg CPU")
                            .frame(width: 55, alignment: .trailing)
                        Text("Memory")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                    Divider()

                    ForEach(Array(viewModel.appProfiles.prefix(8).enumerated()), id: \.offset) { index, profile in
                        appProfileRow(profile, index: index)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func appProfileRow(_ profile: AppProfiler.AppProfile, index: Int) -> some View {
        HStack {
            // Grade badge
            Text(profile.grade)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(gradeColor(profile.grade))
                .frame(width: 22, height: 18)
                .background(gradeColor(profile.grade).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 40, alignment: .leading)

            Text(profile.name)
                .font(.system(size: 11))
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            Text(String(format: "%.1fh", profile.cpuHours))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 55, alignment: .trailing)

            Text(String(format: "%.0f%%", profile.avgCpuPercent))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(profile.avgCpuPercent > 25 ? .red : profile.avgCpuPercent > 10 ? .orange : .secondary)
                .frame(width: 55, alignment: .trailing)

            Text(formatMB(profile.avgMemoryMB))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.04))
    }

    private func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A": return .green
        case "B": return .blue
        case "C": return .yellow
        case "D": return .orange
        case "F": return .red
        default: return .gray
        }
    }

    // MARK: - System Changelog

    private var changelogCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(.green)
                    Text("System Changelog")
                        .font(.headline)
                    Spacer()
                }

                if viewModel.changelogEntries.isEmpty {
                    emptyState(
                        icon: "clock.arrow.circlepath",
                        title: "No changes detected",
                        detail: "Run `pulse changelog scan` to start tracking"
                    )
                } else {
                    ForEach(Array(viewModel.changelogEntries.prefix(10).enumerated()), id: \.offset) { _, entry in
                        changelogRow(entry)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private func changelogRow(_ entry: ChangelogMonitor.ChangeEntry) -> some View {
        HStack(spacing: 8) {
            // Action icon
            let actionInfo = actionStyle(entry.action)
            Image(systemName: actionInfo.icon)
                .font(.system(size: 10))
                .foregroundColor(actionInfo.color)
                .frame(width: 14)

            // Category badge
            Text(entry.category.rawValue.prefix(5).uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.gray.opacity(0.1))
                .foregroundColor(.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.item)
                    .font(.system(size: 11))
                    .lineLimit(1)

                if let details = entry.details {
                    Text(details)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(relativeDate(entry.timestamp))
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func actionStyle(_ action: ChangelogMonitor.Action) -> (icon: String, color: Color) {
        switch action {
        case .added: return ("plus.circle.fill", .green)
        case .removed: return ("minus.circle.fill", .red)
        case .modified: return ("arrow.triangle.2.circlepath", .orange)
        }
    }

    // MARK: - Database Status

    private var databaseCard: some View {
        InsightCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "externaldrive")
                        .foregroundColor(.blue)
                    Text("Database")
                        .font(.headline)
                    Spacer()
                }

                if let stats = viewModel.dbStats {
                    HStack(spacing: 20) {
                        statItem("Size", formatBytes(stats.fileSizeBytes))
                        statItem("Snapshots", "\(stats.snapshotCount)")
                        statItem("Processes", "\(stats.processRecordCount)")
                        statItem("Archived", "\(stats.archivedDaysCount) days")
                    }

                    if let oldest = stats.oldestSnapshot {
                        HStack(spacing: 4) {
                            Text("History since")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                            Text(formatDateShort(oldest))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    if stats.fileSizeBytes > 50_000_000 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text("Database is large. Run `pulse archive run` to compress.")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    Text("No database info available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal)
    }

    private func statItem(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary.opacity(0.5))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }

    private func formatMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes > 1_000_000_000 {
            return String(format: "%.1f GB", Double(bytes) / 1_000_000_000.0)
        } else if bytes > 1_000_000 {
            return String(format: "%.1f MB", Double(bytes) / 1_000_000.0)
        }
        return String(format: "%.0f KB", Double(bytes) / 1_000.0)
    }

    private func formatDateShort(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy"
        return fmt.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        let days = Int(interval / 86400)
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }
        return formatDateShort(date)
    }
}

// MARK: - Insight Card Container

private struct InsightCard<Content: View>: View {
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
