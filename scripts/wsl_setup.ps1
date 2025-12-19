param(
    [string]$DistroChoice = ""
)

$basePath = "C:\doppelganger_assistant"
$wslInstallationPath = "$basePath\wsl"
$username = "doppelganger"
$installAllSoftware = $true

$kaliWslName = "Kali-doppelganger_assistant"
$ubuntuWslName = "Ubuntu-doppelganger_assistant"
$wslName = $null
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"
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

        if (-Not (Test-Path -Path $aria2Path)) { mkdir $aria2Path }

        Invoke-WebRequest -Uri $aria2Url -OutFile $aria2ZipPath
        Expand-Archive -Path $aria2ZipPath -DestinationPath $aria2ExtractPath

        $aria2ExePath = "$aria2ExtractPath\aria2-1.36.0-win-64bit-build1\aria2c.exe"
        Move-Item -Path $aria2ExePath -Destination "$aria2Path\aria2c.exe" -Force

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

            Log "Downloading XAML package..."
            (New-Object System.Net.WebClient).DownloadFile($xamlUrl, $xamlPath)

            Log "Extracting XAML package..."
            Expand-Archive -Path $xamlPath -DestinationPath $xamlExtractPath -Force

            Log "Installing XAML package..."
            Add-AppxPackage -Path "$xamlExtractPath\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx"
        }

        Log "Downloading Winget..."
        (New-Object System.Net.WebClient).DownloadFile($wingetUrl, $wingetPath)
        
        Log "Installing Winget..."
        Add-AppxPackage -Path $wingetPath
        Log "Winget installed successfully."
        return $true
    }
    catch {
        Log "Error installing winget: $_"
        return $false
    }
    finally {
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
    }
    catch {
        return $false
    }
}

# Function to refresh PATH and check for usbipd
function Refresh-UsbIpdCommand {
    Log "Refreshing PATH and checking for usbipd command..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command usbipd -ErrorAction SilentlyContinue) {
        Log "usbipd command is now available."
        return $true
    }
    
    Log "usbipd command is still not available after refreshing PATH."
    return $false
}

Install-Aria2

Log "Checking if NuGet provider is installed and PSGallery is trusted..."

Log "Installing NuGet provider..."
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -Scope CurrentUser

Import-PackageProvider -Name NuGet -Force | Out-Null

$psGallery = Get-PSRepository -Name "PSGallery" -ErrorAction SilentlyContinue
if ($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
    Log "Setting PSGallery to trusted..."
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue | Out-Null
}
elseif (-not $psGallery) {
    Log "PSGallery not found. Registering and setting to trusted..."
    Register-PSRepository -Default -ErrorAction SilentlyContinue | Out-Null
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction SilentlyContinue | Out-Null
}
else {
    Log "PSGallery is already set to trusted."
}

# Check if winget is installed
if (-not (Is-WingetInstalled)) {
    Log "Winget is not installed. Installing Winget..."
    if (Install-Winget) {
        Log "Winget installed successfully. Refreshing PATH..."
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        $env:PSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "Machine")
    }
    else {
        Log "Failed to install winget. Continuing without winget."
    }
}

# Check winget version and update if necessary
if (Is-WingetInstalled) {
    $minWingetVersion = "1.4.0"
    $currentWingetVersion = (winget --version).Trim()
    Log "Current Winget version: $currentWingetVersion"

    $currentVersionWithoutV = $currentWingetVersion -replace '^v', ''
    $minVersionWithoutV = $minWingetVersion -replace '^v', ''

    if ([version]$currentVersionWithoutV -lt [version]$minVersionWithoutV) {
        Log "Winget version is older than $minWingetVersion. Updating Winget..."
        if (Install-Winget) {
            Log "Winget updated successfully. Refreshing PATH..."
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            $newWingetVersion = (winget --version).Trim()
            Log "Updated Winget version: $newWingetVersion"
        }
        else {
            Log "Failed to update winget. Continuing with current version."
        }
    }
    else {
        Log "Winget version is up to date."
    }
}
else {
    Log "Winget is not available. Skipping version check and update."
}

