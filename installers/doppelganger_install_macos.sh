#!/bin/bash

# Function to print colored messages
print_color() {
    COLOR=$1
    MESSAGE=$2
    echo -e "\033[${COLOR}m${MESSAGE}\033[0m"
}

# Function to display ASCII art
display_doppelganger_ascii() {
    print_color "1;31" '
                                                                      
    ____                         _                                 
   |  _ \  ___  _ __  _ __   ___| | __ _  __ _ _ __   __ _  ___ _ __  
   | | | |/ _ \| '"'"'_ \| '"'"'_ \ / _ \ |/ _` |/ _` | '"'"'_ \ / _` |/ _ \ '"'"'__| 
   | |_| | (_) | |_) | |_) |  __/ | (_| | (_| | | | | (_| |  __/ |    
   |____/ \___/| .__/| .__/ \___|_|\__, |\__,_|_| |_|\__, |\___|_|    
               |_|   |_|           |___/             |___/            
                                                                      
'
}

# Display ASCII art
display_doppelganger_ascii

print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "1;32" "  Doppelgänger Assistant Installer for macOS"
print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ============================
# ASK ALL QUESTIONS FIRST
# ============================

# Detect architecture (needed for download URL)
if [[ $(uname -m) == "x86_64" ]]; then
    ARCH="amd64"
    ARCH_NAME="Intel (x86_64)"
elif [[ $(uname -m) == "arm64" ]]; then
    ARCH="arm64"
    ARCH_NAME="Apple Silicon (arm64)"
else
    print_color "1;31" "[✗] Unsupported architecture: $(uname -m)"
    exit 1
fi

print_color "1;36" "System: $ARCH_NAME"
echo ""

# Ask about Proxmark3
INSTALL_PM3=0
BREW_FLAGS=""

if ! command -v pm3 &> /dev/null; then
    print_color "1;33" "Proxmark3 (Iceman) is not currently installed."
    read -p "Would you like to install it? (y/n) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_PM3=1
        echo ""
        print_color "1;36" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        print_color "1;36" "  Select your Proxmark3 device type:"
        print_color "1;36" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        print_color "1;32" "  1) Proxmark3 RDV4 with Blueshark"
        print_color "1;33" "  2) Proxmark3 RDV4 (without Blueshark)"
        print_color "1;35" "  3) Proxmark3 Easy (512KB)"
        echo ""
        read -p "Enter your choice (1-3): " device_choice
        echo ""
        
        case "$device_choice" in
            1)
                print_color "1;32" "✓ Selected: Proxmark3 RDV4 with Blueshark"
                BREW_FLAGS="--HEAD --with-blueshark"
                ;;
            2)
                print_color "1;32" "✓ Selected: Proxmark3 RDV4 (without Blueshark)"
                BREW_FLAGS="--HEAD"
                ;;
            3)
                print_color "1;32" "✓ Selected: Proxmark3 Easy (512KB)"
                BREW_FLAGS="--HEAD --with-generic"
                ;;
            *)
                print_color "1;33" "⚠ Invalid choice. Defaulting to Proxmark3 RDV4 with Blueshark"
                BREW_FLAGS="--HEAD --with-blueshark"
                ;;
        esac
        echo ""
        
        # Check if Homebrew is needed and available
        if ! command -v brew &> /dev/null; then
            print_color "1;33" "Homebrew is required to install Proxmark3."
            read -p "Would you like to install Homebrew? (y/n) " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_color "1;31" "✗ Cannot install Proxmark3 without Homebrew"
                INSTALL_PM3=0
            fi
            echo ""
        fi
    else
        echo ""
    fi
else
    print_color "1;32" "✓ Proxmark3 (Iceman) is already installed"
    echo ""
fi

# ============================
# NOW DO THE INSTALLATION
# ============================

print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "1;32" "  Starting Installation"
print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Download and install Doppelgänger Assistant
TIMESTAMP=$(date +%s)
URL="https://github.com/tweathers-sec/doppelganger_assistant/releases/download/latest/doppelganger_assistant_darwin_${ARCH}.dmg?t=${TIMESTAMP}"

print_color "1;34" "[•] Downloading Doppelgänger Assistant..."
TMP_DMG=$(mktemp -d)/doppelganger_assistant.dmg
if curl -H "Cache-Control: no-cache" -H "Pragma: no-cache" -L "$URL" -o "$TMP_DMG" 2>/dev/null; then
    print_color "1;32" "    ✓ Download completed"
