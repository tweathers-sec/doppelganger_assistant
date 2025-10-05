#!/bin/bash

# Check if running in non-interactive mode (auto-install/update without prompts)
NON_INTERACTIVE=""
PROXMARK_DEVICE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --update|--non-interactive)
            NON_INTERACTIVE="true"
            shift
            ;;
        --device)
            PROXMARK_DEVICE="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to prompt for reinstallation
prompt_reinstall() {
    # If in non-interactive mode, always proceed without prompting
    if [ "$NON_INTERACTIVE" = "true" ]; then
        echo "Non-interactive mode: Installing/updating $1..."
        return 0
    fi
    
    read -p "$1 is already installed. Do you want to reinstall it? (y/n): " choice
    case "$choice" in
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo "Invalid choice. Skipping reinstallation."; return 1;;
    esac
}

# Function to select Proxmark3 device type
select_proxmark_device() {
    # Skip interactive prompt if device was provided as parameter
    if [ -n "$PROXMARK_DEVICE" ]; then
        # Map Windows installer device names to internal names
        case "$PROXMARK_DEVICE" in
            "rdv4-blueshark")
                PROXMARK_DEVICE="rdv4_bt"
                echo "Using provided device: Proxmark3 RDV4 with Blueshark"
                ;;
            "rdv4-no-blueshark")
                PROXMARK_DEVICE="rdv4"
                echo "Using provided device: Proxmark3 RDV4 (without Blueshark)"
                ;;
            "easy-512kb")
                PROXMARK_DEVICE="easy512"
                echo "Using provided device: Proxmark3 Easy (512KB)"
                ;;
            *)
                # Already in internal format, just use it
                echo "Using provided device type: $PROXMARK_DEVICE"
                ;;
        esac
        return
    fi
    
    # Skip interactive prompt in non-interactive mode
    if [ "$NON_INTERACTIVE" = "true" ]; then
        echo "Non-interactive mode: Using default Proxmark3 RDV4 with Blueshark"
        PROXMARK_DEVICE="rdv4_bt"
        return
    fi
    
    echo ""
    echo "=============================================="
    echo "  Select your Proxmark3 device type:"
    echo "=============================================="
    echo "1) Proxmark3 RDV4 with Blueshark"
    echo "2) Proxmark3 RDV4 (without Blueshark)"
    echo "3) Proxmark3 Easy (512KB)"
    echo ""
    read -p "Enter your choice (1-3): " device_choice
    
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

    # Prompt user to select their Proxmark3 device type
    select_proxmark_device
    
    # Configure Makefile based on selected device type
    configure_proxmark_device "$PROXMARK_DEVICE"

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