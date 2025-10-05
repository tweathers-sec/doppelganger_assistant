# Check if the script is running as an administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n*************************************************************" -ForegroundColor Red
    Write-Host "*                                                           *" -ForegroundColor Red
    Write-Host "*       THIS SCRIPT MUST BE RUN AS AN ADMINISTRATOR         *" -ForegroundColor Red
    Write-Host "*                                                           *" -ForegroundColor Red
    Write-Host "*************************************************************`n" -ForegroundColor Red
    Write-Host "Please follow these steps:" -ForegroundColor Yellow
    Write-Host "1. Right-click on PowerShell and select 'Run as administrator'" -ForegroundColor Yellow
    Write-Host "2. Navigate to the script's directory" -ForegroundColor Yellow
    Write-Host "3. Run the script again" -ForegroundColor Yellow
    Write-Host "`nPress any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# Define paths
$basePath = "C:\doppelganger_assistant"
$setupScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_setup.ps1"
$launchScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_windows_launch.ps1"
$pm3TerminalScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_pm3_terminal.ps1"
$installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_doppelganger_install.sh"
$imageUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.ico"
$pm3IconUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_pm3.ico"
$wslEnableScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_enable.ps1"
$usbReconnectScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/usb_reconnect.ps1"
$proxmarkFlashScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/proxmark_flash.ps1"
$uninstallScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/uninstall.ps1"
$setupScriptPath = "$basePath\wsl_setup.ps1"
$launchScriptPath = "$basePath\wsl_windows_launch.ps1"
$pm3TerminalScriptPath = "$basePath\wsl_pm3_terminal.ps1"
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"
$imagePath = "$basePath\doppelganger_assistant.ico"
$pm3IconPath = "$basePath\doppelganger_pm3.ico"
$wslEnableScriptPath = "$basePath\wsl_enable.ps1"
$usbReconnectScriptPath = "$basePath\usb_reconnect.ps1"
$proxmarkFlashScriptPath = "$basePath\proxmark_flash.ps1"
$uninstallScriptPath = "$basePath\uninstall.ps1"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")
$pm3ShortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Proxmark3 Terminal.lnk")

