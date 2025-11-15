#!/bin/bash
# ==========================================
# install_and_restore.sh
# Install required apps then restore from backup
# Usage: sudo ./install_and_restore.sh /path/to/Backup/20251112_081720
# ==========================================

set -euo pipefail

MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESTORE_DIR="$MASTER_DIR/Restore"
BACKUP_DIR="${1:-}"
if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: sudo $0 /path/to/Backup/20251112_081720"
    exit 1
fi
if [ ! -d "$BACKUP_DIR" ]; then
    echo "Backup folder not found: $BACKUP_DIR"
    exit 1
fi

echo "🔄 Install + Restore started..."
export DEBIAN_FRONTEND=noninteractive
export PATH="$RESTORE_DIR/.local/bin:/snap/bin:$PATH"

# ---------- helper functions ----------
apt_install_if_missing() {
    pkg="$1"
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "Installing $pkg..."
        sudo apt-get install -y "$pkg"
    else
        echo "$pkg already installed. Skipping."
    fi
}

download_if_missing() {
    url="$1"; out="$2"
    if [ ! -f "$out" ]; then
        echo "Downloading $url -> $out"
        wget -q "$url" -O "$out"
    else
        echo "File $out already exists. Skipping download."
    fi
}

# ---------- 0. Basic pre-reqs ----------
sudo apt update -y
sudo apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsof flatpak

# ---------- 1. XAMPP ----------
if [ ! -d "/opt/lampp" ]; then
    echo "Installing XAMPP..."
    XAMPP_URL="https://www.apachefriends.org/xampp-files/8.2.12/xampp-linux-x64-8.2.12-0-installer.run"
    TMP="/tmp/xampp-installer.run"
    download_if_missing "$XAMPP_URL" "$TMP"
    chmod +x "$TMP"
    sudo "$TMP" --mode unattended || { echo "XAMPP install failed"; }
    sudo ln -sf /opt/lampp/lampp /usr/local/bin/xampp || true
else
    echo "XAMPP already installed. Skipping."
fi

# ---------- 2. Node.js (LTS) ----------
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo npm install -g npm@latest
else
    echo "Node.js already installed. Skipping."
fi

# ---------- 3. Composer ----------
if ! command -v composer >/dev/null 2>&1; then
    echo "Installing Composer..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"
    ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384','composer-setup.php');")"
    if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
        echo "Composer installer corrupted! Aborting."
        rm -f composer-setup.php
    else
        sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm -f composer-setup.php
    fi
else
    echo "Composer already installed. Skipping."
fi

# ---------- 4. GitHub Desktop (.deb from shiftkey) ----------
if ! command -v github-desktop >/dev/null 2>&1; then
    echo "Installing GitHub Desktop..."
    REL_JSON="$(mktemp)"
    curl -s "https://api.github.com/repos/shiftkey/desktop/releases/latest" -o "$REL_JSON"
    URL=$(grep -oP '"browser_download_url":\s*"\K([^"]*GitHubDesktop-linux.*?\.deb)(?=")' "$REL_JSON" | head -1)
    rm -f "$REL_JSON"
    if [ -n "$URL" ]; then
        TMP_DEB="/tmp/github-desktop.deb"
        download_if_missing "$URL" "$TMP_DEB"
        sudo dpkg -i "$TMP_DEB" || sudo apt -f install -y
    else
        echo "Could not find GitHub Desktop .deb URL; skipping."
    fi
else
    echo "GitHub Desktop already installed. Skipping."
fi

# ---------- 5. VS Code ----------
if ! command -v code >/dev/null 2>&1; then
    echo "Installing VS Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    cat <<EOF | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt update
    sudo apt install -y code || echo "VS Code install failed"
else
    echo "VS Code already installed. Skipping."
fi

# ---------- 6. Windsurf ----------
if ! command -v windsurf >/dev/null 2>&1; then
    echo "Attempt install Windsurf (apt)."
    # Attempt apt style install (best-effort). If not available, use flatpak fallback.
    WINDSURF_KEY_URL="https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg"
    if wget -qO- "$WINDSURF_KEY_URL" | gpg --dearmor > /tmp/windsurf-stable.gpg; then
        sudo install -D -o root -g root -m 644 /tmp/windsurf-stable.gpg /etc/apt/keyrings/windsurf-stable.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/windsurf-stable.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | sudo tee /etc/apt/sources.list.d/windsurf.list >/dev/null
        sudo apt update
        sudo apt install -y windsurf || ( echo "Windsurf apt failed, will try flatpak"; sudo flatpak install -y flathub io.github.SeerUK.Kooha || true )
    else
        echo "Windsurf apt repo key fetch failed, installing via flatpak"
        sudo flatpak install -y flathub io.github.SeerUK.Kooha || true
    fi
else
    echo "Windsurf already installed. Skipping."
fi

# ---------- 7. uLauncher ----------
if ! command -v ulauncher >/dev/null 2>&1; then
    echo "Installing uLauncher..."
    sudo add-apt-repository ppa:agornostal/ulauncher -y
    sudo apt update -y
    sudo apt install -y ulauncher
    mkdir -p ~/.config/autostart
    if [ -f /usr/share/applications/ulauncher.desktop ]; then
        cp /usr/share/applications/ulauncher.desktop ~/.config/autostart/
        sed -i 's/NoDisplay=true/NoDisplay=false/' ~/.config/autostart/ulauncher.desktop || true
        echo "X-GNOME-Autostart-enabled=true" >> ~/.config/autostart/ulauncher.desktop
    fi
