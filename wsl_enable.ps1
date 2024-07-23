# This script installs Windows Subsystem for Linux (WSL) and Ubuntu

# Function to check if a reboot is required
function Get-PendingReboot {
    $rebootRequired = $false

    # Check the registry for pending file rename operations
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $regValue = "PendingFileRenameOperations"
    if (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction SilentlyContinue) {
        $rebootRequired = $true
    }

    # Check the registry for pending computer rename
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName"
    $regValue = "ComputerName"
    if (Get-ItemProperty -Path $regPath -Name $regValue -ErrorAction SilentlyContinue) {
        $rebootRequired = $true
    }

    # Check the registry for pending Windows Update
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (Test-Path $regPath) {
        $rebootRequired = $true
    }

    return $rebootRequired
}

# Enable the necessary features
$rebootRequired = $false

Write-Output "Enabling Windows Subsystem for Linux..."
$wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
if ($wslFeature.State -ne "Enabled") {
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
    $rebootRequired = $true
}

Write-Output "Enabling Virtual Machine Platform..."
$vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
if ($vmFeature.State -ne "Enabled") {
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    $rebootRequired = $true
}

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

# Check if a reboot is required
if ($rebootRequired -or (Get-PendingReboot)) {
    Write-Output "A reboot is required to complete the WSL installation. Please reboot your system and run this script again."
    New-Item -Path "$env:SystemRoot\System32\RebootPending.txt" -ItemType File -Force
    exit
}

Write-Output "Setting WSL 2 as the default version..."
wsl --update

Write-Output "WSL installation and setup complete."