#!/bin/bash

# Function to print messages in color
print_color() {
    local color=$1
    local message=$2
    case $color in
        "red") echo -e "\033[31m$message\033[0m" ;;
        "green") echo -e "\033[32m$message\033[0m" ;;
        "yellow") echo -e "\033[33m$message\033[0m" ;;
        "blue") echo -e "\033[34m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -c, --clean    Clean build artifacts and exit"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Build for all platforms"
    echo "  $0 --clean      # Clean build artifacts"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--clean)
            print_color "blue" "Cleaning build artifacts..."
            rm -rf build/
            rm -rf src/fyne-cross/
            print_color "green" "Build artifacts cleaned successfully."
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_color "red" "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_color "blue" "Cleaning up old packages..."
rm -rf build/
rm -rf src/fyne-cross/
print_color "green" "Old packages have been removed."

print_color "blue" "Checking if Docker is running..."
# Check if Docker is running
if ! docker info &> /dev/null
then
    print_color "yellow" "Docker is not running. Starting Docker..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        open --background -a Docker
        while ! docker info &> /dev/null; do
            sleep 1
        done
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        sudo systemctl start docker
        while ! docker info &> /dev/null; do
            sleep 1
        done
    else
        print_color "red" "Unsupported OS. Please start Docker manually."
        exit 1
    fi
else
    print_color "green" "Docker is already running."
fi

print_color "blue" "Checking if fyne-cross is installed..."
# Ensure that fyne-cross is installed
if ! command -v fyne-cross &> /dev/null
then
    print_color "yellow" "fyne-cross not found. Installing..."
    go install github.com/fyne-io/fyne-cross@latest
else
    print_color "green" "fyne-cross is already installed."
fi

print_color "blue" "Initializing Go module..."
# Initialize Go module
cd src
go mod init doppelganger_assistant || true
go mod tidy
cd ..

# Extract version from src/main.go
VERSION=$(awk -F '"' '/const \(/{flag=1} flag && /Version =/{print $2; exit}' src/main.go)
if [ -z "$VERSION" ]; then
  VERSION="1.0.0"
fi

print_color "blue" "Building for Linux (arm64 and amd64)..."
# Build for Linux (arm64 and amd64)
cd src
fyne-cross linux -arch=arm64,amd64 -app-id=io.mwgroup.doppelganger_assistant

print_color "blue" "Building for macOS (arm64 and amd64)..."
# Set CGO flags to suppress duplicate library warnings on macOS
export CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries"
# Build for macOS (arm64 and amd64)
fyne-cross darwin -arch=arm64,amd64 -app-id=io.mwgroup.doppelganger_assistant

# Rename the macOS apps from src.app to doppelganger_assistant.app
print_color "blue" "Renaming macOS applications..."
if [ -d "fyne-cross/dist/darwin-amd64/src.app" ]; then
    mv fyne-cross/dist/darwin-amd64/src.app fyne-cross/dist/darwin-amd64/doppelganger_assistant.app
fi
if [ -d "fyne-cross/dist/darwin-arm64/src.app" ]; then
    mv fyne-cross/dist/darwin-arm64/src.app fyne-cross/dist/darwin-arm64/doppelganger_assistant.app
fi

# Create DMG for macOS applications
print_color "blue" "Creating DMG files for macOS..."
if [ -d "fyne-cross/dist/darwin-amd64/doppelganger_assistant.app" ]; then
    hdiutil create -volname doppelganger_assistant_darwin_amd64 -srcfolder fyne-cross/dist/darwin-amd64/doppelganger_assistant.app -ov -format UDZO fyne-cross/dist/darwin-amd64/doppelganger_assistant_darwin_amd64.dmg
fi
if [ -d "fyne-cross/dist/darwin-arm64/doppelganger_assistant.app" ]; then
    hdiutil create -volname doppelganger_assistant_darwin_arm64 -srcfolder fyne-cross/dist/darwin-arm64/doppelganger_assistant.app -ov -format UDZO fyne-cross/dist/darwin-arm64/doppelganger_assistant_darwin_arm64.dmg
fi

print_color "blue" "Moving and packaging binaries..."
# Create build directory
mkdir -p ../build/

# Package Linux binaries with Makefile
print_color "blue" "Packaging Linux amd64..."
if [ -f "fyne-cross/bin/linux-amd64/doppelganger_assistant" ]; then
    mkdir -p ../build/doppelganger_assistant
    cp fyne-cross/bin/linux-amd64/doppelganger_assistant ../build/doppelganger_assistant/
    cp Makefile ../build/doppelganger_assistant/
    cd ../build
    tar -cJf doppelganger_assistant_linux_amd64.tar.xz doppelganger_assistant/
    rm -rf doppelganger_assistant/
    cd ../src
