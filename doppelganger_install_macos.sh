#!/bin/bash

# Detect architecture
if [[ $(uname -m) == "x86_64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_amd64.dmg"
elif [[ $(uname -m) == "arm64" ]]; then
    URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_arm64.dmg"
else
    echo "Unsupported architecture"
    exit 1
fi

# Download and mount DMG
TMP_DMG=$(mktemp -d)/doppelganger_assistant.dmg
curl -L "$URL" -o "$TMP_DMG"
hdiutil attach "$TMP_DMG"

# Copy app to Applications folder
cp -R "/Volumes/Doppelganger Assistant/Doppelganger Assistant.app" /Applications/

# Unmount DMG
hdiutil detach "/Volumes/Doppelganger Assistant"

# Run command to ignore Apple Error
xattr -cr "/Applications/Doppelganger Assistant.app"

# Add Assistant to path
PROFILE_FILE="$HOME/.zprofile"
[[ -f "$HOME/.zshrc" ]] && PROFILE_FILE="$HOME/.zshrc"
echo "alias doppelganger_assistant='/Applications/Doppelganger Assistant.app/Contents/MacOS/doppelganger_assistant'" >> "$PROFILE_FILE"

# Check if 'pm3' is installed
if ! command -v pm3 &> /dev/null; then
    read -p "Proxmark3 is not installed. Do you want to install it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        xcode-select --install
        brew install xquartz
        brew tap RfidResearchGroup/proxmark3
        brew install --HEAD --with-blueshark proxmark3
    fi
fi

echo "Doppelganger Assistant has been installed successfully!"
echo "Please restart your terminal or run 'source $PROFILE_FILE' to use the 'doppelganger_assistant' command."