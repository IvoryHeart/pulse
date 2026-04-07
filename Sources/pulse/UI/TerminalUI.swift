import Foundation

enum Color: String {
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
    case gray = "\u{001B}[90m"
    case boldRed = "\u{001B}[1;31m"
    case boldGreen = "\u{001B}[1;32m"
    case boldYellow = "\u{001B}[1;33m"
    case boldCyan = "\u{001B}[1;36m"
    case boldWhite = "\u{001B}[1;37m"
    case reset = "\u{001B}[0m"
    case bold = "\u{001B}[1m"
    case dim = "\u{001B}[2m"
}

enum TerminalUI {
    static func colored(_ text: String, _ color: Color) -> String {
        "\(color.rawValue)\(text)\(Color.reset.rawValue)"
    }

    // Box drawing
    static let topLeft = "╭"
    static let topRight = "╮"
    static let bottomLeft = "╰"
    static let bottomRight = "╯"
    static let horizontal = "─"
    static let vertical = "│"
    static let leftTee = "├"
    static let rightTee = "┤"

    static func box(width: Int, title: String, sections: [[String]]) -> String {
        var lines: [String] = []
        let innerWidth = width - 2

        // Top border with title
        let titleStr = " \(title) "
        let remainingWidth = innerWidth - titleStr.count
        let leftPad = 1
        let rightPad = remainingWidth - leftPad
        lines.append("\(topLeft)\(String(repeating: horizontal, count: leftPad))\(colored(titleStr, .boldCyan))\(String(repeating: horizontal, count: max(0, rightPad)))\(topRight)")

        for (i, section) in sections.enumerated() {
            if i > 0 {
                lines.append("\(leftTee)\(String(repeating: horizontal, count: innerWidth))\(rightTee)")
            }
            for line in section {
                let visibleLength = stripAnsi(line).count
                let padding = max(0, innerWidth - visibleLength - 2)
                lines.append("\(vertical) \(line)\(String(repeating: " ", count: padding)) \(vertical)")
            }
        }

        // Bottom border
        lines.append("\(bottomLeft)\(String(repeating: horizontal, count: innerWidth))\(bottomRight)")
        return lines.joined(separator: "\n")
    }

    static func gauge(label: String, percent: Double, width: Int = 20, warnAt: Double = 70, critAt: Double = 90) -> String {
        let filled = Int((percent / 100.0) * Double(width))
        let empty = width - filled
        let bar = String(repeating: "█", count: max(0, min(filled, width))) + String(repeating: "░", count: max(0, empty))

        let color: Color = percent >= critAt ? .boldRed : percent >= warnAt ? .boldYellow : .boldGreen
        let percentStr = String(format: "%3.0f%%", percent)

        return "\(colored(label, .boldWhite))  \(colored(bar, color))  \(colored(percentStr, color))"
    }

    // Strip ANSI codes for calculating visible string length
    static func stripAnsi(_ str: String) -> String {
        str.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
    }
}
