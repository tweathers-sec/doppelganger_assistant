package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"sort"
	"strings"
)

// recoverHotelKey attempts to recover keys from a hotel key card (MIFARE Classic)
// Uses Proxmark3's built-in recovery tools
// onFilePathsFound is called with dumpFilePath and keyFilePath when files are found
func recoverHotelKey(recoveryMethod string, onFilePathsFound func(string, string)) {
	if ok, msg := checkProxmark3(); !ok {
		WriteStatusError(msg)
		return
	}

	pm3Binary, err := getPm3Path()
	if err != nil {
		WriteStatusError("Failed to find pm3 binary: %v", err)
		return
	}

	device, err := getPm3Device()
	if err != nil {
		WriteStatusError("Failed to detect pm3 device: %v", err)
		return
	}

	var cmd *exec.Cmd
	var cmdStr string
	isRecoveryMethod := true

	switch recoveryMethod {
	case "autopwn":
		// Automatic key recovery - tries multiple methods
		cmdStr = "hf mf autopwn"
		cmd = exec.Command(pm3Binary, "-c", "hf mf autopwn", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using automatic recovery (autopwn) - this will try multiple attack methods")
	case "darkside":
		// Darkside attack - fast but only works on vulnerable cards
		cmdStr = "hf mf darkside"
		cmd = exec.Command(pm3Binary, "-c", "hf mf darkside", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using Darkside attack - fast but only works on vulnerable cards")
	case "nested":
		// Nested attack - works on most cards but slower
		cmdStr = "hf mf nested"
		cmd = exec.Command(pm3Binary, "-c", "hf mf nested", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using Nested attack - works on most cards but may take longer")
	case "hardnested":
		// Hardnested attack - for hardened cards
		cmdStr = "hf mf hardnested"
		cmd = exec.Command(pm3Binary, "-c", "hf mf hardnested", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using Hardnested attack - for hardened MIFARE Classic cards")
	case "staticnested":
		// Static nested attack - for cards with static nonces
		cmdStr = "hf mf staticnested"
		cmd = exec.Command(pm3Binary, "-c", "hf mf staticnested", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using Static Nested attack - for cards with static nonces")
	case "brute":
		// Smart bruteforce - exploits weak key generators
		cmdStr = "hf mf brute"
		cmd = exec.Command(pm3Binary, "-c", "hf mf brute", "-p", device)
		WriteStatusProgress("Starting hotel key card recovery...")
		WriteStatusInfo("Place the hotel key card on the reader and keep it there during recovery")
		WriteStatusInfo("Using Smart Bruteforce attack - exploits weak key generators")
	case "nack":
		// NACK bug test - tests for MIFARE NACK bug vulnerability
		cmdStr = "hf mf nack"
		cmd = exec.Command(pm3Binary, "-c", "hf mf nack", "-p", device)
		WriteStatusProgress("Testing MIFARE card for NACK bug vulnerability...")
		WriteStatusInfo("Place the card on the reader")
		isRecoveryMethod = false
	default:
		WriteStatusError("Unknown recovery method: %s", recoveryMethod)
		return
	}

	fmt.Println(cmdStr)
	fmt.Println()

	output, cmdErr := cmd.CombinedOutput()
	outputStr := string(output)

	// Print full output (no filtering)
	fmt.Println(outputStr)

	// For NACK test, just report completion
	if !isRecoveryMethod {
		if cmdErr != nil {
			WriteStatusError("NACK test failed: %v", cmdErr)
		} else {
			WriteStatusSuccess("NACK test completed. Review output above for results.")
		}
		return
	}

	// Parse recovery results
	sectorsRecovered := parseRecoveryOutput(outputStr)

	if cmdErr != nil {
		WriteStatusError("Recovery failed: %v", cmdErr)
		if sectorsRecovered > 0 {
			WriteStatusInfo("Partial recovery: %d sectors recovered", sectorsRecovered)
		}
		return
	}

	// Check if keys were recovered
	if sectorsRecovered > 0 {
		WriteStatusSuccess("Key recovery successful! Recovered keys for %d sectors", sectorsRecovered)

		// Automatically dump the card data after key recovery
		WriteStatusProgress("Dumping card data...")
		fmt.Println()
		fmt.Println("hf mf dump")
		fmt.Println()

		dumpCmd := exec.Command(pm3Binary, "-c", "hf mf dump", "-p", device)
		dumpOutput, dumpErr := dumpCmd.CombinedOutput()
		dumpOutputStr := string(dumpOutput)
		fmt.Println(dumpOutputStr)

		var dumpFilePath string
		var keyFilePath string

		if dumpErr == nil {
			// Extract dump file location if available
			// Try pattern with backticks first (common in Proxmark3 output)
			dumpFileRegex := regexp.MustCompile(`Saved.*?to.*?file.*?[` + "`" + `'"]?([^` + "`" + `'"]+hf-mf-[A-F0-9]+-dump-[0-9]+\.(bin|eml))[` + "`" + `'"]?`)
			if matches := dumpFileRegex.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
				dumpFilePath = matches[1]
				WriteStatusSuccess("Card data dumped to: %s", dumpFilePath)
			} else {
				// Try pattern without backticks
				dumpFileRegex2 := regexp.MustCompile(`Saved.*?to.*?file.*?([/][^\s]+\.(bin|eml))`)
				if matches := dumpFileRegex2.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
					dumpFilePath = matches[1]
					WriteStatusSuccess("Card data dumped to: %s", dumpFilePath)
				} else {
					// Try alternative pattern for any dump file
					dumpFileRegex3 := regexp.MustCompile(`([/][^\s]+hf-mf-[A-F0-9]+-dump-[0-9]+\.(bin|eml))`)
					if matches := dumpFileRegex3.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
						dumpFilePath = matches[1]
						WriteStatusSuccess("Card data dumped to: %s", dumpFilePath)
					} else {
						WriteStatusSuccess("Card data dumped successfully")
					}
				}
			}

			// Extract key file location if available
			// Try pattern with backticks first
			keyFileRegex := regexp.MustCompile(`Saved.*?key.*?file.*?[` + "`" + `'"]?([/][^` + "`" + `'"]+hf-mf-[A-F0-9]+-key\.bin)[` + "`" + `'"]?`)
			if matches := keyFileRegex.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
				keyFilePath = matches[1]
				WriteStatusInfo("Keys saved to: %s", keyFilePath)
			} else {
				// Try pattern without backticks
				keyFileRegex2 := regexp.MustCompile(`Saved.*?key.*?file.*?([/][^\s]+\.bin)`)
				if matches := keyFileRegex2.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
					keyFilePath = matches[1]
					WriteStatusInfo("Keys saved to: %s", keyFilePath)
				} else {
					// Try alternative pattern for any key file
					keyFileRegex3 := regexp.MustCompile(`([/][^\s]+hf-mf-[A-F0-9]+-key\.bin)`)
					if matches := keyFileRegex3.FindStringSubmatch(dumpOutputStr); len(matches) > 1 {
						keyFilePath = matches[1]
						WriteStatusInfo("Keys saved to: %s", keyFilePath)
					}
				}
			}

			// Show summary of recovered keys
			parseAndDisplayKeySummary(outputStr)

			// Call callback to update GUI fields if provided
			if onFilePathsFound != nil {
				onFilePathsFound(dumpFilePath, keyFilePath)
			}

			// After successful dump, offer to write/restore to a new card
			if dumpFilePath != "" {
				WriteStatusInfo("")
				WriteStatusInfo("To write this data to a new card, use:")
				if keyFilePath != "" {
					WriteStatusInfo("  hf mf restore -f %s -k %s", dumpFilePath, keyFilePath)
				} else {
					WriteStatusInfo("  hf mf restore -f %s", dumpFilePath)
				}
			}

		} else {
			WriteStatusError("Dump failed: %v", dumpErr)
			WriteStatusInfo("You can manually dump with: hf mf dump")
		}
	} else {
		WriteStatusInfo("Recovery completed. Review output above for results.")
	}
}

