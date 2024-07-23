# Define the distribution name, installation path, and other static values
$wslName = "Ubuntu-doppelganger_assistant"
$basePath = "C:\doppelganger_assistant"
$wslInstallationPath = "$basePath\wsl"
$username = "doppelganger"
$installAllSoftware = $true
$rootfsUrl = "https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
$stagingPath = "$basePath\staging"
$rootfsPath = "$stagingPath\ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz"
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"  # Update this path as needed

# Function to check if a command exists
function CommandExists {
    param (
        [string]$command
    )
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}
# Function to download and install aria2 manually if not already installed
function Install-Aria2 {
    $aria2Path = "$basePath\aria2"
    if (-Not (Test-Path -Path "$aria2Path\aria2c.exe")) {
        Write-Output "aria2 is not installed. Installing aria2..."

        $aria2Url = "https://github.com/aria2/aria2/releases/download/release-1.36.0/aria2-1.36.0-win-64bit-build1.zip"
        $aria2ZipPath = "$aria2Path\aria2.zip"
        $aria2ExtractPath = "$aria2Path\extract"

        # Create directories if they do not exist
        if (-Not (Test-Path -Path $aria2Path)) { mkdir $aria2Path }

        # Download aria2 zip file
        Invoke-WebRequest -Uri $aria2Url -OutFile $aria2ZipPath

        # Extract aria2 zip file
        Expand-Archive -Path $aria2ZipPath -DestinationPath $aria2ExtractPath

        # Move aria2c.exe to the aria2 directory
        $aria2ExePath = "$aria2ExtractPath\aria2-1.36.0-win-64bit-build1\aria2c.exe"
        Move-Item -Path $aria2ExePath -Destination "$aria2Path\aria2c.exe" -Force

        # Clean up
        Remove-Item $aria2ZipPath
        Remove-Item -Recurse -Force $aria2ExtractPath

        Write-Output "aria2 has been installed."
    }
}

# Function to download a file using aria2
function Download-File {
    param (
        [string]$Url,
        [string]$Destination
    )

    Write-Output "Downloading $Url to $Destination..."
    $aria2Command = "& `$basePath\aria2\aria2c.exe -x 16 -s 16 -d `"$($Destination | Split-Path)`" -o `"$($Destination | Split-Path -Leaf)`" `"$Url`""
    Write-Output "Executing: $aria2Command"
    Invoke-Expression $aria2Command

    if (-not (Test-Path $Destination)) {
        throw "Failed to download $Url to $Destination."
    }
}

# Function to install winget
function InstallWinget {
    Log "winget is not available. Downloading and installing winget..."
    $wingetInstallerUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $wingetInstallerPath = "$basePath\wingetInstaller.msixbundle"
    Download-File -Url $wingetInstallerUrl -Destination $wingetInstallerPath
    Add-AppxPackage -Path $wingetInstallerPath
    if (-not (CommandExists "winget")) {
        Log "Failed to install winget. Please install it manually."
        exit 1
    }
    Log "winget installed successfully."
}
# Ensure aria2 is installed
Install-Aria2

# Install usbipd if it is not installed
if (-not (CommandExists "winget")) {
    InstallWinget
} else {
    Log "winget is already installed."
}

# Check if the WSL distribution already exists
$wslList = wsl.exe -l -q
if ($wslList -contains $wslName) {
    $response = Read-Host "$wslName already exists. Do you want to redownload and reinstall it? (y/n)"
    if ($response -ne 'y') {
        Write-Output "Skipping reinstallation."
        exit
    }
}

# Create staging directory if it does not exist
if (-Not (Test-Path -Path $stagingPath)) { mkdir $stagingPath }

# Download Ubuntu root filesystem
Write-Output "Downloading Ubuntu root filesystem..."
Download-File -Url $rootfsUrl -Destination $rootfsPath

# Import the WSL distribution
if (-Not (Test-Path -Path $wslInstallationPath)) {
    mkdir $wslInstallationPath
}
wsl.exe --import $wslName $wslInstallationPath $rootfsPath

# Clean up staging files
Remove-Item $rootfsPath

