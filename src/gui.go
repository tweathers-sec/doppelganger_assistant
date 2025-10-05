package main

import (
	"bufio"
	"fmt"
	"image/color"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// outputDisplay provides a text display widget for command and status output.
type outputDisplay struct {
	widget.Label
	mu        sync.Mutex
	stripANSI bool
}

func newOutputDisplay(stripANSI bool) *outputDisplay {
	o := &outputDisplay{stripANSI: stripANSI}
	o.ExtendBaseWidget(o)
	o.Wrapping = fyne.TextWrapWord
	o.TextStyle = fyne.TextStyle{Monospace: true}
	return o
}

func (o *outputDisplay) Append(text string) {
	clean := text
	if o.stripANSI {
		clean = stripANSI(text)
	}

	o.mu.Lock()
	o.Text += clean
	o.mu.Unlock()

	fyne.Do(func() {
		o.Refresh()
	})
}

func (o *outputDisplay) Clear() {
	o.mu.Lock()
	o.Text = ""
	o.mu.Unlock()

	fyne.Do(func() {
		o.Refresh()
	})
}

func (o *outputDisplay) Set(text string) {
	clean := text
	if o.stripANSI {
		clean = stripANSI(text)
	}

	o.mu.Lock()
	o.Text = clean
	o.mu.Unlock()

	fyne.Do(func() {
		o.Refresh()
	})
}

// stripANSI removes ANSI escape codes from a string.
func stripANSI(str string) string {
	ansiRegex := regexp.MustCompile(`\x1b\[[0-9;]*[a-zA-Z]`)
	return ansiRegex.ReplaceAllString(str, "")
}

// guiWriter implements io.Writer to route output to GUI widgets.
type guiWriter struct {
	output *outputDisplay
	scroll *container.Scroll
}

func (w *guiWriter) Write(p []byte) (n int, err error) {
	text := string(p)

	if strings.HasPrefix(text, "[SUCCESS] ") {
		text = "[OK] " + strings.TrimPrefix(text, "[SUCCESS] ")
	} else if strings.HasPrefix(text, "[ERROR] ") {
		text = "[!!] " + strings.TrimPrefix(text, "[ERROR] ")
	} else if strings.HasPrefix(text, "[INFO] ") {
		text = "[>>] " + strings.TrimPrefix(text, "[INFO] ")
	} else if strings.HasPrefix(text, "[PROGRESS] ") {
		text = "[..] " + strings.TrimPrefix(text, "[PROGRESS] ")
	}

	w.output.Append(text)

	if w.scroll != nil {
		fyne.Do(func() {
			w.scroll.ScrollToBottom()
		})
	}

	return len(p), nil
}

// fixedWidthLayout provides a fixed-width layout for the left sidebar.
type fixedWidthLayout struct {
	width float32
}

func (l *fixedWidthLayout) MinSize(objects []fyne.CanvasObject) fyne.Size {
	return fyne.NewSize(l.width, 600)
}

func (l *fixedWidthLayout) Layout(objects []fyne.CanvasObject, size fyne.Size) {
	for _, obj := range objects {
		obj.Resize(fyne.NewSize(l.width, size.Height))
		obj.Move(fyne.NewPos(0, 0))
	}
}

// outlinedButton provides a custom button with orange outline styling.
type outlinedButton struct {
	widget.BaseWidget
	text     string
	onTapped func()
	bg       *canvas.Rectangle
	border   *canvas.Rectangle
	label    *canvas.Text
	hovered  bool
}

func newOutlinedButton(text string, tapped func()) *outlinedButton {
	btn := &outlinedButton{
		text:     text,
		onTapped: tapped,
	}
	btn.ExtendBaseWidget(btn)
	return btn
}

func (b *outlinedButton) CreateRenderer() fyne.WidgetRenderer {
	b.bg = canvas.NewRectangle(color.RGBA{R: 226, G: 88, B: 34, A: 20})
	b.bg.CornerRadius = 5

	b.border = canvas.NewRectangle(color.RGBA{R: 0, G: 0, B: 0, A: 0})
	b.border.StrokeColor = color.RGBA{R: 226, G: 88, B: 34, A: 255}
	b.border.StrokeWidth = 2
	b.border.CornerRadius = 5

	b.label = canvas.NewText(b.text, color.RGBA{R: 226, G: 88, B: 34, A: 255})
	b.label.Alignment = fyne.TextAlignCenter
	b.label.TextSize = 13
	b.label.TextStyle = fyne.TextStyle{Bold: true}

	return &outlinedButtonRenderer{
		button:  b,
		bg:      b.bg,
		border:  b.border,
		label:   b.label,
		objects: []fyne.CanvasObject{b.bg, b.border, b.label},
	}
}

func (b *outlinedButton) Tapped(*fyne.PointEvent) {
	if b.onTapped != nil {
		b.onTapped()
	}
}

func (b *outlinedButton) MouseIn(*desktop.MouseEvent) {
	b.hovered = true
	b.bg.FillColor = color.RGBA{R: 226, G: 88, B: 34, A: 40} // Slightly more opaque on hover
	b.bg.Refresh()
}

func (b *outlinedButton) MouseOut() {
	b.hovered = false
	b.bg.FillColor = color.RGBA{R: 226, G: 88, B: 34, A: 20}
	b.bg.Refresh()
}

func (b *outlinedButton) MouseMoved(*desktop.MouseEvent) {}

type outlinedButtonRenderer struct {
	button  *outlinedButton
	bg      *canvas.Rectangle
	border  *canvas.Rectangle
	label   *canvas.Text
	objects []fyne.CanvasObject
}

func (r *outlinedButtonRenderer) Layout(size fyne.Size) {
	r.bg.Resize(size)
	r.bg.Move(fyne.NewPos(0, 0))

	r.border.Resize(size)
	r.border.Move(fyne.NewPos(0, 0))

	r.label.Resize(size)
	r.label.Move(fyne.NewPos(0, 0))
}

func (r *outlinedButtonRenderer) MinSize() fyne.Size {
	textSize := fyne.MeasureText(r.label.Text, r.label.TextSize, r.label.TextStyle)
	return fyne.NewSize(textSize.Width+30, 30)
}

func (r *outlinedButtonRenderer) Refresh() {
	r.label.Text = r.button.text
	r.label.Refresh()
	canvas.Refresh(r.button)
}

func (r *outlinedButtonRenderer) Objects() []fyne.CanvasObject {
	return r.objects
}

func (r *outlinedButtonRenderer) Destroy() {}

// arrowDarkTheme provides a custom dark theme for the application.
type arrowDarkTheme struct{}

func (t *arrowDarkTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return color.RGBA{R: 12, G: 14, B: 16, A: 255} // #0c0e10
	case theme.ColorNameButton:
		return color.RGBA{R: 226, G: 88, B: 34, A: 255} // #e25822
	case theme.ColorNameDisabledButton:
		return color.RGBA{R: 100, G: 100, B: 100, A: 255}
	case theme.ColorNameDisabled:
		return color.RGBA{R: 240, G: 246, B: 252, A: 255} // Same as foreground - keep text visible
	case theme.ColorNameHover:
		return color.RGBA{R: 255, G: 109, B: 61, A: 255} // #ff6d3d
	case theme.ColorNameInputBackground:
		return color.RGBA{R: 30, G: 35, B: 41, A: 255} // #1e2329
	case theme.ColorNameInputBorder:
		return color.RGBA{R: 42, G: 48, B: 55, A: 255} // #2a3037
	case theme.ColorNameFocus:
		return color.RGBA{R: 226, G: 88, B: 34, A: 255} // #e25822
	case theme.ColorNameForeground:
		return color.RGBA{R: 240, G: 246, B: 252, A: 255} // #f0f6fc
	case theme.ColorNamePlaceHolder:
		return color.RGBA{R: 169, G: 182, B: 201, A: 255} // #a9b6c9
	case theme.ColorNamePressed:
		return color.RGBA{R: 191, G: 73, B: 25, A: 255} // #bf4919
	case theme.ColorNamePrimary:
		return color.RGBA{R: 226, G: 88, B: 34, A: 255} // #e25822
	case theme.ColorNameScrollBar:
		return color.RGBA{R: 42, G: 48, B: 55, A: 255} // #2a3037
	case theme.ColorNameSelection:
		return color.RGBA{R: 226, G: 88, B: 34, A: 100}
	case theme.ColorNameSeparator:
		return color.RGBA{R: 42, G: 48, B: 55, A: 255} // #2a3037
	case theme.ColorNameShadow:
		return color.RGBA{R: 0, G: 0, B: 0, A: 51}
	default:
		return theme.DefaultTheme().Color(name, variant)
	}
}

