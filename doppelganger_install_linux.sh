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

# Function to run a command with sudo if available, otherwise run without sudo
run_with_sudo() {
    if command_exists sudo; then
        sudo "$@"
    else
        "$@"
    fi
}

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    as_root=true
else
    as_root=false
fi

# Update and upgrade system packages
if $as_root || command_exists sudo; then
    run_with_sudo apt update
    run_with_sudo apt upgrade -y
else
    echo "Warning: Cannot update system packages without sudo or root privileges."
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
    if $as_root || command_exists sudo; then
        run_with_sudo apt install -y libgl1 xterm make git
    else
        echo "Warning: Cannot install required packages without sudo or root privileges."
        echo "Please install the following packages manually: libgl1 xterm make git"
        read -p "Press Enter to continue once you've installed the required packages..."
    fi

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
if [ -z "$skip_proxmark_install" ]; then
    if $as_root || command_exists sudo; then
        run_with_sudo apt install --no-install-recommends -y git ca-certificates build-essential pkg-config \
        libreadline-dev gcc-arm-none-eabi libnewlib-dev qtbase5-dev \
        libbz2-dev liblz4-dev libbluetooth-dev libpython3-dev libssl-dev libgd-dev
    else
        echo "Warning: Cannot install Proxmark3 dependencies without sudo or root privileges."
        echo "Please install the following packages manually:"
        echo "git ca-certificates build-essential pkg-config libreadline-dev gcc-arm-none-eabi libnewlib-dev qtbase5-dev libbz2-dev liblz4-dev libbluetooth-dev libpython3-dev libssl-dev libgd-dev"
        read -p "Press Enter to continue once you've installed the required packages..."
    fi

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

echo "Installation process completed. If any steps were skipped due to lack of privileges, please run them manually as root or with sudo."