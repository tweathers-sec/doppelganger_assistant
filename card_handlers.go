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
	var preamble uint64
	var cardData uint64

	if bitLength != 26 && bitLength != 35 {
		fmt.Println(Red, "Invalid bit length for iCLASS. Supported bit lengths are 26 and 35.", Reset)
		return
	}

	if bitLength == 26 {
		preamble = 0x2004000000
		cardData = generate26bitHex(facilityCode, cardNumber, preamble, write, simulate)
	} else if bitLength == 35 {
		preamble = 0x2800000000
		cardData = generate35bitHex(facilityCode, cardNumber, preamble, write, simulate)
	}

	if simulate {
		simulateCardData("iclass", cardData, bitLength, facilityCode, cardNumber, "", "")
	} else if write {
		writeCardData("iclass", cardData, bitLength, facilityCode, cardNumber, "", verify, "")
	}

	if verify {
		verifyCardData("iclass", facilityCode, cardNumber, "", "")
	}
}

func handleProx(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("prox", 0, bitLength, facilityCode, cardNumber, "", "")
	} else {
		fmt.Println(Green, "\nHandling Prox card...", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a T5577 card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a T5577 card:", Reset)
		}

		fmt.Println(Green, "", Reset)

		switch bitLength {
		case 26:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w H10301 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 30:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w ATSW30 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 31:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w ADT31 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 33:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w D10202 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 34:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w H10306 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 35:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w C1k35s --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 36:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w S12906 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 37:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w H10304 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		case 48:
			fmt.Println(Yellow, fmt.Sprintf("lf hid clone -w C1k48s --fc %d --cn %d", facilityCode, cardNumber), Reset)
		default:
			fmt.Println(Red, "Unsupported bit length for Prox card.", Reset)
			return
		}

		if write {
			writeCardData("prox", 0, bitLength, facilityCode, cardNumber, "", verify, "")
		}

		if verify {
			verifyCardData("prox", facilityCode, cardNumber, "", "")
		}
	}
}

func handleAWID(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("awid", 0, bitLength, facilityCode, cardNumber, "", "")
	} else {
		fmt.Println(Green, "\nHandling AWID card...", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a T5577 card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a T5577 card:", Reset)
		}
		fmt.Println(Green, "", Reset)

		bitLength := 26

		if bitLength == 26 {
			fmt.Println(Yellow, fmt.Sprintf("\nlf awid clone --fmt 26 --fc %d --cn %d", facilityCode, cardNumber), Reset)
		}

		if write {
			writeCardData("awid", 0, bitLength, facilityCode, cardNumber, "", verify, "")
		}

		if verify {
			verifyCardData("awid", facilityCode, cardNumber, "", "")
		}
	}
}

func handleIndala(facilityCode, cardNumber, bitLength int, simulate, write, verify bool) {
	if simulate {
		simulateCardData("indala", 0, bitLength, facilityCode, cardNumber, "", "")
	} else {
		fmt.Println(Green, "\nHandling Indala card...", Reset)
		fmt.Println(Yellow, "\nNote that the only supported bit length for writing an Indala card is 26-bit. Indala 27-bit and 29-bit will be written as a 26-bit card. \nThis may cause an issue given facility code and card number ranges. If so, grab the BIN data from doppelganger and encode the data\nfor writing or you can simulate the card with the Proxmark3: `lf hid sim -w ind27/ind29 --fc {FC} --cn {CN}'", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a T5577 card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a T5577 card:", Reset)
		}
		fmt.Println(Green, "", Reset)

		bitLength := 26

		fmt.Println(Yellow, fmt.Sprintf("lf indala clone --fc %d --cn %d", facilityCode, cardNumber), Reset)

		if write {
			writeCardData("indala", 0, bitLength, facilityCode, cardNumber, "", verify, "")
		}

		if verify {
			verifyCardData("indala", facilityCode, cardNumber, "", "")
		}
	}
}

func handleEM(hexData string, simulate, write, verify bool) {
	if simulate {
		simulateCardData("em", 0, 0, 0, 0, hexData, "")
	} else {
		fmt.Println(Green, "\nHandling EM card...", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a T5577 card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a T5577 card:", Reset)
		}
		fmt.Println(Green, "", Reset)

		fmt.Println(Yellow, fmt.Sprintf("lf em 410x clone --id %s", hexData), Reset)

		if write {
			writeCardData("em", 0, 0, 0, 0, hexData, verify, "")
		}

		if verify {
			verifyCardData("em", 0, 0, hexData, "")
		}
	}
}

func handlePIV(uid string, simulate bool, write, verify bool) {
	if simulate {
		simulateCardData("piv", 0, 0, 0, 0, "", uid)
	} else {
		fmt.Println(Green, "\nHandling PIV card...", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a UID rewritable MIFARE card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a UID rewritable MIFARE card:", Reset)
		}
		fmt.Println(Green, "", Reset)
		fmt.Println(Yellow, fmt.Sprintf("hf mf csetuid -u %s", uid), Reset)
		fmt.Println(Green, "\nNote, this will only emulate the Wiegand signal of the captured card. This will not fully replicate the captured PIV card. This considered experimental as the badging system that your client employs may interpret the data differently than the reader that provided the Wiegand output to doppelganger.", Reset)

		if write {
			writeCardData("piv", 0, 0, 0, 0, "", verify, uid)
		}

		if verify {
			verifyCardData("piv", 0, 0, "", uid)
		}
	}
}

func handleMIFARE(uid string, simulate bool, write, verify bool) {
	if simulate {
		simulateCardData("mifare", 0, 0, 0, 0, "", uid)
	} else {
		fmt.Println(Green, "\nHandling MIFARE card...", Reset)
		if write {
			fmt.Println(Green, "\nThe following will be written to a UID rewritable MIFARE card:", Reset)
		} else {
			fmt.Println(Green, "\nWrite the following values to a UID rewritable MIFARE card:", Reset)
		}
		fmt.Println(Green, "", Reset)
		fmt.Println(Yellow, fmt.Sprintf("hf mf csetuid -u %s", uid), Reset)
		fmt.Println(Green, "\nNote, this will only emulate the Wiegand signal of the captured card. This will not fully replicate the captured MIFARE card. This considered experimental as the badging system that your client employs may interpret the data differently than the reader that provided the Wiegand output to doppelganger.", Reset)

		if write {
			writeCardData("mifare", 0, 0, 0, 0, "", verify, uid)
		}

		if verify {
			verifyCardData("mifare", 0, 0, "", uid)
		}
	}
}
