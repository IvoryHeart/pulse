import Testing
@testable import PulseCore

@Suite("PulseProcessInfo")
struct ProcessInfoTests {

    @Test("shortName extracts app name from bundle path")
    func shortNameBundle() {
        let proc = PulseProcessInfo(
            pid: 100, name: "/Applications/Safari.app/Contents/MacOS/Safari",
            cpuPercent: 5.0, memPercent: 1.0, rssBytes: 200_000_000
        )
        #expect(proc.shortName == "Safari")
    }

    @Test("shortName extracts app name with helper type in parentheses")
    func shortNameBundleWithHelper() {
        let proc = PulseProcessInfo(
            pid: 200, name: "/Applications/Arc.app/Contents/Frameworks/Arc Helper (Renderer).app/Contents/MacOS/Arc Helper (Renderer)",
            cpuPercent: 30.0, memPercent: 3.0, rssBytes: 500_000_000
        )
        #expect(proc.shortName == "Arc (Renderer)")
    }

    @Test("shortName handles non-bundle paths (returns last path component)")
    func shortNameNonBundle() {
        let proc = PulseProcessInfo(
            pid: 1, name: "/usr/sbin/syslogd",
            cpuPercent: 0.1, memPercent: 0.0, rssBytes: 5_000_000
        )
        #expect(proc.shortName == "syslogd")
    }

    @Test("shortName handles simple name without path")
    func shortNameSimple() {
        let proc = PulseProcessInfo(
            pid: 2, name: "kernel_task",
            cpuPercent: 3.0, memPercent: 1.0, rssBytes: 50_000_000
        )
        #expect(proc.shortName == "kernel_task")
    }

    @Test("shortName handles nested Applications path")
    func shortNameNestedApp() {
        let proc = PulseProcessInfo(
            pid: 300, name: "/Applications/Xcode.app/Contents/MacOS/Xcode",
            cpuPercent: 20.0, memPercent: 5.0, rssBytes: 1_000_000_000
        )
        #expect(proc.shortName == "Xcode")
    }

    @Test("rssFormatted returns human-readable string")
    func rssFormatted() {
        let proc = PulseProcessInfo(
            pid: 1, name: "test",
            cpuPercent: 1.0, memPercent: 0.5, rssBytes: 256_000_000
        )
        // 256_000_000 bytes = ~244.1 MB
        let formatted = proc.rssFormatted
        #expect(formatted.contains("MB"))
    }

    @Test("rssFormatted for GB-sized process")
    func rssFormattedGB() {
        let proc = PulseProcessInfo(
            pid: 1, name: "test",
            cpuPercent: 1.0, memPercent: 5.0, rssBytes: 2_147_483_648  // 2 GB
        )
        #expect(proc.rssFormatted == "2 GB")
    }
}
