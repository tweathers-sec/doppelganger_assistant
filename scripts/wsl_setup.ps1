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
            $xamlPath = "$env:TEMP\Microsoft.UI.Xaml.2.8.6.nupkg"
            $xamlExtractPath = "$env:TEMP\Microsoft.UI.Xaml"

            # Download XAML package
            Log "Downloading XAML package..."
            Download-File -Url $xamlUrl -Destination $xamlPath

            # Extract XAML package
            Log "Extracting XAML package..."
            Expand-Archive -Path $xamlPath -DestinationPath $xamlExtractPath -Force

            # Install XAML package
            Log "Installing XAML package..."
            Add-AppxPackage -Path "$xamlExtractPath\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"
        }

        # Download and install Winget
        Log "Downloading Winget..."
        Download-File -Url $wingetUrl -Destination $wingetPath
        
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

# Function to check if winget is installed
function Is-WingetInstalled {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
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
        $installOutput = Start-Process winget -ArgumentList "install --exact dorssel.usbipd-win" -Wait -PassThru -ErrorAction Stop
        if ($installOutput.ExitCode -ne 0) {
            throw "Winget installation failed with exit code: $($installOutput.ExitCode)"
        }
    } catch {
        Log "Error installing usbipd using winget. Trying alternative method..."
        $usbIpdUrl = "https://github.com/dorssel/usbipd-win/releases/latest/download/usbipd-win_x64.msi"
        $usbIpdMsiPath = "$env:TEMP\usbipd-win_x64.msi"
        Invoke-WebRequest -Uri $usbIpdUrl -OutFile $usbIpdMsiPath
        $msiExecOutput = Start-Process msiexec.exe -ArgumentList "/i `"$usbIpdMsiPath`" /qn" -Wait -PassThru
        if ($msiExecOutput.ExitCode -ne 0) {
            Log "Error installing usbipd using MSI. Exit code: $($msiExecOutput.ExitCode)"
            exit 1
        }
        Remove-Item $usbIpdMsiPath -Force
    }
    
    # Check if usbipd is available after installation
    if (-not (Refresh-UsbIpdCommand)) {
        $response = Read-Host "usbipd command is not available. Do you want to restart PowerShell to make it available? (y/n)"
        if ($response -eq 'y') {
            Log "Restarting PowerShell to make usbipd available..."
            Start-Process powershell -ArgumentList "-File `"$($MyInvocation.MyCommand.Path)`"" -Wait
            exit
        } else {
            Log "User chose not to restart PowerShell. usbipd may not be available for this session."
        }
    }
} else {
    Log "usbipd is already installed."
}

# Check if the WSL distribution already exists
$wslList = wsl.exe -l -q
if ($wslList -contains $wslName) {
    $response = Read-Host "$wslName already exists. Do you want to redownload and reinstall it? (y/n)"
    if ($response -ne 'y') {
        Log "Skipping reinstallation."
        exit
    }
}

# Create staging directory if it does not exist
if (-Not (Test-Path -Path $stagingPath)) { mkdir $stagingPath }

# Download Ubuntu root filesystem
Log "Downloading Ubuntu root filesystem..."
Download-File -Url $rootfsUrl -Destination $rootfsPath

# Import the WSL distribution
if (-Not (Test-Path -Path $wslInstallationPath)) {
    mkdir $wslInstallationPath
}
wsl.exe --import $wslName $wslInstallationPath $rootfsPath

# Clean up staging files
Remove-Item $rootfsPath

# Ensure WSL is initialized
Log "Initializing WSL and $wslName..."
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
Log "Updating system and creating user..."
wsl -d $wslName -u root bash -ic "apt update && apt upgrade -y && bash $wslUbuntuUserScriptPath"
Remove-Item $ubuntuUserScriptPath

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

Log "Doppelganger_assistant WSL and Ubuntu setup is complete."