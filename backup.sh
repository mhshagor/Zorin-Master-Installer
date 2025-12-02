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

ask_yes_no() {
    local question="$1"
    read -p "$question [y/N]: " choice
    choice=${choice,,}  # lowercase
    [[ "$choice" == "y" || "$choice" == "yes" ]]
}


if ask_yes_no "Do you want to backup?"; then
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
            antigravity)
                [ -d "$HOME/.antigravity/extensions" ] && ext="$HOME/.antigravity/extensions"
                [ -d "$CONF_DIR/Antigravity/User" ] && conf="$CONF_DIR/Antigravity/User"
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
    for app in ulauncher vscode windsurf extension-manager antigravity; do
            paths=$(detect_paths "$app")
            conf="${paths%%|*}"
            ext="${paths##*|}"
            backup_app "$app" "$conf" "$ext"
    done

    # -------------------------------
    # XAMPP Backup (config only)
    # -------------------------------
    if ask_yes_no "Do you want to backup XAMPP?"; then
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
                if sudo tar -czf "$XAMPP_BACKUP_DIR/$dir.tar.gz" -C "$XAMPP_DIR" "$dir"; then
                    echo "✅ XAMPP $dir backed up successfully"
                else
                    echo "⚠️ Failed to backup $dir"
                fi
            else
                echo "⚠️ XAMPP $dir folder not found"
            fi
        done

    fi
    # -------------------------------
    # GNOME Extensions Backup (user + system)
    # -------------------------------

    if ask_yes_no "Do you want to backup GNOME Extensions?"; then
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
    fi
    
    # -------------------------------
    # Chrome Backup (Extensions + User Data)
    # -------------------------------
    if ask_yes_no "Do you want to backup Chrome (extensions + user data)?"; then
        echo "🟢 Chrome backup started..."
        CHROME_BACKUP_DIR="$BACKUP_DIR/chrome"
        mkdir -p "$CHROME_BACKUP_DIR"
        
        # Detect Chrome installation paths
        CHROME_PATHS=(
            "$HOME/.config/google-chrome"                           # Normal installation
            "$HOME/snap/chromium/common/chromium"                   # Snap Chromium
            "$HOME/.var/app/com.google.Chrome/config/google-chrome" # Flatpak Chrome
        )
        
        CHROME_DIR=""
        for path in "${CHROME_PATHS[@]}"; do
            if [ -d "$path" ]; then
                CHROME_DIR="$path"
                echo "📍 Found Chrome at: $CHROME_DIR"
                break
            fi
        done
        
        if [ -z "$CHROME_DIR" ]; then
            echo "⚠️ Chrome directory not found!"
        else
            # Backup all profiles (Default, Profile 1, Profile 2, etc.)
            for profile in "$CHROME_DIR"/*/; do
                if [ -d "$profile" ]; then
                    profile_name=$(basename "$profile")
                    
                    # Skip non-profile directories
                    if [[ ! "$profile_name" =~ ^(Default|Profile\ [0-9]+)$ ]]; then
                        continue
                    fi
                    
                    echo "📦 Backing up profile: $profile_name"
                    PROFILE_BACKUP="$CHROME_BACKUP_DIR/$profile_name"
                    mkdir -p "$PROFILE_BACKUP"
                    
                    # Backup Extensions
                    if [ -d "$profile/Extensions" ]; then
                        tar -czf "$PROFILE_BACKUP/Extensions.tar.gz" -C "$profile" Extensions
                        echo "  ✅ Extensions backed up"
                    fi
                    
                    # Backup important user data files
                    FILES_TO_BACKUP=(
                        "Bookmarks"
                        "Bookmarks.bak"
                        "History"
                        "Favicons"
                        "Preferences"
                        "Secure Preferences"
                        "Login Data"
                        "Web Data"
                        "Cookies"
                        "Sessions"
                        "Current Session"
                        "Current Tabs"
                        "Last Session"
                        "Last Tabs"
                    )
                    
                    for file in "${FILES_TO_BACKUP[@]}"; do
                        if [ -f "$profile/$file" ]; then
                            cp "$profile/$file" "$PROFILE_BACKUP/"
                        fi
                    done
                    echo "  ✅ User data files backed up"
                    
                    # Create extension list
                    if [ -d "$profile/Extensions" ]; then
                        find "$profile/Extensions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; > "$PROFILE_BACKUP/extensions_list.txt"
                        echo "  ✅ Extension list created"
                    fi
                fi
            done
            
            # Backup Local State (contains profile info)
            if [ -f "$CHROME_DIR/Local State" ]; then
                cp "$CHROME_DIR/Local State" "$CHROME_BACKUP_DIR/"
                echo "📦 Local State backed up"
            fi
            
            echo "✅ Chrome backup completed!"
        fi
    fi
    
    # -------------------------------
    # Brave Backup (Extensions + User Data)
    # -------------------------------
    if ask_yes_no "Do you want to backup Brave (extensions + user data)?"; then
        echo "🟢 Brave backup started..."
        BRAVE_BACKUP_DIR="$BACKUP_DIR/brave"
        mkdir -p "$BRAVE_BACKUP_DIR"
        
        # Detect Brave installation paths
        BRAVE_PATHS=(
            "$HOME/.config/BraveSoftware/Brave-Browser"              # Normal installation
            "$HOME/snap/brave/current/.config/BraveSoftware/Brave-Browser" # Snap Brave
            "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser" # Flatpak Brave
        )
        
        BRAVE_DIR=""
        for path in "${BRAVE_PATHS[@]}"; do
            if [ -d "$path" ]; then
                BRAVE_DIR="$path"
                echo "📍 Found Brave at: $BRAVE_DIR"
                break
            fi
        done
        
        if [ -z "$BRAVE_DIR" ]; then
            echo "⚠️ Brave directory not found!"
        else
            # Backup all profiles (Default, Profile 1, Profile 2, etc.)
            for profile in "$BRAVE_DIR"/*/; do
                if [ -d "$profile" ]; then
                    profile_name=$(basename "$profile")
                    
                    # Skip non-profile directories
                    if [[ ! "$profile_name" =~ ^(Default|Profile\ [0-9]+)$ ]]; then
                        continue
                    fi
                    
                    echo "📦 Backing up profile: $profile_name"
                    PROFILE_BACKUP="$BRAVE_BACKUP_DIR/$profile_name"
                    mkdir -p "$PROFILE_BACKUP"
                    
                    # Backup Extensions
                    if [ -d "$profile/Extensions" ]; then
                        tar -czf "$PROFILE_BACKUP/Extensions.tar.gz" -C "$profile" Extensions
                        echo "  ✅ Extensions backed up"
                    fi
                    
                    # Backup important user data files
                    FILES_TO_BACKUP=(
                        "Bookmarks"
                        "Bookmarks.bak"
                        "History"
                        "Favicons"
                        "Preferences"
                        "Secure Preferences"
                        "Login Data"
                        "Web Data"
                        "Cookies"
                        "Sessions"
                        "Current Session"
                        "Current Tabs"
                        "Last Session"
                        "Last Tabs"
                        "Brave Rewards"
                    )
                    
                    for file in "${FILES_TO_BACKUP[@]}"; do
                        if [ -f "$profile/$file" ]; then
                            cp "$profile/$file" "$PROFILE_BACKUP/"
                        fi
                    done
                    echo "  ✅ User data files backed up"
                    
                    # Create extension list
                    if [ -d "$profile/Extensions" ]; then
                        find "$profile/Extensions" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; > "$PROFILE_BACKUP/extensions_list.txt"
                        echo "  ✅ Extension list created"
                    fi
                fi
            done
            
            # Backup Local State (contains profile info)
            if [ -f "$BRAVE_DIR/Local State" ]; then
                cp "$BRAVE_DIR/Local State" "$BRAVE_BACKUP_DIR/"
                echo "📦 Local State backed up"
            fi
            
            echo "✅ Brave backup completed!"
        fi
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