if (-not (CommandExists "usbipd")) {
    Log "Installing usbipd..."
    try {
        $installOutput = Start-Process winget -ArgumentList "install --exact --silent --accept-source-agreements --accept-package-agreements usbipd" -Wait -PassThru -ErrorAction Stop
        if ($installOutput.ExitCode -ne 0) {
            throw "Winget installation failed with exit code: $($installOutput.ExitCode)"
        }
    }
    catch {
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
        }
        catch {
            Log "WARNING: Failed to install usbipd: $_"
            Log "You can manually install usbipd later from: https://github.com/dorssel/usbipd-win/releases"
            Log "Continuing with installation..."
        }
    }
    
    if (-not (Refresh-UsbIpdCommand)) {
        Log "NOTE: usbipd is not available in current session. It may require a restart or manual installation."
        Log "Continuing with WSL setup..."
    }
}
else {
    Log "usbipd is already installed."
}

Log "Proceeding with WSL installation..."

$wslList = wsl.exe -l -q | ForEach-Object { $_.Trim() -replace "`0", "" }
$existingKali = $false
$existingUbuntu = $false

foreach ($distro in $wslList) {
    if ($distro -eq $kaliWslName) {
        $existingKali = $true
    }
    elseif ($distro -eq $ubuntuWslName) {
        $existingUbuntu = $true
    }
}

if ($existingKali -or $existingUbuntu) {
    if ($existingKali) {
        $wslName = $kaliWslName
    }
    else {
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
        Log "Updating Doppelganger Assistant and Proxmark3 in existing WSL container..."
        
        Log "Downloading latest installation script..."
        $installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_doppelganger_install.sh"
        $installScriptPath = "$basePath\wsl_doppelganger_install.sh"
        if (-Not (Test-Path -Path $basePath)) { mkdir $basePath }
        Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath
        
        $username = wsl -d $wslName bash -c "whoami"
        $username = $username.Trim()
        Log "Detected WSL user: $username"
        
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
    }
    elseif ($response -eq "2") {
        Log "Unregistering existing $wslName for full reinstall..."
        wsl.exe --unregister $wslName
    }
    else {
        Log "Exiting without changes."
        exit
    }
}

Log "No existing Doppelganger Assistant installation found."
Log "Proceeding with fresh installation..."

if ($DistroChoice -ne "") {
    Log "Using provided distro choice: $DistroChoice"
    if ($DistroChoice -eq "Kali") {
        $distroChoice = "1"
    }
    elseif ($DistroChoice -eq "Ubuntu") {
        $distroChoice = "2"
    }
    else {
        Log "Invalid distro choice provided. Defaulting to Kali."
        $distroChoice = "1"
    }
}
else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  Select Linux Distribution for WSL2" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) Kali Linux (latest) - Recommended" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "2) Ubuntu 24.04 LTS (Noble) - Alternative" -ForegroundColor Green
    Write-Host ""

    do {
        $distroChoice = Read-Host "Enter your choice (1 or 2)"
    } while ($distroChoice -ne "1" -and $distroChoice -ne "2")
}

if (-Not (Test-Path -Path "$basePath\staging")) { mkdir "$basePath\staging" }

$processorArch = $env:PROCESSOR_ARCHITECTURE
Log "Detected processor architecture: $processorArch"