# Ensure WSL is initialized
Write-Output "Initializing WSL and $wslName..."
wsl -d $wslName -e echo "WSL initialized"

# Wait for WSL to initialize
Start-Sleep -Seconds 10

# Create a user setup script with Unix line endings
$ubuntuUserScriptPath = [System.IO.Path]::Combine($env:TEMP, "ubuntu_user_setup.sh")
$createUserScript = @"
#!/bin/bash
username=$username
password=password

# Add user
useradd -m -s /bin/bash \$username
echo '\${username}:\${password}' | chpasswd

# Add user to sudoers
usermod -aG sudo \$username

# Add user to dialout group
usermod -aG dialout \$username

# Set default user for WSL
echo '[user]' | tee -a /etc/wsl.conf
echo 'default=$username' | tee -a /etc/wsl.conf
"@
$createUserScript = $createUserScript -replace "`r`n", "`n"
Set-Content -Path $ubuntuUserScriptPath -Value $createUserScript -NoNewline -Encoding Ascii

# Correct path conversion for WSL
$wslUbuntuUserScriptPath = $ubuntuUserScriptPath -replace "\\", "/"
$wslUbuntuUserScriptPath = $wslUbuntuUserScriptPath -replace "C:", "/mnt/c"

# Update the system and create the user
Write-Output "Updating the system and creating user..."
wsl -d $wslName -u root bash -ic "apt update && apt upgrade -y && bash $wslUbuntuUserScriptPath"
Remove-Item $ubuntuUserScriptPath

# Ensure WSL Distro is restarted when first used with user account
wsl --terminate $wslName

if ($installAllSoftware -eq $true) {
    Write-Output "Installing additional software..."
    # Add sudo without password
    $sudoNoPasswdScript = @"
#!/bin/bash
username=$username

# Allow sudo without password
echo '\${username} ALL=(ALL) NOPASSWD:ALL' | tee -a /etc/sudoers.d/\$username
chmod 0440 /etc/sudoers.d/\$username
"@
    $sudoNoPasswdScript = $sudoNoPasswdScript -replace "`r`n", "`n"
    $sudoNoPasswdScriptPath = [System.IO.Path]::Combine($env:TEMP, "sudoNoPasswd.sh")
    Set-Content -Path $sudoNoPasswdScriptPath -Value $sudoNoPasswdScript -NoNewline -Encoding Ascii

    $wslNoPasswdScriptPath = $sudoNoPasswdScriptPath -replace "\\", "/"
    $wslNoPasswdScriptPath = $wslNoPasswdScriptPath -replace "C:", "/mnt/c"

    wsl -d $wslName -u root bash -ic "bash $wslNoPasswdScriptPath"
    Remove-Item $sudoNoPasswdScriptPath

    # Install base packages
    wsl -d $wslName -u root bash -ic "apt install -y build-essential curl file git usbutils"

    # Install all software
    $installAllSoftwareScript = @"
#!/bin/bash
# Add additional software installation commands here
"@
    $installAllSoftwareScript = $installAllSoftwareScript -replace "`r`n", "`n"
    $installAllSoftwareScriptPath = [System.IO.Path]::Combine($env:TEMP, "installAllSoftware.sh")
    Set-Content -Path $installAllSoftwareScriptPath -Value $installAllSoftwareScript -NoNewline -Encoding Ascii

    $wslAllSoftwareScriptPath = $installAllSoftwareScriptPath -replace "\\", "/"
    $wslAllSoftwareScriptPath = $wslAllSoftwareScriptPath -replace "C:", "/mnt/c"

    wsl -d $wslName -u $username bash -ic "bash $wslAllSoftwareScriptPath"
    Remove-Item $installAllSoftwareScriptPath

    # Mount and run the custom installation script
    $wslInstallScriptPath = $installScriptPath -replace "\\", "/"
    $wslInstallScriptPath = $wslInstallScriptPath -replace "C:", "/mnt/c"

    Write-Output "Running custom installation script..."
    wsl -d $wslName -u $username bash -ic "bash $wslInstallScriptPath"
}

wsl --update

Write-Output "Doppelganger_assistant WSL and Ubuntu setup is complete."