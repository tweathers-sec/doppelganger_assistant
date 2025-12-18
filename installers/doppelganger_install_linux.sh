#!/bin/bash


# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to display ASCII art
display_doppelganger_ascii() {
    echo -e "\e[31m"
    cat << "EOF"
                                                                      
    ____                         _                                 
   |  _ \  ___  _ __  _ __   ___| | __ _  __ _ _ __   __ _  ___ _ __  
   | | | |/ _ \| '_ \| '_ \ / _ \ |/ _` |/ _` | '_ \ / _` |/ _ \ '__| 
   | |_| | (_) | |_) | |_) |  __/ | (_| | (_| | | | | (_| |  __/ |    
   |____/ \___/| .__/| .__/ \___|_|\__, |\__,_|_| |_|\__, |\___|_|    
               |_|   |_|           |___/             |___/            
                                                                      
EOF
    echo -e "\e[0m"
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
    
    rm -f "$HOME/Desktop/Doppelganger Assistant.desktop"
    rm -f "$HOME/Desktop/doppelganger_assistant.desktop"
    rm -f "$HOME/.local/share/applications/doppelganger_assistant.desktop"
    
    sudo rm -f "/usr/share/pixmaps/doppelganger_assistant.png"
    
    if command_exists doppelganger_assistant; then
        sudo make uninstall
    fi
    
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
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
        return
    fi
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
    local session_type="${XDG_SESSION_TYPE:-unknown}"
    for wm in xfwm4 mutter kwin_wayland kwin_x11 openbox i3 sway xmonad awesome spectrwm bspwm enlightenment; do
        if pgrep -x "$wm" >/dev/null 2>&1; then
            echo "$wm ($session_type)"
            return
        fi
    done

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
    
    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    
    if command -v xdg-desktop-menu &> /dev/null; then
        xdg-desktop-menu forceupdate 2>/dev/null || true
    fi
    
    if command -v update-desktop-database &> /dev/null && command -v grep &> /dev/null; then
        (touch "$HOME/.local/share/applications" >/dev/null 2>&1) || true
    fi
    case "$desktop_env" in
        *"XFCE"*)
            echo "Applying XFCE-specific desktop refresh..."
            if command -v xfdesktop &> /dev/null; then
                (xfdesktop --reload >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"GNOME"*|*"Ubuntu"*)
            echo "Applying GNOME-specific desktop refresh..."
            if command -v gnome-shell &> /dev/null; then
                (killall -HUP gnome-shell >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"KDE"*|*"Plasma"*)
            echo "Applying KDE Plasma-specific desktop refresh..."
            if command -v kbuildsycoca5 &> /dev/null; then
                (kbuildsycoca5 >/dev/null 2>&1 &) || true
            elif command -v kbuildsycoca6 &> /dev/null; then
                (kbuildsycoca6 >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"Cinnamon"*)
            echo "Applying Cinnamon-specific desktop refresh..."
            if command -v cinnamon &> /dev/null && command -v dbus-send &> /dev/null; then
                (dbus-send --type=method_call --dest=org.Cinnamon /org/Cinnamon org.Cinnamon.ReloadXlet string:'menu@cinnamon.org' string:'APPLET' >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"MATE"*)
            echo "Applying MATE-specific desktop refresh..."
            if command -v mate-panel &> /dev/null; then
                (nohup mate-panel --replace >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"Budgie"*)
            echo "Applying Budgie-specific desktop refresh..."
            if command -v budgie-panel &> /dev/null; then
                (nohup budgie-panel --replace >/dev/null 2>&1 &) || true
            fi
            ;;
            
        *"LXDE"*|*"LXQt"*)
            echo "Applying LXDE/LXQt-specific desktop refresh..."
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

if [ "$PREFLIGHT_DONE" != "1" ]; then
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
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_SUFFIX="amd64"
            ;;
        aarch64|arm64)
            ARCH_SUFFIX="arm64"
            ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    case "$OS" in
        "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
            echo "Detected Debian-based system. Installing from .deb package..."
            
            # Install required dependencies
            install_packages libgl1 xterm wget
            
            # Download the latest Doppelganger Assistant .deb package
            TIMESTAMP=$(date +%s)
            DEB_FILE="doppelganger_assistant_linux_${ARCH_SUFFIX}.deb"
            
            echo "Downloading ${DEB_FILE}..."
            wget --no-cache --no-cookies "https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/${DEB_FILE}?t=${TIMESTAMP}" -O "${DEB_FILE}"
            
            # Install the .deb package
            echo "Installing Doppelganger Assistant..."
            sudo dpkg -i "${DEB_FILE}" || sudo apt-get install -f -y
            
            # Cleanup
            rm -f "${DEB_FILE}"
            
            echo "Doppelganger Assistant installed successfully via .deb package."
            ;;
            
        *)
            echo "Non-Debian system detected. Installing from tar.xz archive..."
            
            # Install required dependencies
            install_packages libgl1 xterm make git wget
            
            # Download the latest Doppelganger Assistant release
            TIMESTAMP=$(date +%s)
            TARBALL="doppelganger_assistant_linux_${ARCH_SUFFIX}.tar.xz"
            
            echo "Downloading ${TARBALL}..."
            wget --no-cache --no-cookies "https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/${TARBALL}?t=${TIMESTAMP}" -O "${TARBALL}"
            
            # Extract and install Doppelganger Assistant
            tar xvf "${TARBALL}"
            cd doppelganger_assistant
            sudo make install
            
            # Cleanup
            cd ..
            rm -rf doppelganger_assistant
            rm -f "${TARBALL}"
            
            echo "Doppelganger Assistant installed successfully from tarball."
            ;;
    esac
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

    if [ -z "$PROXMARK_DEVICE" ]; then
        select_proxmark_device
    fi
    
    configure_proxmark_device "$PROXMARK_DEVICE"
    make clean && make -j$(nproc)
    sudo make install
