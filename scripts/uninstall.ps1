# Doppelganger Assistant Uninstaller
# 
# To run this script:
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/uninstall.ps1 | iex"
#
# Or if already installed:
#   powershell -ExecutionPolicy Bypass -File C:\doppelganger_assistant\uninstall.ps1

# Check if running from install directory - if so, copy to temp and re-execute
$scriptPath = $MyInvocation.MyCommand.Path
$basePath = "C:\doppelganger_assistant"

if ($scriptPath -and $scriptPath.StartsWith($basePath)) {
    Write-Host "Relocating script to temp directory to enable cleanup..." -ForegroundColor Yellow
    $tempScript = "$env:TEMP\doppelganger_uninstall_temp.ps1"
    Copy-Item -Path $scriptPath -Destination $tempScript -Force
    
    # Re-execute from temp location
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$tempScript`"" -Wait -NoNewWindow
    
    # Exit this instance
    exit
}

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
    }
    elseif ($distro -eq $ubuntuWslName) {
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
}
else {
    Log "Base directory $basePath not found."
}

# Remove the desktop shortcut
if (Test-Path -Path $shortcutPath) {
    Log "Removing desktop shortcut $shortcutPath..."
    Remove-Item -Path $shortcutPath -Force
    Log "Desktop shortcut $shortcutPath removed."
}
else {
    Log "Desktop shortcut $shortcutPath not found."
}

# Uninstall usbipd (will be reinstalled by installer)
if (CommandExists "winget") {
    Log "Uninstalling usbipd..."
    $uninstallOutput = Start-Process winget -ArgumentList "uninstall --exact usbipd" -Wait -PassThru -NoNewWindow
    if ($uninstallOutput.ExitCode -ne 0) {
        Log "Warning: Could not uninstall usbipd. Exit code: $($uninstallOutput.ExitCode)"
    }
    else {
        Log "usbipd uninstalled successfully."
    }
}
else {
    Log "winget not found. Cannot uninstall usbipd automatically."
}

Log "Uninstallation complete."

# Clean up temp script if this was relocated
if ($scriptPath -and $scriptPath.Contains("\Temp\")) {
    Log "Cleaning up temporary script..."
    Start-Sleep -Seconds 2
    Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
}