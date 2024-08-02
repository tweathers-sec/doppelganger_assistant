#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
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

# Update and upgrade system packages
sudo apt update
sudo apt upgrade -y

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
    if [ "$(uname -m)" = "x86_64" ]; then
        wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_amd64.tar.xz
    else
        wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_arm64.tar.xz
    fi

    # Extract and install Doppelganger Assistant
    tar xvf doppelganger_assistant_*.tar.xz
    sudo make install

    # Cleanup the directory, if desired
    rm -rf usr/
    rm doppelganger_assistant*
    rm Makefile
fi

# Install dependencies for Proxmark3
if [ -z "$skip_proxmark_install" ]; then
    sudo apt install --no-install-recommends -y git ca-certificates build-essential pkg-config \
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
    sudo make install
fi