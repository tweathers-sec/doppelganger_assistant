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
if [[ $(uname -m) == "x86_64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_amd64.dmg"
    print_color "0;32" "Detected x86_64 architecture."
elif [[ $(uname -m) == "arm64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_arm64.dmg"
    print_color "0;32" "Detected arm64 architecture."
else
    print_color "1;31" "Unsupported architecture detected. Exiting."
    exit 1
fi

# Download and mount DMG
print_color "1;33" "Downloading and mounting the Doppelganger Assistant disk image..."
TMP_DMG=$(mktemp -d)/doppelganger_assistant.dmg
curl -L "$URL" -o "$TMP_DMG"
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

# Run command to ignore Apple Error
print_color "1;33" "Ignoring Apple error for Doppelganger Assistant..."
xattr -cr "/Applications/Doppelganger Assistant.app"
print_color "0;32" "Apple error ignored successfully."

# Add Assistant to path
print_color "1;33" "Adding Doppelganger Assistant to path..."
PROFILE_FILE="$HOME/.zprofile"
[[ -f "$HOME/.zshrc" ]] && PROFILE_FILE="$HOME/.zshrc"
echo "alias doppelganger_assistant='/Applications/Doppelganger Assistant.app/Contents/MacOS/doppelganger_assistant'" >> "$PROFILE_FILE"
print_color "0;32" "Doppelganger Assistant added to path successfully."

# Check if 'pm3' is installed
print_color "1;33" "Checking if Proxmark3 is installed..."
if ! command -v pm3 &> /dev/null; then
    print_color "1;31" "Proxmark3 is not installed."
    read -p "Do you want to install it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_color "1;33" "Installing Proxmark3..."
        xcode-select --install
        brew install xquartz
        brew tap RfidResearchGroup/proxmark3
        brew install --HEAD --with-blueshark proxmark3
        print_color "0;32" "Proxmark3 installed successfully."
    fi
fi

print_color "1;32" "Doppelganger Assistant has been installed successfully!"
print_color "1;33" "Please restart your terminal or run 'source $PROFILE_FILE' to use the 'doppelganger_assistant' command."