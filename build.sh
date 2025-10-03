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

print_color "blue" "Checking if fyne-cross is installed..."
# Ensure that fyne-cross is installed
if ! command -v fyne-cross &> /dev/null
then
    print_color "yellow" "fyne-cross not found. Installing..."
    go install github.com/fyne-io/fyne-cross@latest
    export PATH=$PATH:$(go env GOPATH)/bin
else
    print_color "green" "fyne-cross is already installed."
fi

print_color "blue" "Initializing Go module..."
# Initialize Go module
cd src
go mod init doppelganger_assistant || true
go mod tidy
cd ..

print_color "blue" "Creating build directory..."
mkdir -p build

print_color "blue" "Building the application..."
print_color "yellow" "CPU Architecture: $(uname -m)"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_color "blue" "Building for Linux amd64 and arm64 using fyne-cross..."
    cd src
    fyne-cross linux -arch amd64,arm64 -icon ../img/doppelganger_assistant.png -app-id io.mwgroup.doppelganger_assistant
    # Create proper directory structure for installation
    mkdir -p ../build/doppelganger_assistant
    cp -r fyne-cross/dist/linux-amd64/* ../build/doppelganger_assistant/
    cp Makefile ../build/doppelganger_assistant/
    cd ../build
    tar -cJf doppelganger_assistant_linux_amd64.tar.xz doppelganger_assistant/
    rm -rf doppelganger_assistant/
    cd ../src
    mkdir -p ../build/doppelganger_assistant
    cp -r fyne-cross/dist/linux-arm64/* ../build/doppelganger_assistant/
    cp Makefile ../build/doppelganger_assistant/
    cd ../build
    tar -cJf doppelganger_assistant_linux_arm64.tar.xz doppelganger_assistant/
    rm -rf doppelganger_assistant/
    cd ..
elif [[ "$OSTYPE" == "darwin"* ]]; then
    cd src
    if [[ $(uname -m) == "arm64" ]]; then
        print_color "blue" "Building for macOS arm64..."
        fyne package -os darwin -icon ../img/doppelganger_assistant.png -appID io.mwgroup.doppelganger_assistant
        hdiutil create -volname doppelganger_assistant_darwin_arm64 -srcfolder doppelganger_assistant.app -ov -format UDZO ../build/doppelganger_assistant_darwin_arm64.dmg
        # Extract CLI binary and compress it
        tar -cJf ../build/doppelganger_assistant_darwin_arm64.tar.xz doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant
        rm -rf doppelganger_assistant.app
    elif [[ $(uname -m) == "x86_64" ]]; then
        print_color "blue" "Building for macOS amd64..."
        fyne package -os darwin -icon ../img/doppelganger_assistant.png -appID io.mwgroup.doppelganger_assistant
        hdiutil create -volname doppelganger_assistant_darwin_amd64 -srcfolder doppelganger_assistant.app -ov -format UDZO ../build/doppelganger_assistant_darwin_amd64.dmg
        # Extract CLI binary and compress it
        tar -cJf ../build/doppelganger_assistant_darwin_amd64.tar.xz doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant
        rm -rf doppelganger_assistant.app
    else
        print_color "red" "Unsupported architecture for macOS."
        exit 1
    fi
    cd ..
else
    print_color "red" "Unsupported OS."
    exit 1
fi

print_color "blue" "Listing files in build directory."
ls -l build/

print_color "green" "Build process completed successfully."