// parseRecoveryOutput parses the autopwn output to count recovered sectors
func parseRecoveryOutput(output string) int {
	// Look for the key table summary - count sectors with at least one key recovered
	// Pattern: "[+]  000 | 003 | FFFFFFFFFFFF | D | FFFFFFFFFFFF | D "
	// or "[+]  001 | 007 | ------------ | 0 | ------------ | 0 " (failed)
	keyTableRegex := regexp.MustCompile(`\[\+\]\s+(\d{3})\s+\|\s+\d{3}\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([DSUNHRCA0])\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([DSUNHRCA0])`)
	matches := keyTableRegex.FindAllStringSubmatch(output, -1)

	if len(matches) > 0 {
		// Count sectors where at least one key was recovered (result is not "0")
		recoveredCount := 0
		for _, match := range matches {
			if len(match) >= 6 {
				keyAResult := match[3]
				keyBResult := match[5]
				// If either key was recovered (not "0"), count this sector
				if keyAResult != "0" || keyBResult != "0" {
					recoveredCount++
				}
			}
		}
		return recoveredCount
	}

	// Fallback: count "found valid key" messages
	foundKeyRegex := regexp.MustCompile(`found valid key`)
	matches2 := foundKeyRegex.FindAllStringSubmatch(output, -1)
	return len(matches2) / 2 // Divide by 2 since each sector has key A and key B
}

