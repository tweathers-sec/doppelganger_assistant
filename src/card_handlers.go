package main

import (
	"fmt"
)

func handleCardType(cardType string, facilityCode, cardNumber, bitLength int, write, verify bool, uid, hexData string, simulate bool) {
	switch cardType {
	case "iclass":
		handleICLASS(facilityCode, cardNumber, bitLength, simulate, write, verify)
	case "prox":
		handleProx(facilityCode, cardNumber, bitLength, simulate, write, verify)
	case "awid":
		handleAWID(facilityCode, cardNumber, bitLength, simulate, write, verify)
	case "indala":
		handleIndala(facilityCode, cardNumber, bitLength, simulate, write, verify)
	case "avigilon":
		handleAvigilon(facilityCode, cardNumber, bitLength, simulate, write, verify)
	case "em":
		handleEM(hexData, simulate, write, verify)
	case "piv":
		handlePIV(uid, simulate, write, verify)
	case "mifare":
		handleMIFARE(uid, simulate, write, verify)
	default:
		fmt.Println(Red, "Unsupported card type. Supported types are: iclass, prox, awid, indala, em, piv, mifare.", Reset)
	}
}

func handleICLASS(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	validBitLengths := map[int]bool{26: true, 30: true, 33: true, 34: true, 35: true, 36: true, 37: true, 46: true, 48: true}
	if !validBitLengths[bitLength] {
		WriteStatusError("Invalid bit length for iCLASS. Supported: 26, 30, 33, 34, 35, 36, 37, 46, 48")
		return
	}

	if simulate {
		WriteStatusError("iCLASS card simulation is currently disabled")
		return
	}

	var formatCode string
	switch bitLength {
	case 26:
		formatCode = "H10301"
	case 30:
		formatCode = "ATSW30"
	case 33:
		formatCode = "D10202"
	case 34:
		formatCode = "H10306"
	case 35:
		formatCode = "C1k35s"
	case 36:
		formatCode = "S12906"
	case 37:
		formatCode = "H10304"
	case 46:
		formatCode = "H800002"
	case 48:
		formatCode = "C1k48s"
	}

	if write {
		WriteStatusInfo("Writing to iCLASS 2k card...")
		WriteStatusInfo("Command: hf iclass encode -w %s --fc %d --cn %d --ki 0", formatCode, facilityCode, cardNumber)
		writeCardData("iclass", 0, bitLength, facilityCode, cardNumber, "", verify, formatCode)
	}

	if verify {
		verifyCardData("iclass", facilityCode, cardNumber, bitLength, "", "")
	}
}

func handleProx(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("prox", 0, bitLength, facilityCode, cardNumber, "", "")
		return
	}

	var cmdTemplate string
	switch bitLength {
	case 26:
		cmdTemplate = "lf hid clone -w H10301 --fc %d --cn %d"
	case 30:
		cmdTemplate = "lf hid clone -w ATSW30 --fc %d --cn %d"
	case 31:
		cmdTemplate = "lf hid clone -w ADT31 --fc %d --cn %d"
	case 33:
		cmdTemplate = "lf hid clone -w D10202 --fc %d --cn %d"
	case 34:
		cmdTemplate = "lf hid clone -w H10306 --fc %d --cn %d"
	case 35:
		cmdTemplate = "lf hid clone -w C1k35s --fc %d --cn %d"
	case 36:
		cmdTemplate = "lf hid clone -w S12906 --fc %d --cn %d"
	case 37:
		cmdTemplate = "lf hid clone -w H10304 --fc %d --cn %d"
	case 46:
		cmdTemplate = "lf hid clone -w H800002 --fc %d --cn %d"
	case 48:
		cmdTemplate = "lf hid clone -w C1k48s --fc %d --cn %d"
	default:
		WriteStatusError("Unsupported bit length for Prox card")
		return
	}

	if write {
		WriteStatusInfo("Writing to T5577 card...")
		WriteStatusInfo("Command: "+cmdTemplate, facilityCode, cardNumber)
		writeCardData("prox", 0, bitLength, facilityCode, cardNumber, "", verify, "")
	}

	if verify {
		verifyCardData("prox", facilityCode, cardNumber, bitLength, "", "")
	}
}

