# aur-lite

A minimalist, opt-in, and RAM-safe AUR (Arch User Repository) helper written entirely in pure Bash. 

Unlike traditional AUR helpers that take over your entire system and blindly scan for foreign packages, `aur-lite` is designed for purists. It uses a local text file to track **only the packages you explicitly tell it to track**, giving you absolute control over your system.

## Table of Contents
* [Key Features & Security Measures](#key-features--security-measures)
* [Dependencies](#dependencies)
* [Installation](#installation)
  * [Enable Autocompletion](#enable-autocompletion)
  * [Uninstallation](#uninstallation)
* [Sudo Password Mitigation](#sudo-password-mitigation)
* [Usage Guide & Commands](#usage-guide--commands)
  * [Search](#search)
  * [Add / Update](#add--update)
  * [List](#list)
  * [Install](#install)
  * [Check Updates](#check-updates)
  * [View PKGBUILD](#view-pkgbuild)
  * [Log (Git History)](#log-git-history)
  * [Remove (From Memory)](#remove-from-memory)
  * [Uninstall (From System)](#uninstall-from-system)
* [License](#license)


## Key Features & Security Measures

* **KISS Compliant**: No Go, no Rust, no background magic. Just standard Bash.
* **RAM-Safe Builds**: Large AUR packages (like browsers or electron apps) can easily crash your system if compiled in `tmpfs` (RAM). `aur-lite` clones and builds everything on your physical disk (`~/.cache/aur-lite`), keeping your memory free and your system stable.
* **Smart Safeguards**:
  * **Pacman Lock Check**: Verifies `/var/lib/pacman/db.lck` before starting any operation.
  * **Removal Blocker**: Prevents you from untracking an alias using `remove` if the software is still physically installed on your system.
  * **VCS/Bin Alerts**: Warns you if you attempt to downgrade a non-standard package where specific commits might be ignored or missing.
* **Time Machine (Downgrades)**: Easily install a specific version of a package by appending a git commit hash.
* **Clean Workflow**: Automatically detects missing AUR dependencies, provides links to add them, and prompts you to remove build orphans once the installation is done.
* **Bash Autocompletion**: Full `TAB` completion support for both commands and your custom package aliases.

## Dependencies

Ensure you have the required base tools installed on your Arch system:

    sudo pacman -S base-devel git curl jq less

*(Note: `base-devel` provides `makepkg`, which is mandatory for building AUR packages. `less` is used to safely view `PKGBUILD` files).*

## Installation

The recommended way to install `aur-lite` is via the provided `Makefile`. This will place the script in `/usr/local/bin` (making it executable from anywhere in your terminal) and configure the bash autocompletion.

    git clone https://github.com/Costa-exe/aur-lite.git
    cd aur-lite
    sudo make install


### Enable Autocompletion
To make the `TAB` autocompletion work immediately without rebooting your terminal, run:

    source /usr/share/bash-completion/completions/aur-lite

*(Alternatively, just close and reopen your terminal).*

### Uninstallation
If you ever want to remove `aur-lite` from your system:

    sudo make uninstall


## Sudo Password Mitigation

By default, Linux security (`tty_tickets` and subshells) might prompt you for your `sudo` password multiple times during long package compilations. 

If you prefer a seamless, uninterrupted installation experience, you can configure Sudo to allow `pacman` to run without a password prompt. **This is completely optional and also a security compromise.**

1. Open the sudoers configuration safely:

       sudo EDITOR=nano visudo -f /etc/sudoers.d/aur-lite

2. Add the following line (replace `your_username` with your actual Linux user):

       your_username ALL=(ALL) NOPASSWD: /usr/bin/pacman

3. Save and exit. Now `aur-lite` will compile and install packages completely unattended!


## Usage Guide & Commands

All your tracked packages are securely saved in a local memory file: `~/.config/aur-lite/repos.txt`.

### Search
Search for a package by its exact name on the AUR.

    aur-lite search <keyword>
    # Example: aur-lite search spotify

**Example Output:**
```text
Searching for 'spotify' on AUR...
------------------------------------------------------------------------
spotify 1.2.37.701-1 [Votes: 4500]
   A proprietary music streaming service
   https://aur.archlinux.org/spotify.git
```

### Add / Update
Add a repository to your tracking list using a custom alias. If the alias already exists, it updates the URL.

    aur-lite add <alias> <git-url>
    # Example: aur-lite add music-player https://aur.archlinux.org/spotify.git


### List
Show a beautifully formatted table of all tracked aliases, their real package names, installed versions, and repository links.

    aur-lite list

**Example Output:**
```text
Saved repositories:

ALIAS         REAL NAME  INSTALLED VERSION  REPO LINK
-----         ---------  -----------------  ---------
music-player  spotify    1.2.37.701-1       https://aur.archlinux.org/spotify.git
my-bonsai     cbonsai    Not-installed      https://aur.archlinux.org/cbonsai-git.git
```

### Install
Clone, compile, and install packages. You can specify one or multiple aliases. If no alias is provided, it processes **all** tracked packages.

    # Install a specific tracked package
    aur-lite install music-player

    # Install all tracked packages
    aur-lite install

    # Install a specific older version (Downgrade) using a Git commit hash
    aur-lite install music-player@a1b2c3d

**Note on Downgrades:** Installing via specific commit (`@hash`) works flawlessly for **standard packages**. However, for VCS packages (`-git`, `-svn`) `makepkg` will ignore the commit and pull the latest source code anyway. For binary packages (`-bin`), the build will fail if the author deleted the old binary from their server. The script will throw an alert if you attempt to downgrade a non-standard package.

### Check Updates
Perform a blazing-fast bulk API call to check if any of your tracked packages have updates available on the AUR. It will prompt you to install them automatically.

    aur-lite check

**Example Output:**
```text
Checking for updates (optimized)...
  music-player: Up to date (1.2.37.701-1)
  my-bonsai (cbonsai): Update available (Not-installed -> 1.4.2-1)

Do you want to install updates now? [y/N]
```

### View PKGBUILD
Download and inspect the `PKGBUILD` of a tracked package using `less` before deciding to install it.

    aur-lite view music-player

**Example Output:**
```text
# Maintainer: John Doe <john@example.com>
pkgname=spotify
pkgver=1.2.37.701
pkgrel=1
pkgdesc="A proprietary music streaming service"
arch=('x86_64')
...
(END)
```

### Log (Git History)
View the last 10 commits of a package, including their hashes, exact version numbers, and commit messages. Extremely useful for finding the right hash for a downgrade.

    aur-lite log music-player

**Example Output:**
```text
COMMIT   | VERSION         | COMMIT MESSAGE
------------------------------------------------------------------------
a1b2c3d  | 1.2.37.701-1    | Update to version 1.2.37.701
f9e8d7c  | 1.2.31.1205-2   | Fix missing dependency
b4a5d6e  | 1.2.31.1205-1   | Update to version 1.2.31.1205
```

### Remove (From Memory)
Remove an alias from your `repos.txt` tracking list. 
*Note: This command will be blocked if the software is still installed on your system, preventing untracked "orphan" software.*

    aur-lite remove music-player


### Uninstall (From System)
The proper way to remove software. It uninstalls the package and its unused dependencies from your Arch system via `pacman`. Upon success, it will conveniently ask if you also want to remove the alias from your tracking memory.

    aur-lite uninstall music-player



## License
This project is licensed under the **MIT License**. See the `LICENSE` file for details.
