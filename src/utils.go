package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

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

func checkProxmark3Version() bool {
	cmd := newPM3Cmd("-v")
	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println(Red, "Error checking Proxmark3 version:", err, Reset)
		return false
	}

	outputStr := string(output)
	if strings.Contains(outputStr, "Iceman") {
		return true
	}

	fmt.Println(Red, "Proxmark3 Iceman fork not detected. Please use the Iceman fork.", Reset)
	return false
}

// isInteractive checks if stdin is connected to a terminal
// Returns true for CLI usage, false for GUI subprocess usage
func isInteractive() bool {
	return term.IsTerminal(int(os.Stdin.Fd()))
}

// flushOutput forces stdout to flush, critical for WSL2 subprocess output
func flushOutput() {
	os.Stdout.Sync()
}

// resolvePM3 attempts to locate the actual pm3 CLI binary, avoiding wrapper scripts
// that may try to spawn external terminals. It prefers ELF binaries and known client paths.
func resolvePM3() string {
	// First, try PATH
	if p, err := exec.LookPath("pm3"); err == nil {
		// Prefer non-script (ELF) binary
		if isELFOrUnknownBinary(p) && !fileContains(p, "xterm") {
			return p
		}
	}

	// Try common alternate names/locations
	candidates := []string{
		"/usr/local/bin/pm3",
		"/usr/bin/pm3",
		"/usr/local/bin/proxmark3",
		"/usr/bin/proxmark3",
	}

	// User-local build locations
	if home, err := os.UserHomeDir(); err == nil {
		candidates = append(candidates,
			filepath.Join(home, "src/proxmark3/client/pm3"),
			filepath.Join(home, "src/proxmark3/client/proxmark3"),
			filepath.Join(home, "proxmark3/client/pm3"),
			filepath.Join(home, "proxmark3/client/proxmark3"),
		)
	}

	for _, c := range candidates {
		if _, err := os.Stat(c); err == nil {
			if isELFOrUnknownBinary(c) && !fileContains(c, "xterm") {
				return c
			}
		}
	}

	// Fallback: rely on PATH (may be a script, but still functional)
	if p, err := exec.LookPath("pm3"); err == nil {
		return p
	}

	// Final fallback: just return name; OS will fail with clear error
	return "pm3"
}

// isELFOrUnknownBinary returns true if the file appears to be an ELF binary or
// not a text script (heuristic: not starting with shebang).
func isELFOrUnknownBinary(path string) bool {
	data, err := os.ReadFile(path)
	if err != nil || len(data) < 4 {
		return true // don't block if unreadable; let exec fail later
	}
	// ELF magic: 0x7F 'E' 'L' 'F'
	if data[0] == 0x7f && data[1] == 'E' && data[2] == 'L' && data[3] == 'F' {
		return true
	}
	// Shebang indicates script
	if len(data) >= 2 && data[0] == '#' && data[1] == '!' {
		return false
	}
	return true
}

// fileContains returns true if the file's content contains the given substring (best-effort).
func fileContains(path, substr string) bool {
	data, err := os.ReadFile(path)
	if err != nil {
		return false
	}
	return strings.Contains(string(data), substr)
}

// newPM3Cmd creates an exec.Cmd for pm3 with a WSL-safe environment to avoid GUI popups.
// Specifically, in WSL we unset DISPLAY/WAYLAND vars to ensure pure CLI behavior.
func newPM3Cmd(args ...string) *exec.Cmd {
	pm3 := resolvePM3()
	cmd := exec.Command(pm3, args...)
	env := os.Environ()

	if isWSL2() {
		// Ensure pm3 behaves as CLI, not spawning external terminals
		env = unsetEnvVars(env, "DISPLAY", "WAYLAND_DISPLAY", "TERM_PROGRAM")
	}

	cmd.Env = env
	return cmd
}

func unsetEnvVars(env []string, keys ...string) []string {
	keySet := map[string]struct{}{}
	for _, k := range keys {
		keySet[strings.ToUpper(k)] = struct{}{}
	}
	filtered := make([]string, 0, len(env))
	for _, kv := range env {
		upper := kv
		if idx := strings.IndexByte(kv, '='); idx >= 0 {
			upper = strings.ToUpper(kv[:idx])
		}
		if _, found := keySet[upper]; found {
			continue
		}
		filtered = append(filtered, kv)
	}
	return filtered
}
