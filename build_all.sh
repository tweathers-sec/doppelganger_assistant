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

print_color "blue" "Cleaning up..."
# clean up
rm -rf fyne-cross/
cd ..

print_color "green" "Build process completed successfully."