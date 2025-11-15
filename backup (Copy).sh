#!/bin/bash
# ==========================================
# Zorin Master - Complete Backup Script v1.2
# Supports Snap, Flatpak, Normal apps with DEFAULT fallback
# ==========================================

set -e

MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DIR="$MASTER_DIR/DEFAULT"
BACKUP_DIR="$MASTER_DIR/Backup/$(date +%Y%m%d_%H%M%S)"
CONF_DIR="$HOME/.config"

mkdir -p "$BACKUP_DIR" "$CONF_DIR"
export PATH="$HOME/.local/bin:/snap/bin:$PATH"

echo "🔄 Backup process started..."
echo "📂 Backup directory: $BACKUP_DIR"

# -------------------------------
# Function to backup app
# -------------------------------
backup_app() {
    local name="$1"
    local conf_dir="$2"
    local ext_dir="$3"
    local backup_dir="$BACKUP_DIR/$name"
    mkdir -p "$backup_dir"

    # Backup settings files
    for file in settings.json keybindings.json shortcuts.json; do
        if [ -f "$conf_dir/$file" ]; then
            cp "$conf_dir/$file" "$backup_dir/$file"
        elif [ -f "$DEFAULT_DIR/$name/$file" ]; then
            cp "$DEFAULT_DIR/$name/$file" "$backup_dir/$file"
            echo "⚠️ $name $file missing, DEFAULT $file copied"
        fi
    done

    # Backup extensions directory as .tar.gz
    if [ -d "$ext_dir" ]; then
        tar -czf "$backup_dir/extensions.tar.gz" -C "$ext_dir" .
        echo "📦 $name extensions backed up as .tar.gz"
    elif [ -d "$DEFAULT_DIR/$name/extensions" ]; then
        tar -czf "$backup_dir/extensions.tar.gz" -C "$DEFAULT_DIR/$name/extensions" .
        echo "⚠️ $name extensions missing, DEFAULT extensions copied"
    fi

    # Backup extensions list
    if command -v "$name" >/dev/null 2>&1; then
        "$name" --list-extensions > "$backup_dir/extensions_list.txt" 2>/dev/null || true
    fi
    if [ ! -f "$backup_dir/extensions_list.txt" ] && [ -f "$DEFAULT_DIR/$name/extensions_list.txt" ]; then
        cp "$DEFAULT_DIR/$name/extensions_list.txt" "$backup_dir/extensions_list.txt"
        echo "⚠️ $name extensions list missing, DEFAULT extensions list copied"
    fi
}

# -------------------------------
# 1. Ulauncher Backup
# -------------------------------
echo "🟢 Ulauncher Backup Start ..."
ULAUNCHER_EXT_DIR="${HOME}/.local/share/ulauncher/extensions"
[ ! -d "$ULAUNCHER_EXT_DIR" ] && ULAUNCHER_EXT_DIR="${HOME}/.config/ulauncher/extensions"
backup_app "ulauncher" "$CONF_DIR/ulauncher" "$ULAUNCHER_EXT_DIR"

# -------------------------------
# 2. VSCode Backup
# -------------------------------
echo "🧩 VSCode Backup Start..."
VSCODE_CONF_DIR=""
if [ -f "$HOME/.config/Code/User/settings.json" ]; then
    VSCODE_CONF_DIR="$HOME/.config/Code/User"
elif [ -f "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json" ]; then
    VSCODE_CONF_DIR="$HOME/.var/app/com.visualstudio.code/config/Code/User"
fi
VSCODE_EXT_DIR="${HOME}/.vscode/extensions"
backup_app "vscode" "$VSCODE_CONF_DIR" "$VSCODE_EXT_DIR"

# -------------------------------
# 3. Windsurf Backup
# -------------------------------
echo "🟢 Windsurf Backup Start..."
WINDSURF_CONF_DIR="$CONF_DIR/Windsurf/User"
WINDSURF_EXT_DIR="$HOME/.windsurf/extensions"
backup_app "windsurf" "$WINDSURF_CONF_DIR" "$WINDSURF_EXT_DIR"

# -------------------------------
# 4. Final message
# -------------------------------
echo "✅ Backup complete!"
echo "📂 All backups saved to: $BACKUP_DIR"
