# aur-taw (The Arch Way)

A minimalist, opt-in, and RAM-safe AUR (Arch User Repository) helper written entirely in pure Bash. 

Unlike traditional AUR helpers that take over your entire system and blindly scan for foreign packages, `aur-taw` is designed for purists. It uses a local flat-file database to track **only the packages you explicitly tell it to track**, giving you absolute control over your system.

## Table of Contents
* [Key Features & Security Measures](#key-features--security-measures)
* [Dependencies](#dependencies)
* [Installation (AUR Method)](#installation-aur-method)
  * [The Auto-Bootstrap](#the-auto-bootstrap)
  * [Enable Autocompletion](#enable-autocompletion)
* [Sudo Password Mitigation](#sudo-password-mitigation)
* [Usage Guide & Commands](#usage-guide--commands)
  * [Search](#search)
  * [Add / Update](#add--update)
  * [Import (Already Installed)](#import-already-installed)
  * [List](#list)
  * [Install & Upgrade](#install--upgrade)
  * [Check Updates](#check-updates)
  * [View PKGBUILD](#view-pkgbuild)
  * [Log (Git History)](#log-git-history)
  * [Remove (From Memory)](#remove-from-memory)
  * [Uninstall (From System)](#uninstall-from-system)
* [License](#license)


## Key Features & Security Measures

* **KISS Compliant & Modular**: No Go, no Rust, no background magic. Just standard Bash cleanly divided into modular libraries (`lib/`) for maximum maintainability.
* **Smart Build Engine**: Acts like `pacman -S --needed`. It intelligently skips compiling packages that are already installed and up-to-date, saving you immense amounts of time.
* **RAM-Safe Builds**: Large AUR packages (like browsers or electron apps) can easily crash your system if compiled in `tmpfs` (RAM). `aur-taw` clones and builds everything on your physical disk (`~/.cache/aur-taw`), keeping your memory free and your system stable.
* **Self-Updating**: `aur-taw` automatically tracks itself upon first run, allowing it to update itself through the standard update checking process.
* **Offline-Ready List**: The `list` command instantly displays your installed versions alongside the latest known AUR versions directly from local memory, without hanging on slow network requests.
* **Smart Import**: Easily migrate from other helpers by scanning your system for installed AUR packages and interactively choosing which ones to track.
* **Strict Safeguards**:
  * **Input Validation**: Rejects invalid URLs and spaces in aliases to protect database integrity.
  * **Pacman Lock Check**: Verifies `/var/lib/pacman/db.lck` before starting any operation.
  * **Removal Blocker**: Prevents you from untracking an alias using `remove` if the software is still physically installed on your system. It also strictly protects the `aur-taw` alias from accidental removal.
  * **VCS/Bin Alerts**: Warns you if you attempt to downgrade a non-standard package where specific commits might be ignored or missing.
* **Time Machine (Downgrades)**: Easily install a specific version of a package by appending a git commit hash.
* **Clean Workflow**: Automatically detects missing AUR dependencies, provides links to add them, and prompts you to remove build orphans once the installation is done.
* **Bash Autocompletion**: Full `TAB` completion support for commands, tracking aliases, and mass-processing flags.

## Dependencies

Ensure you have the required base tools installed on your Arch system:

    sudo pacman -S --needed base-devel git curl jq less

*(Note: `base-devel` provides `makepkg`, which is mandatory for building AUR packages. `less` is used to safely view `PKGBUILD` files).*

## Installation (AUR Method)

`aur-taw` is designed to be installed the standard "Arch Way" using `makepkg`.

1. Clone the repository from the AUR:
    git clone https://aur.archlinux.org/aur-taw.git

2. Navigate into the directory and build/install the package:
    cd aur-taw
    makepkg -si

3. You can now safely delete the cloned directory, as `aur-taw` is installed on your system.

### The Auto-Bootstrap
The first time you run any `aur-taw` command (e.g., `aur-taw check`), the tool will initialize its configuration files in `~/.config/aur-taw/` and **automatically add itself to the tracking list**. From that moment on, `aur-taw` will check for its own updates and self-upgrade just like any other tracked package!

### Enable Autocompletion
The installation automatically places the completion script in the correct system directory. To make the `TAB` autocompletion work immediately without rebooting your terminal, simply close and reopen your terminal, or run:

    source /usr/share/bash-completion/completions/aur-taw

## Sudo Password Mitigation

By default, Linux security (`tty_tickets` and subshells) might prompt you for your `sudo` password multiple times during long package compilations. 

If you prefer a seamless, uninterrupted installation experience, you can configure Sudo to allow `pacman` to run without a password prompt. **This is completely optional and also a security compromise.**

1. Open the sudoers configuration safely:

       sudo EDITOR=nano visudo -f /etc/sudoers.d/aur-taw

2. Add the following line (replace `your_username` with your actual Linux user):

       your_username ALL=(ALL) NOPASSWD: /usr/bin/pacman

3. Save and exit. Now `aur-taw` will compile and install packages completely unattended!


## Usage Guide & Commands

All your tracked packages are securely saved in a local memory file: `~/.config/aur-taw/repos.txt`.

### Search
Search for a package by its exact name on the AUR.

    aur-taw search <keyword>
    # Example: aur-taw search spotify

**Example Output:**

    Searching for 'spotify' on AUR...
    ------------------------------------------------------------------------
    spotify 1.2.37.701-1 [Votes: 4500]
       A proprietary music streaming service
       https://aur.archlinux.org/spotify.git


### Add / Update
Add a repository to your tracking list using a custom alias. If the alias already exists, it updates the URL.
*Note: The alias must be a single word without spaces (e.g., `music-player`). The URL must be a valid `http://` or `https://` git link.*

    aur-taw add <alias> <git-url>
    # Example: aur-taw add music-player https://aur.archlinux.org/spotify.git

### Import (Already Installed)
Scan your system for foreign packages and query the AUR to see which ones are valid. You will be prompted `[y/N]` for each package, allowing you to selectively add them to your tracking memory.

    aur-taw import

If you want to skip the prompts and instantly add all valid installed AUR packages to your tracking list, use the `--all` flag:

    aur-taw import --all

### List
Show a beautifully formatted table of all tracked aliases, their real package names, installed versions, the latest known AUR versions, and repository links.

    aur-taw list

**Example Output:**

    Saved repositories:
      (Run 'aur-taw check' to refresh the LATEST AUR column)

    ALIAS         REAL NAME  INSTALLED VERSION  LATEST AUR    REPO LINK
    -----         ---------  -----------------  ----------    ---------
    aur-taw       aur-taw    1.2.0              1.2.0         https://aur.archlinux.org/aur-taw.git
    music-player  spotify    1.2.37.701-1       1.2.40.100-1  https://aur.archlinux.org/spotify.git
    my-bonsai     cbonsai    Not-installed      Unknown       https://aur.archlinux.org/cbonsai-git.git


### Install & Upgrade
Clone, compile, and install packages. `aur-taw` is smart: if you ask it to install a package that is already installed, it will automatically skip it to save time, unless you explicitly request an upgrade.

    # Install a specific tracked package (Skips if already installed)
    aur-taw install music-player

    # Upgrade a specific package (Only builds if a newer version is available)
    aur-taw install music-player --upgrade

    # Mass process ALL tracked packages (Builds only missing ones)
    aur-taw install --all

    # Mass UPGRADE all tracked packages (The equivalent of a full AUR system update)
    aur-taw install --all --upgrade

    # Time Machine: Install a specific older version using a Git commit hash
    aur-taw install music-player@a1b2c3d

*(Note: Mass commands using `--all` will trigger a single safety prompt before proceeding completely unattended via `--noconfirm`).*

**Note on Downgrades:** Installing via specific commit (`@hash`) works flawlessly for **standard packages**. However, for VCS packages (`-git`, `-svn`) `makepkg` will ignore the commit and pull the latest source code anyway. For binary packages (`-bin`), the build will fail if the author deleted the old binary from their server. The script will throw an alert if you attempt to downgrade a non-standard package.

### Check Updates
Perform a blazing-fast bulk API call to check for updates on the AUR. This command updates your local memory database silently, populating the `LATEST AUR` column for your `list` command.

    aur-taw check

**Example Output:**

    Checking for updates and refreshing memory...
      [UPDATE] music-player: 1.2.37.701-1 -> 1.2.40.100-1

    Check completed. Memory updated.
    Run 'aur-taw list' to see current statuses,
    or 'aur-taw install --all --upgrade' to apply available updates.


### View PKGBUILD
Download and inspect the `PKGBUILD` of a tracked package using `less` before deciding to install it.

    aur-taw view music-player

**Example Output:**

    # Maintainer: John Doe <john@example.com>
    pkgname=spotify
    pkgver=1.2.37.701
    pkgrel=1
    pkgdesc="A proprietary music streaming service"
    arch=('x86_64')
    ...
    (END)


### Log (Git History)
View the last 10 commits of a package, including their hashes, exact version numbers, and commit messages. Extremely useful for finding the right hash for a downgrade.

    aur-taw log music-player

**Example Output:**

    COMMIT   | VERSION         | COMMIT MESSAGE
    ------------------------------------------------------------------------
    a1b2c3d  | 1.2.37.701-1    | Update to version 1.2.37.701
    f9e8d7c  | 1.2.31.1205-2   | Fix missing dependency
    b4a5d6e  | 1.2.31.1205-1   | Update to version 1.2.31.1205


### Remove (From Memory)
Remove an alias from your `repos.txt` tracking list. 
*Note: This command will be blocked if the software is still installed on your system, preventing untracked "orphan" software. The `aur-taw` alias itself is strictly protected and cannot be removed.*

    aur-taw remove music-player


### Uninstall (From System)
The proper way to remove software. It uninstalls the package and its unused dependencies from your Arch system via `pacman`. Upon success, it will conveniently ask if you also want to remove the alias from your tracking memory.

    aur-taw uninstall music-player

**Self-Destruct & Cleanup:** If you use this command to uninstall the helper itself (`aur-taw uninstall aur-taw`), you will be presented with a security warning. If you proceed, the script will completely purge itself, its configuration folder, and its cache from your system, leaving no trace behind while keeping your other AUR packages safely installed.


## License
This project is licensed under the **MIT License**. See the `LICENSE` file for details.