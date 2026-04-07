// CLIIntegrationTests.swift
// Integration tests for the `pulse` CLI binary.
//
// REQUIREMENT: The binary must be built before running these tests.
// Run `swift build` from the project root to produce `.build/debug/pulse`.

import Testing
import Foundation
@testable import PulseCore

@Suite("CLI Integration Tests")
struct CLIIntegrationTests {

    /// Path to the built `pulse` binary, resolved relative to this source file.
    let binaryPath: String = {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // PulseCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // project root
            .appendingPathComponent(".build/debug/pulse")
            .path
    }()

    /// Run the `pulse` binary with the given arguments and return stdout + exit code.
    ///
    /// Reads pipe data **before** `waitUntilExit()` to avoid deadlock when the
    /// output exceeds the pipe buffer size.
    private func runHK(_ args: [String], timeoutSeconds: TimeInterval = 30) throws -> (stdout: String, exitCode: Int32) {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = args
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read all stdout data before waiting (prevents pipe-buffer deadlock).
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let output = String(data: data, encoding: .utf8) ?? ""
        return (output, process.terminationStatus)
    }

    // MARK: - Version

    @Test("pulse --version prints version string and exits 0")
    func testVersion() throws {
        let result = try runHK(["--version"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("pulse v\(PulseVersion.current)"))
    }

    // MARK: - Help

    @Test("pulse --help includes COMMANDS section and all major commands")
    func testHelp() throws {
        let result = try runHK(["--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("COMMANDS:"))
        #expect(result.stdout.contains("status"))
        #expect(result.stdout.contains("score"))
        #expect(result.stdout.contains("net"))
    }

    // MARK: - Status

    @Test("pulse status exits 0 and contains expected headers")
    func testStatus() throws {
        let result = try runHK(["status"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("PULSE"))
        #expect(result.stdout.contains("Health Score:"))
    }

    // MARK: - Score

    @Test("pulse score exits 0 and contains expected headers")
    func testScore() throws {
        let result = try runHK(["score"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("HEALTH SCORE"))
        #expect(result.stdout.contains("/100"))
    }

    // MARK: - Status JSON

    @Test("pulse status --json exits 0 and produces valid JSON")
    func testStatusJSON() throws {
        let result = try runHK(["status", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        #expect(obj is [String: Any], "Expected top-level JSON object")
    }

    @Test("pulse status --json contains expected top-level keys")
    func testStatusJSONKeys() throws {
        let result = try runHK(["status", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

        #expect(dict["healthScore"] != nil, "Missing 'healthScore' key")
        #expect(dict["cpu"] != nil, "Missing 'cpu' key")
        #expect(dict["memory"] != nil, "Missing 'memory' key")
        #expect(dict["disk"] != nil, "Missing 'disk' key")
    }

    @Test("pulse status --json healthScore.score is between 0 and 100")
    func testStatusJSONHealthScoreRange() throws {
        let result = try runHK(["status", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]
        let healthScore = dict["healthScore"] as! [String: Any]
        let score = healthScore["score"] as! Int

        #expect(score >= 0, "Health score should be >= 0, got \(score)")
        #expect(score <= 100, "Health score should be <= 100, got \(score)")
    }

    // MARK: - Score JSON

    @Test("pulse score --json exits 0 and produces valid JSON with expected keys")
    func testScoreJSON() throws {
        let result = try runHK(["score", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

        #expect(dict["score"] != nil, "Missing 'score' key")
        #expect(dict["deductions"] != nil, "Missing 'deductions' key")
    }

    // MARK: - Log

    @Test("pulse log --info exits 0 and contains database info")
    func testLogInfo() throws {
        let result = try runHK(["log", "--info"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Database:"))
        #expect(result.stdout.contains("Snapshots:"))
    }

    // MARK: - Net Speed

    @Test("pulse net speed exits 0 and contains throughput labels",
          .timeLimit(.minutes(1)))
    func testNetSpeed() throws {
        let result = try runHK(["net", "speed"], timeoutSeconds: 30)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("Download:"))
        #expect(result.stdout.contains("Upload:"))
    }

    // MARK: - Bluetooth

    @Test("pulse bt exits 0 and contains Bluetooth")
    func testBluetoothShortAlias() throws {
        let result = try runHK(["bt"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("BLUETOOTH"),
                "Expected output to contain 'BLUETOOTH' header")
    }

    @Test("pulse bluetooth exits 0 and contains Bluetooth")
    func testBluetoothFullCommand() throws {
        let result = try runHK(["bluetooth"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("BLUETOOTH"),
                "Expected output to contain 'BLUETOOTH' header")
    }

    @Test("pulse bt --json exits 0 and produces valid JSON")
    func testBluetoothJSON() throws {
        let result = try runHK(["bt", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        #expect(obj is [String: Any], "Expected top-level JSON object")

        let dict = obj as! [String: Any]
        #expect(dict["isAvailable"] != nil, "Missing 'isAvailable' key")
        #expect(dict["isPoweredOn"] != nil, "Missing 'isPoweredOn' key")
        #expect(dict["pairedDevices"] != nil, "Missing 'pairedDevices' key")
        #expect(dict["connectedCount"] != nil, "Missing 'connectedCount' key")
    }

    // MARK: - Net WiFi

    @Test("pulse net wifi exits 0 and contains WiFi-related content")
    func testNetWifi() throws {
        let result = try runHK(["net", "wifi"])
        #expect(result.exitCode == 0)
        // The output should contain "WIFI" header or "WiFi" if connected, or "not connected" message
        let hasWifiContent = result.stdout.contains("WIFI") || result.stdout.contains("WiFi") || result.stdout.contains("not connected")
        #expect(hasWifiContent,
                "Expected WiFi-related content in output")
    }

    @Test("pulse net wifi --json exits 0 and produces valid JSON")
    func testNetWifiJSON() throws {
        let result = try runHK(["net", "wifi", "--json"])
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: jsonData, options: [])
        #expect(obj is [String: Any], "Expected top-level JSON object")
    }

    // MARK: - Net Overview JSON

    @Test("pulse net --json exits 0 and produces valid JSON with wifi field",
          .timeLimit(.minutes(1)))
    func testNetOverviewJSON() throws {
        let result = try runHK(["net", "--json"], timeoutSeconds: 30)
        #expect(result.exitCode == 0)

        let jsonData = result.stdout.data(using: .utf8)!
        let dict = try JSONSerialization.jsonObject(with: jsonData, options: []) as! [String: Any]

        #expect(dict["interfaces"] != nil, "Missing 'interfaces' key")
        #expect(dict["connectionCount"] != nil, "Missing 'connectionCount' key")
        // wifi field may be null if WiFi is off, but the key should exist
        #expect(dict.keys.contains("wifi"), "Missing 'wifi' key")
    }

    // MARK: - Help includes new commands

    @Test("pulse --help mentions bluetooth command")
    func testHelpIncludesBluetooth() throws {
        let result = try runHK(["--help"])
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("bluetooth") || result.stdout.contains("bt"),
                "Help should mention bluetooth command")
    }

    // MARK: - Unknown Command

    @Test("pulse unknown_command outputs unknown command message")
    func testUnknownCommand() throws {
        let result = try runHK(["unknown_command"])
        #expect(result.stdout.contains("Unknown command"))
    }
}
