package main

import (
	"context"
	"os"
	"os/exec"
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

// checkProxmark3 checks if Proxmark3 is connected and responding
// Returns (connected, error message)
func checkProxmark3() (bool, string) {
	// Check if pm3 binary exists in PATH
	_, err := exec.LookPath("pm3")
	if err != nil {
		return false, "Proxmark3 client (pm3) not found in PATH"
	}

	// Quick device check with short timeout - use 'quit' command which exits immediately
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, "pm3", "-c", "quit")
	output, err := cmd.CombinedOutput()

	// If timeout, device not connected
	if ctx.Err() == context.DeadlineExceeded {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	// Check output for common error indicators
	outputStr := strings.ToLower(string(output))
	if strings.Contains(outputStr, "offline") ||
		strings.Contains(outputStr, "cannot open") ||
		strings.Contains(outputStr, "no such device") ||
		err != nil && strings.Contains(err.Error(), "exit status") {
		return false, "Proxmark3 device not detected. Please connect your Proxmark3"
	}

	return true, ""
}

// isInteractive checks if stdin is connected to a terminal
// Returns true for CLI usage, false for GUI subprocess usage
func isInteractive() bool {
	return term.IsTerminal(int(os.Stdin.Fd()))
}
