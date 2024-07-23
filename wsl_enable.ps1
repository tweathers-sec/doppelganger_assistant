# This script installs Windows Subsystem for Linux (WSL) and Ubuntu

# Log file path
$logFile = "C:\doppelganger_assistant\wsl_enable.log"

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

# Enable the necessary features
$rebootRequired = $false

Log "Enabling Windows Subsystem for Linux..."
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
if ($wslFeature.State -ne "Enabled") {
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    $rebootRequired = $true
}

Log "Enabling Virtual Machine Platform..."
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
if ($vmFeature.State -ne "Enabled") {
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $rebootRequired = $true
}

# Check if WSL 2 is available
$wslVersion = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "VirtualMachinePlatform" }
if ($wslVersion.State -ne "Enabled") {
    Log "WSL 2 is not available. Please ensure your Windows is updated."
    exit
}

# Check if a reboot is required
if ($rebootRequired) {
    Log "A reboot is required to complete the WSL installation. Please reboot your system and run this script again."
    New-Item -Path "$env:SystemRoot\System32\RebootPending.txt" -ItemType File -Force
    exit
}

Log "Setting WSL 2 as the default version..."
wsl --set-default-version 2

Log "Updating WSL..."
wsl --update

Log "WSL installation and setup complete."