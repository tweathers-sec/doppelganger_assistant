package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

func simulateProxmark3Command(command string) (string, error) {
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

	WriteStatusInfo("Simulation started - press PM3 button to stop")
	WriteStatusInfo("With battery: you can remove device and simulation continues")

	cmd := exec.Command(pm3Binary, "-c", command, "-p", device)

	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("error running command: %w", err)
	}

	WriteStatusSuccess("Simulation completed")
	return "", nil
}

func simulateCardData(cardType string, cardData uint64, bitLength, facilityCode, cardNumber int, hexData, uid string) {
	var command string
	switch cardType {
	case "iclass":

		type Card struct {
			CSN           string `json:"CSN"`
			Configuration string `json:"Configuration"`
			Epurse        string `json:"Epurse"`
			Kd            string `json:"Kd"`
			Kc            string `json:"Kc"`
			AIA           string `json:"AIA"`
		}

		type Blocks struct {
			Block0  string `json:"0"`
			Block1  string `json:"1"`
			Block2  string `json:"2"`
			Block3  string `json:"3"`
			Block4  string `json:"4"`
			Block5  string `json:"5"`
			Block6  string `json:"6"`
			Block7  string `json:"7"`
			Block8  string `json:"8"`
			Block9  string `json:"9"`
			Block10 string `json:"10"`
			Block11 string `json:"11"`
			Block12 string `json:"12"`
			Block13 string `json:"13"`
			Block14 string `json:"14"`
			Block15 string `json:"15"`
			Block16 string `json:"16"`
			Block17 string `json:"17"`
			Block18 string `json:"18"`
		}

		type IClass struct {
			Created  string `json:"Created"`
			FileType string `json:"FileType"`
			Card     Card   `json:"Card"`
			Blocks   Blocks `json:"blocks"`
		}

		iclass := IClass{
			Created:  "doppelganager_assistant",
			FileType: "iclass",
			Card: Card{
				CSN:           "28668B15FEFF12E0",
				Configuration: "12FFFFFF7F1FFF3C",
				Epurse:        "FFFFFFFFD9FFFFFF",
				Kd:            "843F766755B8DBCE",
				Kc:            "FFFFFFFFFFFFFFFF",
				AIA:           "FFFFFFFFFFFFFFFF",
			},
			Blocks: Blocks{
				Block0:  "28668B15FEFF12E0",
				Block1:  "12FFFFFF7F1FFF3C",
				Block2:  "FFFFFFFFD9FFFFFF",
				Block3:  "843F766755B8DBCE",
				Block4:  "FFFFFFFFFFFFFFFF",
				Block5:  "FFFFFFFFFFFFFFFF",
				Block6:  "030303030003E014",
				Block7:  fmt.Sprintf("%016x", cardData),
				Block8:  "0000000000000000",
				Block9:  "0000000000000000",
				Block10: "FFFFFFFFFFFFFFFF",
				Block11: "FFFFFFFFFFFFFFFF",
				Block12: "FFFFFFFFFFFFFFFF",
				Block13: "FFFFFFFFFFFFFFFF",
				Block14: "FFFFFFFFFFFFFFFF",
				Block15: "FFFFFFFFFFFFFFFF",
				Block16: "FFFFFFFFFFFFFFFF",
				Block17: "FFFFFFFFFFFFFFFF",
				Block18: "FFFFFFFFFFFFFFFF",
			},
		}

		homeDir, err := os.UserHomeDir()
		if err != nil {
			fmt.Println("Error getting home directory:", err)
			return
		}

		fileName := filepath.Join(homeDir, fmt.Sprintf("iclass_sim_%d_%d_%d_%s.json", bitLength, facilityCode, cardNumber, time.Now().Format("20060102150405")))
		file, err := os.Create(fileName)
		if err != nil {
			fmt.Println("Error creating file:", err)
			return
		}
		defer file.Close()

		encoder := json.NewEncoder(file)
		encoder.SetIndent("", "  ")
		if err := encoder.Encode(iclass); err != nil {
			fmt.Println("Error encoding JSON:", err)
			return
		}

		WriteStatusInfo("iCLASS simulation file saved: %s", fileName)
		command = fmt.Sprintf("hf iclass eload -f %s; hf iclass sim -t 3", fileName)

		output, err := simulateProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, err, Reset)
			fmt.Println(output)
		}

	case "prox":
		switch bitLength {
		case 26:
			command = fmt.Sprintf("lf hid sim -w H10301 --fc %d --cn %d", facilityCode, cardNumber)
		case 30:
			command = fmt.Sprintf("lf hid sim -w ATSW30 --fc %d --cn %d", facilityCode, cardNumber)
		case 31:
			command = fmt.Sprintf("lf hid sim -w ADT31 --fc %d --cn %d", facilityCode, cardNumber)
		case 33:
			command = fmt.Sprintf("lf hid sim -w D10202 --fc %d --cn %d", facilityCode, cardNumber)
		case 34:
			command = fmt.Sprintf("lf hid sim -w H10306 --fc %d --cn %d", facilityCode, cardNumber)
		case 35:
			command = fmt.Sprintf("lf hid sim -w C1k35s --fc %d --cn %d", facilityCode, cardNumber)
		case 36:
			command = fmt.Sprintf("lf hid sim -w S12906 --fc %d --cn %d", facilityCode, cardNumber)
		case 37:
			command = fmt.Sprintf("lf hid sim -w H10304 --fc %d --cn %d", facilityCode, cardNumber)
		case 46:
			command = fmt.Sprintf("lf hid sim -w H800002 --fc %d --cn %d", facilityCode, cardNumber)
		case 48:
			command = fmt.Sprintf("lf hid sim -w C1k48s --fc %d --cn %d", facilityCode, cardNumber)
		}
		output, err := simulateProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, err, Reset)
			fmt.Println(output)
		}
	case "awid":
		command = fmt.Sprintf("lf awid sim --fmt 26 --fc %d --cn %d", facilityCode, cardNumber)
		output, err := simulateProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, err, Reset)
			fmt.Println(output)
		}

	case "indala":
		switch bitLength {
		case 26:
			command = fmt.Sprintf("lf indala sim --fc %d --cn %d", facilityCode, cardNumber)
		case 27:
			command = fmt.Sprintf("lf hid sim -w ind27 --fc %d --cn %d", facilityCode, cardNumber)
		case 29:
			command = fmt.Sprintf("lf hid sim -w ind29 --fc %d --cn %d", facilityCode, cardNumber)
		}
		output, err := simulateProxmark3Command(command)
		if err != nil {
			fmt.Println(Red, err, Reset)
			fmt.Println(output)
		}

	case "avigilon":
		command = fmt.Sprintf("lf hid sim -w Avig56 --fc %d --cn %d", facilityCode, cardNumber)
		_, err := simulateProxmark3Command(command)
		if err != nil {
			WriteStatusError("Simulation failed: %v", err)
		}

	case "em":
		command = fmt.Sprintf("lf em 410x sim --id %s", hexData)
		_, err := simulateProxmark3Command(command)
		if err != nil {
			WriteStatusError("Simulation failed: %v", err)
		}

	case "piv":
		command = fmt.Sprintf("hf 14a sim -t 3 --uid %s", uid)
		_, err := simulateProxmark3Command(command)
		if err != nil {
			WriteStatusError("Simulation failed: %v", err)
		}

	case "mifare":
		command = fmt.Sprintf("hf 14a sim -t 1 --uid %s", uid)
		_, err := simulateProxmark3Command(command)
		if err != nil {
			WriteStatusError("Simulation failed: %v", err)
		}
	}
}
