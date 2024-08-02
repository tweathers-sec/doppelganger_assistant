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

# Function to update Microsoft Store and its apps
function Update-MicrosoftStore {
    Log "Updating Microsoft Store and its apps..."
    try {
        # First update attempt
        Log "First update attempt..."
        Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
        $namespaceName = "root\cimv2\mdm\dmmap"
        $className = "MDM_EnterpriseModernAppManagement_AppManagement01"
        $wmiObj = Get-WmiObject -Namespace $namespaceName -Class $className
        $result = $wmiObj.UpdateScanMethod()
        Log "First update attempt completed. Result: $($result.ReturnValue)"

        # Wait for 30 seconds
        Log "Waiting for 30 seconds before second update attempt..."
        Start-Sleep -Seconds 30

        # Second update attempt
        Log "Second update attempt..."
        Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" | Invoke-CimMethod -MethodName UpdateScanMethod
        $wmiObj = Get-WmiObject -Namespace $namespaceName -Class $className
        $result = $wmiObj.UpdateScanMethod()
        Log "Second update attempt completed. Result: $($result.ReturnValue)"

        Log "Microsoft Store and apps update process completed."
    } catch {
        Log "Error updating Microsoft Store and apps: $_"
    }
}

# Function to install winget
function Install-Winget {
    Log "Installing winget..."
    $wingetUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $wingetPath = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    
    try {
        Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetPath
        Add-AppxPackage -Path $wingetPath
        Log "Winget installed successfully."
    } catch {
        Log "Error installing winget: $_"
        return $false
    } finally {
        Remove-Item $wingetPath -ErrorAction SilentlyContinue
    }
    return $true
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

# Function to check if NuGet provider is installed
function Test-NuGetProvider {
    $providers = Get-PackageProvider -ListAvailable
    return $providers | Where-Object { $_.Name -eq 'NuGet' }
}

# Check and install NuGet provider silently
if (-not (Test-NuGetProvider)) {
    Log "NuGet provider not found. Installing NuGet provider..."
    try {
        Install-PackageProvider -Name "NuGet" -Force -Scope CurrentUser -MinimumVersion 2.8.5.201 -ErrorAction Stop | Out-Null
        Log "NuGet provider installed successfully."
    }
    catch {
        Log "Failed to install NuGet provider. Error: $_"
    }
} else {
    Log "NuGet provider is already installed."
}

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

# Install winget if not present
if (-not (CommandExists "winget")) {
    if (Install-Winget) {
        Log "Winget installed successfully. Refreshing PATH..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Log "Failed to install winget. Exiting script."
        exit 1
    }
} else {
    Log "Winget is already installed."
}

# Check winget version
$wingetVersion = (winget --version).Trim()
Log "Winget version: $wingetVersion"

if ($wingetVersion -ne "v1.8.1911") {
    # Update Microsoft Store
    Update-MicrosoftStore

    # Wait for updates to process
    Log "Waiting for updates to process..."
    Start-Sleep -Seconds 60

    # Update winget and all packages
    Log "Updating winget and all packages..."
    winget upgrade --all
} else {
    Log "Winget version is v1.8.1911. Skipping Microsoft Store update and winget upgrade."
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