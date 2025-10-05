#!/bin/bash


# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to display ASCII art
display_doppelganger_ascii() {
    echo -e "\e[31m"  # Set text color to red
    cat << "EOF"
                                                                      
    ____                         _                                 
   |  _ \  ___  _ __  _ __   ___| | __ _  __ _ _ __   __ _  ___ _ __  
   | | | |/ _ \| '_ \| '_ \ / _ \ |/ _` |/ _` | '_ \ / _` |/ _ \ '__| 
   | |_| | (_) | |_) | |_) |  __/ | (_| | (_| | | | | (_| |  __/ |    
   |____/ \___/| .__/| .__/ \___|_|\__, |\__,_|_| |_|\__, |\___|_|    
               |_|   |_|           |___/             |___/            
                                                                      
EOF
    echo -e "\e[0m"  # Reset text color
}

# Function to prompt for reinstallation
prompt_reinstall() {
    read -p "$1 is already installed. Do you want to reinstall it? (y/n): " choice < /dev/tty
    case "$choice" in
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo "Invalid choice. Skipping reinstallation."; return 1;;
    esac
}

# Function to select Proxmark3 device type
select_proxmark_device() {
    echo ""
    echo "=============================================="
    echo "  Select your Proxmark3 device type:"
    echo "=============================================="
    echo "1) Proxmark3 RDV4 with Blueshark"
    echo "2) Proxmark3 RDV4 (without Blueshark)"
    echo "3) Proxmark3 Easy (512KB)"
    echo ""
    read -p "Enter your choice (1-3): " device_choice < /dev/tty
    
    case "$device_choice" in
        1)
            echo "Selected: Proxmark3 RDV4 with Blueshark"
            PROXMARK_DEVICE="rdv4_bt"
            ;;
        2)
            echo "Selected: Proxmark3 RDV4 (without Blueshark)"
            PROXMARK_DEVICE="rdv4"
            ;;
        3)
            echo "Selected: Proxmark3 Easy (512KB)"
            PROXMARK_DEVICE="easy512"
            ;;
        *)
            echo "Invalid choice. Defaulting to Proxmark3 RDV4 with Blueshark"
            PROXMARK_DEVICE="rdv4_bt"
            ;;
    esac
}

# Function to configure Proxmark3 based on device type
configure_proxmark_device() {
    local device_type=$1
    
    case "$device_type" in
        "rdv4_bt")
            echo "Configuring Proxmark3 RDV4 with Blueshark..."
            cp Makefile.platform.sample Makefile.platform
            sed -i 's/^#PLATFORM=PM3RDV4/PLATFORM=PM3RDV4/' Makefile.platform
            sed -i 's/#PLATFORM_EXTRAS=BTADDON/PLATFORM_EXTRAS=BTADDON/' Makefile.platform
            ;;
        "rdv4")
            echo "Configuring Proxmark3 RDV4 (no Blueshark)..."
            cp Makefile.platform.sample Makefile.platform
            sed -i 's/^#PLATFORM=PM3RDV4/PLATFORM=PM3RDV4/' Makefile.platform
            sed -i 's/^PLATFORM_EXTRAS=BTADDON/#PLATFORM_EXTRAS=BTADDON/' Makefile.platform
            ;;
        "easy512")
            echo "Configuring Proxmark3 Easy (512KB)..."
            cp Makefile.platform.sample Makefile.platform
            sed -i 's/^#PLATFORM=PM3GENERIC/PLATFORM=PM3GENERIC/' Makefile.platform
            sed -i 's/^#PLATFORM_SIZE=512/PLATFORM_SIZE=512/' Makefile.platform
            ;;
    esac
}

# Function to uninstall Doppelganger Assistant and Proxmark3
uninstall_doppelganger() {
    echo "Uninstalling Doppelganger Assistant..."
    
    # Remove the desktop shortcuts
    rm -f "$HOME/Desktop/Doppelganger Assistant.desktop"
    rm -f "$HOME/Desktop/doppelganger_assistant.desktop"
    rm -f "$HOME/.local/share/applications/doppelganger_assistant.desktop"
    
    # Remove the icon
    sudo rm -f "/usr/share/pixmaps/doppelganger_assistant.png"
    
    # Uninstall Doppelganger Assistant
    if command_exists doppelganger_assistant; then
        sudo make uninstall
    fi
    
    # Remove Proxmark3
    if [ -d "proxmark3" ]; then
        cd proxmark3
        sudo make uninstall
        cd ..
        rm -rf proxmark3
    fi
    
    echo "Doppelganger Assistant has been uninstalled."
    exit 0
}

