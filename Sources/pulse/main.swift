import Foundation
import PulseCore

let args = Array(CommandLine.arguments.dropFirst())
let jsonFlag = args.contains("--json")
let filteredArgs = args.filter { $0 != "--json" }
let command = filteredArgs.first ?? "status"
let restArgs = Array(filteredArgs.dropFirst())

switch command {
case "status", "s":
    StatusCommand.run(json: jsonFlag)
case "score":
    ScoreCommand.run(json: jsonFlag)
case "hot", "h":
    HotCommand.run()
case "clean", "c":
    let confirm = filteredArgs.contains("--confirm")
    CleanCommand.run(confirm: confirm)
case "log", "l":
    LogCommand.run(args: restArgs)
case "history", "hist":
    HistoryCommand.run(args: restArgs)
case "net", "n":
    NetCommand.run(args: restArgs, json: jsonFlag)
case "bt", "bluetooth":
    BluetoothCommand.run(json: jsonFlag)
case "trend", "trends":
    TrendCommand.run(json: jsonFlag)
case "diff", "compare":
    DiffCommand.run(args: restArgs, json: jsonFlag)
case "apps", "profile":
    AppsCommand.run(args: restArgs, json: jsonFlag)
case "changelog", "changes":
    ChangelogCommand.run(args: restArgs, json: jsonFlag)
case "watch", "w":
    WatchCommand.run(args: restArgs)
case "archive":
    ArchiveCommand.run(args: restArgs, json: jsonFlag)
case "help", "--help", "-h":
    printHelp()
case "version", "--version", "-v":
    print("pulse v\(PulseVersion.current)")
default:
    print(TerminalUI.colored("Unknown command: \(command)", .red))
    printHelp()
}

func printHelp() {
    print("""

    \(TerminalUI.colored("pulse", .boldCyan)) - Mac Health Monitor

    \(TerminalUI.colored("USAGE:", .boldWhite))
      pulse <command> [options]

    \(TerminalUI.colored("COMMANDS:", .boldWhite))
      status, s       System health dashboard (default)
      score           Composite health score with breakdown
      hot, h          Find hot/resource-heavy processes
      clean, c        Scan for cleanup opportunities
      log, l          Record a health snapshot to database
      history, hist   View health trends with sparkline charts
      net, n          Network overview and monitoring
      bt, bluetooth   Bluetooth devices and status
      trend           Predictive trend analysis from history
      diff, compare   Compare current state vs N days ago
      apps, profile   App energy profiling (CPU-hours, grades)
      changelog       System changelog (app installs/updates/removals)
      watch, w        Live-updating terminal dashboard
      archive         Database maintenance and archiving

    \(TerminalUI.colored("GLOBAL OPTIONS:", .boldWhite))
      --json          Output as JSON (status, score, net, trend, diff, apps)

    \(TerminalUI.colored("LOG OPTIONS:", .boldWhite))
      --info          Show database info
      --prune         Remove snapshots older than 30 days

    \(TerminalUI.colored("HISTORY OPTIONS:", .boldWhite))
      --1h/--6h/--12h/--7d   Time window shortcuts
      --hours N       Custom time window in hours

    \(TerminalUI.colored("NET SUBCOMMANDS:", .boldWhite))
      overview        Network overview with topology (default)
      topology, topo  Detailed network map and device layout
      bandwidth, bw   Throughput and per-service bandwidth chart
      connections     Show active TCP connections
      services        Group connections by service type
      home            Show devices on home network
      wifi, signal    WiFi signal diagnostics
      speed           Live throughput monitor

    \(TerminalUI.colored("DIFF OPTIONS:", .boldWhite))
      --1d/--7d/--30d Time period to compare against (default: 7d)

    \(TerminalUI.colored("APPS OPTIONS:", .boldWhite))
      --1d/--7d/--30d Time period for profiling (default: 7d)

    \(TerminalUI.colored("CHANGELOG SUBCOMMANDS:", .boldWhite))
      (default)       Show recent changes
      scan            Scan now and record changes
      --30d           Show changes from last 30 days

    \(TerminalUI.colored("ARCHIVE SUBCOMMANDS:", .boldWhite))
      (default)       Show database stats and recommendations
      run             Archive old data and vacuum
      export          Export recent data as JSON
      stats           Detailed database statistics

    \(TerminalUI.colored("WATCH OPTIONS:", .boldWhite))
      -i N            Refresh interval in seconds (default: 2)

    \(TerminalUI.colored("CLEAN OPTIONS:", .boldWhite))
      --confirm       Actually delete with per-item confirmation

    \(TerminalUI.colored("GENERAL:", .boldWhite))
      --help, -h      Show this help
      --version, -v   Show version

    """)
}
