#!/bin/bash

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/aur-taw"
CONFIG_FILE="$CONFIG_DIR/repos.txt"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/aur-taw"

init_core() {
    local is_first_run=0

    if [[ ! -f "$CONFIG_FILE" ]]; then
        is_first_run=1
    fi

    mkdir -p "$CONFIG_DIR" "$CACHE_DIR"
    touch "$CONFIG_FILE"

    if [[ $is_first_run -eq 1 ]]; then
        local initial_taw_ver="Unknown"
        if pacman -Qq aur-taw >/dev/null 2>&1; then
            initial_taw_ver=$(pacman -Q aur-taw 2>/dev/null | awk '{print $2}')
        fi
        echo "aur-taw https://aur.archlinux.org/aur-taw.git $initial_taw_ver" >> "$CONFIG_FILE"
    fi

    if [[ $is_first_run -eq 0 ]] && grep -qE '^[^ ]+ [^ ]+$' "$CONFIG_FILE"; then
        sed -i 's/$/ Unknown/' "$CONFIG_FILE"
    fi
}

get_installed_pkg() {
    local base="$1"
    
    if pacman -Qq "$base" >/dev/null 2>&1; then
        echo "$base"
        return 0
    fi
    
    local stripped
    stripped=$(echo "$base" | sed -E 's/-(git|bin|svn|hg|bzr|cvs|nightly)$//')
    
    if [[ "$stripped" != "$base" ]] && pacman -Qq "$stripped" >/dev/null 2>&1; then
        echo "$stripped"
        return 0
    fi
    
    return 1
}