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
    & usbipd detach --busid $busId 2>&1 | Tee-Object -Variable detachOutputResult | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Log "Error detaching device. It might not be attached. Exit code: $LASTEXITCODE"
        Log "Detach output: $detachOutputResult"
    }
    else {
        Log "Device detached successfully."
    }

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

# Function to verify device is attached in WSL
function VerifyDeviceAttachedInWSL {
    param (
        [string]$busId,
        [int]$timeoutSeconds = 10
    )
    
    $distroName = Get-DoppelgangerDistro
    if ($null -eq $distroName) {
        return $false
    }
    
    Log "Verifying device attachment in WSL (timeout: ${timeoutSeconds}s)..."
    $startTime = Get-Date
    $elapsed = 0
    
    while ($elapsed -lt $timeoutSeconds) {
        $checkCommand = "ls /dev/ttyACM* /dev/ttyUSB* 2>/dev/null | head -1"
        $wslOutput = wsl -d $distroName --exec bash -c $checkCommand 2>&1
        
        if ($wslOutput -and $wslOutput.Trim() -ne "") {
            Log "Device verified in WSL: $wslOutput"
            return $true
        }
        
        Start-Sleep -Seconds 1
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
    }
    
    Log "Device attachment verification timed out after ${timeoutSeconds} seconds."
    return $false
}

# Function to refresh PATH and check for usbipd
function Refresh-UsbIpdCommand {
    Log "Refreshing PATH and checking for usbipd command..."
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command usbipd -ErrorAction SilentlyContinue) {
        Log "usbipd command is now available."
        return $true
    }
    
    Log "usbipd command is still not available after refreshing PATH."
    return $false
}

