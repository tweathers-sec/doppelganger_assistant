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
	output, err := cmd.CombinedOutput()
		if err == nil {
	outputStr := string(output)
	lines := strings.Split(outputStr, "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
				if line != "" && strings.Contains(line, ":\\") {
					return line, nil
				}
			}
		}
		return "", fmt.Errorf("pm3 binary not found")
	}

	// On macOS and Linux, use 'command -v' which works in sh/bash/zsh
	// Use /bin/sh to ensure we have a shell, and 'command -v' is POSIX standard
	cmd = exec.Command("/bin/sh", "-c", "command -v pm3")
	output, err := cmd.CombinedOutput()
	if err == nil {
		path := strings.TrimSpace(string(output))
		if path != "" && strings.HasPrefix(path, "/") {
			return path, nil
			}
	}

	// If shell lookup fails, try common installation paths directly
	var commonPaths []string
	if runtime.GOOS == "darwin" {
		commonPaths = []string{
			"/opt/homebrew/bin/pm3",               // Homebrew on Apple Silicon
			"/usr/local/bin/pm3",                  // Homebrew on Intel Mac
			"/opt/local/bin/pm3",                  // MacPorts
			"/usr/local/Cellar/proxmark3/bin/pm3", // Older Homebrew layout
		}
	} else {
		// Linux
		commonPaths = []string{
			"/usr/local/bin/pm3",
			"/usr/bin/pm3",
			"/opt/proxmark3/pm3",
		}
	}

	for _, path := range commonPaths {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}

	return "", fmt.Errorf("pm3 binary not found in PATH or common installation locations")
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

// resetPm3DeviceCache clears the cached device detection so it will be re-checked
func resetPm3DeviceCache() {
	pm3DeviceChecked = false
	pm3Device = ""
	pm3DeviceErr = nil
}

// checkProxmark3 verifies if Proxmark3 is connected and responding.
// Returns (connected, error message).
func checkProxmark3() (bool, string) {
	pm3Binary, err := getPm3Path()
	if err != nil || pm3Binary == "" {
		return false, "Proxmark3 client (pm3) not found in PATH"
	}

	// Reset cache to force fresh detection
	resetPm3DeviceCache()
	device, err := getPm3Device()
	if err != nil || device == "" {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, pm3Binary, "-c", "quit", "-p", device)
	output, err := cmd.CombinedOutput()

	if ctx.Err() == context.DeadlineExceeded {
		resetPm3DeviceCache()
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	outputStr := strings.ToLower(string(output))
	if strings.Contains(outputStr, "offline") ||
		strings.Contains(outputStr, "cannot open") ||
		strings.Contains(outputStr, "no such device") ||
		err != nil && strings.Contains(err.Error(), "exit status") {
		resetPm3DeviceCache()
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	return true, ""
}

// isInteractive checks if stdin is connected to a terminal.
func isInteractive() bool {
	return term.IsTerminal(int(os.Stdin.Fd()))
}

// validateEM4100Hex validates EM4100 hex data format
// EM4100 IDs must be exactly 5 hex bytes (10 hex characters)
func validateEM4100Hex(hexData string) (bool, string) {
	// Remove any whitespace
	hexData = strings.TrimSpace(hexData)

	// Check if empty
	if hexData == "" {
		return false, "Hex Data is required for EM4100 / Net2 cards"
	}

	// Check length - must be exactly 10 hex characters (5 bytes)
	if len(hexData) != 10 {
		return false, fmt.Sprintf("EM4100 / Net2 ID must be exactly 10 hex characters (5 bytes), got %d characters", len(hexData))
	}

	// Check if all characters are valid hex
	for _, c := range hexData {
		if !((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')) {
			return false, fmt.Sprintf("Invalid hex character in EM4100 / Net2 ID: %c (only 0-9, A-F allowed)", c)
		}
	}

	return true, ""
}

// launchPm3Terminal launches Proxmark3 in the OS default terminal
func launchPm3Terminal() error {
	pm3Binary, err := getPm3Path()
	if err != nil {
		return fmt.Errorf("failed to find pm3 binary: %w", err)
	}

	device, err := getPm3Device()
	if err != nil {
		// If device not found, launch without device parameter
		device = ""
	}

	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "darwin":
		// macOS: Use osascript to open Terminal.app with the command
		var script string
		if device != "" {
			script = fmt.Sprintf(`tell application "Terminal"
	activate
	do script "%s -p %s"
end tell`, pm3Binary, device)
		} else {
			script = fmt.Sprintf(`tell application "Terminal"
	activate
	do script "%s"
end tell`, pm3Binary)
		}
		cmd = exec.Command("osascript", "-e", script)
	case "linux":
		// Linux: Try common terminals
		terminals := []string{"gnome-terminal", "xterm", "konsole", "x-terminal-emulator", "terminator"}
		var terminalCmd string
		var terminalArgs []string

		for _, term := range terminals {
			if _, err := exec.LookPath(term); err == nil {
				terminalCmd = term
				switch term {
				case "gnome-terminal":
					if device != "" {
						terminalArgs = []string{"--", pm3Binary, "-p", device}
					} else {
						terminalArgs = []string{"--", pm3Binary}
					}
				case "xterm":
					if device != "" {
						terminalArgs = []string{"-e", pm3Binary, "-p", device}
					} else {
						terminalArgs = []string{"-e", pm3Binary}
					}
				case "konsole":
					if device != "" {
						terminalArgs = []string{"-e", pm3Binary, "-p", device}
					} else {
						terminalArgs = []string{"-e", pm3Binary}
					}
				case "x-terminal-emulator":
					if device != "" {
						terminalArgs = []string{"-e", pm3Binary, "-p", device}
					} else {
						terminalArgs = []string{"-e", pm3Binary}
					}
				case "terminator":
					if device != "" {
						terminalArgs = []string{"-e", pm3Binary, "-p", device}
					} else {
						terminalArgs = []string{"-e", pm3Binary}
					}
				}
				break
			}
		}

		if terminalCmd == "" {
			return fmt.Errorf("no terminal emulator found. Please install gnome-terminal, xterm, konsole, or terminator")
		}

		cmd = exec.Command(terminalCmd, terminalArgs...)
	case "windows":
		// Windows: Use cmd.exe
		if device != "" {
			cmd = exec.Command("cmd.exe", "/c", "start", "cmd.exe", "/k", pm3Binary, "-p", device)
		} else {
			cmd = exec.Command("cmd.exe", "/c", "start", "cmd.exe", "/k", pm3Binary)
		}
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}

	return cmd.Start()
}
