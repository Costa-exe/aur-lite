_aur_taw_completions() {
    local cur prev cmds repos config_file
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    cmds="search add import remove uninstall list view log install check"

    config_file="${XDG_CONFIG_HOME:-$HOME/.config}/aur-taw/repos.txt"
    if [[ -f "$config_file" ]]; then
        repos=$(awk '{print $1}' "$config_file" 2>/dev/null)
    fi

    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${cmds}" -- "${cur}") )
        return 0
    fi

    case "${prev}" in
        install|remove|uninstall|view|log)
            COMPREPLY=( $(compgen -W "${repos}" -- "${cur}") )
            return 0
            ;;
        import)
            COMPREPLY=( $(compgen -W "--all" -- "${cur}") )
            return 0
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

complete -F _aur_taw_completions aur-taw