else
    print_color "1;31" "    ✗ Download failed"
    exit 1
fi

print_color "1;34" "[•] Mounting disk image..."
if hdiutil attach "$TMP_DMG" -quiet 2>/dev/null; then
    print_color "1;32" "    ✓ Disk image mounted"
else
    print_color "1;31" "    ✗ Failed to mount disk image"
    exit 1
fi

print_color "1;34" "[•] Installing to /Applications..."
if cp -R "/Volumes/doppelganger_assistant_darwin_${ARCH}/doppelganger_assistant.app" /Applications/ 2>/dev/null; then
    print_color "1;32" "    ✓ Application installed"
else
    print_color "1;31" "    ✗ Installation failed"
    hdiutil detach "/Volumes/doppelganger_assistant_darwin_${ARCH}" -quiet 2>/dev/null
    exit 1
fi

print_color "1;34" "[•] Removing quarantine attributes..."
xattr -cr "/Applications/doppelganger_assistant.app"
print_color "1;32" "    ✓ Application authorized"

print_color "1;34" "[•] Cleaning up..."
hdiutil detach "/Volumes/doppelganger_assistant_darwin_${ARCH}" -quiet 2>/dev/null
rm -f "$TMP_DMG"
print_color "1;32" "    ✓ Temporary files removed"
echo ""

# Configure shell
print_color "1;34" "[•] Configuring shell environment..."
PROFILE_FILE="$HOME/.zprofile"
[[ -f "$HOME/.zshrc" ]] && PROFILE_FILE="$HOME/.zshrc"
ALIAS_LINE="alias doppelganger_assistant='/Applications/doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant'"

if grep -q "$ALIAS_LINE" "$PROFILE_FILE" 2>/dev/null; then
    print_color "1;32" "    ✓ Command alias already configured"
else
    echo "$ALIAS_LINE" >> "$PROFILE_FILE"
    print_color "1;32" "    ✓ Command alias added to $PROFILE_FILE"
fi
echo ""

# Install Proxmark3 if requested
if [[ "$INSTALL_PM3" == "1" ]]; then
    print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_color "1;32" "  Installing Proxmark3 (Iceman)"
    print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Install Xcode Command Line Tools (must come first)
    print_color "1;34" "[•] Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || print_color "1;32" "    ✓ Already installed"
    echo ""
    
    # Install Homebrew if needed
    if ! command -v brew &> /dev/null; then
        print_color "1;34" "[•] Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for this script
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$PROFILE_FILE"
        else
            eval "$(/usr/local/bin/brew shellenv)"
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$PROFILE_FILE"
        fi
        
        print_color "1;32" "    ✓ Homebrew installed and configured"
        echo ""
    else
        print_color "1;32" "    ✓ Homebrew already installed"
        echo ""
    fi
    
    # Install XQuartz
    print_color "1;34" "[•] Installing XQuartz..."
    brew install xquartz 2>/dev/null
    print_color "1;32" "    ✓ XQuartz installed"
    echo ""
    
    # Tap the RfidResearchGroup repo
    print_color "1;34" "[•] Adding Proxmark3 repository..."
    brew tap RfidResearchGroup/proxmark3 2>/dev/null
    print_color "1;32" "    ✓ Repository added"
    echo ""
    
    # Install Proxmark3
    print_color "1;34" "[•] Installing Proxmark3..."
    if brew install $BREW_FLAGS rfidresearchgroup/proxmark3/proxmark3 2>/dev/null; then
        print_color "1;32" "    ✓ Proxmark3 installed successfully"
    else
        print_color "1;33" "    ⚠ Proxmark3 installation encountered issues"
        print_color "0;37" "      You may need to run: brew install $BREW_FLAGS rfidresearchgroup/proxmark3/proxmark3"
    fi
    echo ""
fi

# Final message
print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_color "1;32" "  Installation Complete!"
print_color "1;32" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
print_color "1;36" "Application Location:"
print_color "0;37" "  /Applications/doppelganger_assistant.app"
echo ""
print_color "1;36" "To use the command-line interface:"
print_color "0;37" "  Restart your terminal or run: source $PROFILE_FILE"
print_color "0;37" "  Then use: doppelganger_assistant"
echo ""
print_color "1;32" "Thank you for installing Doppelgänger Assistant!"
echo ""
