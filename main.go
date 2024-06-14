// iCLASS Card Writing Assistant (Doppelgagner/Stealth Reader/MFAS Reader)
// Author: @tweathers-sec (@tweathers_sec on X.com)
// Version: 1.0
// Last Edit: June 13, 2024

package main

import (
	"flag"
	"fmt"
	"os"
)

const (
	Red    = "\033[31m"
	Green  = "\033[32m"
	Yellow = "\033[33m"
	Reset  = "\033[0m"
)

func main() {
	bitLength := flag.Int("bl", 0, "Bit length")
	facilityCode := flag.Int("fc", 0, "Facility code")
	cardNumber := flag.Int("cn", 0, "Card number")
	cardType := flag.String("t", "prox", "Card type (iclass, prox, awid, indala, em, piv, mifare)")
	uid := flag.String("uid", "", "UID for PIV and MIFARE cards (4 x HEX Bytes in the Card_Number column)")
	hexData := flag.String("hex", "", "Hex data for EM cards")
	write := flag.Bool("w", false, "Write card data")
	verify := flag.Bool("v", false, "Verify written card data")
	simulate := flag.Bool("s", false, "Card simulation (only for PIV and MIFARE)")

	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: %s -bl <bit length> -fc <facility code> -cn <card number> -t <card type> [-uid <UID>] [-hex <Hex Data>] [-w] [-v] [-s]\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "\n")
		flag.PrintDefaults()
		fmt.Fprintf(os.Stderr, "\n")
		fmt.Fprintf(os.Stderr, "Supported card types and bit lengths:\n")
		fmt.Fprintf(os.Stderr, "\n")
		fmt.Fprintf(os.Stderr, "  iclass: 26, 35\n")
		fmt.Fprintf(os.Stderr, "  prox: 26, 30, 31, 33, 34, 35, 36, 37, 48\n")
		fmt.Fprintf(os.Stderr, "  awid: 26\n")
		fmt.Fprintf(os.Stderr, "  indala: 26, 27, 28, 29\n")
		fmt.Fprintf(os.Stderr, "  em: 32\n")
		fmt.Fprintf(os.Stderr, "  piv: N/A\n")
		fmt.Fprintf(os.Stderr, "  mifare: N/A\n")
	}

	flag.Parse()

	if *cardType == "piv" || *cardType == "mifare" {
		if *uid == "" {
			fmt.Println(Red, "UID is required for PIV and MIFARE card types.", Reset)
			return
		}
		if *write || *verify {
			fmt.Println(Red, "Write and Verify modes are not applicable for PIV and MIFARE card types.", Reset)
			return
		}
	} else {
		if *bitLength == 0 || (*cardType != "em" && (*facilityCode == 0 || *cardNumber == 0)) {
			flag.Usage()
			return
		}
		if *simulate {
			fmt.Println(Red, "Simulate mode is only applicable for PIV and MIFARE card types.", Reset)
			return
		}
		switch *cardType {
		case "iclass":
			if *bitLength != 26 && *bitLength != 35 {
				fmt.Println(Red, "Invalid bit length for iCLASS. Supported bit lengths are 26 and 35.", Reset)
				return
			}
		case "indala":
			if *bitLength != 26 && *bitLength != 27 && *bitLength != 28 && *bitLength != 29 {
				fmt.Println(Red, "Invalid bit length for Indala. Supported bit lengths are 26, 27, 28, and 29.", Reset)
				return
			}
		case "prox":
			if *bitLength != 26 && *bitLength != 30 && *bitLength != 31 && *bitLength != 33 && *bitLength != 34 && *bitLength != 35 && *bitLength != 36 && *bitLength != 37 && *bitLength != 48 {
				fmt.Println(Red, "Invalid bit length for Prox. Supported bit lengths are 26, 30, 31, 33, 34, 35, 36, 37, and 48.", Reset)
				return
			}
		case "awid":
			if *bitLength != 26 {
				fmt.Println(Red, "Invalid bit length for AWID. Supported bit length is 26.", Reset)
				return
			}
		case "em":
			if *bitLength != 32 {
				fmt.Println(Red, "Invalid bit length for EM. Supported bit length is 32.", Reset)
				return
			}
			if *hexData == "" {
				fmt.Println(Red, "Hex data is required for EM card type.", Reset)
				return
			}
		default:
			fmt.Println(Red, "Unsupported card type.", Reset)
			return
		}
	}

	if !checkProxmark3Version() {
		return
	}

	handleCardType(*cardType, *facilityCode, *cardNumber, *bitLength, *write, *verify, *uid, *hexData, *simulate)
}
