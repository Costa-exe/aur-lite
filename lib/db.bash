#!/bin/bash

add_repo() {
    if [[ $# -ne 2 ]]; then
        echo "Error: Invalid number of parameters."
        echo "Usage: aur-taw add <alias> <url>"
        echo "Note: The alias cannot contain spaces. Use hyphens instead (e.g., my-package)."
        exit 1
    fi

    local name="$1"
    local url="$2"

    if [[ "$name" =~ [[:space:]] ]]; then
        echo "Error: The alias '$name' contains spaces."
        echo "Please use a single word without spaces (e.g., my-package)."
        exit 1
    fi

    if [[ ! "$url" =~ ^https?:// ]]; then
        echo "Error: The URL provided does not seem valid. It must start with http:// or https://"
        exit 1
    fi

    local existing_alias
    existing_alias=$(awk -v u="$url" '$2==u {print $1}' "$CONFIG_FILE")
    
    if [[ -n "$existing_alias" ]]; then
        if [[ "$existing_alias" == "$name" ]]; then
            echo "Info: The repository is already tracked as '$name'."
            exit 0
        else
            echo "Error: The repository '$url' is already tracked under the alias '$existing_alias'."
            exit 1
        fi
    fi

    if grep -q "^$name " "$CONFIG_FILE"; then
        local old_url
        old_url=$(awk -v r="$name" '$1==r {print $2}' "$CONFIG_FILE")
        echo "Warning: Alias '$name' already exists and points to '$old_url'."
        read -p "Do you want to overwrite it with the new URL? [y/N] " resp
        if [[ "$resp" != "y" && "$resp" != "Y" ]]; then
            echo "Operation canceled."
            exit 0
        fi
    fi

    sed -i "/^$name /d" "$CONFIG_FILE"
    
    local real_pkgname=$(basename "$url" .git)
    local installed_name=$(get_installed_pkg "$real_pkgname")
    local initial_ver="Unknown"
    
    if [[ -n "$installed_name" ]]; then
        initial_ver=$(pacman -Q "$installed_name" 2>/dev/null | awk '{print $2}')
    fi

    echo "$name $url $initial_ver" >> "$CONFIG_FILE"
    echo "Saved: $name -> $url"
}

remove_repo() {
    local alias_name="$1"
    if [[ -z "$alias_name" ]]; then echo "Error: Provide the alias."; exit 1; fi

    if [[ "$alias_name" == "aur-taw" ]]; then
        if [[ "$VERSION" == *"-dev"* ]]; then
            echo "[!] ERROR: 'aur-taw' is currently installed in development mode ($VERSION)."
            echo "    It cannot be managed or removed from memory this way."
            echo "    To remove it cleanly, go to the source directory and run:"
            echo "    sudo make uninstall"
            exit 1
        fi
        echo "Error: The 'aur-taw' repository is essential for self-updates and cannot be removed from memory."
        exit 1
    fi
    
    local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
    
    if [[ -z "$url" ]]; then 
        echo "Error: Alias '$alias_name' not found in memory."
        exit 1
    fi

    local real_pkgname=$(basename "$url" .git)
    local installed_name=$(get_installed_pkg "$real_pkgname")
    
    if [[ -n "$installed_name" ]]; then
        echo "Cannot remove alias '$alias_name' from memory!"
        echo "The software is still physically installed in the system under the name: '$installed_name'."
        echo "To remove everything cleanly, use first: aur-taw uninstall $alias_name"
        exit 1
    fi

    sed -i "/^$alias_name /d" "$CONFIG_FILE"
    echo "Removed from memory: $alias_name"
}

list_repos() {
    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo "No repositories added."
        return
    fi

    local output="ALIAS|REAL NAME|INSTALLED VERSION|LATEST AUR|REPO LINK\n"
    output+="-----|---------|-----------------|----------|---------\n"
    local count=0

    while read -r alias_name url latest_ver; do
        [[ -z "$alias_name" ]] && continue
        count=$((count + 1))
        
        if [[ -z "$latest_ver" ]]; then
            latest_ver="Unknown"
        fi

        if [[ "$alias_name" == "aur-taw" && "$VERSION" == *"-dev"* ]]; then
            output+="${alias_name}|aur-taw|${VERSION} (Dev Build)|${VERSION} (Dev Build)|${url}\n"
            continue
        fi

        local real_pkgname=$(basename "$url" .git)
        local installed_name=$(get_installed_pkg "$real_pkgname")
        local installed_ver="Not-installed"
        
        if [[ -n "$installed_name" ]]; then
            installed_ver=$(pacman -Q "$installed_name" 2>/dev/null | awk '{print $2}')
        else
            installed_name="$real_pkgname"
        fi
        
        output+="${alias_name}|${installed_name}|${installed_ver}|${latest_ver}|${url}\n"
    done < "$CONFIG_FILE"

    if [[ $count -eq 0 ]]; then
        echo "No repositories added."
        return
    fi

    echo "Saved repositories:"
    echo "  (Run 'aur-taw check' to refresh the LATEST AUR column)"
    echo ""
    echo -e "$output" | column -t -s '|'
}

import_repos() {
    local import_all=0
    if [[ "$1" == "--all" ]]; then
        import_all=1
    fi

    echo "Searching for already installed AUR packages..."
    
    local foreign_pkgs=($(pacman -Qmq 2>/dev/null))
    
    if [[ ${#foreign_pkgs[@]} -eq 0 ]]; then
        echo "No foreign packages found on the system."
        return
    fi

    echo "Found ${#foreign_pkgs[@]} foreign packages. Verifying presence on AUR servers..."

    local api_query=""
    for pkg in "${foreign_pkgs[@]}"; do 
        api_query+="arg[]=$pkg&"
    done

    local aur_json=$(curl -s "https://aur.archlinux.org/rpc/v5/info?$api_query")
    local valid_aur_pkgs=($(echo "$aur_json" | jq -r '.results[].Name'))

    if [[ ${#valid_aur_pkgs[@]} -eq 0 ]]; then
        echo "None of the installed foreign packages are from AUR."
        return
    fi

    echo ""
    echo "The following installed packages were found on AUR:"
    
    local added_count=0
    for pkg in "${valid_aur_pkgs[@]}"; do
        local url="https://aur.archlinux.org/$pkg.git"
        
        if awk '{print $2}' "$CONFIG_FILE" | grep -Fq "$url"; then
            continue
        fi
        
        local installed_ver=$(pacman -Q "$pkg" 2>/dev/null | awk '{print $2}')
        [[ -z "$installed_ver" ]] && installed_ver="Unknown"
        
        if [[ $import_all -eq 1 ]]; then
            echo "$pkg $url $installed_ver" >> "$CONFIG_FILE"
            echo "  -> Auto-added to memory: $pkg"
            ((added_count++))
        else
            read -p "Do you want to track '$pkg' in aur-taw? [y/N] " resp
            if [[ "$resp" == "y" || "$resp" == "Y" ]]; then
                echo "$pkg $url $installed_ver" >> "$CONFIG_FILE"
                echo "  -> Added to memory: $pkg"
                ((added_count++))
            fi
        fi
    done

    echo ""
    if [[ $added_count -gt 0 ]]; then
        echo "Import completed: $added_count new repositories added."
    else
        echo "No new repositories added."
    fi
}