# Check for uninstall flag
if [ "$1" = "--uninstall" ]; then
    uninstall_doppelganger
fi

# Function to detect the OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS=$DISTRIB_ID
    else
        OS=$(uname -s)
    fi

    echo $OS
}

# Function to detect the Desktop Environment
detect_desktop_environment() {
    # First, check XDG_CURRENT_DESKTOP (most reliable for modern DEs)
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
        return
    fi
    
    # Fall back to checking running processes and environment variables
    if [ -n "$GNOME_DESKTOP_SESSION_ID" ] || command -v gnome-shell &> /dev/null; then
        echo "GNOME"
    elif [ -n "$KDE_FULL_SESSION" ] || command -v plasmashell &> /dev/null; then
        echo "KDE"
    elif command -v xfce4-session &> /dev/null; then
        echo "XFCE"
    elif [ -n "$MATE_DESKTOP_SESSION_ID" ] || command -v mate-session &> /dev/null; then
        echo "MATE"
    elif command -v cinnamon &> /dev/null; then
        echo "Cinnamon"
    elif command -v lxsession &> /dev/null; then
        echo "LXDE"
    elif command -v lxqt-session &> /dev/null; then
        echo "LXQt"
    elif command -v budgie-panel &> /dev/null; then
        echo "Budgie"
    else
        echo "Unknown"
    fi
}

# Function to detect the Window Manager
detect_window_manager() {
    # Wayland or X11 session type
    local session_type="${XDG_SESSION_TYPE:-unknown}"

    # Common WMs (process-based detection)
    for wm in xfwm4 mutter kwin_wayland kwin_x11 openbox i3 sway xmonad awesome spectrwm bspwm enlightenment; do
        if pgrep -x "$wm" >/dev/null 2>&1; then
            echo "$wm ($session_type)"
            return
        fi
    done

    # As a fallback, try wmctrl if available (X11)
    if command -v wmctrl >/dev/null 2>&1; then
        local name=$(wmctrl -m 2>/dev/null | awk -F: '/Name/ {print $2}' | xargs)
        if [ -n "$name" ]; then
            echo "$name ($session_type)"
            return
        fi
    fi

    echo "unknown ($session_type)"
}

# Function to refresh desktop environment and make new .desktop files visible
refresh_desktop_integration() {
    local desktop_env=$1
    
    echo "Refreshing desktop integration for $desktop_env..."
    
    # Update desktop database (works for most DEs)
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    # Force update XDG desktop menu cache (standard method)
    if command -v xdg-desktop-menu &> /dev/null; then
        xdg-desktop-menu forceupdate 2>/dev/null || true
    fi
    
    # If available, refresh garcon (XFCE XDG menu implementation)
    if command -v update-desktop-database &> /dev/null && command -v grep &> /dev/null; then
        # Touch the local applications directory so menu watchers see the change
        (touch "$HOME/.local/share/applications" >/dev/null 2>&1) || true
    fi
    
    # Desktop environment specific refresh commands
    case "$desktop_env" in
        *"XFCE"*)
            echo "Applying XFCE-specific desktop refresh..."
            # Kali/XFCE uses garcon (XDG menus). Menu updates after cache refresh.
            # Do NOT attempt to restart xfce4-panel here — in non-interactive contexts
            # (installer, sudo) there is no user session D-Bus and it triggers an error dialog.
            # Refresh desktop icons (desktop entry on ~/Desktop) safely instead.
            if command -v xfdesktop &> /dev/null; then
                (xfdesktop --reload >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"GNOME"*|*"Ubuntu"*)
            echo "Applying GNOME-specific desktop refresh..."
            # GNOME Shell updates menu automatically, but we can trigger it
            if command -v gnome-shell &> /dev/null; then
                # Send a signal to gnome-shell to refresh (non-intrusive)
                (killall -HUP gnome-shell >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"KDE"*|*"Plasma"*)
            echo "Applying KDE Plasma-specific desktop refresh..."
            # KDE's kbuildsycoca rebuilds the system configuration cache
            if command -v kbuildsycoca5 &> /dev/null; then
                (kbuildsycoca5 >/dev/null 2>&1 &) || true
            elif command -v kbuildsycoca6 &> /dev/null; then
                (kbuildsycoca6 >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"Cinnamon"*)
            echo "Applying Cinnamon-specific desktop refresh..."
            # Cinnamon can reload its configuration
            if command -v cinnamon &> /dev/null && command -v dbus-send &> /dev/null; then
                (dbus-send --type=method_call --dest=org.Cinnamon /org/Cinnamon org.Cinnamon.ReloadXlet string:'menu@cinnamon.org' string:'APPLET' >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"MATE"*)
            echo "Applying MATE-specific desktop refresh..."
            # MATE panel refresh
            if command -v mate-panel &> /dev/null; then
                (nohup mate-panel --replace >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"Budgie"*)
            echo "Applying Budgie-specific desktop refresh..."
            # Budgie panel refresh
            if command -v budgie-panel &> /dev/null; then
                (nohup budgie-panel --replace >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"LXDE"*|*"LXQt"*)
            echo "Applying LXDE/LXQt-specific desktop refresh..."
            # LXPanel or LXQt panel refresh
            if command -v lxpanelctl &> /dev/null; then
                (lxpanelctl restart >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *)
            echo "Unknown desktop environment. Using generic refresh methods only."
            ;;
    esac
    
    echo "Desktop integration refresh completed."
}

