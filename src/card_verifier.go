package main

import (
	"fmt"
	"os/exec"
	"regexp"
	"strings"
)

func verifyCardData(cardType string, facilityCode, cardNumber, bitLength int, hexData string, uid string) {
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

	fmt.Println("\n|----------- VERIFICATION -----------|")
	WriteStatusProgress("Verifying card data - place card flat on reader...")

	if IsOperationCancelled() {
		WriteStatusInfo("Operation cancelled by user")
		return
	}

	var cmd *exec.Cmd
	switch cardType {
	case "iclass":
		// Use dump to get full card data, then decrypt and decode block 7 for verification
		cmd = exec.Command(pm3Binary, "-c", "hf iclass dump --ki 0", "-p", device)
	case "prox":
		cmd = exec.Command(pm3Binary, "-c", "lf hid reader", "-p", device)
	case "awid":
		cmd = exec.Command(pm3Binary, "-c", "lf awid reader", "-p", device)
	case "indala":
		cmd = exec.Command(pm3Binary, "-c", "lf indala reader", "-p", device)
	case "avigilon":
		cmd = exec.Command(pm3Binary, "-c", "lf hid reader", "-p", device)
	case "em":
		cmd = exec.Command(pm3Binary, "-c", "lf em 410x reader", "-p", device)
	case "piv", "mifare":
		cmd = exec.Command(pm3Binary, "-c", "hf mf info", "-p", device)
	default:
		WriteStatusError("Unsupported card type for verification")
		return
	}

	output, cmdErr := cmd.CombinedOutput()
	if cmdErr != nil {
		WriteStatusError("Failed to read card data: %v", cmdErr)
		return
	}

	outputStr := string(output)
	fmt.Println(outputStr)

	if cardType == "iclass" {
		// Parse the dump output to get FC/CN/bit length
		cardData, _ := parseICLASSReaderOutput(outputStr)

		// Check if FC/CN is available, decrypt if needed
		if _, hasFC := cardData["facilityCode"]; !hasFC {
			// Check if block 7 is encrypted (shows as "Enc Cred" in dump)
			if strings.Contains(outputStr, "Enc Cred") && !strings.Contains(outputStr, "Block 7 decoder") {
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

						cardData, _ = parseICLASSReaderOutput(decryptStr)

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

								decodedData, _ := parseICLASSReaderOutput(string(decodeOutput))
								if decodedData != nil {
									// Merge decoded data into cardData
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
			}
		}

		// Verify FC/CN/bit length match
		if cardData != nil {
			readFC, hasFC := cardData["facilityCode"].(int)
			readCN, hasCN := cardData["cardNumber"].(int)
			readBL, hasBL := cardData["bitLength"].(int)

			if hasFC && hasCN && hasBL {
				if readFC == facilityCode && readCN == cardNumber && readBL == bitLength {
					WriteStatusSuccess("Verification successful - FC, CN, and Bit Length match")
					WriteStatusSuccess("Card contains: %d-bit, FC: %d, CN: %d", readBL, readFC, readCN)
					return
				} else {
					WriteStatusError("Verification failed - data mismatch")
					WriteStatusInfo("Expected: %d-bit, FC: %d, CN: %d", bitLength, facilityCode, cardNumber)
					WriteStatusInfo("Read: %d-bit, FC: %d, CN: %d", readBL, readFC, readCN)
					return
				}
			} else if hasFC && hasCN {
				// Verify FC/CN if bit length is not available
				if readFC == facilityCode && readCN == cardNumber {
					WriteStatusSuccess("Verification successful - FC and CN match")
					WriteStatusInfo("Card contains: FC: %d, CN: %d", readFC, readCN)
					if hasBL {
						WriteStatusInfo("Bit Length: %d (expected %d)", readBL, bitLength)
					}
					return
				} else {
					WriteStatusError("Verification failed - FC/CN mismatch")
					WriteStatusInfo("Expected: FC: %d, CN: %d", facilityCode, cardNumber)
					WriteStatusInfo("Read: FC: %d, CN: %d", readFC, readCN)
					return
				}
			}
		}

		WriteStatusError("Verification failed - unable to decode card data")
		return
	} else {
		lines := strings.Split(outputStr, "\n")
		for _, line := range lines {
			if cardType == "awid" || cardType == "indala" {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("Card: %d", cardNumber)) {
					WriteStatusSuccess("Verification successful - FC and CN match")
					return
				}
			} else if cardType == "avigilon" {
				if strings.Contains(line, "[Avig56") && strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("CN: %d", cardNumber)) {
					WriteStatusSuccess("Verification successful - Avigilon FC and CN match")
					return
				}
			} else if cardType == "em" {
				if strings.Contains(line, fmt.Sprintf("EM 410x ID %s", hexData)) {
					WriteStatusSuccess("Verification successful - EM4100 / Net2 ID matches")
					return
				}
			} else if cardType == "piv" || cardType == "mifare" {
				if strings.Contains(line, "[+]  UID:") {
					uidStartIndex := strings.Index(line, "[+]  UID:") + len("[+]  UID:")
					extractedUID := strings.TrimSpace(line[uidStartIndex:])
					normalizedUID := strings.ToUpper(strings.ReplaceAll(extractedUID, " ", ""))
					if normalizedUID == strings.ToUpper(uid) {
						WriteStatusSuccess("Verification successful - UID matches")
						return
					}
				}
			} else {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("CN: %d", cardNumber)) {
					WriteStatusSuccess("Verification successful - FC and CN match")
					return
				}
			}
		}
	}

	if cardType == "piv" || cardType == "mifare" {
		WriteStatusError("Verification failed - UID does not match or card read failed")
	} else if cardType == "em" {
		WriteStatusError("Verification failed - EM4100 / Net2 ID does not match or card read failed")
	} else {
		WriteStatusError("Verification failed - FC/CN do not match or card read failed")
	}
}
