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
    echo "Debug: Function called"
    #local question="$1"
    #read -p "$question [y/N]: " choice
    #choice=${choice,,}  # lowercase
    #[[ "$choice" == "y" || "$choice" == "yes" ]]
}

# Check if pv (Pipe Viewer) is installed for progress bars
if ! command -v pv > /dev/null 2>&1; then
    echo "📦 Installing 'pv' for progress bars..."
    sudo apt install -y pv > /dev/null 2>&1
fi


if ask_yes_no "Do you want to backup?"; then
    # -------------------------------
    # Detect config & extension paths
    # -------------------------------

    echo "🔍 Detecting application configurations and extensions..."
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
    for app in ulauncher vscode windsurf extension-manager gnome-extensions antigravity; do
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
    # XAMPP htdocs Backup (Smart - excludes heavy folders)
    # -------------------------------
    if ask_yes_no "Do you want to backup XAMPP htdocs (projects)?"; then
        echo "🟢 XAMPP htdocs backup started..."
        HTDOCS_DIR="/opt/lampp/htdocs"
        HTDOCS_BACKUP_DIR="$BACKUP_DIR/htdocs"
        
        if [ -d "$HTDOCS_DIR" ]; then
            mkdir -p "$HTDOCS_BACKUP_DIR"
            
            echo "📦 Backing up htdocs (excluding node_modules, vendor, .git)..."
            
            # Calculate size for progress decision
            HTDOCS_SIZE=$(sudo du -sb /opt/lampp/htdocs 2>/dev/null | cut -f1)
            HTDOCS_SIZE_MB=$((HTDOCS_SIZE / 1024 / 1024))
            
            # Use progress bar only for large backups (>100MB, likely >5 seconds)
            if [ "$HTDOCS_SIZE_MB" -gt 100 ] && command -v pv > /dev/null 2>&1; then
                echo "⏳ Large backup detected (${HTDOCS_SIZE_MB}MB), showing progress..."
                sudo tar -c \
                    -C /opt/lampp \
                    --exclude='htdocs/*/node_modules' \
                    --exclude='htdocs/*/vendor' \
                    --exclude='htdocs/*/.git' \
                    --exclude='htdocs/*/storage/logs/*' \
                    --exclude='htdocs/*/storage/framework/cache/*' \
                    --exclude='htdocs/*/storage/framework/sessions/*' \
                    --exclude='htdocs/*/storage/framework/views/*' \
                    htdocs | pv -s "$HTDOCS_SIZE" -p -t -e -r -b | gzip > "$HTDOCS_BACKUP_DIR/htdocs.tar.gz"
            else
                # Quick backup without progress bar
                sudo tar -czf "$HTDOCS_BACKUP_DIR/htdocs.tar.gz" \
                    -C /opt/lampp \
                    --exclude='htdocs/*/node_modules' \
                    --exclude='htdocs/*/vendor' \
                    --exclude='htdocs/*/.git' \
                    --exclude='htdocs/*/storage/logs/*' \
                    --exclude='htdocs/*/storage/framework/cache/*' \
                    --exclude='htdocs/*/storage/framework/sessions/*' \
                    --exclude='htdocs/*/storage/framework/views/*' \
                    htdocs
            fi
            
            if [ $? -eq 0 ]; then
                echo "✅ htdocs backed up successfully"
                
                # Create a list of projects
                ls -1 "$HTDOCS_DIR" > "$HTDOCS_BACKUP_DIR/projects_list.txt"
                echo "📃 Projects list created"
                
                # Create exclusion info file
                cat > "$HTDOCS_BACKUP_DIR/README.txt" << 'EOF'
XAMPP htdocs Backup Information
================================

