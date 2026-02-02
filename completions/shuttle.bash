# Bash completion for shuttle
# Install: source this file in .bashrc

_shuttle_completions() {
    local cur prev commands
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    commands="offload restore status list config health help"

    case $prev in
        shuttle)
            COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            return 0
            ;;
        offload|off|o|restore|res|r|status|stat|s)
            # Complete directories
            COMPREPLY=( $(compgen -d -- "$cur") )
            return 0
            ;;
    esac

    # Default to directory completion
    COMPREPLY=( $(compgen -d -- "$cur") )
}

complete -F _shuttle_completions shuttle
