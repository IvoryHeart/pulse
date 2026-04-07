# pulse — macOS Health Monitor

A health monitoring tool for macOS. CLI with a terminal dashboard, plus a SwiftUI menu bar app. Written in pure Swift with zero external dependencies.

`pulse` gives you a single health score (0--100) that summarizes the state of your Mac across CPU, memory, disk, thermals, battery, and runaway processes. Log snapshots to a local SQLite database and view trends over time with sparkline charts.

## Features

- **Health score** -- composite 0--100 score with explainable per-category deductions
- **System dashboard** -- CPU, memory, disk, battery, thermal state, and top processes in one view
- **Resource-heavy process finder** -- identifies CPU and memory hogs with actionable suggestions
- **Cleanup scanner** -- finds reclaimable space in caches, logs, derived data, old downloads, and trash
- **Health logging** -- record snapshots to SQLite (`~/.pulse/health.db`) for longitudinal tracking
- **History with sparklines** -- view CPU, memory, load, swap, and battery trends over time
- **Network overview** -- active interfaces, WiFi signal quality, throughput, connections, services, home devices
- **WiFi diagnostics** -- RSSI, noise floor, SNR, channel, band, PHY mode, transmit rate
- **JSON output** -- all model structs are `Codable`; pass `--json` for machine-readable output
- **Menu bar app** -- SwiftUI app with live gauges, sparklines, WiFi quality, throughput, and process list
- **Dashboard window** -- Charts framework sparklines, circular gauges, network cards, warnings panel
- **Safe cleanup** -- protected paths, per-item confirmation, double-confirm for items over 1 GB, no sudo

## Install

### Homebrew (recommended)

```
brew tap IvoryHeart/pulse
brew install pulse
```

### From source

```
git clone https://github.com/IvoryHeart/pulse.git && cd pulse
swift build -c release
cp .build/release/pulse /usr/local/bin/pulse
```

To build and run the menu bar app:

```
swift build --product PulseApp
.build/debug/PulseApp
```

## Command Reference

### `pulse status` (alias: `s`)

System health dashboard. This is the default command when you run `pulse` with no arguments.

Displays the health score, CPU/memory/disk/battery gauges, thermal state, load average, and the top 8 processes sorted by CPU. Warnings are shown for high swap, memory pressure, thermal throttling, and runaway processes.

```
pulse status
pulse status --json     # full system snapshot as JSON
```

### `pulse score`

Health score with a detailed breakdown of every deduction.

Each deduction shows its category, label, explanation, and point penalty, sorted by severity. When no issues are detected the output confirms the system is healthy.

```
pulse score
pulse score --json
```

### `pulse hot` (alias: `h`)

Find resource-heavy processes.

Lists CPU-intensive processes (above 10% CPU) and memory-intensive processes (above 500 MB RSS). Includes swap pressure analysis and suggestions such as restarting heavy processes, closing redundant browsers, or freeing memory.

```
pulse hot
```

### `pulse clean` (alias: `c`)

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
pulse clean                # dry run -- scan only
pulse clean --confirm      # interactive cleanup with per-item confirmation
```

When `--confirm` is used, each item requires you to type the full word `yes` to delete. Items over 1 GB trigger a second confirmation. You can type `quit` at any prompt to stop. Protected paths (home directory, Documents, Desktop, Library root, system directories) are blocked and cannot be deleted.

### `pulse log` (alias: `l`)

Record a health snapshot to the SQLite database at `~/.pulse/health.db`.

Each snapshot captures CPU, memory, disk, battery, thermal state, top processes, and the computed health score. Designed for periodic logging via cron or launchd.

```
pulse log                  # record a snapshot
pulse log --info           # show database path, snapshot count, time range
pulse log --prune          # remove snapshots older than 30 days
```

**Tip** -- add a cron job to log every 15 minutes:

```
*/15 * * * * /usr/local/bin/pulse log
```

### `pulse history` (alias: `hist`)

View health trends with sparkline charts in the terminal.

Displays sparklines for CPU usage, memory usage, load average, swap (GB), and battery percentage. Below the charts a summary shows min/avg/max for each metric, the time range, and a thermal state breakdown.

```
pulse history              # last 24 hours (default)
pulse history --1h         # last 1 hour
pulse history --6h         # last 6 hours
pulse history --12h        # last 12 hours
pulse history --7d         # last 7 days
pulse history --hours 48   # custom window
```

### `pulse net` (alias: `n`)

Network overview and monitoring. Without a subcommand, shows the full overview.

```
pulse net                  # overview (default)
pulse net --json           # overview as JSON
```

The overview includes active interfaces, WiFi SSID and signal quality, gateway, DNS servers, a 1-second throughput sample, established connection count, top remote hosts, and device count on the local network.

#### Subcommands

| Subcommand | Alias | Description |
|------------|-------|-------------|
| `pulse net connections` | `conn` | Active TCP connections (up to 30 shown) with local port, remote address, and named remote port |
| `pulse net services` | `svc` | Connections grouped by service type (HTTPS, HTTP, SSH, DNS, etc.) with bar chart |
| `pulse net home` | `devices` | Devices on the home network from the ARP table. MAC addresses are logged to SQLite with first-seen and last-seen timestamps. Includes vendor hints for common manufacturers (Apple, Google, Raspberry Pi, Samsung, Amazon) |
| `pulse net wifi` | `signal` | WiFi signal diagnostics: SSID, BSSID, RSSI, noise floor, SNR, channel, band, channel width, PHY mode, transmit rate, transmit power, and a signal gauge |
| `pulse net speed` | -- | 2-second throughput measurement with download/upload rates and cumulative traffic since boot |

WiFi subcommand also supports JSON:

```
pulse net wifi --json
```

### General

```
pulse help                 # show usage
pulse version              # print version (v0.4.0)
```

## Menu Bar App (PulseApp)

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
pulse/
  Package.swift
  Sources/
    PulseCore/                     # shared library
      Models/
        HealthSnapshot.swift    # CPUInfo, MemoryInfo, DiskInfo, BatteryInfo, ThermalInfo
        HealthScore.swift       # HealthScore, ScoreDeduction, HealthScoreCalculator
        ProcessInfo.swift       # PulseProcessInfo with shortName extraction
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
    pulse/                         # CLI executable
      main.swift                # Command router
      Commands/
        StatusCommand.swift     # pulse status
        ScoreCommand.swift      # pulse score
        HotCommand.swift        # pulse hot
        CleanCommand.swift      # pulse clean
        LogCommand.swift        # pulse log
        HistoryCommand.swift    # pulse history
        NetCommand.swift        # pulse net (all subcommands)
      UI/
        TerminalUI.swift        # ANSI colors, box drawing, gauges
        ProgressBar.swift       # Spinner animation
    PulseApp/                      # SwiftUI menu bar app
      PulseApp.swift               # @main App with MenuBarExtra + Window
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
| `PulseCore` | Library | IOKit, CoreWLAN |
| `pulse` | Executable | PulseCore |
| `PulseApp` | Executable | PulseCore, SwiftUI, Charts |

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

Health snapshots are stored in a SQLite database at `~/.pulse/health.db`. The schema includes three tables:

- **snapshots** -- one row per `pulse log` invocation with all system metrics and the health score
- **top_processes** -- top 10 processes per snapshot with CPU%, memory%, and RSS
- **connection_log** -- network device sightings with MAC address, IP, hostname, and first/last seen timestamps

Use `pulse log --prune` to remove data older than 30 days.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9 or later
- Apple Silicon or Intel

## License

See LICENSE file for details.