# ASCII Art function
function Write-DoppelgangerAscii {
    $color = 'Red'
    Write-Host @"
                                                                      
    ____                         _                                 
   |  _ \  ___  _ __  _ __   ___| | __ _  __ _ _ __   __ _  ___ _ __  
   | | | |/ _ \| '_ \| '_ \ / _ \ |/ _` |/ _` | '_ \ / _` |/ _ \ '__| 
   | |_| | (_) | |_) | |_) |  __/ | (_| | (_| | | | | (_| |  __/ |    
   |____/ \___/| .__/| .__/ \___|_|\__, |\__,_|_| |_|\__, |\___|_|    
               |_|   |_|           |___/             |___/            
                                                                      
"@ -ForegroundColor $color
}

# Display ASCII art
Write-DoppelgangerAscii

Write-Host "`n*************************************************************" -ForegroundColor Green
Write-Host "*                                                           *" -ForegroundColor Green
Write-Host "*           RUNNING WITH ADMINISTRATOR PRIVILEGES           *" -ForegroundColor Green
Write-Host "*                                                           *" -ForegroundColor Green
Write-Host "*************************************************************`n" -ForegroundColor Green

# Log file path (outside install directory to persist through updates)
$logFile = "C:\doppelganger_install_windows.log"

# Function to log output to both file and screen
function Log {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('u')
    $logMessage = "$timestamp - $message"
    Write-Output $message
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

# Check for nested virtualization support
Log "Checking for nested virtualization support..."
$nestedVirtSupported = $false

try {
    # Check if Hyper-V is available and nested virtualization is enabled
    $hypervFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
    
    # Check for signs of running in a VM
    $computerSystem = Get-WmiObject -Class Win32_ComputerSystem
    $isVM = $computerSystem.Model -match "Virtual" -or $computerSystem.Manufacturer -match "VMware|Microsoft Corporation|Xen|QEMU|VirtualBox|Parallels"
    
    if ($isVM) {
        Write-Host "`n*************************************************************" -ForegroundColor Red
        Write-Host "*                                                           *" -ForegroundColor Red
        Write-Host "*                 NESTED VM DETECTED                        *" -ForegroundColor Red
        Write-Host "*                                                           *" -ForegroundColor Red
        Write-Host "*   Doppelganger Assistant DOES NOT support installation    *" -ForegroundColor Red
        Write-Host "*   in nested virtual machine environments (VM within VM).  *" -ForegroundColor Red
        Write-Host "*                                                           *" -ForegroundColor Red
        Write-Host "*   Please install on:                                      *" -ForegroundColor Red
        Write-Host "*   - Physical Windows hardware                             *" -ForegroundColor Red
        Write-Host "*                                                           *" -ForegroundColor Red
        Write-Host "*   Installation will now exit.                             *" -ForegroundColor Red
        Write-Host "*                                                           *" -ForegroundColor Red
        Write-Host "*************************************************************`n" -ForegroundColor Red
        
        Log "ERROR: Nested VM detected. Installation blocked - nested VMs are not supported."
        Write-Host "`nPress any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
    else {
        Log "Running on physical hardware or primary VM."
    }
}
catch {
    Log "Could not determine virtualization status. Proceeding with installation..."
}

# Function to create a shortcut that runs as an administrator
function New-Shortcut {
    param (
        [string]$TargetPath,
        [string]$ShortcutPath,
        [string]$Arguments,
        [string]$Description,
        [string]$WorkingDirectory,
        [string]$IconLocation
    )
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments
    $Shortcut.Description = $Description
    $Shortcut.WorkingDirectory = $WorkingDirectory
    $Shortcut.IconLocation = $IconLocation
    $Shortcut.Save()

    # Set the shortcut to run as administrator
    $bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes($ShortcutPath, $bytes)
}

# Remove RebootPending.txt if it exists
if (Test-Path "$env:SystemRoot\System32\RebootPending.txt") {
    Remove-Item "$env:SystemRoot\System32\RebootPending.txt" -Force
}

# Define headers to prevent caching (needed for uninstaller download)
$headers = @{
    'Cache-Control' = 'no-cache'
    'Pragma'        = 'no-cache'
}

# Check for existing installation
if (Test-Path -Path $basePath) {
    Write-Host "`n*************************************************************" -ForegroundColor Yellow
    Write-Host "*                                                           *" -ForegroundColor Yellow
    Write-Host "*         EXISTING INSTALLATION DETECTED                    *" -ForegroundColor Yellow
    Write-Host "*                                                           *" -ForegroundColor Yellow
    Write-Host "*************************************************************`n" -ForegroundColor Yellow
    
    $updateChoice = Read-Host "An existing installation was found. Do you want to remove and re-install (update)? [Recommended] (y/n)"
    
    if ($updateChoice -eq "y" -or $updateChoice -eq "Y" -or $updateChoice -eq "") {
        Log "User chose to update. Running uninstaller..."
        
        # Download and run uninstaller
        try {
            Log "Downloading uninstaller script..."
            $uninstallScript = Invoke-RestMethod -Uri $uninstallScriptUrl -Headers $headers
            
            Log "Executing uninstaller..."
            Invoke-Expression $uninstallScript
            Start-Sleep -Seconds 2
        }
        catch {
            Log "Failed to download/run uninstaller. Performing manual cleanup..."
            # Fallback to manual cleanup
            wsl --shutdown
            Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -Path $shortcutPath) {
                Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
            }
        }
        
        Log "Previous installation removed. Proceeding with fresh installation..."
    }
    else {
        Log "User chose not to update. Exiting installer."
        Write-Host "`nInstallation cancelled. Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        exit
    }
}

# Create base directory
mkdir $basePath | Out-Null

# ============================
# Pre-flight questions (gather all input up-front)
# ============================

Write-Host "`nWhich WSL distro would you like to install?" -ForegroundColor Yellow
Write-Host "1) Kali Linux 2025.3 [default]" -ForegroundColor Green
Write-Host "2) Ubuntu 24.04 LTS (Noble)" -ForegroundColor Cyan
$installDistro = Read-Host "`nEnter your choice (1-2) [default: 1]"
if ($installDistro -eq "2") {
    $selectedDistro = "Ubuntu"
}
else {
    $selectedDistro = "Kali"
}

Write-Host "`nWhich Proxmark3 device do you have?" -ForegroundColor Yellow
Write-Host "1) RDV4 with Blueshark [default]" -ForegroundColor Green
Write-Host "2) RDV4 without Blueshark" -ForegroundColor Cyan
Write-Host "3) Proxmark3 Easy (512KB)" -ForegroundColor Magenta
$pm3Device = Read-Host "`nEnter your choice (1-3) [default: 1]"
if ($pm3Device -eq "2") {
    $pm3DeviceType = "rdv4-no-blueshark"
}
elseif ($pm3Device -eq "3") {
    $pm3DeviceType = "easy-512kb"
}
else {
    $pm3DeviceType = "rdv4-blueshark"
}

# Download the setup, launch, install scripts, and images from GitHub
Log "Downloading setup script..."
Invoke-WebRequest -Uri $setupScriptUrl -OutFile $setupScriptPath -Headers $headers

Log "Downloading GUI launch script..."
Invoke-WebRequest -Uri $launchScriptUrl -OutFile $launchScriptPath -Headers $headers

Log "Downloading PM3 terminal launch script..."
Invoke-WebRequest -Uri $pm3TerminalScriptUrl -OutFile $pm3TerminalScriptPath -Headers $headers

Log "Downloading install script..."
Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath -Headers $headers

Log "Downloading Doppelganger icon..."
Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath -Headers $headers

Log "Downloading PM3 icon..."
Invoke-WebRequest -Uri $pm3IconUrl -OutFile $pm3IconPath -Headers $headers

Log "Downloading WSL enable script..."
Invoke-WebRequest -Uri $wslEnableScriptUrl -OutFile $wslEnableScriptPath -Headers $headers

Log "Downloading USB reconnect script..."
Invoke-WebRequest -Uri $usbReconnectScriptUrl -OutFile $usbReconnectScriptPath -Headers $headers

Log "Downloading Proxmark3 flash script..."
Invoke-WebRequest -Uri $proxmarkFlashScriptUrl -OutFile $proxmarkFlashScriptPath -Headers $headers

Log "Downloading uninstall script..."
Invoke-WebRequest -Uri $uninstallScriptUrl -OutFile $uninstallScriptPath -Headers $headers

# Run the WSL enable script
Log "Running WSL enable script..."
powershell -ExecutionPolicy Bypass -File $wslEnableScriptPath

# Check if a reboot is required
if (Test-Path "$env:SystemRoot\System32\RebootPending.txt") {
    Write-Host "`n*************************************************************" -ForegroundColor Yellow
    Write-Host "*                                                           *" -ForegroundColor Yellow
    Write-Host "*   A REBOOT IS REQUIRED TO COMPLETE THE WSL INSTALLATION.  *" -ForegroundColor Yellow
    Write-Host "*    PLEASE REBOOT YOUR SYSTEM AND RUN THIS SCRIPT AGAIN.   *" -ForegroundColor Yellow
    Write-Host "*                                                           *" -ForegroundColor Yellow
    Write-Host "*************************************************************`n" -ForegroundColor Yellow
    Write-Host "Press any key to exit..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}
# Run the setup script with distro choice
Log "Running WSL setup script..."
powershell -ExecutionPolicy Bypass -File $setupScriptPath -DistroChoice $selectedDistro

# Run the install script with device type
Log "Running Doppelganger Assistant installation..."
if ($selectedDistro -eq "Kali") {
    wsl -d "Kali-doppelganger_assistant" -u doppelganger bash -c "bash /mnt/c/doppelganger_assistant/wsl_doppelganger_install.sh --device $pm3DeviceType"
}
else {
    wsl -d "Ubuntu-doppelganger_assistant" -u doppelganger bash -c "bash /mnt/c/doppelganger_assistant/wsl_doppelganger_install.sh --device $pm3DeviceType"
}

# Create desktop shortcuts
Log "Creating Doppelganger Assistant desktop shortcut..."
New-Shortcut -TargetPath "powershell.exe" `
    -ShortcutPath $shortcutPath `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`"" `
    -Description "Launch Doppelganger Assistant GUI as Administrator" `
    -WorkingDirectory $basePath `
    -IconLocation $imagePath

Log "Doppelganger Assistant shortcut created."

Log "Creating Proxmark3 Terminal desktop shortcut..."
New-Shortcut -TargetPath "powershell.exe" `
    -ShortcutPath $pm3ShortcutPath `
    -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$pm3TerminalScriptPath`"" `
    -Description "Launch Proxmark3 Terminal (pm3) as Administrator" `
    -WorkingDirectory $basePath `
    -IconLocation $pm3IconPath
Log "Proxmark3 Terminal shortcut created."

Log "Setup complete. Shortcuts created on the desktop."

# Prompt user to flash Proxmark3 firmware
Write-Host "`nDo you want to flash your Proxmark3 device firmware now?" -ForegroundColor Yellow
Write-Host "WARNING: Only flash on physical hardware, not in VMs!" -ForegroundColor Red
$flashChoice = Read-Host "Flash Proxmark3 firmware? (y/N)"
if ($flashChoice -eq "y" -or $flashChoice -eq "Y") {
    Log "User chose to flash Proxmark3 firmware. Running Proxmark3 flash script..."
    powershell -ExecutionPolicy Bypass -File $proxmarkFlashScriptPath
}
else {
    Log "User chose not to flash Proxmark3 firmware."
}

# Delete this script (only if running from a file)
$scriptPath = $MyInvocation.MyCommand.Path
if ($scriptPath) {
    Log "Deleting installation script..."
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
    Log "Installation script deleted."
}
else {
    Log "Script was run directly (not from file). Nothing to delete."
}

Log "Installation complete!"