This backup EXCLUDES the following to save space:
- node_modules/ (npm dependencies - reinstall with: npm install)
- vendor/ (composer dependencies - reinstall with: composer install)
- .git/ (git repository - clone from remote if needed)
- storage/logs/* (Laravel logs)
- storage/framework/cache/* (Laravel cache)
- storage/framework/sessions/* (Laravel sessions)
- storage/framework/views/* (Laravel compiled views)

To restore:
1. Extract: sudo tar -xzf htdocs.tar.gz -C /opt/lampp/
2. Set permissions: sudo chown -R $USER:$USER /opt/lampp/htdocs
3. For each Laravel project:
   - Run: composer install
   - Run: npm install
   - Run: php artisan key:generate
   - Run: php artisan migrate

All your source code, .env files, and databases are included!
EOF
                echo "📄 README created with restore instructions"
                
                # Calculate backup size
                BACKUP_SIZE=$(du -sh "$HTDOCS_BACKUP_DIR/htdocs.tar.gz" | cut -f1)
                echo "💾 Backup size: $BACKUP_SIZE"
            else
                echo "⚠️ Failed to backup htdocs"
            fi
        else
            echo "⚠️ htdocs directory not found at $HTDOCS_DIR"
        fi
    fi
    
    # -------------------------------
    # MySQL Database Backup (All Databases)
    # -------------------------------
#    if ask_yes_no "Do you want to backup MySQL databases?"; then
#        echo "🟢 MySQL database backup started..."
#        MYSQL_BACKUP_DIR="$BACKUP_DIR/mysql"
#        mkdir -p "$MYSQL_BACKUP_DIR"
#        
#        # Check if MySQL is running
#        if ! sudo /opt/lampp/lampp status | grep -q "MySQL.*running"; then
#            echo "⚠️ MySQL is not running. Starting MySQL..."
#            sudo /opt/lampp/lampp startmysql
#            sleep 3
#        fi
#        
#        # Get MySQL root password
#        echo ""
#        echo "📝 Enter MySQL root password (press Enter if no password):"
#        read -s MYSQL_PASSWORD
#        
#        if [ -z "$MYSQL_PASSWORD" ]; then
#            MYSQL_CMD="/opt/lampp/bin/mysql -u root"
#            MYSQLDUMP_CMD="/opt/lampp/bin/mysqldump -u root"
#        else
#            MYSQL_CMD="/opt/lampp/bin/mysql -u root -p$MYSQL_PASSWORD"
#            MYSQLDUMP_CMD="/opt/lampp/bin/mysqldump -u root -p$MYSQL_PASSWORD"
#        fi
#        
#        # Test MySQL connection
#        if ! $MYSQL_CMD -e "SELECT 1;" > /dev/null 2>&1; then
#            echo "❌ Failed to connect to MySQL. Please check your password."
#        else
#            echo "✅ MySQL connection successful"
#            
#            # Get list of databases (excluding system databases)
#            DATABASES=$($MYSQL_CMD -e "SHOW DATABASES;" | grep -Ev #"^(Database|information_schema|performance_schema|mysql|sys|phpmyadm#in)$")
#            
#            if [ -z "$DATABASES" ]; then
#                echo "⚠️ No user databases found"
#            else
#                echo "📦 Found databases to backup:"
#                echo "$DATABASES" | sed 's/^/   - /'
#                
#                # Save database list
#                echo "$DATABASES" > "$MYSQL_BACKUP_DIR/databases_list.txt"
#                
#                # Backup each database individually
#                for DB in $DATABASES; do
#                    echo "📦 Backing up database: $DB"
#                    $MYSQLDUMP_CMD --databases "$DB" --add-drop-database --routines -#-triggers --events \
#                        > "$MYSQL_BACKUP_DIR/${DB}.sql" 2>/dev/null
#                    
#                    if [ $? -eq 0 ]; then
#                        # Compress the SQL file
#                        gzip "$MYSQL_BACKUP_DIR/${DB}.sql"
#                        echo "  ✅ $DB backed up and compressed"
#                    else
#                        echo "  ⚠️ Failed to backup $DB"
#                    fi
#                done
#                
#                # Create a combined backup of all databases
#                echo "📦 Creating combined backup of all databases..."
#                
#                $MYSQLDUMP_CMD --all-databases --add-drop-database --routines --#triggers --events \
#                    > "$MYSQL_BACKUP_DIR/all_databases.sql" 2>/dev/null
#                
#                if [ $? -eq 0 ]; then
#                    # Check SQL file size for progress decision
#                    SQL_SIZE=$(stat -c%s "$MYSQL_BACKUP_DIR/all_databases.sql")
#                    SQL_SIZE_MB=$((SQL_SIZE / 1024 / 1024))
#                    
#                    # Use progress bar only for large SQL files (>10MB, likely >5 #seconds)
#                    if [ "$SQL_SIZE_MB" -gt 10 ] && command -v pv > /dev/null 2>&1; #then
#                        echo "⏳ Large database (${SQL_SIZE_MB}MB), compressing with #progress..."
#                        pv -s "$SQL_SIZE" -p -t -e -r -b #"$MYSQL_BACKUP_DIR/all_databases.sql" | gzip > #"$MYSQL_BACKUP_DIR/all_databases.sql.gz"
#                        rm "$MYSQL_BACKUP_DIR/all_databases.sql"
#                    else
#                        # Quick compression without progress bar
#                        gzip "$MYSQL_BACKUP_DIR/all_databases.sql"
#                    fi
#                    echo "✅ Combined backup created and compressed"
#                fi
#                
#                # Create restore instructions
#                cat > "$MYSQL_BACKUP_DIR/README.txt" << 'EOF'
#MySQL Database Backup Information
#==================================
#
#This backup includes:
#- Individual database dumps (database_name.sql.gz)
#- Combined backup of all databases (all_databases.sql.gz)
#- List of all databases (databases_list.txt)
#
#To restore:
#
#Option 1: Restore all databases at once
#----------------------------------------
#1. Start MySQL: sudo /opt/lampp/lampp startmysql
#2. Decompress: gunzip all_databases.sql.gz
#3. Import: /opt/lampp/bin/mysql -u root -p < all_databases.sql
#
#Option 2: Restore individual database
#--------------------------------------
#1. Start MySQL: sudo /opt/lampp/lampp startmysql
#2. Decompress: gunzip database_name.sql.gz
#3. Import: /opt/lampp/bin/mysql -u root -p < database_name.sql
#
#Option 3: Restore specific database with new name
#--------------------------------------------------
#1. Decompress: gunzip database_name.sql.gz
#2. Create DB: /opt/lampp/bin/mysql -u root -p -e "CREATE DATABASE new_name;"
#3. Import: /opt/lampp/bin/mysql -u root -p new_name < database_name.sql
#
#Important Notes:
#- All databases include structure, data, triggers, routines, and events
#- Backups are compressed with gzip to save space
#- Always test restore on a development environment first
#EOF
#                
#                echo "📄 README created with restore instructions"
#                
#                # Calculate total backup size
#                TOTAL_SIZE=$(du -sh "$MYSQL_BACKUP_DIR" | cut -f1)
#                echo "💾 Total MySQL backup size: $TOTAL_SIZE"
#                echo "✅ MySQL backup completed successfully!"
#            fi
#        fi
#    fi
#    
#    # -------------------------------
#    # GNOME Extensions Backup (user + system)
#    # -------------------------------
#
#    if ask_yes_no "Do you want to backup GNOME Extensions?"; then
#        echo "🟢 GNOME Extensions backup started..."
#        GNOME_BACKUP_DIR="$BACKUP_DIR/gnome-extensions"
#        mkdir -p "$GNOME_BACKUP_DIR"
#
#        USER_EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
#        SYS_EXT_DIR="/usr/share/gnome-shell/extensions"
#
#        if [ -d "$USER_EXT_DIR" ]; then
#            tar -czf "$GNOME_BACKUP_DIR/user-extensions.tar.gz" -C "$USER_EXT_DIR" .
#            echo "📦 User GNOME extensions backed up."
#        fi
#
#        if [ -d "$SYS_EXT_DIR" ]; then
#            sudo tar -czf "$GNOME_BACKUP_DIR/system-extensions.tar.gz" -C #"$SYS_EXT_DIR" .
#            echo "📦 System GNOME extensions backed up."
#        fi
#
#        if command -v gnome-extensions >/dev/null 2>&1; then
#            gnome-extensions list > "$GNOME_BACKUP_DIR/extensions_list.txt"
#            echo "📃 GNOME extensions list created."
#        fi
#    fi
    
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
