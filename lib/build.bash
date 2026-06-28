#!/bin/bash

install_repos() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "Error: Pacman is locked (/var/lib/pacman/db.lck)."
        exit 1
    fi

    local is_upgrade=0
    local is_all=0
    local input_repos=()

    for arg in "$@"; do
        if [[ "$arg" == "--upgrade" ]]; then
            is_upgrade=1
        elif [[ "$arg" == "--all" ]]; then
            is_all=1
        else
            input_repos+=("$arg")
        fi
    done

    if [[ $is_all -eq 1 ]]; then
        mapfile -t input_repos < <(awk '{print $1}' "$CONFIG_FILE")
    fi

    if [[ ${#input_repos[@]} -eq 0 ]]; then 
        echo "Error: Provide an alias to install, or use --all."
        exit 1
    fi

    echo "Analyzing packages..."
    local filtered_repos=()
    
    for item in "${input_repos[@]}"; do
        local alias_name="${item%@*}"
        local commit=""
        if [[ "$item" == *"@"* ]]; then commit="${item#*@}"; fi

        if [[ "$alias_name" == "aur-taw" && "$VERSION" == *"-dev"* ]]; then
            echo "  [!] $alias_name: Skipped (Running dev build $VERSION)."
            continue
        fi

        local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
        local latest_ver=$(awk -v r="$alias_name" '$1==r {print $3}' "$CONFIG_FILE")
        
        if [[ -z "$url" ]]; then continue; fi

        local real_pkgname=$(basename "$url" .git)
        local installed_name=$(get_installed_pkg "$real_pkgname")
        
        if [[ -n "$installed_name" ]]; then
            if [[ -n "$commit" ]]; then
                filtered_repos+=("$item")
            elif [[ $is_upgrade -eq 1 ]]; then
                if [[ "$latest_ver" == "Unknown" || -z "$latest_ver" ]]; then
                    echo "  [?] $alias_name: Unknown remote version. Run 'aur-taw check' first."
                    continue
                fi
                local installed_ver=$(pacman -Q "$installed_name" 2>/dev/null | awk '{print $2}')
                
                if [[ $(vercmp "$installed_ver" "$latest_ver") -lt 0 ]]; then
                    filtered_repos+=("$item")
                else
                    echo "  [i] $alias_name: Already up to date ($installed_ver)."
                fi
            else
                echo "  [i] $alias_name: Already installed. (Pass --upgrade to update it)"
            fi
        else
            filtered_repos+=("$item")
        fi
    done

    input_repos=("${filtered_repos[@]}")
    
    if [[ ${#input_repos[@]} -eq 0 ]]; then
        echo "Nothing to do."
        exit 0
    fi

    local makepkg_flags="-si"
    if [[ $is_all -eq 1 ]]; then
        echo ""
        echo "The following packages will be processed: ${input_repos[*]}"
        echo "WARNING: You are about to mass-process multiple packages."
        echo "This procedure will automatically resolve and install packages and dependencies"
        echo "without asking for further confirmation."
        echo ""
        read -p "Do you want to proceed? [y/N] " resp
        if [[ "$resp" != "y" && "$resp" != "Y" ]]; then
            echo "Operation canceled."
            exit 0
        fi
        makepkg_flags="-si --noconfirm"
    else
        echo ""
        echo "The following packages will be processed: ${input_repos[*]}"
    fi

    for item in "${input_repos[@]}"; do
        local alias_name="${item%@*}"
        local commit=""
        if [[ "$item" == *"@"* ]]; then commit="${item#*@}"; fi

        local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
        if [[ -z "$url" ]]; then echo "Error: '$alias_name' not found in memory."; continue; fi

        echo ""
        echo "=== Starting process for: $alias_name ==="
        local temp_dir=$(mktemp -d -p "$CACHE_DIR" aur-taw-XXXXXX)
        cd "$temp_dir" || continue

        echo "Cloning $url into disk cache..."
        if ! git clone "$url" repo_dir; then
            echo "Error: 'git clone' failed."; cd - > /dev/null; rm -rf "$temp_dir"; continue
        fi
        cd repo_dir || continue

        if [[ -n "$commit" ]]; then
            if [[ "$url" =~ -(git|bin|svn|hg|bzr|nightly)\.git$ ]]; then
                echo "WARNING: You are trying to install a specific commit (@$commit)"
                echo "   of a non-standard package (e.g. -git or -bin)."
                echo "   - VCS packages (-git) will still download the latest source code ignoring the commit."
                echo "   - Binary packages (-bin) will fail if the old executable is no longer online."
                echo ""
                read -p "Do you want to continue anyway? [y/N] " downgrade_resp
                if [[ "$downgrade_resp" != "y" && "$downgrade_resp" != "Y" ]]; then
                    echo "Skipping $alias_name..."
                    cd - > /dev/null
                    rm -rf "$temp_dir"
                    continue
                fi
            fi

            echo "Checkout of version ($commit)..."
            if ! git checkout "$commit"; then
                echo "Error: Checkout failed."; cd - > /dev/null; rm -rf "$temp_dir"; continue
            fi
        fi

        echo "Compiling and installing..."
        local log_file="$temp_dir/makepkg.log"

        set -o pipefail
        LANG=C makepkg $makepkg_flags 2>&1 | tee "$log_file"
        local makepkg_status=$?
        set +o pipefail

        if [[ $makepkg_status -ne 0 ]]; then
            echo "Error: 'makepkg' failed."
            local missing_deps=$(grep "target not found:" "$log_file" | awk -F': ' '{print $2}' | tr -d '\r')
            if [[ -n "$missing_deps" ]]; then
                echo ""
                echo "Missing AUR dependencies to compile this package:"
                for dep in $missing_deps; do
                    echo -e "\u001b[1;32m$dep\u001b[0m -> \u001b[36mhttps://aur.archlinux.org/$dep.git\u001b[0m"
                done
            fi
        else
            echo "Success: Installation completed."
            
            local real_pkg=$(basename "$url" .git)
            local newly_installed=$(get_installed_pkg "$real_pkg")
            if [[ -n "$newly_installed" ]]; then
                local newly_ver=$(pacman -Q "$newly_installed" 2>/dev/null | awk '{print $2}')
                if [[ -n "$newly_ver" ]]; then
                    sed -i "s|^$alias_name $url.*|$alias_name $url $newly_ver|" "$CONFIG_FILE"
                fi
            fi
        fi

        echo "Cleaning cache for $alias_name..."
        cd - > /dev/null
        rm -rf "$temp_dir"
    done

    local orphans=$(pacman -Qtdq 2>/dev/null)
    if [[ -n "$orphans" ]]; then
        echo ""
        echo "Found orphans: $(echo $orphans | tr '\n' ' ')"
        read -p "Do you want to remove them from the system? [y/N] " resp
        if [[ "$resp" == "y" || "$resp" == "Y" ]]; then
            sudo pacman -Rns --noconfirm $(echo "$orphans")
            echo "Cleanup completed."
        fi
    fi
}

uninstall_pkg() {
    local alias_name="$1"
    if [[ -z "$alias_name" ]]; then echo "Error: Provide the alias to uninstall."; exit 1; fi
    
    local url=$(awk -v r="$alias_name" '$1==r {print $2}' "$CONFIG_FILE")
    local real_pkgname="$alias_name"
    
    if [[ -n "$url" ]]; then
        real_pkgname=$(basename "$url" .git)
    fi

    if [[ "$alias_name" == "aur-taw" && "$VERSION" == *"-dev"* ]]; then
        echo "[!] ERROR: 'aur-taw' is currently installed in development mode ($VERSION)."
        echo "    It is not managed by pacman and cannot be uninstalled here."
        echo "    To uninstall, enter the source code directory and run:"
        echo "    sudo make uninstall"
        exit 1
    fi

    local installed_name=$(get_installed_pkg "$real_pkgname")

    if [[ -z "$installed_name" ]]; then
        echo "Cannot proceed: The software associated with '$alias_name' is not installed."
        exit 1
    fi

    if [[ "$installed_name" == "aur-taw" ]]; then
        echo ""
        echo "WARNING: You are about to completely uninstall aur-taw from your system!"
        echo "This will remove aur-taw, its configuration files, and cache."
        echo "However, the individual AUR packages you have installed will NOT be removed."
        echo "If you choose to proceed, aur-taw can only be used again after a fresh installation."
        echo ""
        read -p "Are you absolutely sure you want to proceed? [y/N] " confirm_suicide
        if [[ "$confirm_suicide" != "y" && "$confirm_suicide" != "Y" ]]; then
            echo "Operation canceled."
            exit 0
        fi
    fi

    echo "Uninstalling '$installed_name' (and orphaned dependencies)..."
    sudo pacman -Rns "$installed_name"
    
    if ! pacman -Qq "$installed_name" >/dev/null 2>&1; then
        echo "Uninstallation completed."

        if [[ "$installed_name" == "aur-taw" ]]; then
            echo "Cleaning up aur-taw files and cache..."
            rm -rf "$CONFIG_DIR" "$CACHE_DIR"
            echo "Total cleanup completed. Goodbye!"
            exit 0
        fi
        
        if [[ -n "$url" ]]; then
            echo ""
            read -p "Do you also want to remove the repository '$alias_name' from your memory? [y/N] " resp
            if [[ "$resp" == "y" || "$resp" == "Y" ]]; then
                sed -i "/^$alias_name /d" "$CONFIG_FILE"
                echo "Removed from memory: $alias_name"
            fi
        fi
    else
        echo "Operation canceled or failed."
    fi
}