if ($distroChoice -eq "1") {
    Log "Installing Kali Linux via direct rootfs import..."
    $wslName = $kaliWslName
    
    $kaliCurrentUrl = "https://kali.download/wsl-images/current"
    $kaliVersion = $null
    $rootfsUrl = $null
    
    function Get-KaliWslRootfs {
        param (
            [string]$Arch
        )
        
        try {
            Log "Querying $kaliCurrentUrl for available WSL images..."
            $html = Invoke-WebRequest -Uri "$kaliCurrentUrl/" -UseBasicParsing -ErrorAction Stop
            $content = $html.Content
            
            $pattern = "kali-linux-(\d{4}\.\d+[a-z]?)-wsl-rootfs-$Arch\.wsl"
            if ($content -match $pattern) {
                $version = $matches[1]
                $filename = $matches[0]
                $url = "$kaliCurrentUrl/$filename"
                
                try {
                    $headResponse = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -ErrorAction Stop
                    if ($headResponse.StatusCode -eq 200) {
                        Log "Found Kali Linux $version for $Arch in /current/"
                        return @{
                            Version = $version
                            Url     = $url
                        }
                    }
                }
                catch {
                    Log "Found filename $filename but file verification failed: $_"
                }
            }
            else {
                Log "No matching WSL rootfs file found for $Arch in directory listing"
            }
        }
        catch {
            Log "Failed to query $kaliCurrentUrl : $_"
        }
        
        return $null
    }
    
    if ($processorArch -eq "ARM64") {
        $result = Get-KaliWslRootfs -Arch "arm64"
        if ($result) {
            $rootfsUrl = $result.Url
            $kaliVersion = $result.Version
        }
        else {
            Log "ERROR: Could not find ARM64 WSL rootfs in $kaliCurrentUrl"
            Log "Please check https://kali.download/wsl-images/current/ manually"
            throw "Failed to locate Kali Linux ARM64 WSL rootfs"
        }
        
        $rootfsFile = "$basePath\staging\kali.rootfs.wsl"
        $distroName = "Kali Linux $kaliVersion"
    }
    else {
        $result = Get-KaliWslRootfs -Arch "amd64"
        if ($result) {
            $rootfsUrl = $result.Url
            $kaliVersion = $result.Version
        }
        else {
            Log "ERROR: Could not find AMD64 WSL rootfs in $kaliCurrentUrl"
            Log "Please check https://kali.download/wsl-images/current/ manually"
            throw "Failed to locate Kali Linux AMD64 WSL rootfs"
        }
        
        $rootfsFile = "$basePath\staging\kali.rootfs.wsl"
        $distroName = "Kali Linux $kaliVersion"
    }
}
else {
    Log "Installing Ubuntu 24.04 (Noble) via direct rootfs import..."
    $wslName = $ubuntuWslName
    
    $ubuntuBaseUrl = "https://cloud-images.ubuntu.com/wsl/releases/noble/current"
    $ubuntuVersion = $null
    $rootfsUrl = $null
    
    function Get-UbuntuWslRootfs {
        param (
            [string]$Arch
        )
        
        try {
            Log "Querying $ubuntuBaseUrl for available WSL images..."
            $html = Invoke-WebRequest -Uri "$ubuntuBaseUrl/" -UseBasicParsing -ErrorAction Stop
            $content = $html.Content
            
            $patterns = @(
                "ubuntu-noble-wsl-$Arch-([\d\.]+lts)\.rootfs\.tar\.gz",
                "ubuntu-noble-wsl-$Arch-wsl\.rootfs\.tar\.gz"
            )
            
            $filename = $null
            $url = $null
            $version = $null
            
            foreach ($pattern in $patterns) {
                if ($content -match $pattern) {
                    $filename = $matches[0]
                    $url = "$ubuntuBaseUrl/$filename"
                    
                    if ($matches.Count -gt 1 -and $matches[1]) {
                        $version = $matches[1]
                    }
                    else {
                        $version = "wsl"
                    }
                    
                    try {
                        $headResponse = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 5 -ErrorAction Stop
                        if ($headResponse.StatusCode -eq 200) {
                            Log "Found Ubuntu Noble WSL image for $Arch in /current/ (version: $version, file: $filename)"
                            return @{
                                Version = $version
                                Url     = $url
                            }
                        }
                    }
                    catch {
                        Log "Found filename $filename but file verification failed: $_"
                    }
                }
            }
            
            if (-not $filename) {
                Log "No matching WSL rootfs file found for $Arch in directory listing"
            }
        }
        catch {
            Log "Failed to query $ubuntuBaseUrl : $_"
        }
        
        return $null
    }
    
    if ($processorArch -eq "ARM64") {
        $result = Get-UbuntuWslRootfs -Arch "arm64"
        if ($result) {
            $rootfsUrl = $result.Url
            $ubuntuVersion = $result.Version
        }
        else {
            Log "ERROR: Could not find ARM64 WSL rootfs in $ubuntuBaseUrl"
            Log "Please check https://cloud-images.ubuntu.com/wsl/releases/noble/current/ manually"
            throw "Failed to locate Ubuntu Noble ARM64 WSL rootfs"
        }
        
        $rootfsFile = "$basePath\staging\ubuntu.rootfs.tar.gz"
        $distroName = "Ubuntu 24.04 (Noble)"
    }
    else {
        $result = Get-UbuntuWslRootfs -Arch "amd64"
        if ($result) {
            $rootfsUrl = $result.Url
            $ubuntuVersion = $result.Version
        }
        else {
            Log "ERROR: Could not find AMD64 WSL rootfs in $ubuntuBaseUrl"
            Log "Please check https://cloud-images.ubuntu.com/wsl/releases/noble/current/ manually"
            throw "Failed to locate Ubuntu Noble AMD64 WSL rootfs"
        }
        
        $rootfsFile = "$basePath\staging\ubuntu.rootfs.tar.gz"
        $distroName = "Ubuntu 24.04 (Noble)"
    }
}

