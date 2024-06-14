package main

import (
	"fmt"
)

func generate35bitHex(facilityCode, cardCode int, preamble uint64, write bool) uint64 {
	cardData := (uint64(facilityCode) << 21) + (uint64(cardCode) << 1)
	parity1 := bitCount(cardData&0x1B6DB6DB6) & 1
	cardData += uint64(parity1) << 33
	parity2 := bitCount(cardData&0x36DB6DB6C)&1 ^ 1
	cardData += uint64(parity2)
	parity3 := bitCount(cardData)&1 ^ 1
	cardData += uint64(parity3) << 34

	preamble ^= 0x2000000000
	cardData |= preamble

	fmt.Println("")
	if write {
		fmt.Println(Green, "The following will be written to an iCLASS 2k card:", Reset)
	} else {
		fmt.Println(Green, "Write the following values to an iCLASS 2k card:", Reset)
	}
	fmt.Println(Green, "", Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0", Reset)
	fmt.Println(Yellow, fmt.Sprintf("hf iclass wrbl --blk 7 -d %016x --ki 0", cardData), Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0", Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0", Reset)
	fmt.Println(Green, "", Reset)

	return cardData
}

func generate26bitHex(facilityCode, cardCode int, preamble uint64, write bool) uint64 {
	cardData := (uint64(facilityCode) << 17) + (uint64(cardCode) << 1)
	parity1 := bitCount(cardData&0x1FFE000) & 1
	parity2 := bitCount(cardData&0x0001FFE)&1 ^ 1
	cardData += (uint64(parity1) << 25) + uint64(parity2)

	preamble ^= 0x2000000000
	cardData |= preamble

	fmt.Println("")
	if write {
		fmt.Println(Green, "The following will be written to an iCLASS 2k card:", Reset)
	} else {
		fmt.Println(Green, "Write the following values to an iCLASS 2k card:", Reset)
	}
	fmt.Println(Green, "", Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0", Reset)
	fmt.Println(Yellow, fmt.Sprintf("hf iclass wrbl --blk 7 -d %016x --ki 0", cardData), Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0", Reset)
	fmt.Println(Yellow, "hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0", Reset)
	fmt.Println(Green, "", Reset)

	return cardData
}
