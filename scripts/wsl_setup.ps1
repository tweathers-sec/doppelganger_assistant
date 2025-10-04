# Define the installation path and other static values
$basePath = "C:\doppelganger_assistant"
$wslInstallationPath = "$basePath\wsl"
$username = "doppelganger"
$installAllSoftware = $true

# Possible WSL distribution names (will be set based on user choice)
$kaliWslName = "Kali-doppelganger_assistant"
$ubuntuWslName = "Ubuntu-doppelganger_assistant"
$wslName = $null  # Will be set after user selects distribution

# Use WSL's built-in Ubuntu installation instead of manual rootfs download
# This works for both AMD64 and ARM64 architectures
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"

# Log file path
$logFile = "C:\doppelganger_assistant\wsl_setup.log"

# Function to log output to both file and screen
function Log {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('u')
    $logMessage = "$timestamp - $message"
    Write-Output $message
    Add-Content -Path $logFile -Value $logMessage
}

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
        Log "aria2 is not installed. Installing aria2..."

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

        Log "aria2 has been installed."
    }
}

# Function to download a file using aria2
function Download-File {
    param (
        [string]$Url,
        [string]$Destination
    )

    Log "Downloading $Url to $Destination..."
    $aria2Command = "& `$basePath\aria2\aria2c.exe -x 16 -s 16 -d `"$($Destination | Split-Path)`" -o `"$($Destination | Split-Path -Leaf)`" `"$Url`""
    Log "Executing: $aria2Command"
    Invoke-Expression $aria2Command

    if (-not (Test-Path $Destination)) {
        throw "Failed to download $Url to $Destination."
    }
}

