# This script installs Windows Subsystem for Linux (WSL) and Ubuntu

# Function to check the installed WSL kernel version
function Get-WSLKernelVersion {
    $wslStatus = & wsl.exe --status 2>&1
    $wslStatusLines = [System.Text.Encoding]::Unicode.GetString([System.Text.Encoding]::UTF8.GetBytes($wslStatus)) -split "`r?`n"
    
    foreach ($line in $wslStatusLines) {
        $trimmedLine = $line.Trim()
        if ($trimmedLine -match "Kernel version:\s*([\d\.]+)") {
            return $matches[1]
        }
    }
    
    return $null
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

# Check the installed WSL kernel version
$currentKernelVersion = Get-WSLKernelVersion
$latestKernelVersion = "5.10.16"  # Replace with the latest known version

Write-Output "Current WSL Kernel Version: $currentKernelVersion"
Write-Output "Latest WSL Kernel Version: $latestKernelVersion"

if ($currentKernelVersion -ne $latestKernelVersion) {
    Write-Output "Installing the latest WSL kernel..."
    Invoke-WebRequest -Uri https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi -OutFile wsl_update_x64.msi
    Start-Process -FilePath msiexec.exe -ArgumentList "/i wsl_update_x64.msi /quiet" -Wait
    $rebootRequired = $true
} else {
    Write-Output "The latest WSL kernel is already installed."
}

# Check if a reboot is required
if ($rebootRequired ) {
    Write-Output "A reboot is required to complete the WSL installation. Please reboot your system and run this script again."
    New-Item -Path "$env:SystemRoot\System32\RebootPending.txt" -ItemType File -Force
    exit
}

Write-Output "Setting WSL 2 as the default version..."
wsl --set-default-version 2

Write-Output "Updating WSL..."
wsl --update

Write-Output "WSL installation and setup complete."