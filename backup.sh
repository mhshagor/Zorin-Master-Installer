#!/bin/bash
# ==========================================
# Zorin Master - Complete Backup Script v1.3
# Supports Snap, Flatpak, Normal apps with DEFAULT fallback
# ==========================================

set -e

MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_DIR="$MASTER_DIR/DEFAULT"
BACKUP_DIR="$MASTER_DIR/Backup/$(date +%Y%m%d_%H%M%S)"
CONF_DIR="$HOME/.config"

mkdir -p "$BACKUP_DIR" "$CONF_DIR"
export PATH="$HOME/.local/bin:/snap/bin:$PATH"

echo "🔄 Backup started..."
echo "📂 Backup directory: $BACKUP_DIR"

read -p "Do you want to backup? [y/N]: " backup_choice
backup_choice=${backup_choice,,}  # convert to lowercase

if [[ "$backup_choice" == "y" || "$backup_choice" == "yes" ]]; then
    # -------------------------------
    # Detect config & extension paths
    # -------------------------------
    detect_paths() {
        local app="$1"
        local conf="" ext=""

        case "$app" in
            ulauncher)
                [ -d "$HOME/.local/share/ulauncher/extensions" ] && ext="$HOME/.local/share/ulauncher/extensions"
                [ -z "$ext" ] && [ -d "$HOME/.config/ulauncher/extensions" ] && ext="$HOME/.config/ulauncher/extensions"
                [ -d "$HOME/.config/ulauncher" ] && conf="$HOME/.config/ulauncher"
                ;;
            vscode)
                # Normal
                [ -f "$HOME/.config/Code/User/settings.json" ] && conf="$HOME/.config/Code/User"
                # Snap
                [ -z "$conf" ] && [ -f "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json" ] && conf="$HOME/.var/app/com.visualstudio.code/config/Code/User"
                # Flatpak (optional)
                [ -z "$conf" ] && [ -f "$HOME/.var/app/com.visualstudio.code/config/Code/User/settings.json" ] && conf="$HOME/.var/app/com.visualstudio.code/config/Code/User"
                [ -d "$HOME/.vscode/extensions" ] && ext="$HOME/.vscode/extensions"
                ;;
            windsurf)
                [ -d "$HOME/.windsurf/extensions" ] && ext="$HOME/.windsurf/extensions"
                [ -d "$CONF_DIR/Windsurf/User" ] && conf="$CONF_DIR/Windsurf/User"
                ;;
            extension-manager)
                [ -d "$HOME/.config/extension-manager" ] && conf="$HOME/.config/extension-manager"
                [ -d "$HOME/.local/share/gnome-shell/extensions" ] && ext="$HOME/.local/share/gnome-shell/extensions"
                ;;
        esac

        echo "$conf|$ext"
    }

    # -------------------------------
    # Backup function
    # -------------------------------
    backup_app() {
        local name="$1" conf="$2" ext="$3"
        [ -z "$name" ] && return

        local backup="$BACKUP_DIR/$name"
        mkdir -p "$backup"

        echo "🟢 $name backup started..."

        # Settings files
        local files=(settings.json keybindings.json shortcuts.json)
        for f in "${files[@]}"; do
            if [ -f "$conf/$f" ]; then
                cp "$conf/$f" "$backup/$f"
            elif [ -f "$DEFAULT_DIR/$name/$f" ]; then
                cp "$DEFAULT_DIR/$name/$f" "$backup/$f"
                echo "⚠️ $name $f missing, DEFAULT copied"
            fi
        done

        # Extensions
        if [ -d "$ext" ]; then
            tar -czf "$backup/extensions.tar.gz" -C "$ext" .
            ls "$ext" > "$backup/extensions_list.txt" || true
            echo "📦 $name extensions backed up"
        elif [ -d "$DEFAULT_DIR/$name/extensions" ]; then
            tar -czf "$backup/extensions.tar.gz" -C "$DEFAULT_DIR/$name/extensions" .
            ls "$DEFAULT_DIR/$name/extensions" > "$backup/extensions_list.txt" || true
            echo "⚠️ $name extensions missing, DEFAULT copied"
        else
            echo "# No extensions found" > "$backup/extensions_list.txt"
            echo "⚠️ $name extensions folder missing, empty list created"
        fi

        # Extensions list via command
        if command -v "$name" >/dev/null 2>&1; then
            "$name" --list-extensions > "$backup/extensions_list_cmd.txt" 2>/dev/null || true
        fi
    }

    # -------------------------------
    # Backup apps
    # -------------------------------
    for app in ulauncher vscode windsurf extension-manager; do
        paths=$(detect_paths "$app")
        conf="${paths%%|*}"
        ext="${paths##*|}"
        backup_app "$app" "$conf" "$ext"
    done

    # -------------------------------
    # XAMPP Backup (config only)
    # -------------------------------
    echo "🟢 XAMPP backup started..."
    XAMPP_DIR="/opt/lampp"
    XAMPP_BACKUP_DIR="$BACKUP_DIR/xampp"
    mkdir -p "$XAMPP_BACKUP_DIR"

    # Config directories to backup
    XAMPP_CONF_DIRS=("etc" "php/etc")

    for dir in "${XAMPP_CONF_DIRS[@]}"; do
        SRC="$XAMPP_DIR/$dir"
        if [ -d "$SRC" ]; then
            echo "📦 Backing up XAMPP $dir..."
            sudo tar -czf "$XAMPP_BACKUP_DIR/$dir.tar.gz" -C "$XAMPP_DIR" "$dir"
            if [ $? -eq 0 ]; then
                echo "✅ XAMPP $dir backed up successfully"
            else
                echo "⚠️ Failed to backup $dir"
            fi
        else
            echo "⚠️ XAMPP $dir folder not found"
        fi
    done

    # -------------------------------
    # GNOME Extensions Backup (user + system)
    # -------------------------------
    echo "🟢 GNOME Extensions backup started..."
    GNOME_BACKUP_DIR="$BACKUP_DIR/gnome-extensions"
    mkdir -p "$GNOME_BACKUP_DIR"

    USER_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
    SYS_EXT_DIR="/usr/share/gnome-shell/extensions"

    if [ -d "$USER_EXT_DIR" ]; then
        tar -czf "$GNOME_BACKUP_DIR/user-extensions.tar.gz" -C "$USER_EXT_DIR" .
        echo "📦 User GNOME extensions backed up."
    fi

    if [ -d "$SYS_EXT_DIR" ]; then
        sudo tar -czf "$GNOME_BACKUP_DIR/system-extensions.tar.gz" -C "$SYS_EXT_DIR" .
        echo "📦 System GNOME extensions backed up."
    fi

    if command -v gnome-extensions >/dev/null 2>&1; then
        gnome-extensions list > "$GNOME_BACKUP_DIR/extensions_list.txt"
        echo "📃 GNOME extensions list created."
    fi

    # ------------------------------------------
    # Backup command folder
    # ------------------------------------------
    if [ -d "$DEFAULT_DIR/command" ]; then
        echo "📦 Backing up $DEFAULT_DIR/command folder..."
        mkdir -p "$BACKUP_DIR/command"
        cp -r "$DEFAULT_DIR/command/"* "$BACKUP_DIR/command/"
        echo "✅ Command folder backup completed at $BACKUP_DIR/command"
    fi

    # -------------------------------
    # Done
    # -------------------------------
    echo "✅ Backup complete!"
    echo "📂 All backups saved to: $BACKUP_DIR"

else
    echo "ℹ️ Backup skipped by user."
fi