# Detect the OS
OS=$(detect_os)

# Detect the Desktop Environment
DESKTOP_ENV=$(detect_desktop_environment)

# Detect Window Manager
WINDOW_MANAGER=$(detect_window_manager)

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    as_root=true
else
    as_root=false
fi

# Display Doppelganger ASCII art
display_doppelganger_ascii

# Display detected environment
echo "Detected OS: $OS"
echo "Detected Desktop Environment: $DESKTOP_ENV"
echo "Detected Window Manager: $WINDOW_MANAGER"
echo ""

# ============================
# Pre-flight questions (gather all input up-front)
# ============================

# Ask about (re)installing Doppelganger Assistant
if command_exists doppelganger_assistant; then
    if prompt_reinstall "Doppelganger Assistant"; then
        echo "Proceeding with Doppelganger Assistant reinstallation."
        skip_doppelganger_install=false
    else
        echo "Skipping Doppelganger Assistant installation."
        skip_doppelganger_install=true
    fi
else
    echo "Doppelganger Assistant not found. Proceeding with installation."
    skip_doppelganger_install=false
fi

# Ask about (re)installing Proxmark3 and capture device selection now
if command_exists pm3; then
    if prompt_reinstall "Proxmark3"; then
        echo "Proceeding with Proxmark3 reinstallation."
        skip_proxmark_install=false
    else
        echo "Skipping Proxmark3 installation."
        skip_proxmark_install=true
    fi
else
    echo "Proxmark3 not found. Proceeding with installation."
    skip_proxmark_install=false
fi

if [ "$skip_proxmark_install" = false ]; then
    # Capture device choice up-front so we don't ask later
    select_proxmark_device
fi

PREFLIGHT_DONE=1

# Function to install packages based on the detected OS
install_packages() {
    case "$OS" in
        "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
            sudo apt update
            sudo apt install -y "$@"
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}

# Update and upgrade system packages
case "$OS" in
    "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
        sudo apt update
        sudo apt upgrade -y
        ;;
    *)
        echo "Unsupported operating system: $OS"
        exit 1
        ;;
esac

# If preflight already answered, do not prompt again
if [ "$PREFLIGHT_DONE" != "1" ]; then
    # Fallback to legacy prompts (should not happen)
    if command_exists doppelganger_assistant; then
        if prompt_reinstall "Doppelganger Assistant"; then
            skip_doppelganger_install=false
        else
            skip_doppelganger_install=true
        fi
    else
        skip_doppelganger_install=false
    fi

    if command_exists pm3; then
        if prompt_reinstall "Proxmark3"; then
            skip_proxmark_install=false
        else
            skip_proxmark_install=true
        fi
    else
        skip_proxmark_install=false
    fi
fi

