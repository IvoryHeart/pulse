_pulse() {
    local cur prev commands net_sub changelog_sub archive_sub
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="status s score hot h clean c log l history hist net n bt bluetooth trend trends diff compare apps profile changelog changes watch w archive help version"
    net_sub="overview topology topo bandwidth bw connections conn services svc home devices wifi signal speed"
    changelog_sub="scan"
    archive_sub="run export stats"

    # Complete subcommands for specific commands
    case "${COMP_WORDS[1]}" in
        net|n)
            COMPREPLY=( $(compgen -W "$net_sub --json" -- "$cur") )
            return 0
            ;;
        changelog|changes)
            COMPREPLY=( $(compgen -W "$changelog_sub --json --30d" -- "$cur") )
            return 0
            ;;
        archive)
            COMPREPLY=( $(compgen -W "$archive_sub --json" -- "$cur") )
            return 0
            ;;
        clean|c)
            COMPREPLY=( $(compgen -W "--confirm" -- "$cur") )
            return 0
            ;;
        log|l)
            COMPREPLY=( $(compgen -W "--info --prune" -- "$cur") )
            return 0
            ;;
        history|hist)
            COMPREPLY=( $(compgen -W "--1h --6h --12h --7d --hours" -- "$cur") )
            return 0
            ;;
        diff|compare)
            COMPREPLY=( $(compgen -W "--json --1d --7d --30d" -- "$cur") )
            return 0
            ;;
        apps|profile)
            COMPREPLY=( $(compgen -W "--json --1d --7d --30d" -- "$cur") )
            return 0
            ;;
        watch|w)
            COMPREPLY=( $(compgen -W "-i" -- "$cur") )
            return 0
            ;;
        status|s|score|trend|trends|bt|bluetooth)
            COMPREPLY=( $(compgen -W "--json" -- "$cur") )
            return 0
            ;;
    esac

    # Top-level: complete commands and global options
    if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "--json --help -h --version -v" -- "$cur") )
    else
        COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    fi
}

complete -F _pulse pulse