Log "WSL distribution will be installed as: $wslName"

Log "Downloading $distroName rootfs from $rootfsUrl..."
Log "This may take several minutes..."

try {
    if (Test-Path "$basePath\aria2\aria2c.exe") {
        & "$basePath\aria2\aria2c.exe" -x 16 -s 16 -d "$basePath\staging" -o ([System.IO.Path]::GetFileName($rootfsFile)) $rootfsUrl
    }
    else {
        Invoke-WebRequest -Uri $rootfsUrl -OutFile $rootfsFile -UseBasicParsing
    }
    
    if (-Not (Test-Path $rootfsFile)) {
        throw "Failed to download $distroName rootfs"
    }
    
    Log "Download complete. Importing $distroName distribution..."
    
    if (-Not (Test-Path -Path $wslInstallationPath)) { mkdir $wslInstallationPath }
    
    Log "Importing as WSL2 (required for USB device access)..."
    wsl.exe --import $wslName $wslInstallationPath $rootfsFile --version 2
    
    if ($LASTEXITCODE -ne 0) {
        throw "WSL2 import failed. Please ensure nested virtualization is enabled in your VM settings."
    }
    
    Log "$distroName imported successfully as $wslName (WSL2)"
    
    Remove-Item $rootfsFile -Force
    $directImport = $true
}
catch {
    Log "ERROR: Failed to download or import $distroName rootfs: $_"
    throw "$distroName installation failed"
}

if (-not $directImport) {
    Log "ERROR: Could not find or install Linux distribution."
    $allDistrosDebug = wsl.exe -l -v
    Log "Available distributions (detailed):"
    Log "$allDistrosDebug"
    
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
}
else {
    Log "Linux distribution directly imported as $wslName"
}

Log "Initializing WSL and $wslName..."
wsl -d $wslName -e echo "WSL initialized"

Start-Sleep -Seconds 10

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

$wslUserSetupScriptPath = $userSetupScriptPath -replace "\\", "/"
$wslUserSetupScriptPath = $wslUserSetupScriptPath -replace "C:", "/mnt/c"

Log "Configuring package repositories..."
if ($distroChoice -eq "1") {
    Log "Setting Kali Linux to use official repositories..."
    wsl -d $wslName -u root bash -ic "echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware' > /etc/apt/sources.list"
}

Log "Updating system and creating user..."
wsl -d $wslName -u root bash -ic "apt update && apt upgrade -y && bash $wslUserSetupScriptPath"
Remove-Item $userSetupScriptPath

wsl --terminate $wslName

if ($installAllSoftware -eq $true) {
    Log "Installing additional software..."
    
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

    wsl -d $wslName -u root bash -ic "apt install -y build-essential curl file git usbutils"

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

    $wslInstallScriptPath = $installScriptPath -replace "\\", "/"
    $wslInstallScriptPath = $wslInstallScriptPath -replace "C:", "/mnt/c"

    Log "Running custom installation script..."
    wsl -d $wslName -u $username bash -ic "bash $wslInstallScriptPath --update"
}

Log "Doppelganger_assistant WSL setup is complete."
