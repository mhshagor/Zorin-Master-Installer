#!/bin/bash
# ==========================================
# Zorin Master Installer v5.1
# Fully Automated Developer Setup for Zorin OS
# ==========================================
set -e  # Stop on any error

MASTER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/zorin-master-install.log"
exec > >(tee -i "$LOG_FILE") 2>&1

echo -e "\nZorin Master Installer v5.1 Starting..."
echo -e "Log saved at: $LOG_FILE\n"
sleep 2

# ------------------------------------------
# 1. System Update
# ------------------------------------------
echo -e "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

# ------------------------------------------
# 2. Install Basic Tools
# ------------------------------------------
echo -e "Installing essential tools (curl, git, wget, etc.)..."
sudo apt install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsof

# ------------------------------------------
# 3. Install XAMPP (with Port Check)
# ------------------------------------------
echo -e "Installing XAMPP (Apache + MySQL + PHP)..."
if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null || lsof -Pi :443 -sTCP:LISTEN -t >/dev/null; then
    echo -e "Warning: Port 80 or 443 is in use. XAMPP may fail to start."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && echo -e "Installation cancelled by user." && exit 1
fi

XAMPP_URL="https://sourceforge.net/projects/xampp/files/XAMPP%20Linux/8.2.12/xampp-linux-x64-8.2.12-0-installer.run/download"
echo -e "Downloading XAMPP installer..."
wget -q "$XAMPP_URL" -O /tmp/xampp-installer.run
chmod +x /tmp/xampp-installer.run
sudo /tmp/xampp-installer.run --mode unattended
sudo ln -sf /opt/lampp/lampp /usr/local/bin/xampp
echo -e "XAMPP installed successfully!"

# ------------------------------------------
# 4. Install Node.js LTS
# ------------------------------------------
echo -e "Installing Node.js (LTS) + npm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g npm@latest
echo -e "Node.js & npm installed!"

# ------------------------------------------
# 5. Install Composer (Securely)
# ------------------------------------------
echo -e "Installing Composer (PHP Dependency Manager)..."
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
EXPECTED_CHECKSUM="$(curl -s https://composer.github.io/installer.sig)"
ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]; then
    echo -e "ERROR: Composer installer corrupted! Aborting." >&2
    rm composer-setup.php
    exit 1
fi

php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php
echo -e "Composer installed securely!"

# ------------------------------------------
# 6. Install Google Chrome
# ------------------------------------------
echo -e "Installing Google Chrome..."
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
sudo dpkg -i /tmp/chrome.deb || sudo apt -f install -y
echo -e "Chrome installed!"

# ------------------------------------------
# 7. Install GitHub Desktop (Latest)
# ------------------------------------------
echo -e "Installing GitHub Desktop (Latest Version)..."
GITHUB_DESKTOP_URL=$(curl -s https://api.github.com/repos/shiftkey/desktop/releases/latest | grep -o "https.*GitHubDesktop-linux.*deb" | head -1)
wget -q "$GITHUB_DESKTOP_URL" -O /tmp/github-desktop.deb
sudo dpkg -i /tmp/github-desktop.deb || sudo apt -f install -y
echo -e "GitHub Desktop installed!"

# ------------------------------------------
# 8. Install Visual Studio Code (Official APT Repo)
# ------------------------------------------
echo -e "Installing Visual Studio Code via Official APT Repository..."

# Install prerequisites
sudo apt-get install -y wget gpg apt-transport-https

# Add Microsoft GPG key
echo -e "Adding Microsoft GPG key..."
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /tmp/microsoft.gpg
sudo install -D -o root -g root -m 644 /tmp/microsoft.gpg /usr/share/keyrings/microsoft.gpg
rm -f /tmp/microsoft.gpg

# Add VS Code repository (using .sources format)
echo -e "Adding VS Code APT repository..."
VSCODE_SOURCES="/etc/apt/sources.list.d/vscode.sources"
sudo tee "$VSCODE_SOURCES" > /dev/null << EOF
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64
Signed-By: /usr/share/keyrings/microsoft.gpg
EOF

# Enable auto-add repo (non-interactive)
echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections

# Update and install
echo -e "Updating package list and installing VS Code..."
sudo apt update
sudo apt install -y code || {
    echo -e "VS Code installation failed. Skipping."
}

if command -v code >/dev/null 2>&1; then
    echo -e "Visual Studio Code installed successfully via APT!"
else
    echo -e "VS Code not found after installation."
fi
# ------------------------------------------
# 9. Install Windsurf (Official APT Repo)
# ------------------------------------------
echo -e "Installing Windsurf via Official APT Repository..."
sudo apt-get install -y wget gpg apt-transport-https

# Add GPG Key
echo -e "Adding Windsurf GPG key..."
wget -qO- "https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/windsurf.gpg" | gpg --dearmor > /tmp/windsurf-stable.gpg
sudo install -D -o root -g root -m 644 /tmp/windsurf-stable.gpg /etc/apt/keyrings/windsurf-stable.gpg
rm -f /tmp/windsurf-stable.gpg

# Add Repository
echo -e "Adding Windsurf APT repository..."
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/windsurf-stable.gpg] https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/apt stable main" | \
    sudo tee /etc/apt/sources.list.d/windsurf.list > /dev/null

