#!/bin/bash
# ==========================================
# Zorin Master Installer v5.3 (Clean + Updated)
# Skips already installed apps, handles new Backup structure
# ==========================================
set -e
MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$MASTER_DIR/Backup"
CONF_DIR="$HOME/.config"
LOG_FILE="$MASTER_DIR/zorin-master-install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo -e "\nZorin Master Installer v5.3 Starting..."
echo -e "Log saved at: $LOG_FILE\n"
sleep 2

RESTORE_ROOT="$BACKUP_DIR"

if [ -d "$RESTORE_ROOT" ]; then
    LAST_BACKUP=$(find "$RESTORE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | head -1)

    if [ -z "$LAST_BACKUP" ]; then
        echo "⚠️ No backup folder found. Skipping restore..."
    else
        echo "📂 Using backup folder: $LAST_BACKUP"
    fi
else
    echo "⚠️ Backup directory missing!"
fi

ask_yes_no() {
    local question="$1"
    read -p "$question [y/N]: " choice
    choice=${choice,,}  # lowercase
    [[ "$choice" == "y" || "$choice" == "yes" ]]
}

if ask_yes_no "Do you want to restore from backup?"; then

# ------------------------------------------
# 1. System Update
# ------------------------------------------
echo "Updating system packages..."
#sudo apt update -y
#sudo apt upgrade -y

# ------------------------------------------
# 2. Install Basic Tools
# ------------------------------------------
echo "Installing essential tools..."
#sudo apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsof flatpak

# ------------------------------------------
# 3. XAMPP
# ------------------------------------------
if ask_yes_no "Install XAMPP?"; then
    if [ ! -d "/opt/lampp" ]; then

        echo "Installing XAMPP..."

        # Preferred installer: from Backup
        LOCAL_INSTALLER="$LAST_BACKUP/xampp/xampp-linux-x64-8.2.12-0-installer.run"

        if [ -f "$LOCAL_INSTALLER" ]; then
            echo "📦 Installing XAMPP from backup..."
            cd "$LAST_BACKUP/xampp"
            sudo chmod +x xampp-linux-x64-8.2.12-0-installer.run
            sudo ./xampp-linux-x64-8.2.12-0-installer.run
        else
            echo "🌐 Backup installer not found. Downloading XAMPP from web..."
            XAMPP_URL="https://www.apachefriends.org/xampp-files/8.2.12/xampp-linux-x64-8.2.12-0-installer.run"
            wget --no-check-certificate --content-disposition "$XAMPP_URL" -O /tmp/xampp-installer.run
        fi

        sudo ln -sf /opt/lampp/lampp /usr/local/bin/xampp

        cd ../../../
    else
        echo "XAMPP already installed. Skipping..."
    fi
fi

# ------------------------------------------
# 4. Node.js
# ------------------------------------------
if ask_yes_no "Install Node.js?"; then
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g npm@latest
else
    echo "Node.js already installed. Skipping..."
fi
fi

# ------------------------------------------
# 5. Composer
# ------------------------------------------
if ask_yes_no "Install Composer?"; then
    if [ -d "/opt/lampp" ]; then
        echo "Using XAMPP PHP system-wide..."
        export PATH=/opt/lampp/bin:$PATH
        php -v
        which php
    else
        echo "XAMPP not found. Skipping Composer installation..."
        exit 1
    fi

    if ! command -v composer >/dev/null 2>&1; then
        echo "Installing Composer..."
        php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
        EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"
        ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
        if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
            echo "Composer installer corrupted! Aborting."
            rm composer-setup.php
            exit 1
        fi
        # Use full path to XAMPP PHP with sudo
        sudo /opt/lampp/bin/php composer-setup.php --install-dir=/usr/local/bin --filename=composer
        rm composer-setup.php
        echo "✅ Composer installed successfully!"
    else
        echo "Composer already installed. Skipping..."
    fi
fi




# ------------------------------------------
# 6. Google Chrome
# ------------------------------------------
if ask_yes_no "Install Google Chrome?"; then
if ! command -v google-chrome >/dev/null 2>&1; then
    echo "Installing Google Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo dpkg -i /tmp/chrome.deb || sudo apt -f install -y
else
    echo "Chrome already installed. Skipping..."
fi
fi

# ------------------------------------------
# 7. GitHub Desktop
# ------------------------------------------
if ask_yes_no "Install GitHub Desktop?"; then
if ! command -v github-desktop >/dev/null 2>&1; then
    echo "Installing GitHub Desktop..."
    GITHUB_DESKTOP_URL=$(curl -s https://api.github.com/repos/shiftkey/desktop/releases/latest | grep -o "https.*GitHubDesktop-linux.*deb" | head -1)
    wget -q "$GITHUB_DESKTOP_URL" -O /tmp/github-desktop.deb
    sudo dpkg -i /tmp/github-desktop.deb || sudo apt -f install -y
else
    echo "GitHub Desktop already installed. Skipping..."
fi
fi

# ------------------------------------------
# 8. VS Code
# ------------------------------------------
if ask_yes_no "Install VS Code?"; then
    LOCAL_VSCODE="$LAST_BACKUP/vscode/code_1.106.3-1764110892_amd64.deb"

    if [ -f "$LOCAL_VSCODE" ]; then
        echo "Installing VS Code from backup..."
        sudo dpkg -i "$LOCAL_VSCODE" || sudo apt -f install -y
    else
        echo "VS Code backup not found. Downloading version 1.106.3..."
        wget -O /tmp/code_1.106.3-1764110892_amd64.deb https://update.code.visualstudio.com/1.106.3/linux-deb-x64/stable
        sudo dpkg -i /tmp/code_1.106.3-1764110892_amd64.deb || sudo apt -f install -y
        rm -f /tmp/code_1.106.3-1764110892_amd64.deb
    fi
fi

# ------------------------------------------
# 9. Windsurf
# ------------------------------------------
if ask_yes_no "Install Windsurf?"; then
if ! command -v windsurf >/dev/null 2>&1; then
    echo "Installing Windsurf..."
    WINDSURF_KEY_URL="https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg"
    if wget -qO- "$WINDSURF_KEY_URL" | gpg --dearmor > /tmp/windsurf-stable.gpg; then
        sudo install -D -o root -g root -m 644 /tmp/windsurf-stable.gpg /etc/apt/keyrings/windsurf-stable.gpg
        rm -f /tmp/windsurf-stable.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/windsurf-stable.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | \
            sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null
        sudo apt update
        sudo apt install -y windsurf || echo "Windsurf install failed."
    else
        echo "Windsurf key download failed. Skipping."
    fi
else
    echo "Windsurf already installed. Skipping..."
fi
fi

# ------------------------------------------
# 9. Antigravity
# ------------------------------------------
if ask_yes_no "Install Antigravity?"; then
    if ! command -v antigravity >/dev/null 2>&1; then
        echo "Installing Antigravity..."
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
            sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg
        echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
            sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
        sudo apt update -qq
        sudo apt install -y antigravity || echo "⚠️ Antigravity install failed."
    else
        echo "Antigravity already installed. Skipping..."
    fi
fi

# ------------------------------------------
# 10. uLauncher (installation only)
# ------------------------------------------
if ask_yes_no "Install uLauncher?"; then
if ! command -v ulauncher >/dev/null 2>&1; then
    echo "Installing uLauncher..."
    sudo add-apt-repository ppa:agornostal/ulauncher -y
    sudo apt update -y
    sudo apt install -y ulauncher

    # Enable auto-start
    mkdir -p ~/.config/autostart
    cp /usr/share/applications/ulauncher.desktop ~/.config/autostart/
    sed -i 's/NoDisplay=true/NoDisplay=false/' ~/.config/autostart/ulauncher.desktop
    echo "X-GNOME-Autostart-enabled=true" >> ~/.config/autostart/ulauncher.desktop

    echo "✅ uLauncher installed!"
else
    echo "uLauncher already installed. Skipping..."
fi
fi

# ------------------------------------------
# 10. GNOME Extension Manager (installation only)
# ------------------------------------------
if ask_yes_no "Install GNOME Extension Manager?"; then
    # Check if flatpak is installed
    if ! command -v flatpak >/dev/null 2>&1; then
        echo "Flatpak not installed. Installing flatpak..."
        sudo apt install -y flatpak
    fi

    # Install Extension Manager
    echo "Installing GNOME Extension Manager..."
    flatpak install -y flathub com.mattjakeman.ExtensionManager

    echo "✅ GNOME Extension Manager installed!"
else
    echo "Skipping GNOME Extension Manager..."
fi

# ------------------------------------------
# 15. Custom Bash Aliases
# ------------------------------------------
if ask_yes_no "Install Custom Bash Aliases?"; then
    BASHRC="$HOME/.bashrc"
    if ! grep -q "Zorin Master Installer" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" << 'EOF'
# === Custom Aliases by Zorin Master Installer v5.3 ===
alias xstart='sudo /opt/lampp/lampp start'
alias xstop='sudo /opt/lampp/lampp stop'
alias xrestart='sudo /opt/lampp/lampp restart'
alias serve='php artisan serve'
alias dbm='php artisan migrate'
alias dbfs='php artisan migrate:fresh --seed'
alias gitpush='git add . && git commit -m "update" && git push'
alias pa='php artisan'
alias npmrun='npm run dev'
# ================================================
EOF
    fi
fi

# ==========================================
#  RESTORE SECTION - Restore from Backup Folder
# ==========================================
RESTORE_ROOT="$BACKUP_DIR"
if [ -d "$RESTORE_ROOT" ]; then
    LAST_BACKUP=$(find "$RESTORE_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | head -1)

    if [ -z "$LAST_BACKUP" ]; then
        echo "⚠️ No backup folder found. Skipping restore..."
    else
        echo "📂 Using backup folder: $LAST_BACKUP"
    fi
else
    echo "⚠️ Backup directory missing!"
fi

# --------------------------
# Restore Helper Function
# --------------------------
restore_app() {
    local name="$1"
    local config="$2"
    local extensions="$3"
    local src="$LAST_BACKUP/$name"

    if ask_yes_no "Restore $name?"; then
        echo "🔄 Restoring $name ..."

        chmod +x "$src"

        if [ -d "$src" ]; then
            mkdir -p "$config"
            cp -r "$src/"* "$config/"
            ignore="extensions.tar.gz" "extensions_list.txt"
            echo "   ➤ Config files restored"
        fi

        if [ -f "$src/extensions.tar.gz" ]; then
            mkdir -p "$extensions/extensions"
            tar -xzf "$src/extensions.tar.gz" -C "$extensions/extensions"
            echo "   ➤ Extensions restored"
        fi

        # Ensure correct ownership for user
        sudo chown -R "$USER:$USER" "$config"
        sudo chown -R "$USER:$USER" "$extensions"
        echo "   ➤ Ownership set to $USER"
    fi
}

# --------------------------
# Restore uLauncher
# --------------------------
if command -v ulauncher >/dev/null 2>&1; then
    #restore_app "ulauncher" "$HOME/.local/share/ulauncher" "$HOME/.local/share/ulauncher"
    if ask_yes_no "Restore uLauncher?"; then
        echo "🔄 Restoring uLauncher ..."
        src="$LAST_BACKUP/ulauncher"
        chmod +x "$src"

        if [ -d "$src" ]; then
            mkdir -p "$HOME/.local/share/ulauncher"
            cp -r "$src/settings.json" "$HOME/.local/share/ulauncher/"
            cp -r "$src/shortcuts.json" "$HOME/.local/share/ulauncher/"
            echo "   ➤ Config files restored"
        fi

        if [ -f "$src/extensions.tar.gz" ]; then
            mkdir -p "$HOME/.local/share/ulauncher/extensions"
            tar -xzf "$src/extensions.tar.gz" -C "$HOME/.local/share/ulauncher/extensions"
            echo "   ➤ Extensions restored"
        fi

        # Ensure correct ownership for user
        sudo chown -R "$USER:$USER" "$HOME/.local/share/ulauncher"
        echo "   ➤ Ownership set to $USER"
    fi
fi

# --------------------------
# Restore VSCode
# --------------------------
if command -v code >/dev/null 2>&1; then
    #restore_app "vscode" "$HOME/.config/Code/User" "$HOME/.vscode" 
    if ask_yes_no "Restore VSCode?"; then
        echo "🔄 Restoring VSCode ..."
        src="$LAST_BACKUP/vscode"
        chmod +x "$src"

        if [ -d "$src" ]; then
            mkdir -p "$HOME/.config/Code/User"
            cp -r "$src/settings.json" "$HOME/.config/Code/User/"
            cp -r "$src/keybindings.json" "$HOME/.config/Code/User/"
            echo "   ➤ Config files restored"
        fi

        if [ -f "$src/extensions.tar.gz" ]; then
            mkdir -p "$HOME/.vscode/extensions"
            tar -xzf "$src/extensions.tar.gz" -C "$HOME/.vscode/extensions"
            echo "   ➤ Extensions restored"
        fi

        # Ensure correct ownership for user
        sudo chown -R "$USER:$USER" "$HOME/.config/Code/User"
        sudo chown -R "$USER:$USER" "$HOME/.vscode"
        echo "   ➤ Ownership set to $USER"
    fi
fi

# --------------------------
# Restore Windsurf
# --------------------------
if command -v windsurf >/dev/null 2>&1; then
    #restore_app "windsurf" "$HOME/.config/Windsurf/User" "$HOME/.windsurf"

    if ask_yes_no "Restore Windsurf?"; then
        echo "🔄 Restoring Windsurf ..."
        src="$LAST_BACKUP/windsurf"
        chmod +x "$src"

        if [ -d "$src" ]; then
            mkdir -p "$HOME/.config/Windsurf/User"
            cp -r "$src/settings.json" "$HOME/.config/Windsurf/User/"
            cp -r "$src/keybindings.json" "$HOME/.config/Windsurf/User/"
            echo "   ➤ Config files restored"
        fi

        if [ -f "$src/extensions.tar.gz" ]; then
            mkdir -p "$HOME/.windsurf/extensions"
            tar -xzf "$src/extensions.tar.gz" -C "$HOME/.windsurf/extensions"
            echo "   ➤ Extensions restored"
        fi

        # Ensure correct ownership for user
        sudo chown -R "$USER:$USER" "$HOME/.config/Windsurf/User"
        sudo chown -R "$USER:$USER" "$HOME/.windsurf"
        echo "   ➤ Ownership set to $USER"
    fi
fi

# --------------------------
# Restore GNOME Extensions
# --------------------------

if ask_yes_no "Restore GNOME Extensions?"; then
    if [ -d "$LAST_BACKUP/gnome-extensions" ]; then
        mkdir -p "$HOME/.local/share/gnome-shell/extensions"
        tar -xzf "$LAST_BACKUP/gnome-extensions/user-extensions.tar.gz" \
            -C "$HOME/.local/share/gnome-shell/extensions/"
        echo "🧩 GNOME Extensions restored"
    else
        echo "No backup found for GNOME Extensions"
    fi
fi

# --------------------------
# 5. Restore GitHub Desktop
# --------------------------
#if command -v github-desktop >/dev/null 2>&1; then
#    if [ -d "$LAST_BACKUP/github-desktop" ]; then
#        mkdir -p "$HOME/.config/GitHubDesktop"
#        cp -r "$LAST_BACKUP/github-desktop/"* "$HOME/.config/GitHubDesktop/"
#        echo "🐙 GitHub Desktop restored"
#    fi
#fi

# --------------------------
# 6. Restore XAMPP config
# --------------------------
if ask_yes_no "Restore XAMPP config?"; then
if [ -d "$LAST_BACKUP/xampp" ]; then
    echo "🔧 Restoring XAMPP config..."
    sudo tar -xzf "$LAST_BACKUP/xampp/etc.tar.gz" -C /opt/lampp/
    echo "   ➤ XAMPP config restored"
fi
fi

# ------------------------------------------
# Restore command folder
# ------------------------------------------
if ask_yes_no "Restore command folder?"; then
if [ -d "$LAST_BACKUP/command" ]; then
    echo "📦 Restoring command folder from backup..."
    mkdir -p "$HOME/command"
    cp -r "$LAST_BACKUP/command/"* "$HOME/command/"
    echo "✅ Command folder restored at $HOME/command"

    sudo chmod +x "$HOME/command/start"
    echo "✅ Command start script made executable"

    sudo chown shagor:shagor "$HOME/command/start"
    echo "✅ Command start script ownership set"
fi
fi

echo "🎯 Restore completed successfully."

# ------------------------------------------
# 16. Cleanup
# ------------------------------------------
sudo rm -f /tmp/*.deb /tmp/*.run /tmp/*.gpg
sudo apt autoremove -y
sudo apt clean

# ==========================================
echo -e "\n🎉 Zorin Master Setup v5.3 Completed!"
echo -e "Log: $LOG_FILE"
echo -e "Restart terminal or run: source ~/.bashrc"

else
    echo "ℹ️ Restore skipped by user."
fi