# Function to reinstall usbipd
function Reinstall-UsbIpd {
    Log "Attempting to reinstall usbipd..."
    
    # First, try to uninstall using winget
    if (CommandExists "winget") {
        Log "Uninstalling usbipd..."
        $uninstallOutput = Start-Process winget -ArgumentList "uninstall --exact --silent usbipd" -Wait -PassThru -NoNewWindow
        if ($uninstallOutput.ExitCode -eq 0) {
            Log "usbipd uninstalled successfully."
            Start-Sleep -Seconds 2
        }
        else {
            Log "Warning: Could not uninstall usbipd via winget. Exit code: $($uninstallOutput.ExitCode)"
        }
    }
    else {
        Log "winget not found. Skipping uninstall step."
    }
    
    # Now reinstall
    Log "Reinstalling usbipd..."
    try {
        if (CommandExists "winget") {
            $installOutput = Start-Process winget -ArgumentList "install --exact --silent --accept-source-agreements --accept-package-agreements usbipd" -Wait -PassThru -ErrorAction Stop
            if ($installOutput.ExitCode -ne 0) {
                throw "Winget installation failed with exit code: $($installOutput.ExitCode)"
            }
            Log "usbipd reinstalled via winget."
        }
        else {
            # Fallback to direct MSI download
            Log "winget not available, using direct MSI download..."
            $usbIpdUrl = "https://github.com/dorssel/usbipd-win/releases/latest/download/usbipd-win_x64.msi"
            $usbIpdMsiPath = "$env:TEMP\usbipd-win_x64.msi"
            Invoke-WebRequest -Uri $usbIpdUrl -OutFile $usbIpdMsiPath
            $msiExecOutput = Start-Process msiexec.exe -ArgumentList "/i `"$usbIpdMsiPath`" /qn" -Wait -PassThru
            if ($msiExecOutput.ExitCode -ne 0) {
                throw "MSI installation failed with exit code: $($msiExecOutput.ExitCode)"
            }
            Remove-Item $usbIpdMsiPath -Force
            Log "usbipd reinstalled via MSI."
        }
        
        # Refresh PATH and verify
        Start-Sleep -Seconds 2
        if (Refresh-UsbIpdCommand) {
            Log "usbipd reinstallation successful and command is available."
            return $true
        }
        else {
            Log "WARNING: usbipd reinstalled but command not immediately available. May require restart."
            return $false
        }
    }
    catch {
        Log "ERROR: Failed to reinstall usbipd: $_"
        return $false
    }
}

# Function to attach a USB device to WSL with verification and auto-reinstall on failure
function AttachUSBDeviceToWSL {
    param (
        [string]$busId,
        [int]$maxRetries = 2
    )
    
    $retryCount = 0
    $attachSuccess = $false
    
    while ($retryCount -lt $maxRetries -and -not $attachSuccess) {
        if ($retryCount -gt 0) {
            Log "Retry attempt $retryCount of $maxRetries..."
        }
    
    Log "Attaching device with busid $busId to WSL (WSL2 required)..."
        & usbipd attach --wsl --busid $busId 2>&1 | Tee-Object -Variable attachOutputResult | Out-Null
        
    if ($LASTEXITCODE -ne 0) {
        Log "Error attaching device to WSL. Exit code: $LASTEXITCODE"
        Log "Attach output: $attachOutputResult"
            
            if ($retryCount -eq 0) {
                Log "Attachment failed. Attempting to reinstall usbipd and retry..."
                
                if (Reinstall-UsbIpd) {
                    Log "usbipd reinstalled. Retrying attachment..."
                    Start-Sleep -Seconds 3
                    $retryCount++
                    continue
                }
                else {
                    Log "Failed to reinstall usbipd. Cannot retry attachment."
                    return $false
                }
            }
            else {
                Log "Attachment failed after usbipd reinstall. Giving up."
        Log "NOTE: USB passthrough requires WSL2 with nested virtualization enabled."
                return $false
            }
        }
        else {
            Log "Attach command succeeded. Verifying device attachment..."
            
            Start-Sleep -Seconds 2
            if (VerifyDeviceAttachedInWSL -busId $busId -timeoutSeconds 10) {
                Log "Device successfully attached and verified in WSL."
                $attachSuccess = $true
                return $true
            }
            else {
                Log "WARNING: Attach command succeeded but device not detected in WSL."
                
                if ($retryCount -eq 0) {
                    Log "Device verification failed. Attempting to reinstall usbipd and retry..."
                    
                    if (Reinstall-UsbIpd) {
                        Log "usbipd reinstalled. Retrying attachment..."
                        Start-Sleep -Seconds 3
                        $retryCount++
                        continue
                    }
                    else {
                        Log "Failed to reinstall usbipd. Cannot retry attachment."
                        return $false
                    }
                }
                else {
                    Log "Device verification failed after usbipd reinstall. Attachment may have partially succeeded."
                    return $false
                }
            }
        }
    }
    
    return $attachSuccess
}

# Function to launch Doppelganger Assistant in WSL and close the terminal
function LaunchDoppelgangerAssistant {
    $distroName = Get-DoppelgangerDistro
    if ($null -eq $distroName) {
        Log "ERROR: No Doppelganger Assistant WSL distribution found!"
        return
    }
    
    Log "Launching Doppelganger Assistant in $distroName..."
    $wslCommand = "wsl -d $distroName --exec doppelganger_assistant"
    
    Start-Process powershell -ArgumentList "-WindowStyle", "Hidden", "-Command", $wslCommand -WindowStyle Hidden
    
    Log "Doppelganger Assistant launch initiated. This script will now close."
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

# Find the Proxmark3 device by VID 9ac4 and extract the bus ID
$proxmark3Device = $usbDevices | Select-String -Pattern "9ac4"
if ($proxmark3Device) {
    $busId = ($proxmark3Device -split "\s+")[0]
    Log "Found device with busid $busId"

    # Detach the device if it is already attached
    DetachUSBDevice -busId $busId

    # Bind the Proxmark3 device
    Log "Binding Proxmark3 device..."
    & usbipd bind --busid $busId 2>&1 | Tee-Object -Variable bindOutputResult | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Log "Error binding Proxmark3 device. Exit code: $LASTEXITCODE"
        Log "Bind output: $bindOutputResult"
        Log "Continuing without device binding..."
    }
    else {
        $attachSuccess = AttachUSBDeviceToWSL -busId $busId
        
        if (-not $attachSuccess) {
            Log "WARNING: Failed to attach Proxmark3 device to WSL after retries."
            Log "Doppelganger Assistant will launch but may not detect the device."
            $userChoice = Read-Host "Continue anyway? (Y/n)"
            if ($userChoice -eq "n" -or $userChoice -eq "N") {
                Log "User chose to exit. Please check usbipd installation and try again."
                exit 1
            }
        }
    }
    
        LaunchDoppelgangerAssistant
    }
else {
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
        }
        else {
            Log "Proxmark3 device still not found after user intervention. Continuing without the device."
        }
    }
    else {
        Log "User chose to continue without the Proxmark3 device."
    }

    LaunchDoppelgangerAssistant
}

Start-Sleep -Seconds 2
exit