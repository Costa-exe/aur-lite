#!/bin/bash

search_aur() {
    local query="$1"
    if [[ -z "$query" ]]; then
        echo "Error: Provide a search query."
        exit 1
    fi
    echo "Searching for '$query' on AUR..."
    echo "------------------------------------------------------------------------"
    curl -s "https://aur.archlinux.org/rpc/v5/search/$query?by=name" | \
        jq -r '.results | sort_by(.NumVotes) | reverse | .[] | "\u001b[1;32m\(.Name)\u001b[0m \(.Version) [Votes: \(.NumVotes)]\n   \u001b[3m\(.Description // "No description")\u001b[0m\n   \u001b[36mhttps://aur.archlinux.org/\(.Name).git\u001b[0m\n"'
}

check_updates() {
    echo "Checking for updates and refreshing memory..."
    local pkgs=()

    while read -r _ url _; do
        [[ -z "$url" ]] && continue
        pkgs+=("$(basename "$url" .git)")
    done < "$CONFIG_FILE"

    if [[ ${#pkgs[@]} -eq 0 ]]; then echo "No packages saved in memory."; return; fi

    local api_query=""
    for pkg in "${pkgs[@]}"; do api_query+="arg[]=$pkg&"; done

    local aur_json=$(curl -s "https://aur.archlinux.org/rpc/v5/info?$api_query")
    local remote_data=$(echo "$aur_json" | jq -r '.results[] | "\(.Name)|\(.Version)"')
    
    local temp_config=$(mktemp)

    while read -r alias_name url old_latest; do
        [[ -z "$alias_name" ]] && continue
        
        local real_pkgname=$(basename "$url" .git)
        local remote_ver=$(echo "$remote_data" | grep "^${real_pkgname}|" | cut -d'|' -f2)

        if [[ -z "$remote_ver" ]]; then
            echo "  [!] $alias_name: Not found on AUR servers."
            echo "$alias_name $url Unknown" >> "$temp_config"
            continue
        fi

        echo "$alias_name $url $remote_ver" >> "$temp_config"

        if [[ "$alias_name" == "aur-taw" && "$VERSION" == *"-dev"* ]]; then
            continue
        fi

        local installed_name=$(get_installed_pkg "$real_pkgname")
        
        if [[ -z "$installed_name" ]]; then
            continue
        fi

        local installed_ver=$(pacman -Q "$installed_name" 2>/dev/null | awk '{print $2}')

        if [[ $(vercmp "$installed_ver" "$remote_ver") -lt 0 ]]; then
            echo "  [UPDATE] $alias_name: $installed_ver -> $remote_ver"
        fi
    done < "$CONFIG_FILE"

    mv "$temp_config" "$CONFIG_FILE"

    echo ""
    echo "Check completed. Memory updated."
    echo "Run 'aur-taw list' to see current statuses,"
    echo "or 'aur-taw install --all --upgrade' to apply available updates."
}

view_pkgbuild() {
    local alias_name="$1"
    if [[ -z "$alias_name" ]]; then echo "Error: Provide the alias."; exit 1; fi
    local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
    if [[ -z "$url" ]]; then echo "Error: Alias not found."; exit 1; fi

    local temp_dir=$(mktemp -d -p "$CACHE_DIR" aur-taw-view-XXXXXX)
    if ! git clone -q "$url" "$temp_dir/repo_dir"; then
        echo "Network error."; rm -rf "$temp_dir"; exit 1
    fi
    ${PAGER:-less} "$temp_dir/repo_dir/PKGBUILD"
    rm -rf "$temp_dir"
}

log_repo() {
    local alias_name="$1"
    if [[ -z "$alias_name" ]]; then echo "Error: Provide the alias."; exit 1; fi
    local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
    if [[ -z "$url" ]]; then echo "Error: Alias not found."; exit 1; fi

    local temp_dir=$(mktemp -d -p "$CACHE_DIR" aur-taw-log-XXXXXX)
    cd "$temp_dir" || exit 1
    if ! git clone -q "$url" repo_dir; then
        echo "Network error."; cd - > /dev/null; rm -rf "$temp_dir"; exit 1
    fi
    cd repo_dir || exit 1

    echo ""
    printf "%-8s | %-15s | %s\n" "COMMIT" "VERSION" "COMMIT MESSAGE"
    echo "------------------------------------------------------------------------"
    git log --format="%h" -n 10 | while read -r hash; do
        local pkgver=$(git show "${hash}:PKGBUILD" 2>/dev/null | grep -E '^pkgver=' | cut -d= -f2 | tr -d '"'\')
        local pkgrel=$(git show "${hash}:PKGBUILD" 2>/dev/null | grep -E '^pkgrel=' | cut -d= -f2 | tr -d '"'\')
        local commit_msg=$(git log -1 --format="%s" "$hash")
        if [[ -n "$pkgver" ]]; then
            printf "%-8s | %-15s | %s\n" "$hash" "${pkgver}-${pkgrel}" "$commit_msg"
        else
            printf "%-8s | %-15s | %s\n" "$hash" "Not available" "$commit_msg"
        fi
    done
    cd - > /dev/null
    rm -rf "$temp_dir"
}