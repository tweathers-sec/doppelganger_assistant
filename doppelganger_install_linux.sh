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
    read -p "$1 is already installed. Do you want to reinstall it? (y/n): " choice
    case "$choice" in
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo "Invalid choice. Skipping reinstallation."; return 1;;
    esac
}

# Function to run a command with sudo if available, otherwise run without sudo
run_with_sudo() {
    if command_exists sudo; then
        sudo "$@"
    else
        "$@"
    fi
}

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

# Detect the OS
OS=$(detect_os)

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    as_root=true
else
    as_root=false
fi

# Display Doppelganger ASCII art
display_doppelganger_ascii

# Function to install packages based on the detected OS
install_packages() {
    case "$OS" in
        "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
            if $as_root || command_exists sudo; then
                run_with_sudo apt update
                run_with_sudo apt install -y "$@"
            else
                echo "Warning: Cannot install packages without sudo or root privileges."
                echo "Please install the following packages manually: $@"
                read -p "Press Enter to continue once you've installed the required packages..."
            fi
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
}
# Update and upgrade system packages
if $as_root || command_exists sudo; then
    case "$OS" in
        "Ubuntu"|"Debian"|"Kali GNU/Linux"|"Parrot GNU/Linux"|"Parrot Security")
            run_with_sudo apt update
            run_with_sudo apt upgrade -y
            ;;
        *)
            echo "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
else
    echo "Warning: Cannot update system packages without sudo or root privileges."
fi

# Check if doppelganger_assistant is installed
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

# Check if Proxmark3 is installed
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

# Install necessary packages for Doppelganger Assistant
if [ "$skip_doppelganger_install" = false ]; then
    install_packages libgl1 xterm make git
    
    # Download the latest Doppelganger Assistant release
    if [ "$(uname -m)" = "x86_64" ]; then
        wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_amd64.tar.xz
    else
        wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_arm64.tar.xz
    fi

    # Extract and install Doppelganger Assistant
    tar xvf doppelganger_assistant_*.tar.xz
    if $as_root || command_exists sudo; then
        run_with_sudo make install
    else
        echo "Warning: Cannot install Doppelganger Assistant without sudo or root privileges."
        echo "Please run 'sudo make install' manually after the script finishes."
    fi

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

    # Modify Makefile to support the Blueshark Device, if desired
    cp Makefile.platform.sample Makefile.platform
    sed -i 's/#PLATFORM_EXTRAS=BTADDON/PLATFORM_EXTRAS=BTADDON/' Makefile.platform

    # Compile and install Proxmark3 software
    make clean && make -j$(nproc)
    if $as_root || command_exists sudo; then
        run_with_sudo make install
    else
        echo "Warning: Cannot install Proxmark3 software without sudo or root privileges."
        echo "Please run 'sudo make install' manually after the script finishes."
    fi
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
        run_with_sudo wget -O "$icon_path" "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.png"
    fi

    # Create .desktop file
    echo "Creating desktop shortcut..."
    cat > "$desktop_file" << EOL
[Desktop Entry]
Version=1.0
Type=Application
Name=Doppelganger Assistant
Comment=Launch Doppelganger Assistant
Exec=doppelganger_assistant
Icon=$icon_path
Terminal=false
Categories=Utility;
EOL

    # Make the .desktop file executable
    chmod +x "$desktop_file"

    # Create symlink on the desktop
    ln -sf "$desktop_file" "$HOME/Desktop/Doppelganger Assistant.desktop"

    echo "Desktop shortcut created successfully."
fi

echo "Installation process completed. If any steps were skipped due to lack of privileges, please run them manually as root or with sudo."