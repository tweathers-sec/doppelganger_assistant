# Doppelganger Assistant WSL Update Script
# Updates the application, scripts, and Proxmark3 in an existing WSL installation

param(
    [string]$DistroName = ""
)

$basePath = "C:\doppelganger_assistant"
$logFile = "C:\doppelganger_assistant\wsl_update.log"
$kaliWslName = "Kali-doppelganger_assistant"
$ubuntuWslName = "Ubuntu-doppelganger_assistant"

function Log {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('u')
    $logMessage = "$timestamp - $message"
    Write-Output $message
    Add-Content -Path $logFile -Value $logMessage -ErrorAction SilentlyContinue
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Doppelganger Assistant Updater" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$wslList = wsl.exe -l -q | ForEach-Object { $_.Trim() -replace "`0", "" }
$foundDistro = $null

if ($DistroName -ne "") {
    if ($wslList -contains $DistroName) {
        $foundDistro = $DistroName
    }
    else {
        Write-Host "Error: Specified distro '$DistroName' not found." -ForegroundColor Red
        exit 1
    }
}
else {
    foreach ($distro in $wslList) {
        if ($distro -eq $kaliWslName -or $distro -eq $ubuntuWslName) {
            $foundDistro = $distro
            break
        }
    }
}

if (-not $foundDistro) {
    Write-Host "Error: No Doppelganger Assistant WSL installation found." -ForegroundColor Red
    Write-Host "Please run the installer first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Found installation: $foundDistro" -ForegroundColor Green
Log "Updating $foundDistro..."

$username = wsl -d $foundDistro bash -c "whoami"
$username = $username.Trim()
Log "WSL user: $username"

Write-Host "`nThis will update:" -ForegroundColor Yellow
Write-Host "  - Doppelganger Assistant application" -ForegroundColor Gray
Write-Host "  - Repository scripts and installers" -ForegroundColor Gray
Write-Host "  - Proxmark3 firmware and client" -ForegroundColor Gray
Write-Host ""

$confirm = Read-Host "Continue with update? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Log "Update cancelled by user"
    exit 0
}

if (-Not (Test-Path -Path $basePath)) {
    mkdir $basePath | Out-Null
}

Log "Downloading latest installation script..."
$installScriptUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/wsl_doppelganger_install.sh"
$installScriptPath = "$basePath\wsl_doppelganger_install.sh"
try {
    Invoke-WebRequest -Uri $installScriptUrl -OutFile $installScriptPath -ErrorAction Stop
    Log "Installation script downloaded"
}
catch {
    Log "ERROR: Failed to download installation script: $_"
    Write-Host "Error: Could not download update script from GitHub" -ForegroundColor Red
    exit 1
}

Log "Downloading latest Windows scripts..."
$scriptUrls = @(
    "wsl_setup.ps1",
    "wsl_windows_launch.ps1",
    "wsl_pm3_terminal.ps1",
    "wsl_enable.ps1",
    "usb_reconnect.ps1",
    "proxmark_flash.ps1",
    "uninstall.ps1",
    "wsl_update.ps1"
)

foreach ($script in $scriptUrls) {
    try {
        $url = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/$script"
        $destination = "$basePath\$script"
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
        Log "Downloaded $script"
    }
    catch {
        Log "Warning: Could not download $script : $_"
    }
}

Log "Downloading latest installers..."
$installerUrls = @(
    "doppelganger_install_windows.ps1",
    "doppelganger_install_linux.sh",
    "doppelganger_install_macos.sh"
)

foreach ($installer in $installerUrls) {
    try {
        $url = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/installers/$installer"
        $destination = "$basePath\$installer"
        Invoke-WebRequest -Uri $url -OutFile $destination -ErrorAction Stop
        Log "Downloaded $installer"
    }
    catch {
        Log "Warning: Could not download $installer : $_"
    }
}

$wslInstallScriptPath = $installScriptPath -replace "\\", "/"
$wslInstallScriptPath = $wslInstallScriptPath -replace "C:", "/mnt/c"

Log "Running update in WSL..."
Write-Host "`nUpdating Doppelganger Assistant..." -ForegroundColor Cyan
Write-Host "This will:" -ForegroundColor Gray
Write-Host "  - Download latest application binary" -ForegroundColor Gray
Write-Host "  - Update Proxmark3 repository" -ForegroundColor Gray
Write-Host "  - Rebuild Proxmark3 from source" -ForegroundColor Gray
Write-Host ""

wsl -d $foundDistro -u $username bash -ic "bash $wslInstallScriptPath --update"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "  Update Complete!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Launch Doppelganger Assistant with:" -ForegroundColor Cyan
    Write-Host "  wsl -d $foundDistro" -ForegroundColor Yellow
    Write-Host "  doppelganger_assistant" -ForegroundColor Yellow
    Write-Host ""
    Log "Update completed successfully"
}
else {
    Write-Host "`nUpdate encountered errors. Check the log at:" -ForegroundColor Yellow
    Write-Host "  $logFile" -ForegroundColor Gray
    Log "Update completed with errors (exit code: $LASTEXITCODE)"
    exit 1
}