fi

if [ "$skip_doppelganger_install" = false ]; then
    case "$OS" in
        "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
            echo "Configuring desktop integration for Debian-based system..."
            
            if command -v update-desktop-database &> /dev/null; then
                update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
                sudo update-desktop-database /usr/share/applications 2>/dev/null || true
            fi
            
            if command -v update-mime-database &> /dev/null; then
                sudo update-mime-database /usr/share/mime 2>/dev/null || true
            fi
            
            if command -v gtk-update-icon-cache &> /dev/null; then
                sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true
            fi
            mkdir -p "$HOME/Desktop"
            desktop_shortcut="$HOME/Desktop/doppelganger_assistant.desktop"
            
            if [ -f "/usr/share/applications/doppelganger_assistant.desktop" ]; then
                cp /usr/share/applications/doppelganger_assistant.desktop "$desktop_shortcut"
                chmod +x "$desktop_shortcut"
                
                if command -v gio &> /dev/null; then
                    gio set "$desktop_shortcut" metadata::trusted true 2>/dev/null || true
                fi
                
                echo "Desktop shortcut created successfully."
            else
                echo "Warning: System desktop file not found. The application should still be in your menu."
            fi
            
            refresh_desktop_integration "$DESKTOP_ENV"
            
            echo ""
            echo "Desktop integration configured."
            echo "The application should now appear in your applications menu."
            ;;
            
        *)
            echo "Creating desktop files for non-Debian system..."
            
            desktop_file="$HOME/.local/share/applications/doppelganger_assistant.desktop"
            icon_path="/usr/share/pixmaps/doppelganger_assistant.png"

            if [ ! -f "$icon_path" ]; then
                echo "Downloading Doppelganger Assistant icon..."
                sudo wget -O "$icon_path" "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.png"
            fi

            mkdir -p "$HOME/.local/share/applications"
            mkdir -p "$HOME/Desktop"
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

            chmod +x "$desktop_file"

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

            chmod +x "$desktop_shortcut"

            if command -v gio &> /dev/null; then
                gio set "$desktop_shortcut" metadata::trusted true 2>/dev/null || true
            fi

            refresh_desktop_integration "$DESKTOP_ENV"

            echo ""
            echo "Desktop shortcut created successfully."
            ;;
    esac
    
    case "$DESKTOP_ENV" in
        *"XFCE"*)
            echo ""
            echo "XFCE Tips:"
            echo " - If the menu doesn't update immediately, log out and back in"
            echo " - Or run 'xfce4-panel -r' from a user terminal"
            ;;
        *"KDE"*|*"Plasma"*)
            echo ""
            echo "KDE/Plasma Tips:"
            echo " - Menu items should appear immediately"
            echo " - If not, try logging out and back in"
            ;;
        *"GNOME"*)
            echo ""
            echo "GNOME Tips:"
            echo " - Press Super key and search for 'Doppelganger'"
            echo " - If menu doesn't update, press Alt+F2 and type 'r' to restart GNOME Shell"
            ;;
    esac
fi

echo ""
echo "=============================================="
echo "Installation process completed successfully!"
echo "=============================================="
echo ""
echo "To launch Doppelganger Assistant:"
echo "  - Look for 'Doppelganger Assistant' in your applications menu"
echo "  - Or run 'doppelganger_assistant' from the terminal"
echo "  - Or use the desktop shortcut (if created)"
echo ""