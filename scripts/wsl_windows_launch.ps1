# Log file path
$logFile = "C:\doppelganger_assistant\launch_proxmark3_wsl.log"

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
    } else {
        Log "Device successfully attached to WSL."
    }
}

# Function to launch Doppelganger Assistant in WSL and close the terminal
function LaunchDoppelgangerAssistant {
    Log "Launching Doppelganger Assistant in WSL..."
    $wslCommand = "wsl -d Ubuntu-doppelganger_assistant -e bash -c 'nohup doppelganger_assistant > /dev/null 2>&1 &'"
    
    # Create a vbs script to run the WSL command without showing a window
    $vbsScript = @"
    Set WshShell = CreateObject("WScript.Shell")
    WshShell.Run "$wslCommand", 0, false
"@
    
    $vbsPath = [System.IO.Path]::GetTempFileName() + ".vbs"
    Set-Content -Path $vbsPath -Value $vbsScript
    
    # Run the vbs script
    Start-Process -FilePath "wscript.exe" -ArgumentList $vbsPath -WindowStyle Hidden
    
    # Clean up the temporary vbs script
    Start-Sleep -Seconds 2  # Wait a bit to ensure the script has run
    Remove-Item $vbsPath
    
    Log "Doppelganger Assistant launched in WSL. Terminal will close."
}

# Clear the log file
Clear-Content -Path $logFile -ErrorAction SilentlyContinue

Log "Starting setup script."

# Ensure WSL is running
StartWSLIfNotRunning

# List all USB devices and find the Proxmark3 device
Log "Listing all USB devices..."
$usbDevices = & usbipd list 2>&1 | Tee-Object -Variable usbDevicesOutput
Log $usbDevicesOutput

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID (e.g., 1-4)
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0] # Assuming busid is the first column in the list output
    Log "Found device with busid $busId"

    # Detach the device if it is already attached
    DetachUSBDevice -busId $busId

    # Bind the Proxmark3 device
    Log "Binding Proxmark3 device..."
    $bindOutput = & usbipd bind --busid $busId 2>&1 | Tee-Object -Variable bindOutputResult
    if ($LASTEXITCODE -ne 0) {
        Log "Error binding Proxmark3 device. Exit code: $LASTEXITCODE"
        Log "Bind output: $bindOutputResult"
    } else {
        # Attach the Proxmark3 device to WSL
        AttachUSBDeviceToWSL -busId $busId

        # Launch Doppelganger Assistant
        LaunchDoppelgangerAssistant
    }
} else {
    Log "Proxmark3 device not found."
    $userChoice = Read-Host "Proxmark3 device not detected. Do you want to (A)ttach the device and retry, or (C)ontinue without the device? [A/C]"
    
    if ($userChoice -eq "A" -or $userChoice -eq "a") {
        Log "User chose to attach the device. Please connect the Proxmark3 device and press Enter."
        Read-Host "Press Enter when you have connected the Proxmark3 device"
        
        # Retry device detection
        $usbDevices = & usbipd list
        $proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
        
        if ($proxmark3Device) {
            Log "Proxmark3 device found after user intervention. Restarting the script."
            & $MyInvocation.MyCommand.Path  # Restart the script
            exit
        } else {
            Log "Proxmark3 device still not found after user intervention. Continuing without the device."
        }
    } else {
        Log "User chose to continue without the Proxmark3 device."
    }

    # Launch Doppelganger Assistant without the Proxmark3 device
    LaunchDoppelgangerAssistant
}

# Exit the script, which will close the PowerShell window
exit