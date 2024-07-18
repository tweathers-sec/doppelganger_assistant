# This script installs Windows Subsystem for Linux (WSL) and Ubuntu

# Enable the necessary features
Write-Output "Enabling Windows Subsystem for Linux..."
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

Write-Output "Enabling Virtual Machine Platform..."
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Check if WSL 2 is available
$wslVersion = Get-WindowsOptionalFeature -Online | Where-Object { $_.FeatureName -eq "VirtualMachinePlatform" }
if ($wslVersion.State -ne "Enabled") {
    Write-Output "WSL 2 is not available. Please ensure your Windows is updated."
    exit
}

# Set WSL 2 as the default version
Write-Output "Setting WSL 2 as the default version..."
wsl --set-default-version 2

# Install the latest WSL kernel
Write-Output "Installing the latest WSL kernel..."
Invoke-WebRequest -Uri https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -OutFile wsl_update_x64.msi
Start-Process -FilePath msiexec.exe -ArgumentList "/i wsl_update_x64.msi /quiet" -Wait
