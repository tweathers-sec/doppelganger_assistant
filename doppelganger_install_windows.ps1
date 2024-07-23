# Check if the script is running as an administrator
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Output "This script must be run as an administrator. Please run PowerShell as an administrator and try again."
    exit
}

# Define paths
$basePath = "C:\doppelganger_assistant"
$setupScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_setup.ps1"
$launchScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_windows_launch.ps1"
$installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_doppelganger_install.sh"
$imageUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_assistant.ico"
$wslEnableScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_enable.ps1"
$setupScriptPath = "$basePath\wsl_setup.ps1"
$launchScriptPath = "$basePath\wsl_windows_launch.ps1"
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"
$imagePath = "$basePath\doppelganger_assistant.ico"
$wslEnableScriptPath = "$basePath\wsl_enable.ps1"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")

# Remove RebootPending.txt if it exists
if (Test-Path "$env:SystemRoot\System32\RebootPending.txt") {
    Remove-Item "$env:SystemRoot\System32\RebootPending.txt" -Force
}

# Create base directory if it doesn't exist
if (-Not (Test-Path -Path $basePath)) {
    mkdir $basePath
}

# Download the setup, launch, install scripts, and image from GitHub
Write-Output "Downloading setup script..."
Invoke-WebRequest -Uri $setupScriptUrl -OutFile $setupScriptPath

Write-Output "Downloading launch script..."
Invoke-WebRequest -Uri $launchScriptUrl -OutFile $launchScriptPath

Write-Output "Downloading install script..."
Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath

Write-Output "Downloading image..."
Invoke-WebRequest -Uri $imageUrl -OutFile $imagePath

Write-Output "Downloading WSL enable script..."
Invoke-WebRequest -Uri $wslEnableScriptUrl -OutFile $wslEnableScriptPath

# Run the WSL enable script
Write-Output "Running WSL enable script..."
& $wslEnableScriptPath

# Check if a reboot is required
if (Test-Path "$env:SystemRoot\System32\RebootPending.txt") {
    Write-Output "A reboot is required to complete the WSL installation. Please reboot your system and run this script again."
    exit
}

# Run the setup script
Write-Output "Running WSL setup script..."
& $setupScriptPath

# Create a shortcut on the desktop to run the launch script as an administrator
Write-Output "Creating desktop shortcut..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`""
$Shortcut.WorkingDirectory = $basePath
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = $imagePath
$Shortcut.Save()

# Set the shortcut to run as administrator
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.Description = "Launch Doppelganger Assistant as Administrator"
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`""
$Shortcut.WorkingDirectory = $basePath
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = $imagePath
$Shortcut.Save()

if ($Shortcut.Verbs) {
    $Shortcut.Verbs | ForEach-Object {
        if ($_.ToLower() -eq "runas") {
            $Shortcut.Verb = $_
        }
    }
    $Shortcut.Save()
} else {
    Write-Output "No verbs found for the shortcut."
}

Write-Output "Setup complete. Shortcut created on the desktop."