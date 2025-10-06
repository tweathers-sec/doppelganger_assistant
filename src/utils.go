package main

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
	"time"

	"golang.org/x/term"
)

func bitCount(intType uint64) int {
	count := 0
	for intType != 0 {
		intType &= intType - 1
		count++
	}
	return count
}

// findPm3Path attempts to find the pm3 binary using shell commands
func findPm3Path() (string, error) {
	var cmd *exec.Cmd

	if runtime.GOOS == "windows" {
		// On Windows, use 'where' command
		cmd = exec.Command("cmd", "/c", "where", "pm3")
	} else {
		// On macOS and Linux, use 'type -a' command through shell
		cmd = exec.Command("bash", "-c", "type -a pm3")
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}

	// Parse the output to get the first valid path
	outputStr := string(output)
	lines := strings.Split(outputStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// On Unix, 'type' output is like "pm3 is /usr/local/bin/pm3"
		if strings.Contains(line, " is ") {
			parts := strings.Split(line, " is ")
			if len(parts) >= 2 {
				return strings.TrimSpace(parts[1]), nil
			}
		} else if strings.HasPrefix(line, "/") || strings.Contains(line, ":\\") {
			// Direct path on Windows or Unix
			return line, nil
		}
	}

	return "", err
}

// findPm3Device detects the pm3 device path using 'pm3 --list'
// Returns the device path (e.g., /dev/tty.usbmodem1101 on macOS, /dev/ttyACM0 on Linux)
func findPm3Device() (string, error) {
	// Get the full path to pm3 binary
	pm3Binary, err := getPm3Path()
	if err != nil || pm3Binary == "" {
		return "", fmt.Errorf("pm3 binary not found")
	}

	cmd := exec.Command(pm3Binary, "--list")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}

	// Parse the output to get the device path
	// Expected format: "1: /dev/tty.usbmodem1101" or "1: /dev/ttyACM0"
	outputStr := string(output)
	lines := strings.Split(outputStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		// Look for lines with device paths
		if strings.Contains(line, ":") {
			parts := strings.SplitN(line, ":", 2)
			if len(parts) == 2 {
				devicePath := strings.TrimSpace(parts[1])
				// Validate it looks like a device path
				if strings.HasPrefix(devicePath, "/dev/") {
					return devicePath, nil
				}
			}
		}
	}

	return "", fmt.Errorf("no pm3 device found")
}

// pm3Device caches the detected device path
var pm3Device string
var pm3DeviceErr error
var pm3DeviceChecked bool

// pm3Path caches the full path to pm3 binary
var pm3Path string
var pm3PathErr error
var pm3PathChecked bool

// getPm3Path returns the cached pm3 binary path or detects it
func getPm3Path() (string, error) {
	if !pm3PathChecked {
		pm3Path, pm3PathErr = findPm3Path()
		pm3PathChecked = true
	}
	return pm3Path, pm3PathErr
}

// getPm3Device returns the cached pm3 device path or detects it
func getPm3Device() (string, error) {
	if !pm3DeviceChecked {
		pm3Device, pm3DeviceErr = findPm3Device()
		pm3DeviceChecked = true
	}
	return pm3Device, pm3DeviceErr
}

// checkProxmark3 verifies if Proxmark3 is connected and responding.
// Returns (connected, error message).
func checkProxmark3() (bool, string) {
	pm3Binary, err := getPm3Path()
	if err != nil || pm3Binary == "" {
		return false, "Proxmark3 client (pm3) not found in PATH"
	}

	// Try to detect the device
	device, err := getPm3Device()
	if err != nil || device == "" {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, pm3Binary, "-c", "quit", "-p", device)
	output, err := cmd.CombinedOutput()

	if ctx.Err() == context.DeadlineExceeded {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	outputStr := strings.ToLower(string(output))
	if strings.Contains(outputStr, "offline") ||
		strings.Contains(outputStr, "cannot open") ||
		strings.Contains(outputStr, "no such device") ||
		err != nil && strings.Contains(err.Error(), "exit status") {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	return true, ""
}

// isInteractive checks if stdin is connected to a terminal.
func isInteractive() bool {
	return term.IsTerminal(int(os.Stdin.Fd()))
}
