package main

import (
	"fmt"
	"os/exec"
	"strings"
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
	cmd := exec.Command("pm3", "-v")
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
