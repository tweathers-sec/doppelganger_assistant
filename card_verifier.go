package main

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func verifyCardData(cardType string, facilityCode, cardNumber int, hexData string, uid string) {
	var cmd *exec.Cmd
	fmt.Println(Green, "\nVerifying that the card data was successfully written. Set your card flat on the reader...\n", Reset)
	time.Sleep(3 * time.Second)
	switch cardType {
	case "iclass":
		cmd = exec.Command("pm3", "-c", "hf iclass dump --ki 0")
	case "prox":
		cmd = exec.Command("pm3", "-c", "lf hid reader")
	case "awid":
		cmd = exec.Command("pm3", "-c", "lf awid reader")
	case "indala":
		cmd = exec.Command("pm3", "-c", "lf indala reader")
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
		var jsonFilePath string
		lines := strings.Split(outputStr, "\n")
		for _, line := range lines {
			if strings.Contains(line, "Saved to json file") {
				parts := strings.Split(line, "`")
				if len(parts) > 1 {
					jsonFilePath = parts[1]
					break
				}
			}
		}

		if jsonFilePath == "" {
			fmt.Println(Red, "Failed to find the JSON file path in the output.", Reset)
			return
		}

		cmd = exec.Command("pm3", "-c", fmt.Sprintf("hf iclass view -f %s", jsonFilePath))
		output, err = cmd.CombinedOutput()
		if err != nil {
			fmt.Println(Red, "Error viewing iCLASS data:", err, Reset)
			return
		}

		outputStr = string(output)
		fmt.Println(outputStr)

		lines = strings.Split(outputStr, "\n")
		for _, line := range lines {
			if strings.Contains(line, "HID") {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("CN: %d", cardNumber)) {
					fmt.Println(Green, "\nVerification successful: Facility Code and Card Number match.\n", Reset)
					return
				}
			}
		}
	} else {
		lines := strings.Split(outputStr, "\n")
		for _, line := range lines {
			if cardType == "awid" || cardType == "indala" {
				if strings.Contains(line, fmt.Sprintf("FC: %d", facilityCode)) && strings.Contains(line, fmt.Sprintf("Card: %d", cardNumber)) {
					fmt.Println(Green, "\nVerification successful: Facility Code and Card Number match.\n", Reset)
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
