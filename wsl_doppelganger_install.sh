#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Update and upgrade system packages
sudo apt update
sudo apt upgrade -y

# Install necessary packages for Doppelganger Assistant
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

# Launch the Doppelganger Assistant GUI
doppelganger_assistant &

# Install dependencies for Proxmark3
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
