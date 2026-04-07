# hk -- Mac Housekeeping

A health monitoring tool for macOS. CLI with a terminal dashboard, plus a SwiftUI menu bar app. Written in pure Swift with zero external dependencies.

`hk` gives you a single health score (0--100) that summarizes the state of your Mac across CPU, memory, disk, thermals, battery, and runaway processes. Log snapshots to a local SQLite database and view trends over time with sparkline charts.

## Features

- **Health score** -- composite 0--100 score with explainable per-category deductions
- **System dashboard** -- CPU, memory, disk, battery, thermal state, and top processes in one view
- **Resource-heavy process finder** -- identifies CPU and memory hogs with actionable suggestions
- **Cleanup scanner** -- finds reclaimable space in caches, logs, derived data, old downloads, and trash
- **Health logging** -- record snapshots to SQLite (`~/.hk/health.db`) for longitudinal tracking
- **History with sparklines** -- view CPU, memory, load, swap, and battery trends over time
- **Network overview** -- active interfaces, WiFi signal quality, throughput, connections, services, home devices
- **WiFi diagnostics** -- RSSI, noise floor, SNR, channel, band, PHY mode, transmit rate
- **JSON output** -- all model structs are `Codable`; pass `--json` for machine-readable output
- **Menu bar app** -- SwiftUI app with live gauges, sparklines, WiFi quality, throughput, and process list
- **Dashboard window** -- Charts framework sparklines, circular gauges, network cards, warnings panel
- **Safe cleanup** -- protected paths, per-item confirmation, double-confirm for items over 1 GB, no sudo

## Quick Start

```
git clone <repo-url> && cd housekeeping
swift build
.build/debug/hk              # runs 'hk status' by default
```

For a release build:

```
swift build -c release
cp .build/release/hk /usr/local/bin/hk
```

To build and run the menu bar app:

```
swift build --product HKApp
.build/debug/HKApp
```

## Command Reference

### `hk status` (alias: `s`)

System health dashboard. This is the default command when you run `hk` with no arguments.

Displays the health score, CPU/memory/disk/battery gauges, thermal state, load average, and the top 8 processes sorted by CPU. Warnings are shown for high swap, memory pressure, thermal throttling, and runaway processes.

```
hk status
hk status --json     # full system snapshot as JSON
```

### `hk score`

Health score with a detailed breakdown of every deduction.

Each deduction shows its category, label, explanation, and point penalty, sorted by severity. When no issues are detected the output confirms the system is healthy.

```
hk score
hk score --json
```

### `hk hot` (alias: `h`)

Find resource-heavy processes.

Lists CPU-intensive processes (above 10% CPU) and memory-intensive processes (above 500 MB RSS). Includes swap pressure analysis and suggestions such as restarting heavy processes, closing redundant browsers, or freeing memory.

```
hk hot
```

### `hk clean` (alias: `c`)

Scan for cleanup opportunities.

By default this runs as a **dry run** -- it scans and reports reclaimable space without deleting anything. Scanned locations:

| Location | Category |
|----------|----------|
| `~/Library/Caches` | Caches |
| `~/Library/Logs` | Logs |
| `~/Library/Developer/Xcode/DerivedData` | Dev |
| `~/Library/Developer/Xcode/Archives` | Dev |
| `~/Library/Caches/Homebrew` | Caches |
| `~/.npm/_cacache` | Caches |
| `~/Downloads` (files older than 30 days) | Downloads |
| `~/.Trash` | Trash |

Items under 1 MB are hidden from the report.

```
hk clean                # dry run -- scan only
hk clean --confirm      # interactive cleanup with per-item confirmation
```

When `--confirm` is used, each item requires you to type the full word `yes` to delete. Items over 1 GB trigger a second confirmation. You can type `quit` at any prompt to stop. Protected paths (home directory, Documents, Desktop, Library root, system directories) are blocked and cannot be deleted.

### `hk log` (alias: `l`)

Record a health snapshot to the SQLite database at `~/.hk/health.db`.

Each snapshot captures CPU, memory, disk, battery, thermal state, top processes, and the computed health score. Designed for periodic logging via cron or launchd.

```
hk log                  # record a snapshot
hk log --info           # show database path, snapshot count, time range
hk log --prune          # remove snapshots older than 30 days
```

**Tip** -- add a cron job to log every 15 minutes:

```
*/15 * * * * /usr/local/bin/hk log
```

### `hk history` (alias: `hist`)

View health trends with sparkline charts in the terminal.

Displays sparklines for CPU usage, memory usage, load average, swap (GB), and battery percentage. Below the charts a summary shows min/avg/max for each metric, the time range, and a thermal state breakdown.

```
hk history              # last 24 hours (default)
hk history --1h         # last 1 hour
hk history --6h         # last 6 hours
hk history --12h        # last 12 hours
hk history --7d         # last 7 days
hk history --hours 48   # custom window
```

### `hk net` (alias: `n`)

Network overview and monitoring. Without a subcommand, shows the full overview.

```
hk net                  # overview (default)
hk net --json           # overview as JSON
```

The overview includes active interfaces, WiFi SSID and signal quality, gateway, DNS servers, a 1-second throughput sample, established connection count, top remote hosts, and device count on the local network.

#### Subcommands

