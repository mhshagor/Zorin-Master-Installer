#!/bin/bash
# ==========================================
# Zorin Master Installer v5.3
# Skips already installed apps
# ==========================================
set -e

MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/zorin-master-install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo -e "\nZorin Master Installer v5.3 Starting..."
echo -e "Log saved at: $LOG_FILE\n"
sleep 2

# ------------------------------------------
# 1. System Update
# ------------------------------------------
echo "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

# ------------------------------------------
# 2. Install Basic Tools
# ------------------------------------------
echo "Installing essential tools..."
sudo apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsof flatpak

# ------------------------------------------
# 3. XAMPP
# ------------------------------------------
if [ ! -d "/opt/lampp" ]; then
    echo "Installing XAMPP..."
    XAMPP_URL="https://www.apachefriends.org/xampp-files/8.2.12/xampp-linux-x64-8.2.12-0-installer.run"
    wget -q "$XAMPP_URL" -O /tmp/xampp-installer.run
    chmod +x /tmp/xampp-installer.run
    sudo /tmp/xampp-installer.run --mode unattended
    sudo ln -sf /opt/lampp/lampp /usr/local/bin/xampp
else
    echo "XAMPP already installed. Skipping..."
fi

# ------------------------------------------
# 4. Node.js
# ------------------------------------------
if ! command -v node >/dev/null 2>&1; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
    sudo npm install -g npm@latest
else
    echo "Node.js already installed. Skipping..."
fi

# ------------------------------------------
# 5. Composer
# ------------------------------------------
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
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
else
    echo "Composer already installed. Skipping..."
fi

# ------------------------------------------
# 6. Google Chrome
# ------------------------------------------
if ! command -v google-chrome >/dev/null 2>&1; then
    echo "Installing Google Chrome..."
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    sudo dpkg -i /tmp/chrome.deb || sudo apt -f install -y
else
    echo "Chrome already installed. Skipping..."
fi

# ------------------------------------------
# 7. GitHub Desktop
# ------------------------------------------
if ! command -v github-desktop >/dev/null 2>&1; then
    echo "Installing GitHub Desktop..."
    GITHUB_DESKTOP_URL=$(curl -s https://api.github.com/repos/shiftkey/desktop/releases/latest | grep -o "https.*GitHubDesktop-linux.*deb" | head -1)
    wget -q "$GITHUB_DESKTOP_URL" -O /tmp/github-desktop.deb
    sudo dpkg -i /tmp/github-desktop.deb || sudo apt -f install -y
else
    echo "GitHub Desktop already installed. Skipping..."
fi

# ------------------------------------------
# 8. VS Code
# ------------------------------------------
if ! command -v code >/dev/null 2>&1; then
    echo "Installing VS Code..."
    sudo apt-get install -y wget gpg apt-transport-https
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
    sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
    rm -f /tmp/microsoft.gpg

    VSCODE_SOURCES="/etc/apt/sources.list.d/vscode.sources"
    sudo tee "$VSCODE_SOURCES" > /dev/null << EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF
    sudo apt update
    sudo apt install -y code || echo "VS Code install failed."
else
    echo "VS Code already installed. Skipping..."
fi

# ------------------------------------------
# 9. Windsurf
# ------------------------------------------
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

# ------------------------------------------
# 10. uLauncher (Only extensions from Shagor's setup)
# ------------------------------------------
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

    # Install only your shown extensions
    echo "Installing your Ulauncher extensions..."
    mkdir -p ~/.config/ulauncher/extensions

    declare -A EXTENSIONS=(
        ["file-search"]="https://github.com/brpaz/ulauncher-file-search.git"
        ["smart-url-opener"]="https://github.com/Ulauncher/ulauncher-smart-url-opener.git"
        ["workspaces"]="https://github.com/brpaz/ulauncher-workspaces.git"
        ["fontawesome-icon-search"]="https://github.com/iboyperson/ulauncher-fontawesome-icon-search.git"
    )

    for name in "${!EXTENSIONS[@]}"; do
        ext_dir="$HOME/.config/ulauncher/extensions/$name"
        if [ ! -d "$ext_dir" ]; then
            echo "Installing $name extension..."
            git clone --depth=1 "${EXTENSIONS[$name]}" "$ext_dir"
        else
            echo "$name extension already installed. Skipping..."
        fi
    done

    echo "✅ uLauncher and your selected extensions installed successfully!"
else
    echo "uLauncher already installed. Skipping..."
fi

# ------------------------------------------
# 11. Kooha
# ------------------------------------------
if ! command -v kooha >/dev/null 2>&1; then
    echo "Installing Kooha..."
    if ! sudo apt install -y kooha; then
        echo "Kooha apt failed. Installing via Flatpak..."
        flatpak install -y flathub io.github.SeerUK.Kooha
    fi
else
    echo "Kooha already installed. Skipping..."
fi

# ------------------------------------------
# 12. VS Code & Windsurf Settings
# ------------------------------------------
VSCODE_DIR="$MASTER_DIR/vscode"
if [ -f "$VSCODE_DIR/settings.json" ]; then
    mkdir -p ~/.config/Code/User/
    cp "$VSCODE_DIR/settings.json" ~/.config/Code/User/settings.json
fi

WINDSURF_DIR="$MASTER_DIR/windsurf"
if [ -f "$WINDSURF_DIR/settings.json" ]; then
    mkdir -p ~/.config/Windsurf/User/
    cp "$WINDSURF_DIR/settings.json" ~/.config/Windsurf/User/settings.json
fi

# ------------------------------------------
# 13. Install VS Code Extensions
# ------------------------------------------
VSCODE_EXT_FILE="$VSCODE_DIR/extensions.txt"
if [ -f "$VSCODE_EXT_FILE" ] && command -v code >/dev/null 2>&1; then
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        code --install-extension "$ext" --force
    done < "$VSCODE_EXT_FILE"
fi

# ------------------------------------------
# 14. Windsurf Extensions
# ------------------------------------------
WINDSURF_EXT_FILE="$WINDSURF_DIR/extensions.txt"
if [ -f "$WINDSURF_EXT_FILE" ] && command -v windsurf >/dev/null 2>&1; then
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        windsurf --install-extension "$ext" --force
    done < "$WINDSURF_EXT_FILE"
fi

# ------------------------------------------
# 15. Custom Bash Aliases
# ------------------------------------------
BASHRC="$HOME/.bashrc"
if ! grep -q "Zorin Master Installer" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# === Custom Aliases by Zorin Master Installer v5.3 ===
alias xstart='sudo /opt/lampp/lampp start'
alias xstop='sudo /opt/lampp/lampp stop'
alias xrestart='sudo /opt/lampp/lampp restart'
alias serve='php artisan serve'
alias runlaravel='php artisan migrate:fresh --seed && php artisan serve'
alias gitpush='git add . && git commit -m "update" && git push'
alias artisan='php artisan'
alias npmrun='npm run dev'
# ================================================
EOF
fi

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
