# Define paths
$basePath = "C:\doppelganger_assistant"
$setupScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_setup.ps1"
$launchScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/wsl_windows_lunch.ps1"
$installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/install.sh"
$setupScriptPath = "$basePath\wsl_setup.ps1"
$launchScriptPath = "$basePath\wsl_windows_lunch.ps1"
$installScriptPath = "$basePath\install.sh"
$shortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "Launch Doppelganger Assistant.lnk")

# Create base directory if it doesn't exist
if (-Not (Test-Path -Path $basePath)) {
    mkdir $basePath
}

# Download the setup, launch, and install scripts from GitHub
Write-Output "Downloading setup script..."
Invoke-WebRequest -Uri $setupScriptUrl -OutFile $setupScriptPath

Write-Output "Downloading launch script..."
Invoke-WebRequest -Uri $launchScriptUrl -OutFile $launchScriptPath

Write-Output "Downloading install script..."
Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath

# Run the setup script
Write-Output "Running WSL setup script..."
& $setupScriptPath

# Create a shortcut on the desktop to run the launch script
Write-Output "Creating desktop shortcut..."
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($shortcutPath)
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launchScriptPath`""
$Shortcut.WorkingDirectory = $basePath
$Shortcut.WindowStyle = 1
$Shortcut.IconLocation = "powershell.exe,0"
$Shortcut.Save()

Write-Output "Setup complete. Shortcut created on the desktop."