# Log file path
$logFile = "C:\doppelganger_assistant\usb_reconnect.log"

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

# Function to detach a USB device
function DetachUSBDevice {
    param (
        [string]$busId
    )
    Log "Detaching device with busid $busId..."
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

# List all USB devices and find the Proxmark3 device
Log "Listing all USB devices..."
$usbDevices = & usbipd list 2>&1 | Tee-Object -Variable usbDevicesOutput
Log $usbDevicesOutput

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0]
    Log "Found device with busid $busId"

    DetachUSBDevice -busId $busId
    Start-Sleep -Seconds 2
    AttachUSBDeviceToWSL -busId $busId
} else {
    Log "Proxmark3 device not found."
}