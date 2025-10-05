#!/bin/bash

# Check if running in update mode (non-interactive)
UPDATE_MODE=${1:-""}

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to prompt for reinstallation
prompt_reinstall() {
    # If in update mode, always update
    if [ "$UPDATE_MODE" = "--update" ]; then
        echo "Update mode: Updating $1..."
        return 0
    fi
    
    read -p "$1 is already installed. Do you want to reinstall it? (y/n): " choice
    case "$choice" in
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo "Invalid choice. Skipping reinstallation."; return 1;;
    esac
}

# Update and upgrade system packages
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Fix locale for GUI applications (critical for Fyne in WSL2)
echo "Setting up locale..."
sudo apt install -y locales
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Add locale to shell profile if not already present
if ! grep -q "export LANG=en_US.UTF-8" ~/.bashrc; then
    echo "export LANG=en_US.UTF-8" >> ~/.bashrc
    echo "export LC_ALL=en_US.UTF-8" >> ~/.bashrc
fi

# Check if doppelganger_assistant is installed
if command_exists doppelganger_assistant; then
    if ! prompt_reinstall "Doppelganger Assistant"; then
        echo "Skipping Doppelganger Assistant installation."
        skip_doppelganger_install=true
    fi
fi

# Check if Proxmark3 is installed
if command_exists pm3; then
    if ! prompt_reinstall "Proxmark3"; then
        echo "Skipping Proxmark3 installation."
        skip_proxmark_install=true
    fi
fi

# Install necessary packages for Doppelganger Assistant
if [ -z "$skip_doppelganger_install" ]; then
    sudo apt install -y libgl1 xterm make git

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
if [ -z "$skip_proxmark_install" ]; then
    echo "Installing/Updating Proxmark3..."
    sudo apt install --no-install-recommends -y git ca-certificates build-essential pkg-config \
    libreadline-dev gcc-arm-none-eabi libnewlib-dev qtbase5-dev \
    libbz2-dev liblz4-dev libbluetooth-dev libpython3-dev libssl-dev libgd-dev
    
    # Create src directory if it doesn't exist
    mkdir -p ~/src
    cd ~/src
    
    # Clone or update the Proxmark3 repository
    if [ ! -d "proxmark3" ]; then
        echo "Cloning Proxmark3 repository..."
        git clone https://github.com/RfidResearchGroup/proxmark3.git
    else
        echo "Updating existing Proxmark3 repository..."
        cd proxmark3
        git fetch origin
        git pull origin master
        cd ~/src
    fi

    cd proxmark3

    # Modify Makefile to support the Blueshark Device, if desired
    cp Makefile.platform.sample Makefile.platform
    sed -i 's/#PLATFORM_EXTRAS=BTADDON/PLATFORM_EXTRAS=BTADDON/' Makefile.platform

    # Compile and install Proxmark3 software
    echo "Building Proxmark3... (this may take several minutes)"
    make clean && make -j$(nproc)
    echo "Installing Proxmark3..."
    sudo make install PREFIX=/usr/local
    
    echo "Proxmark3 installation/update complete!"
fi

echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo ""
echo "To launch Doppelganger Assistant:"
echo "  doppelganger_assistant"
echo ""
echo "To use Proxmark3:"
echo "  pm3"
echo ""