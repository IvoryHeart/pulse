import Foundation

enum Spinner {
    static let frames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    static func show(_ message: String, duration: TimeInterval = 0.5) {
        for i in 0..<Int(duration * 10) {
            let frame = frames[i % frames.count]
            print("\r\(TerminalUI.colored(frame, .cyan)) \(message)", terminator: "")
            fflush(stdout)
            usleep(100_000)
        }
        print("\r\(TerminalUI.colored("✓", .green)) \(message)")
    }
}
