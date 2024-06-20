package main

import (
	"fmt"
	"os"
	"os/exec"
	"runtime"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/widget"
)

func runGUI() {
	a := app.New()
	w := a.NewWindow("Doppelgänger Assistant")

	w.Resize(fyne.NewSize(320, 475))

	cardTypes := []string{"prox", "indala", "awid", "em", "iclass", "mifare", "piv"}
	bitLengths := map[string][]string{
		"prox":   {"26", "30", "31", "32", "33", "34", "36", "37", "48"},
		"indala": {"26", "27", "29"},
		"awid":   {"26"},
		"em":     {"32"},
		"iclass": {"26", "35"},
		"mifare": {"0"},
		"piv":    {"0"},
	}

	facilityCode := widget.NewEntry()
	cardNumber := widget.NewEntry()
	hexData := widget.NewEntry()
	uid := widget.NewEntry()

	dataBlocks := container.NewVBox()

	updateDataBlocks := func(cardType string) {
		dataBlocks.Objects = nil
		switch cardType {
		case "prox", "indala", "awid", "iclass":
			dataBlocks.Add(widget.NewLabel("Facility Code"))
			dataBlocks.Add(facilityCode)
			dataBlocks.Add(widget.NewLabel("Card Number"))
			dataBlocks.Add(cardNumber)
		case "em":
			dataBlocks.Add(widget.NewLabel("Hex Data"))
			dataBlocks.Add(hexData)
		case "mifare", "piv":
			dataBlocks.Add(widget.NewLabel("UID"))
			dataBlocks.Add(uid)
		}
		dataBlocks.Refresh()
	}

	bitLength := widget.NewSelect(bitLengths[cardTypes[0]], nil)
	bitLength.SetSelectedIndex(0)

	cardType := widget.NewSelect(cardTypes, func(value string) {
		bitLength.Options = bitLengths[value]
		bitLength.SetSelectedIndex(0)
		updateDataBlocks(value)
	})
	cardType.SetSelectedIndex(0)

	actions := []string{"Generate Proxmark3 Command", "Write & Verify Card Data", "Simulate Card Data"}
	action := widget.NewSelect(actions, nil)
	action.SetSelectedIndex(0)

	terminalOutput := widget.NewLabel("")

	submit := widget.NewButton("Submit", func() {
		cardTypeValue := cardType.Selected
		bitLengthValue := bitLength.Selected
		facilityCodeValue := facilityCode.Text
		cardNumberValue := cardNumber.Text
		hexDataValue := hexData.Text
		uidValue := uid.Text
		actionValue := action.Selected

		var cmd *exec.Cmd
		cwd, err := os.Getwd()
		if err != nil {
			fmt.Println("Error getting current working directory:", err)
			return
		}

		command := ""
		switch actionValue {
		case "Generate Proxmark3 Command":
			command = fmt.Sprintf("echo Generating Proxmark3 command for %s with bit length %s", cardTypeValue, bitLengthValue)
			if cardTypeValue == "prox" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "iclass" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "awid" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "indala" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "em" {
				command = fmt.Sprintf("%s -t %s --hex %s", os.Args[0], cardTypeValue, hexDataValue)
			} else if cardTypeValue == "mifare" {
				command = fmt.Sprintf("%s -t %s --uid %s", os.Args[0], cardTypeValue, uidValue)
			} else if cardTypeValue == "piv" {
				command = fmt.Sprintf("%s -t %s --uid %s", os.Args[0], cardTypeValue, uidValue)
			}
		case "Write & Verify Card Data":
			command = fmt.Sprintf("echo Writing and verifying card data for %s", cardTypeValue)
			if cardTypeValue == "prox" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -w -v", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "iclass" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -w -v", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "awid" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -w -v", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "indala" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -w -v", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "em" {
				command = fmt.Sprintf("%s -t %s --hex %s -w -v", os.Args[0], cardTypeValue, hexDataValue)
			} else if cardTypeValue == "mifare" {
				command = fmt.Sprintf("%s -t %s --uid %s -w -v", os.Args[0], cardTypeValue, uidValue)
			} else if cardTypeValue == "piv" {
				command = fmt.Sprintf("%s -t %s --uid %s -w -v", os.Args[0], cardTypeValue, uidValue)
			}
		case "Simulate Card Data":
			command = fmt.Sprintf("echo Simulating card data for %s", cardTypeValue)
			if cardTypeValue == "prox" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "iclass" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "awid" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "indala" {
				command = fmt.Sprintf("%s -t %s -bl %s -fc %s -cn %s -s", os.Args[0], cardTypeValue, bitLengthValue, facilityCodeValue, cardNumberValue)
			} else if cardTypeValue == "em" {
				command = fmt.Sprintf("%s -t %s --hex %s -s", os.Args[0], cardTypeValue, hexDataValue)
			} else if cardTypeValue == "mifare" {
				command = fmt.Sprintf("%s -t %s --uid %s -s", os.Args[0], cardTypeValue, uidValue)
			} else if cardTypeValue == "piv" {
				command = fmt.Sprintf("%s -t %s --uid %s -s", os.Args[0], cardTypeValue, uidValue)
			}
		default:
			fmt.Println("Unsupported action")
			return
		}

		switch runtime.GOOS {
		case "darwin":
			cmd = exec.Command("osascript", "-e", fmt.Sprintf("tell application \"Terminal\" to do script \"cd '%s' && clear && %s\"", cwd, command))
		case "linux":
			if _, err := exec.LookPath("gnome-terminal"); err == nil {
				cmd = exec.Command("gnome-terminal", "--", "sh", "-c", fmt.Sprintf("cd \"%s\" && clear && %s; exec bash", cwd, command))
			} else if _, err := exec.LookPath("xterm"); err == nil {
				cmd = exec.Command("xterm", "-bg", "black", "-fg", "white", "-e", fmt.Sprintf("sh -c 'cd \"%s\" && clear && %s; exec bash'", cwd, command))
			} else if _, err := exec.LookPath("x-terminal-emulator"); err == nil {
				cmd = exec.Command("x-terminal-emulator", "-e", fmt.Sprintf("sh -c 'cd \"%s\" && clear && %s; exec bash'", cwd, command))
			} else {
				fmt.Println("No supported terminal emulator found. If you're using WSL run: `sudo apt install xterm`")
				return
			}
		default:
			fmt.Println("Unsupported OS")
			return
		}

		err = cmd.Start()
		if err != nil {
			terminalOutput.SetText(fmt.Sprintf("Error: %s", err))
		} else {
			terminalOutput.SetText("Command executed in new terminal window")
		}
	})

	reset := widget.NewButton("Reset", func() {
		cardType.SetSelectedIndex(0)
		bitLength.SetSelectedIndex(0)
		facilityCode.SetText("")
		cardNumber.SetText("")
		hexData.SetText("")
		uid.SetText("")
		action.SetSelectedIndex(0)
		terminalOutput.SetText("")
		updateDataBlocks(cardTypes[0])
	})

	w.SetContent(container.NewVBox(
		widget.NewLabel("Card Type"),
		cardType,
		widget.NewLabel("Bit Length"),
		bitLength,
		dataBlocks,
		widget.NewLabel("Action"),
		action,
		container.NewHBox(submit, reset),
		terminalOutput,
	))

	w.ShowAndRun()
}