// parseAndDisplayKeySummary extracts and displays a clean summary of recovered keys
func parseAndDisplayKeySummary(output string) {
	// Extract key table section
	keyTableStart := strings.Index(output, "-----+-----+--------------+---+--------------+----")
	if keyTableStart == -1 {
		return
	}

	// Find the end of the key table (look for the legend line)
	keyTableSection := output[keyTableStart:]
	keyTableEnd := strings.Index(keyTableSection, "( D:Dictionary")
	if keyTableEnd == -1 {
		keyTableEnd = len(keyTableSection)
	}

	keyTableSection = keyTableSection[:keyTableEnd]
	lines := strings.Split(keyTableSection, "\n")

	var recoveredSectors []string
	var failedSectors []string
	var totalKeys int
	var keyAMethods = make(map[string]int) // Count by method
	var keyBMethods = make(map[string]int)

	// Parse each line in the key table
	keyLineRegex := regexp.MustCompile(`\[\+\]\s+(\d{3})\s+\|\s+\d{3}\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([DSUNHRCA0])\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([DSUNHRCA0])`)

	for _, line := range lines {
		if matches := keyLineRegex.FindStringSubmatch(line); len(matches) >= 6 {
			sectorNum := matches[1]
			keyA := matches[2]
			keyAResult := matches[3]
			keyB := matches[4]
			keyBResult := matches[5]

			// Track recovery methods
			if keyAResult != "0" && keyA != "------------" {
				totalKeys++
				keyAMethods[keyAResult]++
			}
			if keyBResult != "0" && keyB != "------------" {
				totalKeys++
				keyBMethods[keyBResult]++
			}

			// Track sectors
			if keyAResult != "0" || keyBResult != "0" {
				recoveredSectors = append(recoveredSectors, sectorNum)
			} else {
				failedSectors = append(failedSectors, sectorNum)
			}
		}
	}

	// Display summary
	WriteStatusInfo("")
	WriteStatusInfo("--- Recovery Summary ---")
	WriteStatusInfo("Sectors recovered: %d / 16", len(recoveredSectors))
	WriteStatusInfo("Total keys found: %d", totalKeys)

	if len(recoveredSectors) > 0 {
		WriteStatusSuccess("Recovered sectors: %s", strings.Join(recoveredSectors, ", "))
	}

	if len(failedSectors) > 0 {
		WriteStatusError("Failed sectors: %s", strings.Join(failedSectors, ", "))
	}

	// Show recovery methods used
	methodNames := map[string]string{
		"D": "Dictionary",
		"S": "Darkside",
		"U": "User",
		"R": "Reused",
		"N": "Nested",
		"H": "Hardnested",
		"C": "Static Nested",
		"A": "Key A",
	}

	var methodsUsed []string
	for method, count := range keyAMethods {
		if name, ok := methodNames[method]; ok {
			methodsUsed = append(methodsUsed, fmt.Sprintf("%s (%d)", name, count))
		}
	}
	for method, count := range keyBMethods {
		if name, ok := methodNames[method]; ok {
			// Check if already added
			found := false
			for i, m := range methodsUsed {
				if strings.Contains(m, name) {
					// Update count
					methodsUsed[i] = fmt.Sprintf("%s (%d)", name, count+keyAMethods[method])
					found = true
					break
				}
			}
			if !found {
				methodsUsed = append(methodsUsed, fmt.Sprintf("%s (%d)", name, count))
			}
		}
	}

	if len(methodsUsed) > 0 {
		WriteStatusInfo("Recovery methods: %s", strings.Join(methodsUsed, ", "))
	}
}

