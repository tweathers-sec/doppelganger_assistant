package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func verifyCardData(cardType string, facilityCode, cardNumber, bitLength int, hexData string, uid string) {
	var cmd *exec.Cmd
	fmt.Println(Green, "\nVerifying that the card data was successfully written. Set your card flat on the reader...\n", Reset)
	switch cardType {
	case "iclass":
		// Read block 7 to verify the written data
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
		fmt.Println(Red, "Unsupported card type for verification.", Reset)
		return
	}

	output, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println(Red, "Error dumping card data:", err, Reset)
		return
	}

	outputStr := string(output)
	fmt.Println(outputStr)

	if cardType == "iclass" {
		// Verify block 7 was written correctly
		lines := strings.Split(outputStr, "\n")
		var block7Data string
		for _, line := range lines {
			// Look for the block 7 data in the output
			// Format: "[+]  block   7/0x07 : 75 EE 4D F1 32 AF DF 68"
			if strings.Contains(line, "block") && strings.Contains(line, "7/0x07") {
				// Extract the hex data after the colon
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					block7Data = strings.TrimSpace(parts[1])
					break
				}
			}
		}

		if block7Data != "" {
			fmt.Println(Green, "\nVerification successful: iCLASS card block 7 data read successfully.\n", Reset)
			fmt.Println(Green, "Block 7 contains:", block7Data, "\n", Reset)
			fmt.Println(Green, fmt.Sprintf("The card contains the encoded data for Bit Length %d, Facility Code %d, and Card Number %d\n", bitLength, facilityCode, cardNumber), Reset)
			return
		} else {
			fmt.Println(Red, "\nVerification failed: Unable to read block 7 data from the card.\n", Reset)
			return
		}
	} else {
		lines := strings.Split(outputStr, "\n")
		for _, line := range lines {
			if cardType == "awid" || cardType == "indala" {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("Card: %d", cardNumber)) {
					fmt.Println(Green, "\nVerification successful: Facility Code and Card Number match.\n", Reset)
					return
				}
			} else if cardType == "avigilon" {
				if strings.Contains(line, "[Avig56") && strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("CN: %d", cardNumber)) {
					fmt.Println(Green, "\nVerification successful: Avigilon card detected with matching Facility Code and Card Number.\n", Reset)
					return
				}
			} else if cardType == "em" {
				if strings.Contains(line, fmt.Sprintf("EM 410x ID %s", hexData)) {
					fmt.Println(Green, "\nVerification successful: EM card ID matches. Decoding the wiegand data, the result should match the output in doppelganger\n", Reset)
					output, err := writeProxmark3Command(fmt.Sprintf("wiegand decode -r %s", hexData))
					if err != nil {
						fmt.Println(Red, "Error decoding Wiegand data:", err, Reset)
						return
					}
					fmt.Println(output)
					for _, line := range strings.Split(output, "\n") {
						if strings.Contains(line, "[+] [WIE32   ] Wiegand 32-bit") {
							var emFC, emCN int
							fmt.Sscanf(line, "[+] [WIE32   ] Wiegand 32-bit                   FC: %d  CN: %d", &emFC, &emCN)
							fmt.Printf(Green+"\nThe Facility Code is %d and the Card Number is %d.\n"+Reset, emFC, emCN)
							return
						}
					}
				}
			} else if cardType == "piv" || cardType == "mifare" {
				if strings.Contains(line, "[+]  UID:") {
					// Extract the UID part from the line
					uidStartIndex := strings.Index(line, "[+]  UID:") + len("[+]  UID:")
					extractedUID := strings.TrimSpace(line[uidStartIndex:])
					// Normalize the UID format
					normalizedUID := strings.ToUpper(strings.ReplaceAll(extractedUID, " ", ""))
					if normalizedUID == strings.ToUpper(uid) {
						fmt.Println(Green, "\nVerification successful: UID matches.\n", Reset)
						return
					}
				}
			} else {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("CN: %d", cardNumber)) {
					fmt.Println(Green, "\nVerification successful: Facility Code and Card Number match.\n", Reset)
					return
				}
			}
		}
	}

	fmt.Println(Red, "\nVerification failed: ",
		func() string {
			if cardType == "piv" || cardType == "mifare" {
				return "The UID does not match or the Proxmark3 failed to read the card."
			}
			return "Facility Code and Card Number do not match or the Proxmark3 failed to read the card."
		}(),
		Reset)
}