| Subcommand | Alias | Description |
|------------|-------|-------------|
| `hk net connections` | `conn` | Active TCP connections (up to 30 shown) with local port, remote address, and named remote port |
| `hk net services` | `svc` | Connections grouped by service type (HTTPS, HTTP, SSH, DNS, etc.) with bar chart |
| `hk net home` | `devices` | Devices on the home network from the ARP table. MAC addresses are logged to SQLite with first-seen and last-seen timestamps. Includes vendor hints for common manufacturers (Apple, Google, Raspberry Pi, Samsung, Amazon) |
| `hk net wifi` | `signal` | WiFi signal diagnostics: SSID, BSSID, RSSI, noise floor, SNR, channel, band, channel width, PHY mode, transmit rate, transmit power, and a signal gauge |
| `hk net speed` | -- | 2-second throughput measurement with download/upload rates and cumulative traffic since boot |

WiFi subcommand also supports JSON:

```
hk net wifi --json
```

### General

```
hk help                 # show usage
hk version              # print version (v0.4.0)
```

## Menu Bar App (HKApp)

The menu bar app shows the health score in the system tray and opens a popover with:

- Health score badge
- Circular mini-gauges for CPU, memory, disk, and battery
- CPU sparkline
- WiFi signal quality with SSID, band, and channel
- Live download/upload throughput
- Top 5 processes by CPU
- Swap and thermal warnings

Clicking "Open Dashboard" opens a full window with:

- Large circular gauges with animated arcs
- Charts framework line/area charts for CPU and memory history
- WiFi detail card (SSID, signal quality, SNR, channel, width, PHY mode, transmit rate)
- Live throughput card with download sparkline
- System info card (CPU model, core count, load average, wired/compressed memory, swap)
- Warnings card
- Full process list with alternating row colors

The app polls every 3 seconds and retains the last 60 samples for sparklines. The menu bar icon changes dynamically based on the health score: a filled heart for healthy, a triangle for warnings, a flame for thermal throttling.

## Architecture

```
housekeeping/
  Package.swift
  Sources/
    HKCore/                     # shared library
      Models/
        HealthSnapshot.swift    # CPUInfo, MemoryInfo, DiskInfo, BatteryInfo, ThermalInfo
        HealthScore.swift       # HealthScore, ScoreDeduction, HealthScoreCalculator
        ProcessInfo.swift       # HKProcessInfo with shortName extraction
      System/
        CPUMonitor.swift        # CPU usage and load average
        MemoryMonitor.swift     # RAM, wired, compressed, swap
        DiskMonitor.swift       # Disk capacity and usage
        BatteryMonitor.swift    # Battery via IOKit
        ThermalMonitor.swift    # Thermal state via ProcessInfo
        ProcessMonitor.swift    # Top processes via ps
      Network/
        NetworkInfo.swift       # Interfaces, SSID, DNS, gateway, traffic stats
        WiFiMonitor.swift       # WiFi diagnostics via CoreWLAN
        ConnectionMonitor.swift # TCP connections via netstat/lsof
        NetworkScanner.swift    # ARP table device discovery
      Storage/
        HealthStore.swift       # SQLite3 database (snapshots, processes, devices)
      Formatters/
        ByteFormatter.swift     # Human-readable byte formatting
    hk/                         # CLI executable
      main.swift                # Command router
      Commands/
        StatusCommand.swift     # hk status
        ScoreCommand.swift      # hk score
        HotCommand.swift        # hk hot
        CleanCommand.swift      # hk clean
        LogCommand.swift        # hk log
        HistoryCommand.swift    # hk history
        NetCommand.swift        # hk net (all subcommands)
      UI/
        TerminalUI.swift        # ANSI colors, box drawing, gauges
        ProgressBar.swift       # Spinner animation
    HKApp/                      # SwiftUI menu bar app
      HKApp.swift               # @main App with MenuBarExtra + Window
      ViewModels/
        SystemViewModel.swift   # @MainActor ObservableObject, polling, history
      Views/
        MenuBarView.swift       # Menu bar popover
        DashboardView.swift     # Dashboard window with Charts
        GaugeView.swift         # CircularGaugeView, SparklineView
        ProcessListView.swift   # Process table
```

Three targets in `Package.swift`:

| Target | Type | Dependencies |
|--------|------|--------------|
| `HKCore` | Library | IOKit, CoreWLAN |
| `hk` | Executable | HKCore |
| `HKApp` | Executable | HKCore, SwiftUI, Charts |

All frameworks are built into macOS. There are no external Swift package dependencies.

## Health Score

The health score starts at 100 and deducts points across six categories. Each deduction includes a human-readable explanation.

| Category | Trigger | Max Penalty |
|----------|---------|-------------|
| CPU | Load-per-core ratio above 0.7 | -15 |
| Memory | Usage above 60% | -15 |
| Memory (swap) | Swap usage above 2 GB | -5 |
| Disk | Usage above 70% | -15 |
| Thermal | Fair / Serious / Critical state | -15 |
| Battery | Cycle count above 500, health below 90% | -10 |
| Processes | Individual processes above 50% CPU or 3 GB RAM | -10 |

Score ratings:

| Range | Rating |
|-------|--------|
| 90--100 | Excellent |
| 75--89 | Good |
| 50--74 | Fair |
| 25--49 | Poor |
| 0--24 | Critical |

Penalties scale linearly within their ranges. For example, memory at 60% has no penalty; at 95% the penalty reaches the maximum of 15 points.

## Data Storage

Health snapshots are stored in a SQLite database at `~/.hk/health.db`. The schema includes three tables:

- **snapshots** -- one row per `hk log` invocation with all system metrics and the health score
- **top_processes** -- top 10 processes per snapshot with CPU%, memory%, and RSS
- **connection_log** -- network device sightings with MAC address, IP, hostname, and first/last seen timestamps

Use `hk log --prune` to remove data older than 30 days.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later
- Apple Silicon or Intel

## License

See LICENSE file for details.