// executeMifareCommand executes a MIFARE command and displays output
func executeMifareCommand(cmdStr string, description string) (string, error) {
	if ok, msg := checkProxmark3(); !ok {
		WriteStatusError(msg)
		return "", fmt.Errorf("%s", msg)
	}

	pm3Binary, err := getPm3Path()
	if err != nil {
		WriteStatusError("Failed to find pm3 binary: %v", err)
		return "", err
	}

	device, err := getPm3Device()
	if err != nil {
		WriteStatusError("Failed to detect pm3 device: %v", err)
		return "", err
	}

	WriteStatusProgress(description)
	WriteStatusInfo("Place card on reader")

	fmt.Println(cmdStr)
	fmt.Println()

	cmd := exec.Command(pm3Binary, "-c", cmdStr, "-p", device)
	output, cmdErr := cmd.CombinedOutput()
	outputStr := string(output)
	fmt.Println(outputStr)

	return outputStr, cmdErr
}

// checkKeysFast executes hf mf fchk to check all keys on card
func checkKeysFast(keyFilePath string) {
	cmdStr := "hf mf fchk"
	if keyFilePath != "" {
		cmdStr = fmt.Sprintf("hf mf fchk -f %s", keyFilePath)
	}

	outputStr, cmdErr := executeMifareCommand(cmdStr, "Checking keys on card (fast check)...")

	if cmdErr != nil {
		WriteStatusError("Key check failed: %v", cmdErr)
		return
	}

	// Parse key check results from the table
	// Pattern from Proxmark3: "[+]  001 | 007 | 2A2C13CC242A | 1 | FFFFFFFFFFFF | 1"
	// The format string in Proxmark3 is: " " _YELLOW_("%03d") " | %03d | %s | %s | %s | %s %s"
	// PrintAndLogEx(SUCCESS, ...) adds the [+] prefix
	successCount := 0
	failedCount := 0

	// Extract all found keys from the table
	keyTableRegex := regexp.MustCompile(`\[\+\]\s+(\d{3})\s+\|\s+(\d{3})\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([01])\s+\|\s+([A-F0-9]{12}|-{12})\s+\|\s+([01])`)
	keyMatches := keyTableRegex.FindAllStringSubmatch(outputStr, -1)

	// Store keys by sector/block to group Key A and Key B together
	type sectorBlockKey struct {
		sector string
		block  string
	}
	type keyPair struct {
		keyA string
		keyB string
	}
	keysBySectorBlock := make(map[sectorBlockKey]keyPair)

	for _, match := range keyMatches {
		if len(match) >= 7 {
			sector := match[1]
			block := match[2]
			keyA := match[3]
			keyAResult := match[4]
			keyB := match[5]
			keyBResult := match[6]

			sbKey := sectorBlockKey{sector: sector, block: block}
			pair := keysBySectorBlock[sbKey]

			// Process key A
			if keyAResult == "1" && keyA != "------------" {
				pair.keyA = keyA
				successCount++
			} else if keyAResult == "0" {
				failedCount++
			}

			// Process key B
			if keyBResult == "1" && keyB != "------------" {
				pair.keyB = keyB
				successCount++
			} else if keyBResult == "0" {
				failedCount++
			}

			keysBySectorBlock[sbKey] = pair
		}
	}

	// Build sorted list: Key A first, then Key B for each sector/block
	var foundKeys []string
	var sortedSectors []sectorBlockKey
	for sbKey := range keysBySectorBlock {
		sortedSectors = append(sortedSectors, sbKey)
	}
	// Sort by sector, then block
	sort.Slice(sortedSectors, func(i, j int) bool {
		if sortedSectors[i].sector != sortedSectors[j].sector {
			return sortedSectors[i].sector < sortedSectors[j].sector
		}
		return sortedSectors[i].block < sortedSectors[j].block
	})

	for _, sbKey := range sortedSectors {
		pair := keysBySectorBlock[sbKey]
		// Add Key A first
		if pair.keyA != "" {
			foundKeys = append(foundKeys, fmt.Sprintf("Sector %s Block %s Key A: %s", sbKey.sector, sbKey.block, pair.keyA))
		}
		// Then Key B
		if pair.keyB != "" {
			foundKeys = append(foundKeys, fmt.Sprintf("Sector %s Block %s Key B: %s", sbKey.sector, sbKey.block, pair.keyB))
		}
	}

	// Also check for summary line pattern: "( 0:Failed / 1:Success )" for more accurate counts
	summaryRegex := regexp.MustCompile(`\(\s*(\d+):Failed\s*/\s*(\d+):Success\s*\)`)
	if summaryMatch := summaryRegex.FindStringSubmatch(outputStr); len(summaryMatch) >= 3 {
		// Use summary counts if available (more accurate)
		var failedFromSummary, successFromSummary int
		fmt.Sscanf(summaryMatch[1], "%d", &failedFromSummary)
		fmt.Sscanf(summaryMatch[2], "%d", &successFromSummary)
		if failedFromSummary > 0 || successFromSummary > 0 {
			failedCount = failedFromSummary
			successCount = successFromSummary
		}
	}

	// Always display keys if found, regardless of count source
	if len(foundKeys) > 0 {
		WriteStatusSuccess("Found %d valid keys", successCount)
		if failedCount > 0 {
			WriteStatusInfo("%d keys failed authentication", failedCount)
		}
		WriteStatusInfo("")
		WriteStatusInfo("--- Found Keys ---")
		for _, keyInfo := range foundKeys {
			WriteStatusInfo(keyInfo)
		}
	} else if successCount > 0 {
		WriteStatusSuccess("Found %d valid keys", successCount)
		if failedCount > 0 {
			WriteStatusInfo("%d keys failed authentication", failedCount)
		}
		WriteStatusInfo("(Keys found but format not recognized - see full output)")
	} else {
		WriteStatusError("No valid keys found")
	}
}

