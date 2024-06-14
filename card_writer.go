package main

import (
	"fmt"
	"os/exec"
	"time"
)

func writeProxmark3Command(command string) (string, error) {
	cmd := exec.Command("pm3", "-c", command)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("error writing to card: %w", err)
	}
	return string(output), nil
}

func writeCardData(cardType string, cardData uint64, bitLength int, facilityCode int, cardNumber int, hexData string, verify bool) {
	if cardType == "iclass" {
		fmt.Println(Green, "\nConnect your Proxmark3 and place an iCLASS 2k card flat on the antenna. Press Enter to continue...", Reset)
	} else {
		fmt.Println(Green, "\nConnect your Proxmark3 and a T5577 card flat on the antenna. The card write command will run five (5) times.\n\nIMPORTANT: Move the card slowly across the Proxmark3 after each write and flip the card over and continue.\nPress Enter to continue...", Reset)
	}
	fmt.Scanln()

	switch cardType {
	case "iclass":
		fmt.Println(Green, "Writing block #6...", Reset)
		output, err := writeProxmark3Command("hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0")
		if err != nil {
			fmt.Println(Red, err, Reset)
		} else {
			fmt.Println(output)
		}
		fmt.Println(Green, "Writing block #7...", Reset)
		output, err = writeProxmark3Command(fmt.Sprintf("hf iclass wrbl --blk 7 -d %016x --ki 0", cardData))
		if err != nil {
			fmt.Println(Red, err, Reset)
		} else {
			fmt.Println(output)
		}
		fmt.Println(Green, "Writing block #8...", Reset)
		output, err = writeProxmark3Command("hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0")
		if err != nil {
			fmt.Println(Red, err, Reset)
		} else {
			fmt.Println(output)
		}
		fmt.Println(Green, "Writing block #9...", Reset)
		output, err = writeProxmark3Command("hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0")
		if err != nil {
			fmt.Println(Red, err, Reset)
		} else {
			fmt.Println(output)
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
	}
}