# Update & Install
echo -e "Updating package list and installing Windsurf..."
sudo apt update
sudo apt install -y windsurf || {
    echo -e "Windsurf installation failed. Skipping."
}

if command -v windsurf >/dev/null 2>&1; then
    echo -e "Windsurf installed successfully via APT!"
else
    echo -e "Windsurf CLI not found after install."
fi

# ------------------------------------------
# 10. Apply VS Code Settings
# ------------------------------------------
echo -e "Applying your VS Code settings..."
VSCODE_DIR="$MASTER_DIR/vscode"
if [ -f "$VSCODE_DIR/settings.json" ]; then
    mkdir -p ~/.config/Code/User/
    cp "$VSCODE_DIR/settings.json" ~/.config/Code/User/settings.json
    echo -e "VS Code settings applied!"
fi

# ------------------------------------------
# 11. Apply Windsurf Settings
# ------------------------------------------
echo -e "Applying Windsurf settings..."
WINDSURF_DIR="$MASTER_DIR/windsurf"
if [ -f "$WINDSURF_DIR/settings.json" ]; then
    mkdir -p ~/.config/Windsurf/User/
    cp "$WINDSURF_DIR/settings.json" ~/.config/Windsurf/User/settings.json
    echo -e "Windsurf settings applied!"
fi

# ------------------------------------------
# 12. Install VS Code Extensions
# ------------------------------------------
VSCODE_EXT_FILE="$VSCODE_DIR/extensions.txt"
if [ -f "$VSCODE_EXT_FILE" ]; then
    echo -e "Installing VS Code extensions..."
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        code --install-extension "$ext" --force && echo -e "Installed: $ext"
    done < "$VSCODE_EXT_FILE"
    echo -e "All VS Code extensions installed!"
fi

# ------------------------------------------
# 13. Install Windsurf Extensions (if CLI exists)
# ------------------------------------------
WINDSURF_EXT_FILE="$WINDSURF_DIR/extensions.txt"
if [ -f "$WINDSURF_EXT_FILE" ] && command -v windsurf >/dev/null 2>&1; then
    echo -e "Installing Windsurf extensions..."
    while IFS= read -r ext; do
        [[ -z "$ext" || "$ext" =~ ^# ]] && continue
        windsurf --install-extension "$ext" --force && echo -e "Installed: $ext"
    done < "$WINDSURF_EXT_FILE"
    echo -e "Windsurf extensions installed!"
else
    [ -f "$WINDSURF_EXT_FILE" ] && echo -e "Windsurf CLI not found. Skipping extensions."
fi

# ------------------------------------------
# 14. Install uLauncher + Auto Start
# ------------------------------------------
echo -e "Installing uLauncher (App Launcher)..."
sudo add-apt-repository ppa:agornostal/ulauncher -y
sudo apt update -y
sudo apt install -y ulauncher

# Enable Auto Start
mkdir -p ~/.config/autostart
cp /usr/share/applications/ulauncher.desktop ~/.config/autostart/
sed -i 's/NoDisplay=true/NoDisplay=false/' ~/.config/autostart/ulauncher.desktop
echo "X-GNOME-Autostart-enabled=true" >> ~/.config/autostart/ulauncher.desktop
echo -e "uLauncher installed & set to start on boot!"

# ------------------------------------------
# 15. Install Kooha (Screen Recorder)
# ------------------------------------------
echo -e "Installing Kooha (Screen Recorder)..."
sudo apt install -y kooha
echo -e "Kooha installed!"

# ------------------------------------------
# 16. Add Custom Bash Aliases
# ------------------------------------------
echo -e "Adding useful terminal shortcuts (aliases)..."
BASHRC="$HOME/.bashrc"
if ! grep -q "Zorin Master Installer" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << 'EOF'

# === Custom Aliases by Zorin Master Installer v5.1 ===
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
    echo -e "Aliases added! Run: source ~/.bashrc"
fi

# ------------------------------------------
# 17. Cleanup
# ------------------------------------------
echo -e "Cleaning up temporary files..."
sudo rm -f /tmp/*.deb /tmp/*.run /tmp/packages.microsoft.gpg
sudo apt autoremove -y
sudo apt clean

# ==========================================
# Final Message
# ==========================================
echo -e "\nZorin Master Setup v5.1 Completed Successfully!"
echo -e "Log: $LOG_FILE"
echo -e "Restart terminal or run: source ~/.bashrc"
echo -e "Enjoy your powerful dev environment!\n"