// min helper function
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// getCardInfo executes hf mf info to get detailed card information
func getCardInfo() {
	outputStr, cmdErr := executeMifareCommand("hf mf info", "Getting detailed card information...")

	if cmdErr != nil {
		WriteStatusError("Failed to get card info: %v", cmdErr)
		return
	}

	// Extract UID - format is " UID: 5A F7 0D 9D" or " UID: 5AF70D9D"
	// Try with spaces first, then without
	uidRegex1 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{2}(?:\s+[A-F0-9]{2})+)`)
	if uidMatch := uidRegex1.FindStringSubmatch(outputStr); len(uidMatch) > 1 {
		// Remove spaces from UID
		uid := strings.ReplaceAll(uidMatch[1], " ", "")
		WriteStatusSuccess("Card UID: %s", uid)
	} else {
		// Try without spaces
		uidRegex2 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{8,14})`)
		if uidMatch := uidRegex2.FindStringSubmatch(outputStr); len(uidMatch) > 1 {
			WriteStatusSuccess("Card UID: %s", uidMatch[1])
		}
	}

	// Extract card type
	if strings.Contains(outputStr, "MIFARE Classic") {
		WriteStatusInfo("Card Type: MIFARE Classic")
		if strings.Contains(outputStr, "1K") {
			WriteStatusInfo("Size: 1K (16 sectors)")
		} else if strings.Contains(outputStr, "4K") {
			WriteStatusInfo("Size: 4K (40 sectors)")
		}
	}

	// Extract magic capabilities
	if strings.Contains(outputStr, "Magic capabilities") {
		magicRegex := regexp.MustCompile(`Magic capabilities\.\.\.\s+([^\n]+)`)
		if magicMatch := magicRegex.FindStringSubmatch(outputStr); len(magicMatch) > 1 {
			WriteStatusInfo("Magic: %s", strings.TrimSpace(magicMatch[1]))
		}
	}

	// Extract PRNG info
	if strings.Contains(outputStr, "Prng") {
		prngRegex := regexp.MustCompile(`Prng[^:]*:\s*([^\n]+)`)
		if prngMatch := prngRegex.FindStringSubmatch(outputStr); len(prngMatch) > 1 {
			WriteStatusInfo("PRNG: %s", strings.TrimSpace(prngMatch[1]))
		}
	}

	// Check for Saflok
	if strings.Contains(outputStr, "Saflok") {
		WriteStatusInfo("Detected: Saflok hotel key card")
	}
}

// setMagicCardUID executes hf mf csetuid to set UID on Chinese magic card
func setMagicCardUID(uid string) {
	if uid == "" {
		WriteStatusError("UID is required")
		return
	}
	cmdStr := fmt.Sprintf("hf mf csetuid -u %s", uid)

	outputStr, cmdErr := executeMifareCommand(cmdStr, "Setting UID on magic card...")

	if cmdErr != nil {
		WriteStatusError("Failed to set UID: %v", cmdErr)
		return
	}

	// Check for success
	if strings.Contains(outputStr, "success") || strings.Contains(outputStr, "Success") ||
		strings.Contains(outputStr, "OK") || strings.Contains(outputStr, "ok") {
		WriteStatusSuccess("UID set successfully: %s", uid)
	} else if strings.Contains(outputStr, "error") || strings.Contains(outputStr, "Error") ||
		strings.Contains(outputStr, "failed") || strings.Contains(outputStr, "Failed") {
		WriteStatusError("Failed to set UID")
	} else {
		WriteStatusInfo("UID operation completed - review output for confirmation")
	}
}
