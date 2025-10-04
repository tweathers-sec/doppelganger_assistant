# Doppelganger Assistant Uninstaller
# 
# To run this script:
#   powershell -ExecutionPolicy Bypass -File C:\doppelganger_assistant\uninstall.ps1
#
# Or download and run directly from GitHub:
#   powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/uninstall.ps1' -OutFile 'C:\doppelganger_uninstall.ps1'; & 'C:\doppelganger_uninstall.ps1'"

# Log file path
$logFile = "C:\doppelganger_uninstall.log"

# Function to log output to both file and screen
function Log {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('u')
    $logMessage = "$timestamp - $message"
    Write-Output $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

# Define paths
$basePath = "C:\doppelganger_assistant"
$kaliWslName = "Kali-doppelganger_assistant"
$ubuntuWslName = "Ubuntu-doppelganger_assistant"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")

# Function to check if a command exists
function CommandExists {
    param (
        [string]$command
    )
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Stop WSL
Log "Stopping WSL..."
wsl --shutdown
Log "WSL stopped."

# Uninstall all Doppelganger WSL distributions
$wslDistributions = wsl.exe -l -q | ForEach-Object { $_.Trim() -replace "`0", "" }
$removed = $false

foreach ($distro in $wslDistributions) {
    if ($distro -eq $kaliWslName) {
        Log "Unregistering WSL distribution $kaliWslName..."
        wsl.exe --unregister $kaliWslName
        Log "WSL distribution $kaliWslName unregistered."
        $removed = $true
    } elseif ($distro -eq $ubuntuWslName) {
        Log "Unregistering WSL distribution $ubuntuWslName..."
        wsl.exe --unregister $ubuntuWslName
        Log "WSL distribution $ubuntuWslName unregistered."
        $removed = $true
    }
}

if (-not $removed) {
    Log "No Doppelganger WSL distributions found. Available distributions:"
    $wslDistributions | ForEach-Object { Log "  - $_" }
}

# Ensure no processes are using the directory
Log "Ensuring no processes are using the directory..."
Stop-Process -Name "wsl" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "usbipd" -Force -ErrorAction SilentlyContinue
Log "Processes stopped."

# Remove the base directory
if (Test-Path -Path $basePath) {
    Log "Removing base directory $basePath..."
    Remove-Item -Recurse -Force $basePath
    Log "Base directory $basePath removed."
} else {
    Log "Base directory $basePath not found."
}

# Remove the desktop shortcut
if (Test-Path -Path $shortcutPath) {
    Log "Removing desktop shortcut $shortcutPath..."
    Remove-Item -Path $shortcutPath -Force
    Log "Desktop shortcut $shortcutPath removed."
} else {
    Log "Desktop shortcut $shortcutPath not found."
}

# Uninstall usbipd
if (CommandExists "winget") {
    Log "Uninstalling usbipd..."
    $uninstallOutput = Start-Process winget -ArgumentList "uninstall --exact dorssel.usbipd-win" -Wait -PassThru
    if ($uninstallOutput.ExitCode -ne 0) {
        Log "Error uninstalling usbipd. Exit code: $($uninstallOutput.ExitCode)"
    } else {
        Log "usbipd uninstalled."
    }
} else {
    Log "winget not found. Please uninstall usbipd manually."
}

Log "Uninstallation complete."