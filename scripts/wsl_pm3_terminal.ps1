# Log file path
$logFile = "C:\doppelganger_assistant\launch_pm3_terminal.log"

# Function to check if a command exists
function CommandExists {
    param (
        [string]$command
    )
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

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

# Function to detect which Doppelganger WSL distribution is installed
function Get-DoppelgangerDistro {
    $wslList = wsl.exe -l -q | ForEach-Object { $_.Trim() -replace "`0", "" }
    $kaliName = "Kali-doppelganger_assistant"
    $ubuntuName = "Ubuntu-doppelganger_assistant"
    
    foreach ($distro in $wslList) {
        if ($distro -eq $kaliName) {
            return $kaliName
        }
        elseif ($distro -eq $ubuntuName) {
            return $ubuntuName
        }
    }
    return $null
}

# Function to check if WSL is running
function IsWSLRunning {
    $distroName = Get-DoppelgangerDistro
    if ($null -eq $distroName) {
        return $false
    }
    $wslOutput = wsl -l -q
    return $wslOutput -match $distroName
}

# Function to start WSL if not running
function StartWSLIfNotRunning {
    $distroName = Get-DoppelgangerDistro
    if ($null -eq $distroName) {
        Log "ERROR: No Doppelganger Assistant WSL distribution found!"
        Log "Please run the installer first."
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    if (-not (IsWSLRunning)) {
        Log "WSL is not running. Starting $distroName..."
        & wsl -d $distroName --exec echo "WSL started"
        Log "WSL started."
    }
    else {
        Log "$distroName is already running."
    }
}

# Function to detach a USB device if it is already attached
function DetachUSBDevice {
    param (
        [string]$busId
    )
    Log "Detaching device with busid $busId if it is already attached..."
    $detachOutput = & usbipd detach --busid $busId 2>&1 | Tee-Object -Variable detachOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Device might not be attached. Exit code: $LASTEXITCODE"
    }
    else {
        Log "Device detached successfully."
    }

    # Wait for the device to be fully detached
    Start-Sleep -Seconds 1
}

# Function to attach a USB device to WSL
function AttachUSBDeviceToWSL {
    param (
        [string]$busId
    )
    
    Log "Attaching device with busid $busId to WSL..."
    $attachOutput = & usbipd attach --wsl --busid $busId 2>&1 | Tee-Object -Variable attachOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Error attaching device to WSL. Exit code: $LASTEXITCODE"
        Log "Attach output: $attachOutputResult"
        return $false
    }
    else {
        Log "Device successfully attached to WSL."
        return $true
    }
}

# Function to download/update PM3 icon with cache busting
function Ensure-Pm3Icon {
    param(
        [string]$IconPath
    )

    try {
        $dir = Split-Path -Path $IconPath -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        $timestamp = [int][double]::Parse((Get-Date -UFormat %s))
        $pm3IconUrl = "https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/img/doppelganger_pm3.ico?t=$timestamp"
        
        if (Test-Path $IconPath) {
            Remove-Item $IconPath -Force
        }
        
        Invoke-WebRequest -Uri $pm3IconUrl -OutFile $IconPath -ErrorAction Stop
        Log "Downloaded latest PM3 icon to $IconPath"
        
        Start-Sleep -Milliseconds 500
    }
    catch {
        Log "WARNING: Failed to download PM3 icon: $_"
    }
}

# Function to ensure Windows Terminal profile exists for Proxmark3
function EnsureWindowsTerminalProfile {
    $distroName = Get-DoppelgangerDistro
    $settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    $iconPath = "C:\doppelganger_assistant\doppelganger_pm3.ico"

    Ensure-Pm3Icon -IconPath $iconPath
    
    # Check if Windows Terminal settings exist
    if (Test-Path $settingsPath) {
        try {
            $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
            
            $pm3ProfileExists = $false
            $updatedProfiles = @()
            foreach ($profile in $settings.profiles.list) {
                if ($profile.name -eq "Proxmark3 Terminal") {
                    $pm3ProfileExists = $true
                }
                else {
                    $updatedProfiles += $profile
                }
            }
            
            if ($pm3ProfileExists) {
                $settings.profiles.list = $updatedProfiles
            }
            
            Log "Creating Windows Terminal Proxmark3 profile..."
            
            $newProfile = @{
                name              = "Proxmark3 Terminal"
                commandline       = "wsl.exe -d $distroName --exec bash -c 'pm3'"
                icon              = $iconPath
                startingDirectory = "~"
                guid              = "{" + [guid]::NewGuid().ToString() + "}"
                hidden            = $false
            }
            
            $settings.profiles.list += $newProfile
            
            $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
            Log "Proxmark3 profile created successfully."
        }
        catch {
            Log "Warning: Could not modify Windows Terminal settings: $_"
            Log "Icon may not appear in terminal. You can manually configure it in Windows Terminal settings."
        }
    }
    else {
        Log "Windows Terminal settings not found. Icon may not appear."
    }
}

# Function to launch Proxmark3 terminal
function LaunchProxmark3Terminal {
    $distroName = Get-DoppelgangerDistro
    if ($null -eq $distroName) {
        Log "ERROR: No Doppelganger Assistant WSL distribution found!"
        Read-Host "Press Enter to exit"
        exit 1
    }
    
    EnsureWindowsTerminalProfile
    
    Log "Launching Proxmark3 terminal in $distroName..."
    
    wt.exe -w 0 new-tab -p "Proxmark3 Terminal" --title "Proxmark3 Terminal"
    
    Log "Proxmark3 terminal launched."
}

# Clear the log file
Clear-Content -Path $logFile -ErrorAction SilentlyContinue

Log "Starting Proxmark3 Terminal Launcher..."

# Ensure WSL is running
StartWSLIfNotRunning

# List all USB devices and find the Proxmark3 device
Log "Scanning for Proxmark3 device (VID: 9ac4)..."
$usbDevices = & usbipd list 2>&1 | Tee-Object -Variable usbDevicesOutput

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0]
    Log "Found Proxmark3 device with busid $busId"

    # Detach the device if it is already attached
    DetachUSBDevice -busId $busId

    # Bind the Proxmark3 device
    Log "Binding Proxmark3 device..."
    $bindOutput = & usbipd bind --busid $busId 2>&1 | Tee-Object -Variable bindOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Error binding Proxmark3 device. Exit code: $LASTEXITCODE"
        Log "Bind output: $bindOutputResult"
    }
    else {
        # Attach the Proxmark3 device to WSL
        $attached = AttachUSBDeviceToWSL -busId $busId
        
        if ($attached) {
            Start-Sleep -Seconds 2
            LaunchProxmark3Terminal
        }
        else {
            Log "Failed to attach Proxmark3 device. Cannot launch pm3."
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
}
else {
    Log "Proxmark3 device not found."
    $userChoice = Read-Host "Proxmark3 device not detected. Do you want to (A)ttach the device and retry, or (E)xit? [A/E]"
    
    if ($userChoice -eq "A" -or $userChoice -eq "a") {
        Log "User chose to attach the device. Please connect the Proxmark3 device."
        Read-Host "Press Enter when you have connected the Proxmark3 device"
        
        $usbDevices = & usbipd list
        $proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
        
        if ($proxmark3Device) {
            Log "Proxmark3 device found. Restarting the script."
            & $MyInvocation.MyCommand.Path
            exit
        }
        else {
            Log "Proxmark3 device still not found. Exiting."
            Read-Host "Press Enter to exit"
            exit 1
        }
    }
    else {
        Log "User chose to exit."
        exit 1
    }
}

Start-Sleep -Seconds 2
exit

