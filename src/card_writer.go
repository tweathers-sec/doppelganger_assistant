package main

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func writeProxmark3Command(command string) (string, error) {
	cmd := exec.Command("pm3", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("error writing to card: %w. Output: %s", err, output)
	}
	return string(output), nil
}

// waitForProxmark3 attempts to check if Proxmark3 is available
func waitForProxmark3(maxRetries int) bool {
	for i := 0; i < maxRetries; i++ {
		cmd := exec.Command("pm3", "-c", "hw status")
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
	// Remove interactive prompts to avoid blocking in GUI environments

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
