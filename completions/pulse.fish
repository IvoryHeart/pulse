# Fish completions for pulse

# Disable file completions by default
complete -c pulse -f

# Top-level commands
complete -c pulse -n '__fish_use_subcommand' -a 'status s' -d 'System health dashboard'
complete -c pulse -n '__fish_use_subcommand' -a 'score' -d 'Health score with breakdown'
complete -c pulse -n '__fish_use_subcommand' -a 'hot h' -d 'Find resource-heavy processes'
complete -c pulse -n '__fish_use_subcommand' -a 'clean c' -d 'Scan for cleanup opportunities'
complete -c pulse -n '__fish_use_subcommand' -a 'log l' -d 'Record a health snapshot'
complete -c pulse -n '__fish_use_subcommand' -a 'history hist' -d 'View health trends'
complete -c pulse -n '__fish_use_subcommand' -a 'net n' -d 'Network overview and monitoring'
complete -c pulse -n '__fish_use_subcommand' -a 'bt bluetooth' -d 'Bluetooth devices and status'
complete -c pulse -n '__fish_use_subcommand' -a 'trend trends' -d 'Predictive trend analysis'
complete -c pulse -n '__fish_use_subcommand' -a 'diff compare' -d 'Compare state vs N days ago'
complete -c pulse -n '__fish_use_subcommand' -a 'apps profile' -d 'App energy profiling'
complete -c pulse -n '__fish_use_subcommand' -a 'changelog changes' -d 'System changelog'
complete -c pulse -n '__fish_use_subcommand' -a 'watch w' -d 'Live-updating dashboard'
complete -c pulse -n '__fish_use_subcommand' -a 'archive' -d 'Database maintenance'
complete -c pulse -n '__fish_use_subcommand' -a 'help' -d 'Show usage'
complete -c pulse -n '__fish_use_subcommand' -a 'version' -d 'Print version'

# Global options
complete -c pulse -l json -d 'Output as JSON'
complete -c pulse -l help -s h -d 'Show help'
complete -c pulse -l version -s v -d 'Show version'

# net subcommands
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'overview' -d 'Network overview (default)'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'topology topo' -d 'Network map and device layout'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'bandwidth bw' -d 'Throughput and bandwidth chart'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'connections conn' -d 'Active TCP connections'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'services svc' -d 'Connections by service type'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'home devices' -d 'Home network devices'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'wifi signal' -d 'WiFi signal diagnostics'
complete -c pulse -n '__fish_seen_subcommand_from net n' -a 'speed' -d 'Live throughput monitor'

# clean options
complete -c pulse -n '__fish_seen_subcommand_from clean c' -l confirm -d 'Delete with per-item confirmation'

# log options
complete -c pulse -n '__fish_seen_subcommand_from log l' -l info -d 'Show database info'
complete -c pulse -n '__fish_seen_subcommand_from log l' -l prune -d 'Remove old snapshots'

# history options
complete -c pulse -n '__fish_seen_subcommand_from history hist' -l 1h -d 'Last 1 hour'
complete -c pulse -n '__fish_seen_subcommand_from history hist' -l 6h -d 'Last 6 hours'
complete -c pulse -n '__fish_seen_subcommand_from history hist' -l 12h -d 'Last 12 hours'
complete -c pulse -n '__fish_seen_subcommand_from history hist' -l 7d -d 'Last 7 days'
complete -c pulse -n '__fish_seen_subcommand_from history hist' -l hours -d 'Custom hours' -x

# diff options
complete -c pulse -n '__fish_seen_subcommand_from diff compare' -l 1d -d '1 day ago'
complete -c pulse -n '__fish_seen_subcommand_from diff compare' -l 7d -d '7 days ago'
complete -c pulse -n '__fish_seen_subcommand_from diff compare' -l 30d -d '30 days ago'

# apps options
complete -c pulse -n '__fish_seen_subcommand_from apps profile' -l 1d -d 'Last 1 day'
complete -c pulse -n '__fish_seen_subcommand_from apps profile' -l 7d -d 'Last 7 days'
complete -c pulse -n '__fish_seen_subcommand_from apps profile' -l 30d -d 'Last 30 days'

# changelog subcommands
complete -c pulse -n '__fish_seen_subcommand_from changelog changes' -a 'scan' -d 'Scan and record changes'
complete -c pulse -n '__fish_seen_subcommand_from changelog changes' -l 30d -d 'Last 30 days'

# archive subcommands
complete -c pulse -n '__fish_seen_subcommand_from archive' -a 'run' -d 'Archive old data and vacuum'
complete -c pulse -n '__fish_seen_subcommand_from archive' -a 'export' -d 'Export as JSON'
complete -c pulse -n '__fish_seen_subcommand_from archive' -a 'stats' -d 'Detailed statistics'

# watch options
complete -c pulse -n '__fish_seen_subcommand_from watch w' -s i -d 'Refresh interval (seconds)' -x
