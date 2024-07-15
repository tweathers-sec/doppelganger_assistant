# PowerShell script to install usbipd, bind the Proxmark3 device to WSL, and run doppelganger_assistant in WSL

# Log file path
$logFile = "C:\Scripts\setup_proxmark3_wsl.log"

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

# Function to check if WSL is running
function IsWSLRunning {
    $wslOutput = wsl -l -q
    return $wslOutput -match "Ubuntu"
}

# Function to start WSL if not running
function StartWSLIfNotRunning {
    if (-not (IsWSLRunning)) {
        Log "WSL is not running. Starting WSL..."
        & wsl --exec echo "WSL started"
        Log "WSL started."
    } else {
        Log "WSL is already running."
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
        Log "Error detaching device. It might not be attached. Exit code: $LASTEXITCODE"
        Log "Detach output: $detachOutputResult"
    } else {
        Log "Device detached successfully."
    }

    # Wait for the device to be fully detached
    $maxRetries = 10
    $retryCount = 0
    while ($retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 1
        $usbDevices = & usbipd list
        if (-not ($usbDevices -match $busId)) {
            Log "Device $busId successfully detached."
            return
        }
        $retryCount++
    }

    Log "Device $busId did not detach within the expected time."
}

# Clear the log file
Clear-Content -Path $logFile -ErrorAction SilentlyContinue

Log "Starting setup script."

# Ensure WSL is running
StartWSLIfNotRunning

# Install usbipd using winget
if (-not (CommandExists "usbipd")) {
    Log "Installing usbipd..."
    $installOutput = Start-Process winget -ArgumentList "install --interactive --exact dorssel.usbipd-win" -Wait -PassThru
    if ($installOutput.ExitCode -ne 0) {
        Log "Error installing usbipd. Exit code: $($installOutput.ExitCode)"
        exit 1
    }
} else {
    Log "usbipd is already installed."
}

# List all USB devices and find the Proxmark3 device
Log "Listing all USB devices..."
$usbDevices = & usbipd list 2>&1 | Tee-Object -Variable usbDevicesOutput
Log $usbDevicesOutput

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID (e.g., 1-4)
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0] # Assuming busid is the first column in the list output
    Log "Found Proxmark3 device with busid $busId"

    # Detach the device if it is already attached
    DetachUSBDevice -busId $busId

    # Bind the Proxmark3 device
    Log "Binding Proxmark3 device..."
    $bindOutput = & usbipd bind --busid $busId 2>&1 | Tee-Object -Variable bindOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Error binding Proxmark3 device. Exit code: $LASTEXITCODE"
        Log "Bind output: $bindOutputResult"
        exit 1
    }

    # Attach the Proxmark3 device to WSL
    Log "Attaching Proxmark3 device to WSL..."
    $attachOutput = & usbipd attach --wsl --busid $busId 2>&1 | Tee-Object -Variable attachOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Error attaching Proxmark3 device to WSL. Exit code: $LASTEXITCODE"
        Log "Attach output: $attachOutputResult"
        exit 1
    }

    Log "Proxmark3 device successfully attached to WSL."

    # Run doppelganger_assistant in WSL
    Log "Launching Doppelganger Assistant in WSL..."
    $wslOutput = & wsl -e bash -c "nohup doppelganger_assistant > /dev/null 2>&1 &"
    Log "Doppelganger Assistant launched in WSL."
} else {
    Log "Proxmark3 device not found. Ensure it is connected and try again."
    exit 1
}

# Instructions to run this script with execution policy bypass
Log "To run this script, use the following command in PowerShell with administrative privileges:"
Log "powershell -ExecutionPolicy Bypass -File .\setup_proxmark3_wsl.ps1"

åLog "Setup script completed."