# Function to install winget
function Install-Winget {
    Log "Installing winget..."
    $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $wingetPath = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    
    $isWindows10 = [System.Environment]::OSVersion.Version.Major -eq 10

    try {
        if ($isWindows10) {
            $xamlUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6"
            $xamlPath = "$env:TEMP\Microsoft.UI.Xaml.2.8.6.zip"
            $xamlExtractPath = "$env:TEMP\Microsoft.UI.Xaml"

            # Download XAML package
            Log "Downloading XAML package..."
            (New-Object System.Net.WebClient).DownloadFile($xamlUrl, $xamlPath)

            # Extract XAML package
            Log "Extracting XAML package..."
            Expand-Archive -Path $xamlPath -DestinationPath $xamlExtractPath -Force

            # Install XAML package
            Log "Installing XAML package..."
            Add-AppxPackage -Path "$xamlExtractPath\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"
        }

        # Download and install Winget
        Log "Downloading Winget..."
        (New-Object System.Net.WebClient).DownloadFile($wingetUrl, $wingetPath)
        
        Log "Installing Winget..."
        Add-AppxPackage -Path $wingetPath
        Log "Winget installed successfully."
        return $true
    } catch {
        Log "Error installing winget: $_"
        return $false
    } finally {
        Remove-Item $wingetPath -ErrorAction SilentlyContinue
        if ($isWindows10) {
            Remove-Item $xamlPath -ErrorAction SilentlyContinue
            Remove-Item $xamlExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
# Function to check if winget is installed
function Is-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Function to refresh PATH and check for usbipd
function Refresh-UsbIpdCommand {
    Log "Refreshing PATH and checking for usbipd command..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    if (Get-Command usbipd -ErrorAction SilentlyContinue) {
        Log "usbipd command is now available."
        return $true
    }
    
    Log "usbipd command is still not available after refreshing PATH."
    return $false
}

# Ensure aria2 is installed
Install-Aria2

Log "Checking if NuGet provider is installed and PSGallery is trusted..."

# Install NuGet provider silently if not already installed
Log "Installing NuGet provider..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -Scope CurrentUser

# Ensure the NuGet provider is loaded
Import-PackageProvider -Name NuGet -Force | Out-Null

# Check and set PSGallery to trusted silently
$psGallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
if ($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
    Log "Setting PSGallery to trusted..."
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue | Out-Null
} elseif (-not $psGallery) {
    Log "PSGallery not found. Registering and setting to trusted..."
    Register-PSRepository -Default -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue | Out-Null
} else {
    Log "PSGallery is already set to trusted."
}

# Check if winget is installed
if (-not (Is-WingetInstalled)) {
    Log "Winget is not installed. Installing Winget..."
    if (Install-Winget) {
        Log "Winget installed successfully. Refreshing PATH..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        # Force PowerShell to refresh its command cache
        $env:PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
    } else {
        Log "Failed to install winget. Continuing without winget."
    }
}

# Check winget version and update if necessary
if (Is-WingetInstalled) {
    $minWingetVersion = "1.4.0"  # Set this to the minimum required version
    $currentWingetVersion = (winget --version).Trim()
    Log "Current Winget version: $currentWingetVersion"

    $currentVersionWithoutV = $currentWingetVersion -replace '^v', ''
    $minVersionWithoutV = $minWingetVersion -replace '^v', ''

    if ([version]$currentVersionWithoutV -lt [version]$minVersionWithoutV) {
        Log "Winget version is older than $minWingetVersion. Updating Winget..."
        if (Install-Winget) {
            Log "Winget updated successfully. Refreshing PATH..."
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $newWingetVersion = (winget --version).Trim()
            Log "Updated Winget version: $newWingetVersion"
        } else {
            Log "Failed to update winget. Continuing with current version."
        }
    } else {
        Log "Winget version is up to date."
    }
} else {
    Log "Winget is not available. Skipping version check and update."
}
# Install usbipd using winget or alternative methods
if (-not (CommandExists "usbipd")) {
    Log "Installing usbipd..."
    try {
        $installOutput = Start-Process winget -ArgumentList "install --exact --silent --accept-source-agreements --accept-package-agreements usbipd" -Wait -PassThru -ErrorAction Stop
        if ($installOutput.ExitCode -ne 0) {
            throw "Winget installation failed with exit code: $($installOutput.ExitCode)"
        }
    } catch {
        Log "Error installing usbipd using winget. Trying alternative method..."
        try {
            $usbIpdUrl = "https://github.com/dorssel/usbipd-win/releases/latest/download/usbipd-win_x64.msi"
            $usbIpdMsiPath = "$env:TEMP\usbipd-win_x64.msi"
            Invoke-WebRequest -Uri $usbIpdUrl -OutFile $usbIpdMsiPath
            $msiExecOutput = Start-Process msiexec.exe -ArgumentList "/i `"$usbIpdMsiPath`" /qn" -Wait -PassThru
            if ($msiExecOutput.ExitCode -ne 0) {
                throw "MSI installation failed with exit code: $($msiExecOutput.ExitCode)"
            }
            Remove-Item $usbIpdMsiPath -Force
        } catch {
            Log "WARNING: Failed to install usbipd: $_"
            Log "You can manually install usbipd later from: https://github.com/dorssel/usbipd-win/releases"
            Log "Continuing with installation..."
        }
    }
    
    # Check if usbipd is available after installation
    if (-not (Refresh-UsbIpdCommand)) {
        Log "NOTE: usbipd is not available in current session. It may require a restart or manual installation."
        Log "Continuing with WSL setup..."
    }
} else {
    Log "usbipd is already installed."
}

# Note: Skipping virtualization checks to allow installation in nested VM environments
Log "Proceeding with WSL installation..."

# Check if any Doppelganger WSL distribution already exists
$wslList = wsl.exe -l -q | ForEach-Object { $_.Trim() -replace "`0", "" }
$existingKali = $false
$existingUbuntu = $false

foreach ($distro in $wslList) {
    if ($distro -eq $kaliWslName) {
        $existingKali = $true
    } elseif ($distro -eq $ubuntuWslName) {
        $existingUbuntu = $true
    }
}

if ($existingKali -or $existingUbuntu) {
    # Determine which one exists
    if ($existingKali) {
        $wslName = $kaliWslName
    } else {
        $wslName = $ubuntuWslName
    }
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Existing Installation Detected" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "$wslName already exists. What would you like to do?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1) Update Application & Proxmark3 (keep WSL base)" -ForegroundColor Green
    Write-Host "   - Downloads latest Doppelganger Assistant" -ForegroundColor Gray
    Write-Host "   - Updates Proxmark3 repo and rebuilds" -ForegroundColor Gray
    Write-Host "   - Quick update, preserves your settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2) Full reinstall (removes and recreates WSL)" -ForegroundColor Red
    Write-Host "   - Complete fresh installation" -ForegroundColor Gray
    Write-Host "   - Will lose any customizations" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3) Exit (do nothing)" -ForegroundColor Gray
    Write-Host ""
    
    do {
        $response = Read-Host "Enter your choice (1, 2, or 3)"
    } while ($response -ne "1" -and $response -ne "2" -and $response -ne "3")
    
    if ($response -eq "1") {
        # Update only - skip to app installation
        Log "Updating Doppelganger Assistant and Proxmark3 in existing WSL container..."
        
        # Download latest installation script
        Log "Downloading latest installation script..."
        $installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_doppelganger_install.sh"
        $installScriptPath = "$basePath\wsl_doppelganger_install.sh"
        if (-Not (Test-Path -Path $basePath)) { mkdir $basePath }
        Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath
        
        # Get username from WSL
        $username = wsl -d $wslName bash -c "whoami"
        $username = $username.Trim()
        Log "Detected WSL user: $username"
        
        # Run the installation script in update mode
        $wslInstallScriptPath = $installScriptPath -replace "\\", "/"
        $wslInstallScriptPath = $wslInstallScriptPath -replace "C:", "/mnt/c"
        
        Log "Running installation script to update Doppelganger Assistant and Proxmark3..."
        Log "This will:"
        Log "  - Download latest Doppelganger Assistant binary"
        Log "  - Pull latest Proxmark3 repository changes"
        Log "  - Rebuild Proxmark3 from source"
        Log ""
        wsl -d $wslName -u $username bash -ic "bash $wslInstallScriptPath --update"
        
        Log "Update complete!"
        Write-Host "`n========================================" -ForegroundColor Green
        Write-Host "  Update Complete!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Launch Doppelganger Assistant with:" -ForegroundColor Cyan
        Write-Host "  wsl -d $wslName" -ForegroundColor Yellow
        Write-Host "  doppelganger_assistant" -ForegroundColor Yellow
        Write-Host ""
        exit
    } elseif ($response -eq "2") {
        Log "Unregistering existing $wslName for full reinstall..."
        wsl.exe --unregister $wslName
    } else {
        Log "Exiting without changes."
        exit
    }
}

# No existing Doppelganger installation found, prompt user to select and install
Log "No existing Doppelganger Assistant installation found."
Log "Proceeding with fresh installation..."

# Prompt user to select distribution
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Select Linux Distribution for WSL2" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1) Kali Linux 2025.3 - Recommended" -ForegroundColor Magenta
Write-Host "   - Built for penetration testing (Debian-based)" -ForegroundColor Gray
Write-Host "   - Pre-installed security tools" -ForegroundColor Gray
Write-Host "   - Perfect for Doppelganger Assistant" -ForegroundColor Gray
Write-Host ""
Write-Host "2) Ubuntu 24.04 LTS (Noble) - Alternative" -ForegroundColor Green
Write-Host "   - Latest Ubuntu LTS with modern packages" -ForegroundColor Gray
Write-Host "   - General purpose Linux distribution" -ForegroundColor Gray
Write-Host ""

do {
    $distroChoice = Read-Host "Enter your choice (1 or 2)"
} while ($distroChoice -ne "1" -and $distroChoice -ne "2")

# Create staging directory
if (-Not (Test-Path -Path "$basePath\staging")) { mkdir "$basePath\staging" }

# Detect actual processor architecture using environment variable (most reliable)
$processorArch = $env:PROCESSOR_ARCHITECTURE
Log "Detected processor architecture: $processorArch"

if ($distroChoice -eq "1") {
    Log "Installing Kali Linux 2025.3 via direct rootfs import..."
    $wslName = $kaliWslName  # Set WSL name for Kali
    if ($processorArch -eq "ARM64") {
        # ARM64 for Apple Silicon or Snapdragon processors
        Log "Using ARM64 rootfs (Kali Linux 2025.3)"
        $rootfsUrl = "https://kali.download/wsl-images/current/kali-linux-2025.3-wsl-rootfs-arm64.wsl"
        $rootfsFile = "$basePath\staging\kali.rootfs.wsl"
        $distroName = "Kali Linux 2025.3"
    } else {
        # AMD64/x86_64 for Intel/AMD processors (most common)
        Log "Using AMD64 rootfs (Kali Linux 2025.3)"
        $rootfsUrl = "https://kali.download/wsl-images/current/kali-linux-2025.3-wsl-rootfs-amd64.wsl"
        $rootfsFile = "$basePath\staging\kali.rootfs.wsl"
        $distroName = "Kali Linux 2025.3"
    }
} else {
    Log "Installing Ubuntu 24.04 (Noble) via direct rootfs import..."
    $wslName = $ubuntuWslName  # Set WSL name for Ubuntu
    if ($processorArch -eq "ARM64") {
        # ARM64 for Apple Silicon or Snapdragon processors
        Log "Using ARM64 rootfs (Ubuntu 24.04 Noble)"
        $rootfsUrl = "https://cloud-images.ubuntu.com/wsl/releases/noble/current/ubuntu-noble-wsl-arm64-24.04lts.rootfs.tar.gz"
        $rootfsFile = "$basePath\staging\ubuntu.rootfs.tar.gz"
        $distroName = "Ubuntu 24.04 (Noble)"
    } else {
        # AMD64/x86_64 for Intel/AMD processors (most common)
        Log "Using AMD64 rootfs (Ubuntu 24.04 Noble)"
        $rootfsUrl = "https://cloud-images.ubuntu.com/wsl/releases/noble/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz"
        $rootfsFile = "$basePath\staging\ubuntu.rootfs.tar.gz"
        $distroName = "Ubuntu 24.04 (Noble)"
    }
}

Log "WSL distribution will be installed as: $wslName"

Log "Downloading $distroName rootfs from $rootfsUrl..."
Log "This may take several minutes..."

try {
    # Use aria2 for faster download if available, otherwise use Invoke-WebRequest
    if (Test-Path "$basePath\aria2\aria2c.exe") {
        & "$basePath\aria2\aria2c.exe" -x 16 -s 16 -d "$basePath\staging" -o ([System.IO.Path]::GetFileName($rootfsFile)) $rootfsUrl
    } else {
        Invoke-WebRequest -Uri $rootfsUrl -OutFile $rootfsFile -UseBasicParsing
    }
    
    if (-Not (Test-Path $rootfsFile)) {
        throw "Failed to download $distroName rootfs"
    }
    
    Log "Download complete. Importing $distroName distribution..."
    
    # Import the rootfs directly as our custom distribution name
    if (-Not (Test-Path -Path $wslInstallationPath)) { mkdir $wslInstallationPath }
    
    # Import as WSL2 (required for USB passthrough)
    Log "Importing as WSL2 (required for USB device access)..."
    wsl.exe --import $wslName $wslInstallationPath $rootfsFile --version 2
    
    if ($LASTEXITCODE -ne 0) {
        throw "WSL2 import failed. Please ensure nested virtualization is enabled in your VM settings."
    }
    
    Log "$distroName imported successfully as $wslName (WSL2)"
    
    # Clean up downloaded rootfs
    Remove-Item $rootfsFile -Force
    
    # Mark that we directly imported (skip the export/import step later)
    $directImport = $true
} catch {
    Log "ERROR: Failed to download or import $distroName rootfs: $_"
    throw "$distroName installation failed"
}

# Verify direct import succeeded
if (-not $directImport) {
    # Only throw error if we didn't successfully do a direct import
    Log "ERROR: Could not find or install Linux distribution."
    $allDistrosDebug = wsl.exe -l -v
    Log "Available distributions (detailed):"
    Log "$allDistrosDebug"
    
    # Check if WSL is working at all
    Log "Testing WSL functionality..."
    $wslTest = wsl.exe --status 2>&1
    Log "WSL Status: $wslTest"
    
    Write-Host "`n*************************************************************" -ForegroundColor Red
    Write-Host "*                                                           *" -ForegroundColor Red
    Write-Host "*        LINUX DISTRIBUTION INSTALLATION FAILED             *" -ForegroundColor Red
    Write-Host "*                                                           *" -ForegroundColor Red
    Write-Host "*************************************************************`n" -ForegroundColor Red
    Write-Host "Linux distribution could not be installed via WSL." -ForegroundColor Yellow
    Write-Host "`nPossible solutions:" -ForegroundColor Yellow
    Write-Host "1. Ensure WSL is properly installed: wsl --status" -ForegroundColor Yellow
    Write-Host "2. Check Windows Updates for WSL updates" -ForegroundColor Yellow
    Write-Host "3. Reboot and try again" -ForegroundColor Yellow
    Write-Host "4. Try running the installer again and select a different distribution" -ForegroundColor Yellow
    Write-Host "`nIf in a VM, ensure nested virtualization is enabled or WSL1 is available." -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    throw "Linux distribution not found after installation."
} else {
    Log "Linux distribution directly imported as $wslName"
}

# Ensure WSL is initialized
Log "Initializing WSL and $wslName..."
wsl -d $wslName -e echo "WSL initialized"

# Wait for WSL to initialize
Start-Sleep -Seconds 10

# Create a user setup script with Unix line endings
$userSetupScriptPath = [System.IO.Path]::Combine($env:TEMP, "wsl_user_setup.sh")
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
Set-Content -Path $userSetupScriptPath -Value $createUserScript -NoNewline -Encoding Ascii

# Correct path conversion for WSL
$wslUserSetupScriptPath = $userSetupScriptPath -replace "\\", "/"
$wslUserSetupScriptPath = $wslUserSetupScriptPath -replace "C:", "/mnt/c"

# Update the system and create the user
Log "Updating system and creating user..."
wsl -d $wslName -u root bash -ic "apt update && apt upgrade -y && bash $wslUserSetupScriptPath"
Remove-Item $userSetupScriptPath

# Ensure WSL Distro is restarted when first used with user account
wsl --terminate $wslName

if ($installAllSoftware -eq $true) {
    Log "Installing additional software..."
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

    Log "Running custom installation script..."
    wsl -d $wslName -u $username bash -ic "bash $wslInstallScriptPath"
}

Log "Doppelganger_assistant WSL setup is complete."
