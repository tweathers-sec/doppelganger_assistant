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
$installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_doppelganger_install.sh"
$imageUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.ico"
$wslEnableScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_enable.ps1"
$usbReconnectScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/usb_reconnect.ps1"
$proxmarkFlashScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/proxmark_flash.ps1"
$setupScriptPath = "$basePath\wsl_setup.ps1"
$launchScriptPath = "$basePath\wsl_windows_launch.ps1"
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"
$imagePath = "$basePath\doppelganger_assistant.ico"
$wslEnableScriptPath = "$basePath\wsl_enable.ps1"
$usbReconnectScriptPath = "$basePath\usb_reconnect.ps1"
$proxmarkFlashScriptPath = "$basePath\proxmark_flash.ps1"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")

# ASCII Art function
function Write-DoppelgangerAscii {
    $color = 'Red'
    Write-Host @"
                                                                      
    ____                            _                                 
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

# Log file path
$logFile = "C:\doppelganger_assistant\install_windows.log"

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

# Create base directory if it doesn't exist
if (-Not (Test-Path -Path $basePath)) {
    mkdir $basePath
}

# Download the setup, launch, install scripts, and image from GitHub
Log "Downloading setup script..."
Invoke-WebRequest -Uri $setupScriptUrl -OutFile $setupScriptPath

Log "Downloading launch script..."
Invoke-WebRequest -Uri $launchScriptUrl -OutFile $launchScriptPath

Log "Downloading install script..."
Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath

Log "Downloading image..."
Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath

Log "Downloading WSL enable script..."
Invoke-WebRequest -Uri $wslEnableScriptUrl -OutFile $wslEnableScriptPath

Log "Downloading USB reconnect script..."
Invoke-WebRequest -Uri $usbReconnectScriptUrl -OutFile $usbReconnectScriptPath

Log "Downloading Proxmark3 flash script..."
Invoke-WebRequest -Uri $proxmarkFlashScriptUrl -OutFile $proxmarkFlashScriptPath

# Run the WSL enable script
Log "Running WSL enable script..."
& $wslEnableScriptPath

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
# Run the setup script
Log "Running WSL setup script..."
& $setupScriptPath

# Create a shortcut on the desktop to run the launch script as an administrator
Log "Creating desktop shortcut..."
New-Shortcut -TargetPath "powershell.exe" `
             -ShortcutPath $shortcutPath `
             -Arguments "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`"" `
             -Description "Launch Doppelganger Assistant as Administrator" `
             -WorkingDirectory $basePath `
             -IconLocation $imagePath

Log "Shortcut created on the desktop with administrator privileges."

Log "Setup complete. Shortcut created on the desktop."

# Prompt user to flash Proxmark3
$flashChoice = Read-Host "Do you want to flash your Proxmark3 device now? (y/n)"
if ($flashChoice -eq "y" -or $flashChoice -eq "Y") {
    Log "User chose to flash Proxmark3. Running Proxmark3 flash script..."
    & $proxmarkFlashScriptPath
} else {
    Log "User chose not to flash Proxmark3."
}

# Delete this script
$scriptPath = $MyInvocation.MyCommand.Path
Log "Deleting installation script..."
Remove-Item -Path $scriptPath -Force

Log "Installation script deleted. Process complete."
