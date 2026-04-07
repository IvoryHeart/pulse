import SwiftUI

struct CircularGaugeView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let detail: String
    var warnAt: Double = 70
    var critAt: Double = 90

    private var percentage: Double { min(value / maxValue * 100, 100) }

    private var gaugeColor: Color {
        if percentage >= critAt { return .red }
        if percentage >= warnAt { return .orange }
        return .green
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 70, height: 70)

                // Value arc
                Circle()
                    .trim(from: 0, to: percentage / 100)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: percentage)

                // Center text
                Text("\(Int(percentage))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(gaugeColor)
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))
            Text(detail)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(width: 100)
    }
}

struct SparklineView: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            if values.count > 1 {
                let maxVal = max(values.max() ?? 1, 1)
                let minVal = values.min() ?? 0
                let range = max(maxVal - minVal, 0.1)

                Path { path in
                    for (i, val) in values.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(values.count - 1)
                        let y = geo.size.height * (1 - CGFloat((val - minVal) / range))

                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 1.5)
            }
        }
    }
}