fi

print_color "blue" "Packaging Linux arm64..."
if [ -f "fyne-cross/bin/linux-arm64/doppelganger_assistant" ]; then
    mkdir -p ../build/doppelganger_assistant
    cp fyne-cross/bin/linux-arm64/doppelganger_assistant ../build/doppelganger_assistant/
    cp Makefile ../build/doppelganger_assistant/
    cd ../build
    tar -cJf doppelganger_assistant_linux_arm64.tar.xz doppelganger_assistant/
    rm -rf doppelganger_assistant/
    cd ../src
fi

# Package macOS binaries
print_color "blue" "Packaging macOS binaries..."
if [ -f "fyne-cross/bin/darwin-arm64/doppelganger_assistant" ]; then
    tar -cJf fyne-cross/bin/darwin-arm64/doppelganger_assistant_darwin_arm64.tar.xz -C fyne-cross/bin/darwin-arm64 doppelganger_assistant
    mv fyne-cross/bin/darwin-arm64/doppelganger_assistant_darwin_arm64.tar.xz ../build/
fi
if [ -f "fyne-cross/bin/darwin-amd64/doppelganger_assistant" ]; then
    tar -cJf fyne-cross/bin/darwin-amd64/doppelganger_assistant_darwin_amd64.tar.xz -C fyne-cross/bin/darwin-amd64 doppelganger_assistant
    mv fyne-cross/bin/darwin-amd64/doppelganger_assistant_darwin_amd64.tar.xz ../build/
fi

# Move DMG files
if [ -f "fyne-cross/dist/darwin-arm64/doppelganger_assistant_darwin_arm64.dmg" ]; then
    mv fyne-cross/dist/darwin-arm64/doppelganger_assistant_darwin_arm64.dmg ../build/
fi
if [ -f "fyne-cross/dist/darwin-amd64/doppelganger_assistant_darwin_amd64.dmg" ]; then
    mv fyne-cross/dist/darwin-amd64/doppelganger_assistant_darwin_amd64.dmg ../build/
fi

print_color "blue" "Creating Debian packages (.deb) for Linux..."

# Helper to create .deb package given arch and binary path
create_deb_pkg() {
  local arch=$1
  local bin_path=$2

  if [ ! -f "$bin_path" ]; then
    print_color "yellow" "Skipping .deb for $arch; binary not found at $bin_path"
    return
  fi

  local pkgroot="build/pkgroot-$arch"
  local debname="doppelganger_assistant_linux_${arch}.deb"

  rm -rf "$pkgroot"
  mkdir -p "$pkgroot/DEBIAN"
  mkdir -p "$pkgroot/usr/bin"
  mkdir -p "$pkgroot/usr/share/applications"
  mkdir -p "$pkgroot/usr/share/pixmaps"

  # Control file
  cat > "$pkgroot/DEBIAN/control" << EOF
Package: doppelganger-assistant
Version: $VERSION
Section: utils
Priority: optional
Architecture: $arch
Maintainer: tweathers-sec <noreply@example.com>
Description: Doppelgänger Assistant GUI for Proxmark3 workflows
EOF

  # Post-install script to refresh menus/icons
  cat > "$pkgroot/DEBIAN/postinst" << 'EOF'
#!/bin/sh
set -e
update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
if command -v xdg-desktop-menu >/dev/null 2>&1; then
  xdg-desktop-menu forceupdate >/dev/null 2>&1 || true
fi
exit 0
EOF
  chmod 0755 "$pkgroot/DEBIAN/postinst"

  # Binary
  cp "$bin_path" "$pkgroot/usr/bin/doppelganger_assistant"
  chmod 0755 "$pkgroot/usr/bin/doppelganger_assistant"

  # Icon
  cp img/doppelganger_assistant.png "$pkgroot/usr/share/pixmaps/doppelganger_assistant.png"

  # Desktop entry
  cat > "$pkgroot/usr/share/applications/doppelganger_assistant.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Doppelganger Assistant
Comment=Launch Doppelganger Assistant
Exec=doppelganger_assistant
Icon=doppelganger_assistant
Terminal=false
Categories=Utility;System;
EOF

  # Build the deb
  dpkg-deb --build "$pkgroot" "build/$debname"
  print_color "green" "Created build/$debname"
}

create_deb_pkg amd64 "src/fyne-cross/bin/linux-amd64/doppelganger_assistant"
create_deb_pkg arm64 "src/fyne-cross/bin/linux-arm64/doppelganger_assistant"

print_color "green" "Debian package creation completed."

print_color "blue" "Cleaning up..."
# clean up
rm -rf fyne-cross/
cd ..

print_color "green" "Build process completed successfully."