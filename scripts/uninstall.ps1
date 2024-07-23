# Log file path
$logFile = "C:\doppelganger_assistant\uninstall.log"

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
$wslName = "Ubuntu-doppelganger_assistant"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")

# Function to check if a command exists
function CommandExists {
    param (
        [string]$command
    )
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Uninstall WSL distribution
if (wsl.exe -l -q | Select-String -Pattern $wslName) {
    Log "Unregistering WSL distribution $wslName..."
    wsl.exe --unregister $wslName
    Log "WSL distribution $wslName unregistered."
} else {
    Log "WSL distribution $wslName not found."
}

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