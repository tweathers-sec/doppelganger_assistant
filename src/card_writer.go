package main

import (
	"fmt"
	"os/exec"
	"strings"
	"time"
)

func writeProxmark3Command(command string) (string, error) {
	if ok, msg := checkProxmark3(); !ok {
		return "", fmt.Errorf("%s", msg)
	}

	pm3Binary, err := getPm3Path()
	if err != nil {
		return "", fmt.Errorf("failed to find pm3 binary: %w", err)
	}

	device, err := getPm3Device()
	if err != nil {
		return "", fmt.Errorf("failed to detect pm3 device: %w", err)
	}

	cmd := exec.Command(pm3Binary, "-c", command, "-p", device)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return string(output), fmt.Errorf("error writing to card: %w. Output: %s", err, output)
	}
	return string(output), nil
}

// waitForProxmark3 checks if Proxmark3 is available with retries.
func waitForProxmark3(maxRetries int) bool {
	for i := 0; i < maxRetries; i++ {
		pm3Binary, err := getPm3Path()
		if err != nil {
			if i < maxRetries-1 {
				fmt.Printf("Waiting for Proxmark3 to be ready... (attempt %d/%d)\n", i+1, maxRetries)
				time.Sleep(2 * time.Second)
			}
			continue
		}

		device, err := getPm3Device()
		if err != nil {
			if i < maxRetries-1 {
				fmt.Printf("Waiting for Proxmark3 to be ready... (attempt %d/%d)\n", i+1, maxRetries)
				time.Sleep(2 * time.Second)
			}
			continue
		}

		cmd := exec.Command(pm3Binary, "-c", "hw status", "-p", device)
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
	switch cardType {
	case "iclass":
		fmt.Println("\n|----------- WRITE -----------|")
		WriteStatusProgress("Encoding iCLASS card data...")
		formatCode := formatCodeOrUID
		command := fmt.Sprintf("hf iclass encode -w %s --fc %d --cn %d --ki 0", formatCode, facilityCode, cardNumber)
		output, err := writeProxmark3Command(command)
		if err != nil {
			WriteStatusError("Failed to write iCLASS card: %v", err)
			fmt.Println(output)
		} else {
			fmt.Println(output)
			if verify {
				WriteStatusSuccess("Write complete - starting verification")
			} else {
				WriteStatusSuccess("Write complete")
			}
		}
	case "prox":
		WriteStatusProgress("Writing Prox card (5 attempts)...")

		for i := 0; i < 5; i++ {
			fmt.Printf("\n|----------- WRITE #%d -----------|\n", i+1)
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
				WriteStatusError("Write attempt #%d failed: %v", i+1, err)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				WriteStatusProgress("Move card slowly... Write attempt #%d complete", i+1)
			} else {
				if verify {
					WriteStatusSuccess("All 5 write attempts complete - starting verification")
				} else {
					WriteStatusSuccess("All 5 write attempts complete")
				}
			}
		}
	case "awid":
		WriteStatusProgress("Writing AWID card (5 attempts)...")
		for i := 0; i < 5; i++ {
			fmt.Printf("\n|----------- WRITE #%d -----------|\n", i+1)
			output, err := writeProxmark3Command(fmt.Sprintf("lf awid clone --fmt 26 --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				WriteStatusError("Write attempt #%d failed: %v", i+1, err)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				WriteStatusProgress("Move card slowly... Write attempt #%d complete", i+1)
			} else {
				if verify {
					WriteStatusSuccess("All 5 write attempts complete - starting verification")
				} else {
					WriteStatusSuccess("All 5 write attempts complete")
				}
			}
		}
	case "indala":
		WriteStatusProgress("Writing Indala card (5 attempts)...")
		for i := 0; i < 5; i++ {
			fmt.Printf("\n|----------- WRITE #%d -----------|\n", i+1)
			output, err := writeProxmark3Command(fmt.Sprintf("lf indala clone --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				WriteStatusError("Write attempt #%d failed: %v", i+1, err)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				WriteStatusProgress("Move card slowly... Write attempt #%d complete", i+1)
			} else {
				if verify {
					WriteStatusSuccess("All 5 write attempts complete - starting verification")
				} else {
					WriteStatusSuccess("All 5 write attempts complete")
				}
			}
		}
	case "avigilon":
		WriteStatusProgress("Writing Avigilon card (5 attempts)...")
		for i := 0; i < 5; i++ {
			fmt.Printf("\n|----------- WRITE #%d -----------|\n", i+1)
			output, err := writeProxmark3Command(fmt.Sprintf("lf hid clone -w Avig56 --fc %d --cn %d", facilityCode, cardNumber))
			if err != nil {
				WriteStatusError("Write attempt #%d failed: %v", i+1, err)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				WriteStatusProgress("Move card slowly... Write attempt #%d complete", i+1)
			} else {
				if verify {
					WriteStatusSuccess("All 5 write attempts complete - starting verification")
				} else {
					WriteStatusSuccess("All 5 write attempts complete")
				}
			}
		}
	case "em":
		WriteStatusProgress("Writing EM card (5 attempts)...")
		for i := 0; i < 5; i++ {
			fmt.Printf("\n|----------- WRITE #%d -----------|\n", i+1)
			output, err := writeProxmark3Command(fmt.Sprintf("lf em 410x clone --id %s", hexData))
			if err != nil {
				WriteStatusError("Write attempt #%d failed: %v", i+1, err)
			} else {
				fmt.Println(output)
			}
			time.Sleep(1 * time.Second)
			if i < 4 {
				WriteStatusProgress("Move card slowly... Write attempt #%d complete", i+1)
			} else {
				if verify {
					WriteStatusSuccess("All 5 write attempts complete - starting verification")
				} else {
					WriteStatusSuccess("All 5 write attempts complete")
				}
			}
		}
	case "piv", "mifare":
		fmt.Println("\n|----------- WRITE -----------|")
		WriteStatusProgress("Writing UID to card...")
		uid := formatCodeOrUID
		command := fmt.Sprintf("hf mf csetuid -u %s", uid)
		output, err := writeProxmark3Command(command)
		if err != nil {
			WriteStatusError("Failed to write UID: %v", err)
			fmt.Println(output)
		} else {
			fmt.Println(output)
			WriteStatusSuccess("UID written successfully")
		}
	}
}