# Install necessary packages for Doppelganger Assistant
if [ "$skip_doppelganger_install" = false ]; then
    install_packages libgl1 xterm make git
    
    # Download the latest Doppelganger Assistant release
    # Add timestamp to prevent GitHub CDN caching
    TIMESTAMP=$(date +%s)
    if [ "$(uname -m)" = "x86_64" ]; then
        wget --no-cache --no-cookies "https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_amd64.tar.xz?t=${TIMESTAMP}" -O doppelganger_assistant_linux_amd64.tar.xz
    else
        wget --no-cache --no-cookies "https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_arm64.tar.xz?t=${TIMESTAMP}" -O doppelganger_assistant_linux_arm64.tar.xz
    fi

    # Extract and install Doppelganger Assistant
    tar xvf doppelganger_assistant_*.tar.xz
    cd doppelganger_assistant
    sudo make install

    # Cleanup the directory, if desired
    rm -rf usr/
    rm doppelganger_assistant*
    rm Makefile
fi

# Install dependencies for Proxmark3
if [ "$skip_proxmark_install" = false ]; then
    install_packages git ca-certificates build-essential pkg-config \
    libreadline-dev gcc-arm-none-eabi libnewlib-dev qtbase5-dev \
    libbz2-dev liblz4-dev libbluetooth-dev libpython3-dev libssl-dev libgd-dev
    
    # Clone the Proxmark3 repository
    if [ ! -d "proxmark3" ]; then
        git clone https://github.com/RfidResearchGroup/proxmark3.git
    fi

    cd proxmark3

    # Device type was selected during preflight; if not, ask now (fallback)
    if [ -z "$PROXMARK_DEVICE" ]; then
        select_proxmark_device
    fi
    
    # Configure Makefile based on selected device type
    configure_proxmark_device "$PROXMARK_DEVICE"

    # Compile and install Proxmark3 software
    make clean && make -j$(nproc)
    sudo make install
fi

# Create desktop shortcut for Doppelganger Assistant
if [ "$skip_doppelganger_install" = false ]; then
    desktop_file="$HOME/.local/share/applications/doppelganger_assistant.desktop"
    icon_path="/usr/share/pixmaps/doppelganger_assistant.png"

    # Download the icon
    if [ -f "$icon_path" ]; then
        echo "Icon already exists. Skipping download."
    else
        echo "Downloading Doppelganger Assistant icon..."
        sudo wget -O "$icon_path" "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.png"
    fi

    # Create necessary directories
    mkdir -p "$HOME/.local/share/applications"
    mkdir -p "$HOME/Desktop"

    # Create .desktop file for applications menu
    echo "Creating application menu entry..."
    cat > "$desktop_file" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Doppelganger Assistant
Comment=Launch Doppelganger Assistant
Exec=doppelganger_assistant
Icon=$icon_path
Terminal=false
Categories=Utility;System;
EOL

    # Make the .desktop file executable
    chmod +x "$desktop_file"

    # Also create desktop shortcut
    desktop_shortcut="$HOME/Desktop/doppelganger_assistant.desktop"
    cat > "$desktop_shortcut" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Doppelganger Assistant
Comment=Launch Doppelganger Assistant
Exec=doppelganger_assistant
Icon=$icon_path
Terminal=false
Categories=Utility;System;
EOL

    # Make desktop shortcut executable
    chmod +x "$desktop_shortcut"

    # Mark desktop file as trusted (for GNOME-based desktops)
    if command -v gio &> /dev/null; then
        gio set "$desktop_shortcut" metadata::trusted true 2>/dev/null || true
    fi

    # Refresh desktop integration based on detected DE
    refresh_desktop_integration "$DESKTOP_ENV"

    echo ""
    echo "Desktop shortcut created successfully."
    echo "Note: You may need to right-click the desktop icon and select 'Allow Launching' or 'Trust' on first use."
    
    # Provide DE-specific instructions if needed
    case "$DESKTOP_ENV" in
        *"XFCE"*)
            echo "XFCE detected. If the applications menu does not update immediately, either:"
            echo " - Log out and back in, or"
            echo " - Manually run 'xfce4-panel -r' from a user terminal (not via sudo)."
            ;;
        *"KDE"*|*"Plasma"*)
            echo "If the menu item doesn't appear immediately, try logging out and back in."
            ;;
        *"GNOME"*)
            echo "The menu should update automatically. If not, try pressing Alt+F2 and typing 'r' to restart GNOME Shell."
            ;;
        *)
            echo "If the menu item doesn't appear immediately, try logging out and back in."
            ;;
    esac
fi

echo "Installation process completed."