func handleAWID(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("awid", 0, bitLength, facilityCode, cardNumber, "", "")
		return
	}

	bitLength = 26
	if write {
		WriteStatusInfo("Writing to T5577 card...")
		WriteStatusInfo("Command: lf awid clone --fmt 26 --fc %d --cn %d", facilityCode, cardNumber)
		writeCardData("awid", 0, bitLength, facilityCode, cardNumber, "", verify, "")
	}

	if verify {
		verifyCardData("awid", facilityCode, cardNumber, bitLength, "", "")
	}
}

func handleIndala(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("indala", 0, bitLength, facilityCode, cardNumber, "", "")
		return
	}

	if bitLength != 26 {
		WriteStatusInfo("Note: Indala 27/29-bit will be written as 26-bit. For full replication, use simulation mode")
	}

	bitLength = 26
	if write {
		WriteStatusInfo("Writing to T5577 card...")
		WriteStatusInfo("Command: lf indala clone --fc %d --cn %d", facilityCode, cardNumber)
		writeCardData("indala", 0, bitLength, facilityCode, cardNumber, "", verify, "")
	}

	if verify {
		verifyCardData("indala", facilityCode, cardNumber, bitLength, "", "")
	}
}

func handleEM(hexData string, simulate, write, verify bool) {
	// Validate EM4100 hex data format
	if valid, errMsg := validateEM4100Hex(hexData); !valid {
		WriteStatusError(errMsg)
		return
	}
	
	if simulate {
		simulateCardData("em", 0, 0, 0, 0, hexData, "")
		return
	}

	if write {
		WriteStatusInfo("Writing to T5577 card...")
		WriteStatusInfo("Command: lf em 410x clone --id %s", hexData)
		writeCardData("em", 0, 0, 0, 0, hexData, verify, "")
	}

	if verify {
		verifyCardData("em", 0, 0, 0, hexData, "")
	}
}

func handlePIV(uid string, simulate bool, write, verify bool) {
	if simulate {
		simulateCardData("piv", 0, 0, 0, 0, "", uid)
		return
	}

	if write {
		WriteStatusInfo("Writing UID to rewritable MIFARE card...")
		WriteStatusInfo("Command: hf mf csetuid -u %s", uid)
		WriteStatusInfo("Note: This emulates Wiegand signal only (experimental)")
		writeCardData("piv", 0, 0, 0, 0, "", verify, uid)
	}

	if verify {
		verifyCardData("piv", 0, 0, 0, "", uid)
	}
}

func handleMIFARE(uid string, simulate bool, write, verify bool) {
	if simulate {
		simulateCardData("mifare", 0, 0, 0, 0, "", uid)
		return
	}

	if write {
		WriteStatusInfo("Writing UID to rewritable MIFARE card...")
		WriteStatusInfo("Command: hf mf csetuid -u %s", uid)
		WriteStatusInfo("Note: This emulates Wiegand signal only (experimental)")
		writeCardData("mifare", 0, 0, 0, 0, "", verify, uid)
	}

	if verify {
		verifyCardData("mifare", 0, 0, 0, "", uid)
	}
}

func handleAvigilon(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("avigilon", 0, bitLength, facilityCode, cardNumber, "", "")
		return
	}

	if bitLength != 56 {
		WriteStatusError("Unsupported bit length for Avigilon card. Only 56-bit is supported")
		return
	}

	if write {
		WriteStatusInfo("Writing to T5577 card...")
		WriteStatusInfo("Command: lf hid clone -w Avig56 --fc %d --cn %d", facilityCode, cardNumber)
		writeCardData("avigilon", 0, bitLength, facilityCode, cardNumber, "", verify, "")
	}

	if verify {
		verifyCardData("avigilon", facilityCode, cardNumber, bitLength, "", "")
	}
}
