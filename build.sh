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

print_color "blue" "Cleaning up old packages..."
rm -rf build/
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

print_color "blue" "Checking if fyne is installed..."
# Ensure that fyne is installed
if ! command -v fyne &> /dev/null
then
    print_color "yellow" "fyne not found. Installing..."
    go install fyne.io/fyne/v2/cmd/fyne@latest
    export PATH=$PATH:$(go env GOPATH)/bin
else
    print_color "green" "fyne is already installed."
fi

print_color "blue" "Initializing Go module..."
# Initialize Go module
go mod init doppelganger_assistant || true
go mod tidy

print_color "blue" "Building for Linux (arm64 and amd64)..."
# Build for Linux (arm64 and amd64)
fyne-cross linux -arch=arm64,amd64 -icon=img/doppelganger_assistant.png -app-id=io.mwgroup.doppelganger_assistant

print_color "blue" "Building for macOS (arm64 and amd64)..."
# Build for macOS (arm64 and amd64)
fyne-cross darwin -arch=arm64,amd64 -icon=img/doppelganger_assistant.png -app-id=io.mwgroup.doppelganger_assistant

# Create DMG for macOS applications
hdiutil create -volname doppelganger_assistant_darwin_amd64 -srcfolder fyne-cross/dist/darwin-amd64/doppelganger_assistant.app -ov -format UDZO fyne-cross/dist/darwin-amd64/doppelganger_assistant_darwin_amd64.dmg
hdiutil create -volname doppelganger_assistant_darwin_arm64 -srcfolder fyne-cross/dist/darwin-arm64/doppelganger_assistant.app -ov -format UDZO fyne-cross/dist/darwin-arm64/doppelganger_assistant_darwin_arm64.dmg

print_color "blue" "Moving and relabeling binaries..."
# Move and relabel binaries
mkdir -p build/
tar -cJf fyne-cross/bin/darwin-arm64/doppelganger_assistant_darwin_arm64.tar.xz fyne-cross/bin/darwin-arm64/doppelganger_assistant
tar -cJf fyne-cross/bin/darwin-amd64/doppelganger_assistant_darwin_amd64.tar.xz fyne-cross/bin/darwin-amd64/doppelganger_assistant
mv fyne-cross/dist/linux-arm64/doppelganger_assistant.tar.xz build/doppelganger_assistant_linux_arm64.tar.xz
mv fyne-cross/dist/linux-amd64/doppelganger_assistant.tar.xz build/doppelganger_assistant_linux_amd64.tar.xz
mv fyne-cross/bin/darwin-arm64/doppelganger_assistant_darwin_arm64.tar.xz build/
mv fyne-cross/bin/darwin-amd64/doppelganger_assistant_darwin_amd64.tar.xz build/
mv fyne-cross/dist/darwin-arm64/doppelganger_assistant_darwin_arm64.dmg build/
mv fyne-cross/dist/darwin-amd64/doppelganger_assistant_darwin_amd64.dmg build/

# mv fyne-cross/bin/windows-arm64/doppelganger_assistant* build/doppelganger_assistant_windows_arm64.exe
# mv fyne-cross/bin/windows-amd64/doppelganger_assistant* build/doppelganger_assistant_windows_amd64.exe

print_color "blue" "Cleaning up..."
# Clean up
# rm -rf fyne-cross/
# rm Icon.png

print_color "green" "Build process completed successfully."