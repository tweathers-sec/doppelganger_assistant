package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
)

// readCardData reads card data from the Proxmark3 for the specified card type
func readCardData(cardType string) {
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

	WriteStatusProgress("Reading card - place card flat on reader...")

	if IsOperationCancelled() {
		WriteStatusInfo("Operation cancelled by user")
		return
	}

	var cmdStr string
	var cmd *exec.Cmd
	var parser func(string) (map[string]interface{}, error)

	switch cardType {
	case "prox":
		cmdStr = fmt.Sprintf("lf hid reader -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "lf hid reader", "-p", device)
		parser = parseHIDReaderOutput
	case "iclass":
		// Use dump to get card data, then decrypt and decode block 7 for Wiegand FC/CN
		// The dump command will automatically decrypt and decode if using standard keys
		cmdStr = fmt.Sprintf("hf iclass dump --ki 0 -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "hf iclass dump --ki 0", "-p", device)
		parser = parseICLASSReaderOutput
	case "awid":
		cmdStr = fmt.Sprintf("lf awid reader -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "lf awid reader", "-p", device)
		parser = parseAWIDReaderOutput
	case "indala":
		cmdStr = fmt.Sprintf("lf indala reader -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "lf indala reader", "-p", device)
		parser = parseIndalaReaderOutput
	case "avigilon":
		cmdStr = fmt.Sprintf("lf hid reader -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "lf hid reader", "-p", device)
		parser = parseAvigilonReaderOutput
	case "em":
		cmdStr = fmt.Sprintf("lf em 410x reader -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "lf em 410x reader", "-p", device)
		parser = parseEM4100ReaderOutput
	case "piv", "mifare":
		cmdStr = fmt.Sprintf("hf mf info -p %s", device)
		cmd = exec.Command(pm3Binary, "-c", "hf mf info", "-p", device)
		parser = parseMIFAREReaderOutput
	default:
		WriteStatusError("Unsupported card type for reading")
		return
	}

	// Print command to command output window
	fmt.Println(cmdStr)
	fmt.Println()

	output, cmdErr := cmd.CombinedOutput()
	outputStr := string(output)

	// Print full raw output to command output window
	fmt.Println("--- Raw Proxmark3 Output ---")
	fmt.Println(outputStr)
	fmt.Println("--- End of Output ---")

	// For iCLASS, if dump fails, check if card is encrypted
	if cardType == "iclass" && cmdErr != nil {
		if strings.Contains(outputStr, "authentication") || strings.Contains(outputStr, "key") {
			WriteStatusError("Card may be encrypted. Try using 'hf iclass decrypt' with the correct key.")
			WriteStatusInfo("Raw output: %s", outputStr)
			return
		}
		WriteStatusError("Failed to read card: %v", cmdErr)
		WriteStatusInfo("Raw output: %s", outputStr)
		return
	}

	if cmdErr != nil {
		WriteStatusError("Failed to read card: %v", cmdErr)
		return
	}

	// Try to parse the output
	cardData, parseErr := parser(outputStr)
	if parseErr != nil {
		WriteStatusInfo("Could not parse card data automatically. See raw output below.")
		// For iCLASS, check if CSN is in raw output but FC/CN is missing
		if cardType == "iclass" {
			if strings.Contains(outputStr, "CSN:") && !strings.Contains(outputStr, "FC:") {
				WriteStatusInfo("Card has CSN but FC/CN not found. Card may be encrypted.")
				WriteStatusInfo("Try: hf iclass decrypt -f <dump_file> -k <key>")
			}
		}
		return
	}

	// For iCLASS, if we parsed but don't have FC/CN, check if we need to decrypt first
	if cardType == "iclass" {
		if _, hasFC := cardData["facilityCode"]; !hasFC {
			// Check if block 7 is encrypted (shows as "Enc Cred" in dump)
			if strings.Contains(outputStr, "Enc Cred") && strings.Contains(outputStr, "Block 7 decoder") == false {
				// Card is encrypted, need to decrypt first
				WriteStatusInfo("Card appears encrypted. Attempting to decrypt...")

				// Extract dump filename from output
				dumpFileRegex := regexp.MustCompile(`Saved.*?to binary file ` + "`" + `([^` + "`" + `]+)` + "`")
				if matches := dumpFileRegex.FindStringSubmatch(outputStr); len(matches) > 1 {
					if IsOperationCancelled() {
						WriteStatusInfo("Operation cancelled by user")
						return
					}
					dumpFile := matches[1]
					fmt.Println()
					fmt.Printf("hf iclass decrypt -f %s\n", dumpFile)

					// Run decrypt command
					decryptCmd := exec.Command(pm3Binary, "-c", fmt.Sprintf("hf iclass decrypt -f %s", dumpFile), "-p", device)
					decryptOutput, decryptErr := decryptCmd.CombinedOutput()
					if decryptErr == nil {
						decryptStr := string(decryptOutput)
						fmt.Println(decryptStr)

						decryptedData, _ := parseICLASSReaderOutput(decryptStr)
						if decryptedData != nil {
							if fc, ok := decryptedData["facilityCode"].(int); ok && fc > 0 {
								cardData["facilityCode"] = fc
							}
							if cn, ok := decryptedData["cardNumber"].(int); ok && cn > 0 {
								cardData["cardNumber"] = cn
							}
							if format, ok := decryptedData["format"].(string); ok {
								cardData["format"] = format
							}
							if bl, ok := decryptedData["bitLength"].(int); ok {
								cardData["bitLength"] = bl
							}
						}

						// Fallback: decode block 7 hex if FC/CN not found
						if _, hasFC := cardData["facilityCode"]; !hasFC {
							block7Hex := extractBlock7Hex(decryptStr)
							if block7Hex != "" {
								WriteStatusInfo("Attempting alternative decode of block 7 hex...")
								fmt.Println()
								fmt.Printf("wiegand decode --raw %s --force\n", block7Hex)

								decodeCmd := exec.Command(pm3Binary, "-c", fmt.Sprintf("wiegand decode --raw %s --force", block7Hex), "-p", device)
								decodeOutput, _ := decodeCmd.CombinedOutput()
								fmt.Println(string(decodeOutput))

								// Try to parse decode output
								if decodedData, err := parseICLASSReaderOutput(string(decodeOutput)); err == nil {
									if fc, ok := decodedData["facilityCode"].(int); ok && fc > 0 {
										cardData["facilityCode"] = fc
									}
									if cn, ok := decodedData["cardNumber"].(int); ok && cn > 0 {
										cardData["cardNumber"] = cn
									}
									if format, ok := decodedData["format"].(string); ok {
										cardData["format"] = format
									}
									if bl, ok := decodedData["bitLength"].(int); ok {
										cardData["bitLength"] = bl
									}
								}
							}
						}
					}
				}
			} else if _, hasCSN := cardData["csn"]; hasCSN {
				WriteStatusInfo("Note: Card has CSN but FC/CN not decoded. Block 7 format may not be recognized by decoder.")
			}
		}
	}

	// Display parsed card data in status window
	displayCardData(cardType, cardData)
}

// parseHIDReaderOutput parses HID Prox card reader output
func parseHIDReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Look for FC and Card Number - try multiple patterns
	// Pattern 1: "FC: 111" or "FC:111"
	fcRegex := regexp.MustCompile(`FC:\s*(\d+)`)
	// Pattern 2: "FC: 111 CN: 1111" on same line
	fcCnRegex := regexp.MustCompile(`FC:\s*(\d+).*?CN:\s*(\d+)`)
	// Pattern 3: Just "FC: 111" followed by CN on same or next line
	cnRegex := regexp.MustCompile(`(?:Card|CN):\s*(\d+)`)

	// Try combined pattern first
	if matches := fcCnRegex.FindStringSubmatch(output); len(matches) >= 3 {
		if fc, err := strconv.Atoi(matches[1]); err == nil {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[2]); err == nil {
			data["cardNumber"] = cn
		}
	} else {
		// Try individual patterns
		if matches := fcRegex.FindStringSubmatch(output); len(matches) > 1 {
			if fc, err := strconv.Atoi(matches[1]); err == nil {
				data["facilityCode"] = fc
			}
		}
		if matches := cnRegex.FindStringSubmatch(output); len(matches) > 1 {
			if cn, err := strconv.Atoi(matches[1]); err == nil {
				data["cardNumber"] = cn
			}
		}
	}

	// Look for format - try multiple patterns
	// Pattern 1: "Format: H10301"
	formatRegex := regexp.MustCompile(`Format:\s*(\w+)`)
	// Pattern 2: "[H10301]" or "[Avig56]"
	formatBracketRegex := regexp.MustCompile(`\[(\w+)\]`)
	// Pattern 3: "H10301" or "Avig56" as standalone word
	formatWordRegex := regexp.MustCompile(`\b(H10301|H10302|H10304|H10306|ATSW30|ADT31|D10202|C1k35s|S12906|H800002|C1k48s|Avig56|2804W|IR56)\b`)

	if matches := formatRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["format"] = matches[1]
	} else if matches := formatBracketRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["format"] = matches[1]
	} else if matches := formatWordRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["format"] = matches[1]
	}

	// Look for raw and wiegand data
	rawRegex := regexp.MustCompile(`Raw:\s*([0-9a-fA-F]+)`)
	wiegandRegex := regexp.MustCompile(`Wiegand:\s*([0-9a-fA-F]+)`)

	if matches := rawRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["raw"] = matches[1]
	}

	if matches := wiegandRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["wiegand"] = matches[1]
	}

	// Try to detect bit length from format
	if format, ok := data["format"].(string); ok {
		bitLengthMap := map[string]int{
			"H10301": 26, "H10302": 37, "H10304": 37, "H10306": 34,
			"ATSW30": 30, "ADT31": 31, "D10202": 33, "C1k35s": 35,
			"S12906": 36, "H800002": 46, "C1k48s": 48, "Avig56": 56,
			"2804W": 28, "IR56": 56,
		}
		if bl, exists := bitLengthMap[format]; exists {
			data["bitLength"] = bl
		}
	}

	// Try to detect bit length from output text (e.g., "26-bit", "56-bit")
	bitLengthRegex := regexp.MustCompile(`(\d+)[-\s]bit`)
	if matches := bitLengthRegex.FindStringSubmatch(output); len(matches) > 1 {
		if bl, err := strconv.Atoi(matches[1]); err == nil {
			if _, exists := data["bitLength"]; !exists {
				data["bitLength"] = bl
			}
		}
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// parseICLASSReaderOutput parses iCLASS card dump output
// The dump command automatically decodes block 7 and shows Wiegand FC/CN
func parseICLASSReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Extract CSN (Card Serial Number)
	csnRegex := regexp.MustCompile(`CSN:\s*([0-9a-fA-F\s]+)`)
	if matches := csnRegex.FindStringSubmatch(output); len(matches) > 1 {
		csn := strings.ReplaceAll(strings.TrimSpace(matches[1]), " ", "")
		data["csn"] = csn
	}

	// Extract decoded Wiegand format output
	// Pattern 1: Format name with FC/CN in brackets
	formatFcCnRegex1 := regexp.MustCompile(`\[(\w+)\]\s+.*?FC:\s*(\d+).*?(?:Card|CN):\s*(\d+)`)
	// Pattern 2: Format name with FC/CN without brackets (e.g., "H10301 FC: 123 Card: 456")
	formatFcCnRegex2 := regexp.MustCompile(`(\w+)\s+.*?FC:\s*(\d+).*?(?:Card|CN):\s*(\d+)`)
	// Pattern 3: "FC: 123 Card: 456" or "FC: 123 CN: 456"
	fcCnRegex := regexp.MustCompile(`FC:\s*(\d+).*?(?:Card|CN):\s*(\d+)`)
	// Pattern 4: Separate FC and Card lines
	fcRegex := regexp.MustCompile(`FC:\s*(\d+)`)
	cnRegex := regexp.MustCompile(`(?:Card|CN):\s*(\d+)`)

	// Try combined format+FC+CN patterns first
	if matches := formatFcCnRegex1.FindStringSubmatch(output); len(matches) >= 4 {
		data["format"] = matches[1]
		if fc, err := strconv.Atoi(matches[2]); err == nil && fc > 0 {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[3]); err == nil && cn > 0 {
			data["cardNumber"] = cn
		}
	} else if matches := formatFcCnRegex2.FindStringSubmatch(output); len(matches) >= 4 {
		// Try format without brackets
		data["format"] = matches[1]
		if fc, err := strconv.Atoi(matches[2]); err == nil && fc > 0 {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[3]); err == nil && cn > 0 {
			data["cardNumber"] = cn
		}
	} else if matches := fcCnRegex.FindStringSubmatch(output); len(matches) >= 3 {
		// Try FC+CN pattern - extract even if parity fails
		if fc, err := strconv.Atoi(matches[1]); err == nil && fc > 0 {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[2]); err == nil && cn > 0 {
			data["cardNumber"] = cn
		}
	} else {
		// Try individual patterns
		if matches := fcRegex.FindStringSubmatch(output); len(matches) > 1 {
			if fc, err := strconv.Atoi(matches[1]); err == nil && fc > 0 {
				data["facilityCode"] = fc
			}
		}
		if matches := cnRegex.FindStringSubmatch(output); len(matches) > 1 {
			if cn, err := strconv.Atoi(matches[1]); err == nil && cn > 0 {
				data["cardNumber"] = cn
			}
		}
	}

	// Look for format name - try multiple patterns
	formatRegex := regexp.MustCompile(`Format:\s*(\w+)`)
	formatBracketRegex := regexp.MustCompile(`\[(\w+)\]`)
	formatWordRegex := regexp.MustCompile(`\b(H10301|H10302|H10304|H10306|ATSW30|ADT31|D10202|C1k35s|S12906|H800002|C1k48s)\b`)

	if _, exists := data["format"]; !exists {
		if matches := formatRegex.FindStringSubmatch(output); len(matches) > 1 {
			data["format"] = matches[1]
		} else if matches := formatBracketRegex.FindStringSubmatch(output); len(matches) > 1 {
			data["format"] = matches[1]
		} else if matches := formatWordRegex.FindStringSubmatch(output); len(matches) > 1 {
			data["format"] = matches[1]
		}
	}

	// Map format to bit length
	if format, ok := data["format"].(string); ok {
		bitLengthMap := map[string]int{
			"H10301": 26, "H10302": 37, "H10304": 37, "H10306": 34,
			"ATSW30": 30, "ADT31": 31, "D10202": 33, "C1k35s": 35,
			"S12906": 36, "H800002": 46, "C1k48s": 48,
		}
		if bl, exists := bitLengthMap[format]; exists {
			data["bitLength"] = bl
		}
	}

	// Try to detect bit length from output text (e.g., "26-bit", "HID H10301 26-bit")
	bitLengthRegex := regexp.MustCompile(`(\d+)[-\s]bit`)
	if matches := bitLengthRegex.FindStringSubmatch(output); len(matches) > 1 {
		if bl, err := strconv.Atoi(matches[1]); err == nil {
			if _, exists := data["bitLength"]; !exists {
				data["bitLength"] = bl
			}
		}
	}

	// Check if block 7 is encrypted (would need decrypt command)
	if strings.Contains(output, "encrypted") || strings.Contains(output, "Block 7 decoder") == false {
		// Check if card is encrypted (has CSN but no FC/CN)
		if _, hasFC := data["facilityCode"]; !hasFC {
			if _, hasCSN := data["csn"]; hasCSN {
				data["encrypted"] = true
			}
		}
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// extractBlock7Hex extracts block 7 hex data from iCLASS dump/decrypt output
func extractBlock7Hex(output string) string {
	// Look for block 7 line: "7/0x07 | 00 00 00 00 04 02 FA B7 |"
	block7Regex := regexp.MustCompile(`7/0x07\s+\|\s+([0-9a-fA-F\s]+)\s+\|`)
	if matches := block7Regex.FindStringSubmatch(output); len(matches) > 1 {
		// Remove spaces and convert to uppercase
		hexStr := strings.ReplaceAll(strings.TrimSpace(matches[1]), " ", "")
		hexStr = strings.ToUpper(hexStr)
		// Block 7 is 16 hex chars (8 bytes)
		if len(hexStr) == 16 {
			return hexStr
		}
	}
	return ""
}

// parseAWIDReaderOutput parses AWID card reader output
func parseAWIDReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Try multiple patterns for FC and CN
	fcRegex := regexp.MustCompile(`FC:\s*(\d+)`)
	fcCnRegex := regexp.MustCompile(`FC:\s*(\d+).*?Card:\s*(\d+)`)
	cnRegex := regexp.MustCompile(`(?:Card|CN):\s*(\d+)`)
	rawRegex := regexp.MustCompile(`Raw:\s*([0-9a-fA-F]+)`)
	lenRegex := regexp.MustCompile(`(?:len|length):\s*(\d+)`)
	bitLengthRegex := regexp.MustCompile(`(\d+)[-\s]bit`)

	// Try combined pattern first
	if matches := fcCnRegex.FindStringSubmatch(output); len(matches) >= 3 {
		if fc, err := strconv.Atoi(matches[1]); err == nil {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[2]); err == nil {
			data["cardNumber"] = cn
		}
	} else {
		if matches := fcRegex.FindStringSubmatch(output); len(matches) > 1 {
			if fc, err := strconv.Atoi(matches[1]); err == nil {
				data["facilityCode"] = fc
			}
		}
		if matches := cnRegex.FindStringSubmatch(output); len(matches) > 1 {
			if cn, err := strconv.Atoi(matches[1]); err == nil {
				data["cardNumber"] = cn
			}
		}
	}

	if matches := rawRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["raw"] = matches[1]
	}

	// Try multiple patterns for bit length
	if matches := lenRegex.FindStringSubmatch(output); len(matches) > 1 {
		if bl, err := strconv.Atoi(matches[1]); err == nil {
			data["bitLength"] = bl
		}
	} else if matches := bitLengthRegex.FindStringSubmatch(output); len(matches) > 1 {
		if bl, err := strconv.Atoi(matches[1]); err == nil {
			data["bitLength"] = bl
		}
	} else {
		// AWID is typically 26 or 50 bit
		if strings.Contains(output, "50") || strings.Contains(output, "fifty") {
			data["bitLength"] = 50
		} else {
			data["bitLength"] = 26 // Default for AWID
		}
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// parseIndalaReaderOutput parses Indala card reader output
func parseIndalaReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	fcRegex := regexp.MustCompile(`FC:\s*(\d+)`)
	fcCnRegex := regexp.MustCompile(`FC:\s*(\d+).*?Card:\s*(\d+)`)
	cnRegex := regexp.MustCompile(`(?:Card|CN):\s*(\d+)`)
	rawRegex := regexp.MustCompile(`Raw:\s*([0-9a-fA-F]+)`)
	lenRegex := regexp.MustCompile(`(?:\(len\s+(\d+)\)|len:\s*(\d+)|(\d+)[-\s]bit)`)

	// Try combined pattern first
	if matches := fcCnRegex.FindStringSubmatch(output); len(matches) >= 3 {
		if fc, err := strconv.Atoi(matches[1]); err == nil {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[2]); err == nil {
			data["cardNumber"] = cn
		}
	} else {
		if matches := fcRegex.FindStringSubmatch(output); len(matches) > 1 {
			if fc, err := strconv.Atoi(matches[1]); err == nil {
				data["facilityCode"] = fc
			}
		}
		if matches := cnRegex.FindStringSubmatch(output); len(matches) > 1 {
			if cn, err := strconv.Atoi(matches[1]); err == nil {
				data["cardNumber"] = cn
			}
		}
	}

	if matches := rawRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["raw"] = matches[1]
	}

	// Try multiple patterns for bit length
	if matches := lenRegex.FindStringSubmatch(output); len(matches) > 1 {
		for i := 1; i < len(matches); i++ {
			if matches[i] != "" {
				if bl, err := strconv.Atoi(matches[i]); err == nil {
					data["bitLength"] = bl
					break
				}
			}
		}
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// parseAvigilonReaderOutput parses Avigilon card reader output
func parseAvigilonReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Avigilon uses Avig56 format
	if strings.Contains(output, "Avig56") || strings.Contains(output, "Avigilon") {
		data["format"] = "Avig56"
		data["bitLength"] = 56
	}

	// Try multiple patterns for FC and CN
	fcRegex := regexp.MustCompile(`FC:\s*(\d+)`)
	fcCnRegex := regexp.MustCompile(`FC:\s*(\d+).*?CN:\s*(\d+)`)
	cnRegex := regexp.MustCompile(`(?:Card|CN):\s*(\d+)`)
	rawRegex := regexp.MustCompile(`Raw:\s*([0-9a-fA-F]+)`)

	// Try combined pattern first
	if matches := fcCnRegex.FindStringSubmatch(output); len(matches) >= 3 {
		if fc, err := strconv.Atoi(matches[1]); err == nil {
			data["facilityCode"] = fc
		}
		if cn, err := strconv.Atoi(matches[2]); err == nil {
			data["cardNumber"] = cn
		}
	} else {
		if matches := fcRegex.FindStringSubmatch(output); len(matches) > 1 {
			if fc, err := strconv.Atoi(matches[1]); err == nil {
				data["facilityCode"] = fc
			}
		}
		if matches := cnRegex.FindStringSubmatch(output); len(matches) > 1 {
			if cn, err := strconv.Atoi(matches[1]); err == nil {
				data["cardNumber"] = cn
			}
		}
	}

	if matches := rawRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["raw"] = matches[1]
	}

	// Ensure bit length is set
	if _, exists := data["bitLength"]; !exists {
		data["bitLength"] = 56
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// parseEM4100ReaderOutput parses EM4100 card reader output
func parseEM4100ReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Look for EM 410x ID
	idRegex := regexp.MustCompile(`EM\s+410x\s+ID\s+([0-9a-fA-F]+)`)
	if matches := idRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["hexData"] = strings.ToUpper(matches[1])
		data["bitLength"] = 32 // EM4100 is 32-bit
	} else {
		// Try alternative format
		idRegex2 := regexp.MustCompile(`ID:\s*([0-9a-fA-F]+)`)
		if matches := idRegex2.FindStringSubmatch(output); len(matches) > 1 {
			data["hexData"] = strings.ToUpper(matches[1])
			data["bitLength"] = 32
		}
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// parseMIFAREReaderOutput parses MIFARE/PIV card reader output
func parseMIFAREReaderOutput(output string) (map[string]interface{}, error) {
	data := make(map[string]interface{})

	// Look for UID
	uidRegex := regexp.MustCompile(`UID:\s*([0-9a-fA-F\s]+)`)
	if matches := uidRegex.FindStringSubmatch(output); len(matches) > 1 {
		uid := strings.ReplaceAll(strings.TrimSpace(matches[1]), " ", "")
		data["uid"] = strings.ToUpper(uid)
	}

	// Look for ATQA, SAK, etc.
	atqaRegex := regexp.MustCompile(`ATQA:\s*([0-9a-fA-F\s]+)`)
	if matches := atqaRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["atqa"] = strings.ReplaceAll(strings.TrimSpace(matches[1]), " ", "")
	}

	sakRegex := regexp.MustCompile(`SAK:\s*([0-9a-fA-F\s]+)`)
	if matches := sakRegex.FindStringSubmatch(output); len(matches) > 1 {
		data["sak"] = strings.ReplaceAll(strings.TrimSpace(matches[1]), " ", "")
	}

	if len(data) == 0 {
		return nil, fmt.Errorf("no card data found in output")
	}

	return data, nil
}

// displayCardData displays the parsed card data in a user-friendly format
func displayCardData(cardType string, cardData map[string]interface{}) {
	WriteStatusSuccess("Card read successfully!")
	WriteStatusInfo("")
	WriteStatusInfo("--- Card Data ---")

	// Map internal card type to display name
	cardTypeMap := map[string]string{
		"prox":     "PROX",
		"iclass":   "iCLASS",
		"awid":     "AWID",
		"indala":   "Indala",
		"avigilon": "Avigilon",
		"em":       "EM4100 / Net2",
		"piv":      "PIV",
		"mifare":   "MIFARE",
	}

	displayType := cardTypeMap[cardType]
	if displayType == "" {
		displayType = strings.ToUpper(cardType)
	}
	// Always show Card Type
	WriteStatusInfo("Card Type: %s", displayType)

	// Only show FC/CN/Bit Length for card types that use them
	// MIFARE and PIV use UID/ATQA/SAK instead
	if cardType != "mifare" && cardType != "piv" {
		if fc, ok := cardData["facilityCode"].(int); ok {
			WriteStatusInfo("Facility Code: %d", fc)
		} else {
			WriteStatusInfo("Facility Code: N/A")
		}

		if cn, ok := cardData["cardNumber"].(int); ok {
			WriteStatusInfo("Card Number: %d", cn)
		} else {
			WriteStatusInfo("Card Number: N/A")
		}

		if bl, ok := cardData["bitLength"].(int); ok {
			WriteStatusInfo("Bit Length: %d", bl)
		} else {
			WriteStatusInfo("Bit Length: N/A")
		}
	}

	// Show additional card-specific data
	switch cardType {
	case "prox", "avigilon":
		if format, ok := cardData["format"].(string); ok {
			WriteStatusInfo("Format: %s", format)
		}
		if raw, ok := cardData["raw"].(string); ok {
			WriteStatusInfo("Raw: %s", raw)
		}
		if wiegand, ok := cardData["wiegand"].(string); ok {
			WriteStatusInfo("Wiegand: %s", wiegand)
		}

	case "iclass":
		if csn, ok := cardData["csn"].(string); ok {
			WriteStatusInfo("CSN: %s", csn)
		}
		if format, ok := cardData["format"].(string); ok {
			WriteStatusInfo("Format: %s", format)
		}

	case "awid", "indala":
		if raw, ok := cardData["raw"].(string); ok {
			WriteStatusInfo("Raw: %s", raw)
		}

	case "em":
		if hexData, ok := cardData["hexData"].(string); ok {
			WriteStatusInfo("Hex Data: %s", hexData)
		}

	case "piv", "mifare":
		if uid, ok := cardData["uid"].(string); ok {
			WriteStatusInfo("UID: %s", uid)
		}
		if atqa, ok := cardData["atqa"].(string); ok {
			WriteStatusInfo("ATQA: %s", atqa)
		}
		if sak, ok := cardData["sak"].(string); ok {
			WriteStatusInfo("SAK: %s", sak)
		}
	}

	WriteStatusInfo("")
	WriteStatusSuccess("Use this data to write or verify cards")
}