else
    echo "uLauncher already installed. Skipping."
fi

# ---------- 8. Ensure basic tools for restore ----------
sudo apt install -y tar jq

# ---------- 9. Restore data from BACKUP_DIR ----------
echo "🔄 Starting restore from: $BACKUP_DIR"

# helper restore function (copies files, extracts tar.gz)
restore_files() {
    src="$1"      # backup app folder path
    conf_target="$2"
    ext_target="$3"
    if [ -d "$src" ]; then
        mkdir -p "$conf_target"
        # copy config files (common names)
        for f in settings.json keybindings.json shortcuts.json preferences.json; do
            if [ -f "$src/$f" ]; then
                echo "Restoring $src/$f -> $conf_target/$f"
                cp "$src/$f" "$conf_target/$f"
            fi
        done
        # extract extensions tar.gz if exists
        if [ -f "$src/extensions.tar.gz" ]; then
            mkdir -p "$ext_target"
            echo "Extracting $src/extensions.tar.gz -> $ext_target"
            tar -xzf "$src/extensions.tar.gz" -C "$ext_target"
        fi
        # copy extensions_list if present
        if [ -f "$src/extensions_list.txt" ]; then
            cp "$src/extensions_list.txt" "$src/extensions_list_restored.txt" 2>/dev/null || true
        fi
    else
        echo "No backup for $src (skipping)"
    fi
}

# Ulauncher
restore_files "$BACKUP_DIR/ulauncher" "$RESTORE_DIR/.config/ulauncher" "$RESTORE_DIR/.config/ulauncher/extensions"

# VSCode
mkdir -p "$RESTORE_DIR/.config/Code/User"
restore_files "$BACKUP_DIR/vscode" "$RESTORE_DIR/.config/Code/User" "$RESTORE_DIR/.vscode/extensions"

# Windsurf
restore_files "$BACKUP_DIR/windsurf" "$RESTORE_DIR/.config/Windsurf/User" "$RESTORE_DIR/.windsurf/extensions"

# Extension Manager (config + extensions)
restore_files "$BACKUP_DIR/extension-manager" "$RESTORE_DIR/.config/extension-manager" "$RESTORE_DIR/.local/share/gnome-shell/extensions"

# GNOME extensions (user + system)
GNOME_BACKUP="$BACKUP_DIR/gnome-extensions"
if [ -d "$GNOME_BACKUP" ]; then
    if [ -f "$GNOME_BACKUP/user-extensions.tar.gz" ]; then
        mkdir -p "$RESTORE_DIR/.local/share/gnome-shell/extensions"
        tar -xzf "$GNOME_BACKUP/user-extensions.tar.gz" -C "$RESTORE_DIR/.local/share/gnome-shell/extensions"
    fi
    if [ -f "$GNOME_BACKUP/system-extensions.tar.gz" ]; then
        echo "Restoring system GNOME extensions (sudo required)..."
        sudo tar -xzf "$GNOME_BACKUP/system-extensions.tar.gz" -C /usr/share/gnome-shell/extensions
    fi
    if [ -f "$GNOME_BACKUP/extensions_list.txt" ]; then
        cp "$GNOME_BACKUP/extensions_list.txt" "$BACKUP_DIR/gnome-extensions/extensions_list_restored.txt" 2>/dev/null || true
    fi
fi

# XAMPP config restore (sudo)
if [ -d "$BACKUP_DIR/xampp" ]; then
    for f in etc.tar.gz php/etc.tar.gz; do
        if [ -f "$BACKUP_DIR/xampp/$f" ]; then
            echo "Restoring XAMPP $f -> /opt/lampp (sudo)..."
            sudo tar -xzf "$BACKUP_DIR/xampp/$f" -C /opt/lampp
        fi
    done
fi

# GitHub Desktop config (if backed up)
if [ -d "$BACKUP_DIR/github-desktop" ]; then
    mkdir -p "$RESTORE_DIR/.config/GitHubDesktop"
    cp -r "$BACKUP_DIR/github-desktop/"* "$RESTORE_DIR/.config/GitHubDesktop/" 2>/dev/null || true
fi

# Finalize: enable autostart for ulauncher
if [ -f "$RESTORE_DIR/.config/autostart/ulauncher.desktop" ]; then
    sed -i 's/NoDisplay=true/NoDisplay=false/' "$RESTORE_DIR/.config/autostart/ulauncher.desktop" || true
    grep -q "X-GNOME-Autostart-enabled=true" "$RESTORE_DIR/.config/autostart/ulauncher.desktop" || echo "X-GNOME-Autostart-enabled=true" >> "$RESTORE_DIR/.config/autostart/ulauncher.desktop"
fi

echo "✅ Install + Restore finished."
echo "📂 Restored from: $BACKUP_DIR"
echo "Tip: Restart session (logout/login) for GNOME & autostart to take effect."

