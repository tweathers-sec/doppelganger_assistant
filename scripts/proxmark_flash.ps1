# Log file path
$logFile = "C:\doppelganger_assistant\proxmark_flash.log"

# Function to log output to both file and screen
function Log {
    param (
        [string]$message
    )
    $timestamp = (Get-Date).ToString('u')
    $logMessage = "$timestamp - $message"
    Write-Output $message
    Add-Content -Path $logFile -Value $logMessage
}

# Function to check if a command exists
function CommandExists {
    param (
        [string]$command
    )
    $null = Get-Command $command -ErrorAction SilentlyContinue
    return $?
}

# Function to check if WSL is running
function IsWSLRunning {
    $wslOutput = wsl -l -q
    return $wslOutput -match "Ubuntu-doppelganger_assistant"
}

# Function to start WSL if not running
function StartWSLIfNotRunning {
    if (-not (IsWSLRunning)) {
        Log "WSL is not running. Starting WSL..."
        & wsl -d "Ubuntu-doppelganger_assistant" --exec echo "WSL started"
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
    $detachOutput = & usbipd detach --busid $busId 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log "Error detaching device. It might not be attached. Exit code: $LASTEXITCODE"
        Log "Detach output: $detachOutput"
    } else {
        Log "Device detached successfully."
    }
}

# Function to attach a USB device to WSL
function AttachUSBDeviceToWSL {
    param (
        [string]$busId
    )
    Log "Attaching device with busid $busId to WSL..."
    $attachOutput = & usbipd attach --wsl --busid $busId 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log "Error attaching device to WSL. Exit code: $LASTEXITCODE"
        Log "Attach output: $attachOutput"
    } else {
        Log "Device successfully attached to WSL."
    }
}

# Clear the log file
Clear-Content -Path $logFile -ErrorAction SilentlyContinue

Log "Starting Proxmark3 flashing script."

# Ensure WSL is running
StartWSLIfNotRunning

# List all USB devices and find the Proxmark3 device
Log "Listing all USB devices..."
$usbDevices = & usbipd list 2>&1
Log $usbDevices

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID (e.g., 1-4)
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0] # Assuming busid is the first column in the list output
    Log "Found device with busid $busId"

    # Detach the device if it is already attached
    DetachUSBDevice -busId $busId

    # Bind the Proxmark3 device
    Log "Binding Proxmark3 device..."
    $bindOutput = & usbipd bind --busid $busId 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log "Error binding Proxmark3 device. Exit code: $LASTEXITCODE"
        Log "Bind output: $bindOutput"
    } else {
        # Attach the Proxmark3 device to WSL
        AttachUSBDeviceToWSL -busId $busId

        # Run pm3-flash-all in a new terminal
        Log "Running pm3-flash-all in a new terminal..."
        $command = "wsl -d Ubuntu-doppelganger_assistant -e bash -c 'pm3-flash-all'"

        Start-Process powershell -ArgumentList "-NoExit", "-Command", $command

        # Wait for 15 seconds
        Log "Waiting for 5 seconds..."
        Start-Sleep -Seconds 5

        # Reattach the device
        Log "Reattaching the Proxmark3 device..."
        DetachUSBDevice -busId $busId
        AttachUSBDeviceToWSL -busId $busId

        Log "Proxmark3 flashing process completed. The update is running in a separate terminal."
        Log "Please wait for the update to complete in the new terminal before using the device."
    }
} else {
    Log "Proxmark3 device not found."
}

Log "Script execution completed."