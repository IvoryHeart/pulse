import Foundation

/// Predictive trend analysis using linear regression on health metrics.
public enum TrendAnalyzer {
    public struct Prediction: Sendable, Codable {
        public let metric: String
        public let currentValue: Double
        public let unit: String
        public let trend: Trend
        public let ratePerDay: Double
        public let daysUntilCritical: Int?
        public let criticalThreshold: Double
        public let confidence: Double
        public let dataPoints: Int
        public let timeSpanDays: Double
    }

    public enum Trend: String, Sendable, Codable {
        case increasing, decreasing, stable
    }

    /// Simple linear regression: returns (slope, intercept, rSquared).
    /// xs and ys must have the same count and at least 2 elements.
    public static func linearRegression(xs: [Double], ys: [Double]) -> (slope: Double, intercept: Double, rSquared: Double) {
        let n = Double(xs.count)
        guard n >= 2 else { return (0, ys.first ?? 0, 0) }

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0.0) { $0 + $1.0 * $1.1 }
        let sumX2 = xs.reduce(0.0) { $0 + $1 * $1 }
        let sumY2 = ys.reduce(0.0) { $0 + $1 * $1 }

        let denom = n * sumX2 - sumX * sumX
        guard denom != 0 else { return (0, sumY / n, 0) }

        let slope = (n * sumXY - sumX * sumY) / denom
        let intercept = (sumY - slope * sumX) / n

        // R-squared (coefficient of determination)
        let meanY = sumY / n
        let ssTot = sumY2 - n * meanY * meanY
        let ssRes = zip(xs, ys).reduce(0.0) { acc, pair in
            let predicted = slope * pair.0 + intercept
            let residual = pair.1 - predicted
            return acc + residual * residual
        }
        let rSquared = ssTot > 0 ? max(0, 1.0 - ssRes / ssTot) : 0

        return (slope, intercept, rSquared)
    }

    /// Analyze trends across key metrics from stored health data.
    public static func analyzeTrends(store: HealthStore) throws -> [Prediction] {
        let data = try store.getTrendData(days: 30)
        guard data.count > 10 else { return [] }

        guard let firstTime = data.first?.timestamp.timeIntervalSince1970,
              let lastTime = data.last?.timestamp.timeIntervalSince1970 else {
            return []
        }
        let timeSpanDays = (lastTime - firstTime) / 86400.0
        guard timeSpanDays > 0.5 else { return [] }

        var predictions: [Prediction] = []

        // Convert timestamps to days-since-start for regression
        let dayOffsets = data.map { ($0.timestamp.timeIntervalSince1970 - firstTime) / 86400.0 }

        // --- Disk usage % ---
        let diskValues = data.map { $0.diskUsage }
        let diskReg = linearRegression(xs: dayOffsets, ys: diskValues)
        let diskCurrent = diskValues.last ?? 0
        let diskMean = diskValues.reduce(0, +) / Double(diskValues.count)
        let diskTrend = classifyTrend(slope: diskReg.slope, mean: diskMean, threshold: 0.01)
        let diskDaysUntil = daysUntilThreshold(current: diskCurrent, slope: diskReg.slope, threshold: 90)
        if diskReg.rSquared > 0.3 {
            predictions.append(Prediction(
                metric: "disk", currentValue: diskCurrent, unit: "%",
                trend: diskTrend, ratePerDay: diskReg.slope,
                daysUntilCritical: diskTrend == .increasing ? diskDaysUntil : nil,
                criticalThreshold: 90, confidence: diskReg.rSquared,
                dataPoints: data.count, timeSpanDays: timeSpanDays
            ))
        }

        // --- Memory usage % ---
        let memValues = data.map { $0.memUsage }
        let memReg = linearRegression(xs: dayOffsets, ys: memValues)
        let memCurrent = memValues.last ?? 0
        let memMean = memValues.reduce(0, +) / Double(memValues.count)
        let memTrend = classifyTrend(slope: memReg.slope, mean: memMean, threshold: 0.01)
        let memDaysUntil = daysUntilThreshold(current: memCurrent, slope: memReg.slope, threshold: 95)
        if memReg.rSquared > 0.3 {
            predictions.append(Prediction(
                metric: "memory", currentValue: memCurrent, unit: "%",
                trend: memTrend, ratePerDay: memReg.slope,
                daysUntilCritical: memTrend == .increasing ? memDaysUntil : nil,
                criticalThreshold: 95, confidence: memReg.rSquared,
                dataPoints: data.count, timeSpanDays: timeSpanDays
            ))
        }

        // --- Swap used (in GB) ---
        let swapGBValues = data.map { Double($0.swapUsed) / (1024.0 * 1024.0 * 1024.0) }
        let swapReg = linearRegression(xs: dayOffsets, ys: swapGBValues)
        let swapCurrent = swapGBValues.last ?? 0
        let swapMean = swapGBValues.reduce(0, +) / Double(swapGBValues.count)
        let swapTrend = classifyTrend(slope: swapReg.slope, mean: max(swapMean, 0.1), threshold: 0.01)
        let swapDaysUntil = daysUntilThreshold(current: swapCurrent, slope: swapReg.slope, threshold: 8)
        if swapReg.rSquared > 0.3 {
            predictions.append(Prediction(
                metric: "swap", currentValue: swapCurrent, unit: "GB",
                trend: swapTrend, ratePerDay: swapReg.slope,
                daysUntilCritical: swapTrend == .increasing ? swapDaysUntil : nil,
                criticalThreshold: 8, confidence: swapReg.rSquared,
                dataPoints: data.count, timeSpanDays: timeSpanDays
            ))
        }

        // --- Battery cycles (use battery_percent as health proxy if cycles unavailable) ---
        // The schema stores battery_percent per snapshot but not cycle_count.
        // We track battery_percent decline as a proxy for battery health.
        let battValues = data.compactMap { pt -> Double? in
            let pct = Double(pt.healthScore ?? 0)
            return pct > 0 ? pct : nil
        }
        if battValues.count > 10 {
            let battOffsets = Array(dayOffsets.suffix(battValues.count))
            let battReg = linearRegression(xs: battOffsets, ys: battValues)
            let battCurrent = battValues.last ?? 0
            let battMean = battValues.reduce(0, +) / Double(battValues.count)
            let battTrend = classifyTrend(slope: battReg.slope, mean: battMean, threshold: 0.05)
            if battReg.rSquared > 0.3 {
                predictions.append(Prediction(
                    metric: "health_score", currentValue: battCurrent, unit: "pts",
                    trend: battTrend, ratePerDay: battReg.slope,
                    daysUntilCritical: battTrend == .decreasing ? daysUntilThreshold(current: battCurrent, slope: battReg.slope, threshold: 50) : nil,
                    criticalThreshold: 50, confidence: battReg.rSquared,
                    dataPoints: battValues.count, timeSpanDays: timeSpanDays
                ))
            }
        }

        return predictions
    }

    // MARK: - Helpers

    private static func classifyTrend(slope: Double, mean: Double, threshold: Double) -> Trend {
        let relativeSlope = mean != 0 ? abs(slope / mean) : abs(slope)
        if relativeSlope < threshold { return .stable }
        return slope > 0 ? .increasing : .decreasing
    }

    private static func daysUntilThreshold(current: Double, slope: Double, threshold: Double) -> Int? {
        guard slope > 0, current < threshold else { return nil }
        let days = (threshold - current) / slope
        guard days > 0, days < 365 * 5 else { return nil }
        return Int(days.rounded())
    }
}