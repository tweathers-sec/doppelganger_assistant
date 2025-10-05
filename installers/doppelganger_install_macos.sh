#!/bin/bash

# Function to print colored messages
print_color() {
    COLOR=$1
    MESSAGE=$2
    echo -e "\033[${COLOR}m${MESSAGE}\033[0m"
}

print_color "1;34" "Starting Doppelganger Assistant installation..."

# Detect architecture
print_color "1;33" "Detecting system architecture..."
TIMESTAMP=$(date +%s)
if [[ $(uname -m) == "x86_64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_amd64.dmg?t=${TIMESTAMP}"
    print_color "0;32" "Detected x86_64 architecture."
elif [[ $(uname -m) == "arm64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_arm64.dmg?t=${TIMESTAMP}"
    print_color "0;32" "Detected arm64 architecture."
else
    print_color "1;31" "Unsupported architecture detected. Exiting."
    exit 1
fi

# Download and mount DMG
print_color "1;33" "Downloading and mounting the Doppelganger Assistant disk image..."
TMP_DMG=$(mktemp -d)/doppelganger_assistant.dmg
curl -H "Cache-Control: no-cache" -H "Pragma: no-cache" -L "$URL" -o "$TMP_DMG"
hdiutil attach "$TMP_DMG"
print_color "0;32" "Disk image downloaded and mounted successfully."

# Copy app to Applications folder
print_color "1;33" "Copying Doppelganger Assistant to Applications folder..."
if [[ $(uname -m) == "arm64" ]]; then
    cp -R "/Volumes/doppelganger_assistant_darwin_arm64/doppelganger_assistant.app" /Applications/
else
    cp -R "/Volumes/doppelganger_assistant_darwin_amd64/doppelganger_assistant.app" /Applications/
fi
print_color "0;32" "Doppelganger Assistant copied successfully."

# Unmount DMG
print_color "1;33" "Unmounting the Doppelganger Assistant disk image..."
if [[ $(uname -m) == "arm64" ]]; then
    hdiutil detach "/Volumes/doppelganger_assistant_darwin_arm64"
else
    hdiutil detach "/Volumes/doppelganger_assistant_darwin_amd64"
fi
print_color "0;32" "Disk image unmounted successfully."

# Remove downloaded files
print_color "1;33" "Removing downloaded files..."
rm -f "$TMP_DMG"
print_color "0;32" "Downloaded files removed successfully."

# Run command to ignore Apple Error
print_color "1;33" "Ignoring Apple error for Doppelganger Assistant..."
xattr -cr "/Applications/doppelganger_assistant.app"
print_color "0;32" "Apple error ignored successfully."

# Add Assistant to path
print_color "1;33" "Adding Doppelganger Assistant to path..."
PROFILE_FILE="$HOME/.zprofile"
[[ -f "$HOME/.zshrc" ]] && PROFILE_FILE="$HOME/.zshrc"
ALIAS_LINE="alias doppelganger_assistant='/Applications/doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant'"

if grep -q "$ALIAS_LINE" "$PROFILE_FILE"; then
    print_color "0;32" "Doppelganger Assistant alias already exists in $PROFILE_FILE."
else
    echo "$ALIAS_LINE" >> "$PROFILE_FILE"
    print_color "0;32" "Doppelganger Assistant added to path successfully."
fi

# Function to select Proxmark3 device type
select_proxmark_device_macos() {
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
            print_color "0;32" "Selected: Proxmark3 RDV4 with Blueshark"
            BREW_FLAGS="--HEAD --with-blueshark"
            ;;
        2)
            print_color "0;32" "Selected: Proxmark3 RDV4 (without Blueshark)"
            BREW_FLAGS="--HEAD"
            ;;
        3)
            print_color "0;32" "Selected: Proxmark3 Easy (512KB)"
            BREW_FLAGS="--HEAD --with-generic"
            ;;
        *)
            print_color "1;33" "Invalid choice. Defaulting to Proxmark3 RDV4 with Blueshark"
            BREW_FLAGS="--HEAD --with-blueshark"
            ;;
    esac
}

# Check if 'pm3' is installed
print_color "1;33" "Checking if Proxmark3 is installed..."
if ! command -v pm3 &> /dev/null; then
    print_color "1;31" "Proxmark3 is not installed."
    read -p "Do you want to install the Iceman fork Proxmark3? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "1;33" "Checking if Homebrew is installed..."
        if ! command -v brew &> /dev/null; then
            print_color "1;31" "Homebrew is not installed."
            read -p "Do you want to install Homebrew? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_color "1;33" "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                print_color "0;32" "Homebrew installed successfully."
            else
                print_color "1;31" "Homebrew installation skipped. Proxmark3 cannot be installed."
                print_color "1;31" "Exiting Proxmark3 installation."
                exit 0
            fi
        else
            print_color "0;32" "Homebrew is already installed."
        fi

        # Select Proxmark3 device type
        select_proxmark_device_macos

        print_color "1;33" "Installing Proxmark3..."
        xcode-select --install 2>/dev/null || true
        brew install xquartz
        brew tap RfidResearchGroup/proxmark3
        brew install $BREW_FLAGS rfidresearchgroup/proxmark3/proxmark3
        print_color "0;32" "Proxmark3 installed successfully."
    fi
fi

print_color "1;32" "Doppelganger Assistant has been installed successfully at /Applications/doppelganger_assistant.app!"
print_color "1;33" "Please restart your terminal or run 'source $PROFILE_FILE' to use the 'doppelganger_assistant' command."
