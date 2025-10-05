package main

import (
	"fmt"
	"io"
	"os"
	"sync"
)

// StatusWriter handles writing status messages separately from command output
type StatusWriter struct {
	mu     sync.Mutex
	writer io.Writer
}

var (
	// Global status writer that can be set by GUI or defaults to os.Stderr
	globalStatusWriter *StatusWriter
	statusMu           sync.Mutex
)

func init() {
	globalStatusWriter = &StatusWriter{writer: os.Stderr}
}

// SetStatusWriter sets the global status writer
func SetStatusWriter(w io.Writer) {
	statusMu.Lock()
	defer statusMu.Unlock()
	globalStatusWriter = &StatusWriter{writer: w}
}

// WriteStatus writes a status message to the status writer
func WriteStatus(format string, args ...interface{}) {
	statusMu.Lock()
	defer statusMu.Unlock()
	if globalStatusWriter != nil && globalStatusWriter.writer != nil {
		msg := fmt.Sprintf(format, args...)
		globalStatusWriter.writer.Write([]byte(msg + "\n"))
	}
}

// WriteStatusSuccess writes a success status message (green in GUI)
func WriteStatusSuccess(format string, args ...interface{}) {
	WriteStatus("[SUCCESS] "+format, args...)
}

// WriteStatusError writes an error status message (red in GUI)
func WriteStatusError(format string, args ...interface{}) {
	WriteStatus("[ERROR] "+format, args...)
}

// WriteStatusInfo writes an info status message (yellow in GUI)
func WriteStatusInfo(format string, args ...interface{}) {
	WriteStatus("[INFO] "+format, args...)
}

// WriteStatusProgress writes a progress status message
func WriteStatusProgress(format string, args ...interface{}) {
	WriteStatus("[PROGRESS] "+format, args...)
}
