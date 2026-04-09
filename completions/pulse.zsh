#compdef pulse

_pulse_commands() {
    local -a commands
    commands=(
        'status:System health dashboard (default)'
        's:System health dashboard (alias)'
        'score:Composite health score with breakdown'
        'hot:Find resource-heavy processes'
        'h:Find resource-heavy processes (alias)'
        'clean:Scan for cleanup opportunities'
        'c:Scan for cleanup opportunities (alias)'
        'log:Record a health snapshot to database'
        'l:Record a health snapshot (alias)'
        'history:View health trends with sparkline charts'
        'hist:View health trends (alias)'
        'net:Network overview and monitoring'
        'n:Network overview (alias)'
        'bt:Bluetooth devices and status'
        'bluetooth:Bluetooth devices and status'
        'trend:Predictive trend analysis'
        'trends:Predictive trend analysis (alias)'
        'diff:Compare current state vs N days ago'
        'compare:Compare current state (alias)'
        'apps:App energy profiling'
        'profile:App energy profiling (alias)'
        'changelog:System changelog'
        'changes:System changelog (alias)'
        'watch:Live-updating terminal dashboard'
        'w:Live-updating terminal dashboard (alias)'
        'archive:Database maintenance and archiving'
        'help:Show usage information'
        'version:Print version'
    )
    _describe -t commands 'pulse command' commands
}

_pulse_net_subcommands() {
    local -a subcommands
    subcommands=(
        'overview:Network overview with topology (default)'
        'topology:Detailed network map and device layout'
        'topo:Detailed network map (alias)'
        'bandwidth:Throughput and bandwidth chart'
        'bw:Throughput and bandwidth chart (alias)'
        'connections:Active TCP connections'
        'conn:Active TCP connections (alias)'
        'services:Connections grouped by service type'
        'svc:Connections grouped by service (alias)'
        'home:Devices on home network'
        'devices:Devices on home network (alias)'
        'wifi:WiFi signal diagnostics'
        'signal:WiFi signal diagnostics (alias)'
        'speed:Live throughput monitor'
    )
    _describe -t subcommands 'net subcommand' subcommands
}

_pulse_changelog_subcommands() {
    local -a subcommands
    subcommands=(
        'scan:Scan now and record changes'
    )
    _describe -t subcommands 'changelog subcommand' subcommands
}

_pulse_archive_subcommands() {
    local -a subcommands
    subcommands=(
        'run:Archive old data and vacuum'
        'export:Export recent data as JSON'
        'stats:Detailed database statistics'
    )
    _describe -t subcommands 'archive subcommand' subcommands
}

_pulse() {
    local curcontext="$curcontext" state line
    typeset -A opt_args

    _arguments -C \
        '--json[Output as JSON]' \
        '--help[Show help]' \
        '-h[Show help]' \
        '--version[Show version]' \
        '-v[Show version]' \
        '1: :_pulse_commands' \
        '*:: :->args'

    case $state in
        args)
            case $line[1] in
                net|n)
                    _arguments \
                        '--json[Output as JSON]' \
                        '1: :_pulse_net_subcommands'
                    ;;
                clean|c)
                    _arguments '--confirm[Delete with per-item confirmation]'
                    ;;
                log|l)
                    _arguments \
                        '--info[Show database info]' \
                        '--prune[Remove snapshots older than 30 days]'
                    ;;
                history|hist)
                    _arguments \
                        '--1h[Last 1 hour]' \
                        '--6h[Last 6 hours]' \
                        '--12h[Last 12 hours]' \
                        '--7d[Last 7 days]' \
                        '--hours[Custom time window in hours]:hours:'
                    ;;
                diff|compare)
                    _arguments \
                        '--json[Output as JSON]' \
                        '--1d[Compare against 1 day ago]' \
                        '--7d[Compare against 7 days ago]' \
                        '--30d[Compare against 30 days ago]'
                    ;;
                apps|profile)
                    _arguments \
                        '--json[Output as JSON]' \
                        '--1d[Last 1 day]' \
                        '--7d[Last 7 days]' \
                        '--30d[Last 30 days]'
                    ;;
                changelog|changes)
                    _arguments \
                        '--json[Output as JSON]' \
                        '--30d[Show changes from last 30 days]' \
                        '1: :_pulse_changelog_subcommands'
                    ;;
                watch|w)
                    _arguments '-i[Refresh interval in seconds]:seconds:'
                    ;;
                archive)
                    _arguments \
                        '--json[Output as JSON]' \
                        '1: :_pulse_archive_subcommands'
                    ;;
                status|s|score|trend|trends|bt|bluetooth)
                    _arguments '--json[Output as JSON]'
                    ;;
            esac
            ;;
    esac
}

_pulse "$@"