func (t *arrowDarkTheme) Font(style fyne.TextStyle) fyne.Resource {
	return theme.DefaultTheme().Font(style)
}

func (t *arrowDarkTheme) Icon(name fyne.ThemeIconName) fyne.Resource {
	return theme.DefaultTheme().Icon(name)
}

func (t *arrowDarkTheme) Size(name fyne.ThemeSizeName) float32 {
	return theme.DefaultTheme().Size(name)
}

func runGUI() {
	os.Setenv("FYNE_DISABLE_CALL_CHECKING", "1")

	a := app.New()
	w := a.NewWindow("Doppelgänger Assistant")

	a.Settings().SetTheme(&arrowDarkTheme{})

	w.Resize(fyne.NewSize(1400, 800))
	w.CenterOnScreen()

	logo := canvas.NewImageFromResource(resourceDoppelgangerdmPng)
	logo.FillMode = canvas.ImageFillContain
	logo.SetMinSize(fyne.NewSize(200, 50))

	header := container.NewVBox(
		container.NewCenter(logo),
	)

	cardTypeLabel := canvas.NewText("CARD TYPE", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	cardTypeLabel.TextSize = 11
	cardTypes := []string{"PROX", "iCLASS", "AWID", "Indala", "Avigilon", "EM4100", "PIV", "MIFARE"}
	cardType := widget.NewSelect(cardTypes, nil)

	bitLengthLabel := canvas.NewText("BIT LENGTH", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	bitLengthLabel.TextSize = 11
	bitLength := widget.NewSelect([]string{}, nil)

	facilityCode := widget.NewEntry()
	facilityCode.SetPlaceHolder("Facility Code")
	cardNumber := widget.NewEntry()
	cardNumber.SetPlaceHolder("Card Number")
	hexData := widget.NewEntry()
	hexData.SetPlaceHolder("Hex Data")
	uid := widget.NewEntry()
	uid.SetPlaceHolder("UID")

	dataBlocks := container.NewVBox()

	actionLabel := canvas.NewText("ACTION", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	actionLabel.TextSize = 11
	action := widget.NewSelect([]string{"Generate Command", "Write & Verify", "Simulate Card"}, nil)
	action.SetSelectedIndex(1) // Default to "Write & Verify"

	// Update fields based on card type
	updateDataBlocks := func(selectedType string) {
		dataBlocks.Objects = nil

		// Update bit lengths
		bitLengthOptions := map[string][]string{
			"PROX":     {"26", "30", "31", "33", "34", "35", "36", "37", "46", "48"},
			"iCLASS":   {"26", "30", "33", "34", "35", "36", "37", "46", "48"},
			"AWID":     {"26", "50"},
			"Indala":   {"26", "27", "29"},
			"Avigilon": {"56"},
		}

		if options, ok := bitLengthOptions[selectedType]; ok {
			bitLength.Options = options
			bitLength.SetSelectedIndex(0)
			dataBlocks.Add(bitLengthLabel)
			dataBlocks.Add(bitLength)
			dataBlocks.Add(widget.NewSeparator())
		} else {
			bitLength.Options = []string{}
		}

		// Update input fields based on card type
		switch selectedType {
		case "PROX", "iCLASS", "AWID", "Indala", "Avigilon":
			dataBlocks.Add(facilityCode)
			dataBlocks.Add(cardNumber)
		case "EM4100":
			dataBlocks.Add(hexData)
		case "PIV", "MIFARE":
			dataBlocks.Add(uid)
		}

		// Update action options based on card type
		// iCLASS simulation is disabled, so remove that option
		if selectedType == "iCLASS" {
			action.Options = []string{"Generate Command", "Write & Verify"}
		} else {
			action.Options = []string{"Generate Command", "Write & Verify", "Simulate Card"}
		}
		action.SetSelectedIndex(1)
		action.Refresh()

		dataBlocks.Refresh()
	}

	cardType.OnChanged = updateDataBlocks

	statusOutput := newOutputDisplay(true)
	commandOutput := newOutputDisplay(false)
	var currentStatusOutput *outputDisplay = statusOutput
	var currentCommandOutput *outputDisplay = commandOutput

	var statusScroll *container.Scroll
	var commandScroll *container.Scroll

	executeCommand := func() {
		cardTypeMap := map[string]string{
			"PROX":     "prox",
			"iCLASS":   "iclass",
			"AWID":     "awid",
			"Indala":   "indala",
			"Avigilon": "avigilon",
			"EM4100":   "em",
			"PIV":      "piv",
			"MIFARE":   "mifare",
		}

		cardTypeValue := cardType.Selected
		bitLengthValue := bitLength.Selected
		facilityCodeValue := facilityCode.Text
		cardNumberValue := cardNumber.Text
		hexDataValue := hexData.Text
		uidValue := uid.Text
		actionValue := action.Selected

		cardTypeCmd := cardTypeMap[cardTypeValue]

		var args []string
		args = append(args, "-t", cardTypeCmd)

		switch cardTypeCmd {
		case "prox", "iclass", "awid", "indala", "avigilon":
			if facilityCodeValue == "" || cardNumberValue == "" {
				currentStatusOutput.Set("ERROR: Facility Code and Card Number are required\n")
				return
			}
			args = append(args, "-bl", bitLengthValue, "-fc", facilityCodeValue, "-cn", cardNumberValue)
		case "em":
			if hexDataValue == "" {
				currentStatusOutput.Set("ERROR: Hex Data is required\n")
				return
			}
			args = append(args, "--hex", hexDataValue)
		case "mifare", "piv":
			if uidValue == "" {
				currentStatusOutput.Set("ERROR: UID is required\n")
				return
			}
			args = append(args, "--uid", uidValue)
		}

		switch actionValue {
		case "Write & Verify":
			args = append(args, "-w", "-v")
		case "Simulate Card":
			args = append(args, "-s")
		}

		go func() {
			currentStatusOutput.Clear()
			currentCommandOutput.Clear()

			fc, _ := strconv.Atoi(facilityCodeValue)
			cn, _ := strconv.Atoi(cardNumberValue)
			bl, _ := strconv.Atoi(bitLengthValue)

			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}

			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool)
			go func() {
				scanner := bufio.NewScanner(r)
				for scanner.Scan() {
					line := scanner.Text()
					currentCommandOutput.Append(line + "\n")
					if commandScroll != nil {
						fyne.Do(func() {
							commandScroll.ScrollToBottom()
						})
					}
				}
				done <- true
			}()

			SetStatusWriter(statusWriter)

			if actionValue == "Generate Command" {
				WriteStatusInfo("Generated PM3 command:")

				// Generate the actual PM3 command string based on card type
				var cmdStr string
				switch cardTypeCmd {
				case "prox":
					formatMap := map[int]string{26: "H10301", 30: "ATSW30", 31: "ADT31", 33: "D10202", 34: "H10306", 35: "C1k35s", 36: "S12906", 37: "H10304", 46: "H800002", 48: "C1k48s"}
					if format, ok := formatMap[bl]; ok {
						cmdStr = fmt.Sprintf("lf hid clone -w %s --fc %d --cn %d", format, fc, cn)
					}
				case "iclass":
					formatMap := map[int]string{26: "H10301", 30: "ATSW30", 33: "D10202", 34: "H10306", 35: "C1k35s", 36: "S12906", 37: "H10304", 46: "H800002", 48: "C1k48s"}
					if format, ok := formatMap[bl]; ok {
						cmdStr = fmt.Sprintf("hf iclass encode -w %s --fc %d --cn %d --ki 0", format, fc, cn)
					}
				case "awid":
					cmdStr = fmt.Sprintf("lf awid clone --fmt 26 --fc %d --cn %d", fc, cn)
				case "indala":
					cmdStr = fmt.Sprintf("lf indala clone --fc %d --cn %d", fc, cn)
				case "avigilon":
					cmdStr = fmt.Sprintf("lf hid clone -w Avig56 --fc %d --cn %d", fc, cn)
				case "em":
					cmdStr = fmt.Sprintf("lf em 410x clone --id %s", hexDataValue)
				case "mifare", "piv":
					cmdStr = fmt.Sprintf("hf mf csetuid -u %s", uidValue)
				}

				// Show command in command output
				if cmdStr != "" {
					fmt.Println(cmdStr)
				} else {
					fmt.Println("Error: Unsupported configuration")
				}

				// Restore stdout/stderr
				w.Close()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done

				WriteStatusSuccess("PM3 command generated")
				return
			}

			// Check Proxmark3 status for actual operations
			WriteStatusInfo("Checking Proxmark3 connection...")
			if ok, msg := checkProxmark3(); !ok {
				WriteStatusError(msg)
				w.Close()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}
			WriteStatusSuccess("Proxmark3 connected")
			WriteStatusInfo("Executing %s...", actionValue)

			// Determine operation
			write := (actionValue == "Write & Verify")
			verify := (actionValue == "Write & Verify")
			simulate := (actionValue == "Simulate Card")

			handleCardType(cardTypeCmd, fc, cn, bl, write, verify, uidValue, hexDataValue, simulate)

			os.Stdout.Sync()
			os.Stderr.Sync()

			w.Close()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done

			WriteStatusSuccess("%s completed", actionValue)
		}()
	}

	submit := newOutlinedButton("EXECUTE", executeCommand)
	reset := newOutlinedButton("RESET", func() {
		cardType.SetSelectedIndex(0)
		bitLength.SetSelectedIndex(0)
		facilityCode.SetText("")
		cardNumber.SetText("")
		hexData.SetText("")
		uid.SetText("")
		action.SetSelectedIndex(1)
		updateDataBlocks(cardTypes[0])
	})

	outputLabel := canvas.NewText("OUTPUT", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	outputLabel.TextSize = 11

	copyOutput := newOutlinedButton("COPY OUTPUT", func() {
		currentCommandOutput.mu.Lock()
		commandText := currentCommandOutput.Text
		currentCommandOutput.mu.Unlock()

		w.Clipboard().SetContent(commandText)
		WriteStatusSuccess("Output copied to clipboard!")
	})

	clearOutput := newOutlinedButton("CLEAR OUTPUT", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
	})

	submitSized := container.NewStack(submit)
	submitSized.Resize(fyne.NewSize(100, 30))

	resetSized := container.NewStack(reset)
	resetSized.Resize(fyne.NewSize(80, 30))

	buttonRow := container.NewHBox(
		layout.NewSpacer(),
		submitSized,
		resetSized,
	)

	versionText := canvas.NewText("v"+Version, color.RGBA{R: 169, G: 182, B: 201, A: 128})
	versionText.TextSize = 11
	versionText.Alignment = fyne.TextAlignCenter

	leftColumnContent := container.NewVBox(
		header,
		widget.NewSeparator(),
		container.NewPadded(cardTypeLabel),
		container.NewPadded(cardType),
		widget.NewSeparator(),
		container.NewPadded(dataBlocks),
		widget.NewSeparator(),
		container.NewPadded(actionLabel),
		container.NewPadded(action),
		widget.NewSeparator(),
		container.NewPadded(buttonRow),
		layout.NewSpacer(),
		container.NewPadded(versionText),
	)

	outputHeader := container.NewHBox(
		container.NewPadded(outputLabel),
		layout.NewSpacer(),
		container.NewPadded(copyOutput),
		container.NewPadded(clearOutput),
	)

	statusBg := canvas.NewRectangle(color.RGBA{R: 30, G: 35, B: 41, A: 255})
	statusBg.CornerRadius = 5
	statusBg.StrokeColor = color.RGBA{R: 128, G: 128, B: 128, A: 255}
	statusBg.StrokeWidth = 1
	statusScroll = container.NewScroll(statusOutput)
	statusScroll.SetMinSize(fyne.NewSize(0, 200))
	statusWithBg := container.NewStack(statusBg, statusScroll)

	commandBg := canvas.NewRectangle(color.RGBA{R: 30, G: 35, B: 41, A: 255})
	commandBg.CornerRadius = 5
	commandBg.StrokeColor = color.RGBA{R: 128, G: 128, B: 128, A: 255}
	commandBg.StrokeWidth = 1
	commandScroll = container.NewScroll(commandOutput)
	commandWithBg := container.NewStack(commandBg, commandScroll)

	outputArea := container.NewBorder(
		statusWithBg,
		nil, nil, nil,
		commandWithBg,
	)

	rightColumn := container.NewBorder(
		outputHeader,
		nil, nil, nil,
		outputArea,
	)

	leftWithWrapper := container.New(
		layout.NewMaxLayout(),
		container.NewPadded(
			container.New(
				&fixedWidthLayout{width: 280},
				leftColumnContent,
			),
		),
	)

	content := container.NewBorder(
		nil, nil,
		leftWithWrapper,
		nil,
		rightColumn,
	)

	w.SetContent(content)

	cardType.SetSelectedIndex(0)
	action.SetSelectedIndex(1)
	updateDataBlocks(cardTypes[0])

	w.ShowAndRun()
}

func joinArgs(args []string) string {
	result := ""
	for i, arg := range args {
		if i > 0 {
			result += " "
		}
		if len(arg) > 0 && (arg[0] == '-' || arg == strings.TrimSpace(arg)) {
			result += arg
		} else {
			result += fmt.Sprintf("\"%s\"", arg)
		}
	}
	return result
}
