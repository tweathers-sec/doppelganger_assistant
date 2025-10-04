package main

import (
	"fmt"
	"strings"
	"time"
)

func writeProxmark3Command(command string) (string, error) {
	cmd := newPM3Cmd("-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("error writing to card: %w. Output: %s", err, output)
	}
	return string(output), nil
}

// waitForProxmark3 attempts to check if Proxmark3 is available
func waitForProxmark3(maxRetries int) bool {
	for i := 0; i < maxRetries; i++ {
		cmd := newPM3Cmd("-c", "hw status")
		output, err := cmd.CombinedOutput()
		if err == nil && !strings.Contains(string(output), "cannot communicate") {
			return true
		}
		if i < maxRetries-1 {
			fmt.Printf("Waiting for Proxmark3 to be ready... (attempt %d/%d)\n", i+1, maxRetries)
			time.Sleep(2 * time.Second)
		}
	}
	return false
}

func writeCardData(cardType string, cardData uint64, bitLength int, facilityCode int, cardNumber int, hexData string, verify bool, formatCodeOrUID string) {
	if cardType == "iclass" {
		fmt.Println(Green, "\nConnect your Proxmark3 and place an iCLASS 2k card flat on the antenna. Press Enter to continue...", Reset)
	} else if cardType == "piv" || cardType == "mifare" {
		fmt.Println(Green, "\nConnect your Proxmark3 and place a UID rewritable (S50) card flat on the antenna. Press Enter to continue...", Reset)
	} else {
		fmt.Println(Green, "\nConnect your Proxmark3 and a T5577 card flat on the antenna. The card write command will run five (5) times.\n\nIMPORTANT: Move the card slowly across the Proxmark3 after each write and flip the card over and continue.\nPress Enter to continue...", Reset)
	}

	// Only wait for user input if running in interactive terminal mode
	// Skips the prompt when running as GUI subprocess
	if isInteractive() {
		fmt.Scanln()
	}

	switch cardType {
	case "iclass":
		fmt.Println(Green, "\nWriting iCLASS card data using hf iclass encode...\n", Reset)
		// Use the new hf iclass encode command with the format code
		formatCode := formatCodeOrUID
		command := fmt.Sprintf("hf iclass encode -w %s --fc %d --cn %d --ki 0", formatCode, facilityCode, cardNumber)
		output, err := writeProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, "Error writing to iCLASS card:", err, Reset)
			fmt.Println(output)
		} else {
			fmt.Println(output)
			if verify {
				fmt.Println(Green, "\nWrite complete. Verification will now begin.\n", Reset)
			} else {
				fmt.Println(Green, "\nWrite complete. Please verify the card data.\n", Reset)
			}
		}
	case "prox":
		fmt.Println(Green, "\nWriting Prox card data...\n", Reset)

		// Check if Proxmark3 is available before starting
		if !waitForProxmark3(3) {
			fmt.Println(Red, "Proxmark3 is not responding. Please check your USB connection.", Reset)
			return
		}

		for i := 0; i < 5; i++ {
			var output string
			var err error
			if bitLength == 26 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w H10301 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 30 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w ATSW30 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 31 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w ADT31 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 33 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w D10202 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 34 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w H10306 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 35 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w C1k35s --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 36 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w S12906 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 37 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w H10304 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 46 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w H800002 --fc %d --cn %d", facilityCode, cardNumber))
			} else if bitLength == 48 {
				output, err = writeProxmark3Command(fmt.Sprintf("lf hid clone -w C1k48s --fc %d --cn %d", facilityCode, cardNumber))
			}
			if err != nil {
				fmt.Println(Red, err, Reset)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				fmt.Printf(Green+"Move card... Write attempt #%d complete..."+Reset+"\n", i+1)
			} else {
				if verify {
					fmt.Println(Green, "\nFinal write attempt complete. Verification will now begin.\n", Reset)
				} else {
					fmt.Println(Green, "\nFinal write attempt complete. Please verify the card data.\n", Reset)
				}
			}
		}
	case "awid":
		fmt.Println(Green, "\nWriting AWID card data...\n", Reset)
		for i := 0; i < 5; i++ {
			output, err := writeProxmark3Command(fmt.Sprintf("lf awid clone --fmt 26 --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				fmt.Println(Red, err, Reset)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				fmt.Printf(Green+"Move card... Write attempt #%d complete..."+Reset+"\n", i+1)
			} else {
				if verify {
					fmt.Println(Green, "\nFinal write attempt complete. Verification will now begin.\n", Reset)
				} else {
					fmt.Println(Green, "\nFinal write attempt complete. Please verify the card data.\n", Reset)
				}
			}
		}
	case "indala":
		fmt.Println(Green, "\nWriting Indala card data...\n", Reset)
		for i := 0; i < 5; i++ {
			output, err := writeProxmark3Command(fmt.Sprintf("lf indala clone --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				fmt.Println(Red, err, Reset)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				fmt.Printf(Green+"Move card... Write attempt #%d complete..."+Reset+"\n", i+1)
			} else {
				if verify {
					fmt.Println(Green, "\nFinal write attempt complete. Verification will now begin.\n", Reset)
				} else {
					fmt.Println(Green, "\nFinal write attempt complete. Please verify the card data.\n", Reset)
				}
			}
		}
	case "avigilon":
		fmt.Println(Green, "\nWriting Avigilon card data...\n", Reset)
		for i := 0; i < 5; i++ {
			output, err := writeProxmark3Command(fmt.Sprintf("lf hid clone -w Avig56 --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				fmt.Println(Red, err, Reset)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				fmt.Printf(Green+"Move card... Write attempt #%d complete..."+Reset+"\n", i+1)
			} else {
				if verify {
					fmt.Println(Green, "\nFinal write attempt complete. Verification will now begin.\n", Reset)
				} else {
					fmt.Println(Green, "\nFinal write attempt complete. Please verify the card data.\n", Reset)
				}
			}
		}
	case "em":
		fmt.Println(Green, "\nWriting EM card data...\n", Reset)
		for i := 0; i < 5; i++ {
			output, err := writeProxmark3Command(fmt.Sprintf("lf em 410x clone --id %s", hexData))
			if err != nil {
				fmt.Println(Red, err, Reset)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				fmt.Printf(Green+"Move card... Write attempt #%d complete..."+Reset+"\n", i+1)
			} else {
				if verify {
					fmt.Println(Green, "\nFinal write attempt complete. Verification will now begin.\n", Reset)
				} else {
					fmt.Println(Green, "\nFinal write attempt complete. Please verify the card data.\n", Reset)
				}
			}
		}
	case "piv", "mifare":
		fmt.Println(Green, "\nWriting the provided UID...\n", Reset)
		uid := formatCodeOrUID
		command := fmt.Sprintf("hf mf csetuid -u %s", uid)
		output, err := writeProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, "Error writing to card:", err, Reset)
			fmt.Println("Command output:", output)
		} else {
			fmt.Println(output)
		}
	}
}
