package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func verifyCardData(cardType string, facilityCode, cardNumber, bitLength int, hexData string, uid string) {
	if ok, msg := checkProxmark3(); !ok {
		WriteStatusError(msg)
		return
	}

	fmt.Println("\n|----------- VERIFICATION -----------|")
	WriteStatusProgress("Verifying card data - place card flat on reader...")
	var cmd *exec.Cmd
	switch cardType {
	case "iclass":
		cmd = exec.Command("pm3", "-c", "hf iclass rdbl --blk 7 --ki 0")
	case "prox":
		cmd = exec.Command("pm3", "-c", "lf hid reader")
	case "awid":
		cmd = exec.Command("pm3", "-c", "lf awid reader")
	case "indala":
		cmd = exec.Command("pm3", "-c", "lf indala reader")
	case "avigilon":
		cmd = exec.Command("pm3", "-c", "lf hid reader")
	case "em":
		cmd = exec.Command("pm3", "-c", "lf em 410x reader")
	case "piv", "mifare":
		cmd = exec.Command("pm3", "-c", "hf mf info")
	default:
		WriteStatusError("Unsupported card type for verification")
		return
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		WriteStatusError("Failed to read card data: %v", err)
		return
	}

	outputStr := string(output)
	fmt.Println(outputStr)

	if cardType == "iclass" {
		lines := strings.Split(outputStr, "\n")
		var block7Data string
		for _, line := range lines {
			if strings.Contains(line, "block") && strings.Contains(line, "7/0x07") {
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					block7Data = strings.TrimSpace(parts[1])
					break
				}
			}
		}

		if block7Data != "" {
			WriteStatusSuccess("Verification successful - Block 7: %s", block7Data)
			WriteStatusSuccess("Card contains: %d-bit, FC: %d, CN: %d", bitLength, facilityCode, cardNumber)
			return
		} else {
			WriteStatusError("Verification failed - unable to read block 7 data")
			return
		}
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
					WriteStatusSuccess("Verification successful - EM card ID matches")
					output, err := writeProxmark3Command(fmt.Sprintf("wiegand decode -r %s", hexData))
					if err != nil {
						WriteStatusError("Failed to decode Wiegand data: %v", err)
						return
					}
					fmt.Println(output)
					for _, line := range strings.Split(output, "\n") {
						if strings.Contains(line, "[+] [WIE32   ] Wiegand 32-bit") {
							var emFC, emCN int
							fmt.Sscanf(line, "[+] [WIE32   ] Wiegand 32-bit                   FC: %d  CN: %d", &emFC, &emCN)
							WriteStatusSuccess("Decoded: FC: %d, CN: %d", emFC, emCN)
							return
						}
					}
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
	} else {
		WriteStatusError("Verification failed - FC/CN do not match or card read failed")
	}
}
