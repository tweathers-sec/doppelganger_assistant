package main

import (
	"bufio"
	"fmt"
	"image/color"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

// Global cancellation channel for operations
var operationCancelChan chan struct{}
var operationCancelMutex sync.Mutex

// IsOperationCancelled checks if the current operation has been cancelled
func IsOperationCancelled() bool {
	operationCancelMutex.Lock()
	defer operationCancelMutex.Unlock()
	select {
	case <-operationCancelChan:
		return true
	default:
		return false
	}
}

// filterSearchOutput filters out "Searching for..." lines and keeps only important results
func filterSearchOutput(output string) string {
	lines := strings.Split(output, "\n")
	var filtered []string

	for _, line := range lines {
		// Skip "Searching for..." lines and progress indicators
		if strings.Contains(line, "Searching for") {
			continue
		}
		// Skip progress spinner lines (contain [\], [|], [/], [-])
		if strings.Contains(line, "[\\]") || strings.Contains(line, "[|]") ||
			strings.Contains(line, "[/]") || strings.Contains(line, "[-]") {
			// But keep lines that have [-] and actual content (like errors or results)
			if strings.Contains(line, "[-]") &&
				(strings.Contains(line, "found") || strings.Contains(line, "No") ||
					strings.Contains(line, "failed") || strings.Contains(line, "error")) {
				filtered = append(filtered, line)
			}
			continue
		}
		// Keep everything else (results, errors, hints, etc.)
		filtered = append(filtered, line)
	}

	return strings.Join(filtered, "\n")
}

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
		text = "✓  " + strings.TrimPrefix(text, "[SUCCESS] ")
	} else if strings.HasPrefix(text, "[ERROR] ") {
		text = "✗  " + strings.TrimPrefix(text, "[ERROR] ")
	} else if strings.HasPrefix(text, "[INFO] ") {
		text = "►  " + strings.TrimPrefix(text, "[INFO] ")
	} else if strings.HasPrefix(text, "[PROGRESS] ") {
		text = "⋯  " + strings.TrimPrefix(text, "[PROGRESS] ")
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

// validateCardInput validates facility code and card number ranges for each card type and bit length
func validateCardInput(cardType string, bitLength int, fc int, cn int) (bool, string) {
	type rangeInfo struct {
		fcMax int
		cnMax int
	}

	// Define valid ranges for each card type and bit length
	ranges := map[string]map[int]rangeInfo{
		"prox": {
			26: {fcMax: 255, cnMax: 65535},        // HID H10301
			28: {fcMax: 255, cnMax: 32767},        // 2804 Wiegand 28-bit
			30: {fcMax: 2047, cnMax: 32767},       // ATS Wiegand
			31: {fcMax: 15, cnMax: 8388607},       // HID ADT
			33: {fcMax: 127, cnMax: 16777215},     // HID D10202
			34: {fcMax: 65535, cnMax: 65535},      // HID H10306
			35: {fcMax: 4095, cnMax: 1048575},     // HID Corporate 1000 35-bit
			36: {fcMax: 255, cnMax: 65535},        // HID Simplex (S12906)
			37: {fcMax: 65535, cnMax: 524287},     // HID H10304
			46: {fcMax: 16383, cnMax: 1073741823}, // HID H800002
			48: {fcMax: 4194303, cnMax: 8388607},  // HID Corporate 1000 48-bit
		},
		"iclass": {
			26: {fcMax: 255, cnMax: 65535},        // HID H10301
			30: {fcMax: 2047, cnMax: 32767},       // ATS Wiegand
			33: {fcMax: 127, cnMax: 16777215},     // HID D10202
			34: {fcMax: 65535, cnMax: 65535},      // HID H10306
			35: {fcMax: 4095, cnMax: 1048575},     // HID Corporate 1000 35-bit
			36: {fcMax: 255, cnMax: 65535},        // HID Simplex (S12906)
			37: {fcMax: 65535, cnMax: 524287},     // HID H10304
			46: {fcMax: 16383, cnMax: 1073741823}, // HID H800002
			48: {fcMax: 4194303, cnMax: 8388607},  // HID Corporate 1000 48-bit
		},
		"awid": {
			26: {fcMax: 255, cnMax: 65535},     // Standard 26-bit
			50: {fcMax: 65535, cnMax: 8388607}, // Extended 50-bit
		},
		"indala": {
			26: {fcMax: 255, cnMax: 65535},  // Standard 26-bit
			27: {fcMax: 4095, cnMax: 8191},  // Indala 27-bit
			29: {fcMax: 4095, cnMax: 32767}, // Indala 29-bit
		},
		"avigilon": {
			56: {fcMax: 1048575, cnMax: 4194303}, // Avigilon 56-bit (20/22 split)
		},
	}

	// Check if card type has defined ranges
	cardRanges, exists := ranges[cardType]
	if !exists {
		return true, "" // No validation needed for this card type
	}

	// Check if bit length is valid for this card type
	limits, exists := cardRanges[bitLength]
	if !exists {
		return false, fmt.Sprintf("Invalid bit length %d for card type %s", bitLength, cardType)
	}

	// Validate facility code
	if fc < 0 || fc > limits.fcMax {
		return false, fmt.Sprintf("Facility Code must be between 0 and %d for %d-bit %s cards", limits.fcMax, bitLength, cardType)
	}

	// Validate card number
	if cn < 0 || cn > limits.cnMax {
		return false, fmt.Sprintf("Card Number must be between 0 and %d for %d-bit %s cards", limits.cnMax, bitLength, cardType)
	}

	return true, ""
}

func runGUI() {
	os.Setenv("FYNE_DISABLE_CALL_CHECKING", "1")

	// Set proper scaling for Linux to match macOS appearance
	if runtime.GOOS == "linux" {
		if os.Getenv("FYNE_SCALE") == "" {
			os.Setenv("FYNE_SCALE", "1.0")
		}
	}

	a := app.New()

	// Set the app icon (window title bar, taskbar, etc.)
	a.SetIcon(resourceIconPng)

	w := a.NewWindow("Doppelgänger Assistant")

	// Set window icon explicitly for Linux/Wayland support
	if runtime.GOOS == "linux" {
		w.SetIcon(resourceIconPng)
	}

	a.Settings().SetTheme(&arrowDarkTheme{})

	w.Resize(fyne.NewSize(1200, 875))
	w.CenterOnScreen()

	logo := canvas.NewImageFromResource(resourceDoppelgangerdmPng)
	logo.FillMode = canvas.ImageFillContain
	logo.SetMinSize(fyne.NewSize(200, 50))

	header := container.NewVBox(
		container.NewCenter(logo),
	)

	cardTypeLabel := canvas.NewText("CARD TYPE", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	cardTypeLabel.TextSize = 11
	cardTypes := []string{"PROX", "iCLASS", "AWID", "Indala", "Avigilon", "EM4100 / Net2", "PIV", "MIFARE"}
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

	// Define execute command function early so it can be referenced
	var executeCommand func()

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
			"PROX":     {"26", "28", "30", "31", "33", "34", "35", "36", "37", "46", "48"},
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
		case "EM4100 / Net2":
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
		// Reset to default selection after updating options
		if len(action.Options) > 1 {
			action.SetSelectedIndex(1) // Default to "Write & Verify"
		}
		fyne.Do(func() {
			action.Refresh()
		})

		dataBlocks.Refresh()
	}

	cardType.OnChanged = updateDataBlocks

	statusOutput := newOutputDisplay(true)
	commandOutput := newOutputDisplay(false)
	var currentStatusOutput *outputDisplay = statusOutput
	var currentCommandOutput *outputDisplay = commandOutput

	var statusScroll *container.Scroll
	var commandScroll *container.Scroll

	executeCommand = func() {
		// Clear output immediately when Execute is pressed
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()

		cardTypeMap := map[string]string{
			"PROX":          "prox",
			"iCLASS":        "iclass",
			"AWID":          "awid",
			"Indala":        "indala",
			"Avigilon":      "avigilon",
			"EM4100 / Net2": "em",
			"PIV":           "piv",
			"MIFARE":        "mifare",
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
				currentStatusOutput.Set("✗  Facility Code and Card Number are required\n")
				return
			}

			// Validate FC and CN ranges
			fc, fcErr := strconv.Atoi(facilityCodeValue)
			cn, cnErr := strconv.Atoi(cardNumberValue)
			bl, blErr := strconv.Atoi(bitLengthValue)

			if fcErr != nil || cnErr != nil || blErr != nil {
				currentStatusOutput.Set("✗  Invalid numeric values for Facility Code, Card Number, or Bit Length\n")
				return
			}

			if valid, errMsg := validateCardInput(cardTypeCmd, bl, fc, cn); !valid {
				currentStatusOutput.Set(fmt.Sprintf("✗  %s\n", errMsg))
				return
			}

			args = append(args, "-bl", bitLengthValue, "-fc", facilityCodeValue, "-cn", cardNumberValue)
		case "em":
			if hexDataValue == "" {
				currentStatusOutput.Set("✗  Hex Data is required for EM4100 / Net2 cards\n")
				return
			}
			// Validate EM4100 hex data format
			if valid, errMsg := validateEM4100Hex(hexDataValue); !valid {
				currentStatusOutput.Set(fmt.Sprintf("✗  %s\n", errMsg))
				return
			}
			args = append(args, "--hex", hexDataValue)
		case "mifare", "piv":
			if uidValue == "" {
				currentStatusOutput.Set("✗  UID is required\n")
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
			fc, _ := strconv.Atoi(facilityCodeValue)
			cn, _ := strconv.Atoi(cardNumberValue)
			bl, _ := strconv.Atoi(bitLengthValue)

			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}

			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1) // Buffered channel to prevent blocking
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)

			if actionValue == "Generate Command" {
				WriteStatusInfo("Generating PM3 command...")

				// Generate the actual PM3 command string based on card type
				var cmdStr string
				switch cardTypeCmd {
				case "prox":
					formatMap := map[int]string{26: "H10301", 28: "2804W", 30: "ATSW30", 31: "ADT31", 33: "D10202", 34: "H10306", 35: "C1k35s", 36: "S12906", 37: "H10304", 46: "H800002", 48: "C1k48s"}
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
				// Clean up and restore state
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

	// Initialize cancellation channel
	operationCancelChan = make(chan struct{})

	submit := newOutlinedButton("EXECUTE", func() {
		// Reset cancellation channel when starting new operation
		operationCancelMutex.Lock()
		close(operationCancelChan)
		operationCancelChan = make(chan struct{})
		operationCancelMutex.Unlock()
		executeCommand()
	})

	cancel := newOutlinedButton("CANCEL", func() {
		operationCancelMutex.Lock()
		select {
		case <-operationCancelChan:
			// Already closed
		default:
			close(operationCancelChan)
		}
		operationCancelMutex.Unlock()
		WriteStatusInfo("Operation cancellation requested...")
	})

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

	clearOutput := newOutlinedButton("CLEAR SCREEN", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
	})

	launchPm3Button := newOutlinedButton("LAUNCH PM3", func() {
		err := launchPm3Terminal()
		if err != nil {
			WriteStatusError("Failed to launch Proxmark3 terminal: %v", err)
		} else {
			WriteStatusSuccess("Proxmark3 terminal launched")
		}
	})

	submitSized := container.NewStack(submit)
	submitSized.Resize(fyne.NewSize(100, 30))

	cancelSized := container.NewStack(cancel)
	cancelSized.Resize(fyne.NewSize(90, 30))

	resetSized := container.NewStack(reset)
	resetSized.Resize(fyne.NewSize(80, 30))

	buttonRow := container.NewGridWithColumns(3,
		submitSized,
		cancelSized,
		resetSized,
	)

	versionText := canvas.NewText("v"+Version, color.RGBA{R: 169, G: 182, B: 201, A: 128})
	versionText.TextSize = 11
	versionText.Alignment = fyne.TextAlignCenter

	// READ CARD DATA button - uses the cardType dropdown from Corporate section
	readCardButton := newOutlinedButton("READ CARD DATA", func() {
		// Clear output immediately when Read is pressed
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()

		// Map GUI card type to internal card type
		readCardTypeMap := map[string]string{
			"PROX":          "prox",
			"iCLASS":        "iclass",
			"AWID":          "awid",
			"Indala":        "indala",
			"Avigilon":      "avigilon",
			"EM4100 / Net2": "em",
			"PIV":           "piv",
			"MIFARE":        "mifare",
		}

		// Use the cardType dropdown from Corporate section
		selectedReadType := cardType.Selected
		if selectedReadType == "" {
			WriteStatusError("Please select a card type first")
			return
		}
		cardTypeCmd := readCardTypeMap[selectedReadType]

		// Run in goroutine to keep UI responsive
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}

			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
				scanner := bufio.NewScanner(r)
				for scanner.Scan() {
					line := scanner.Text()
					// Write to command output window
					currentCommandOutput.Append(line + "\n")
					if commandScroll != nil {
						fyne.Do(func() {
							commandScroll.ScrollToBottom()
						})
					}
				}
			}()

			SetStatusWriter(statusWriter)

			WriteStatusInfo("Reading card...")

			// Check Proxmark3 connection
			if ok, msg := checkProxmark3(); !ok {
				WriteStatusError(msg)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			WriteStatusSuccess("Proxmark3 connected")
			readCardData(cardTypeCmd)

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done

			WriteStatusSuccess("Read card completed")
		}()
	})

	// Size the read card button
	readCardButtonSized := container.NewStack(readCardButton)
	readCardButtonSized.Resize(fyne.NewSize(120, 30))

	// Corporate Access Control Cards Section - collapsible
	corporateSectionContent := container.NewVBox(
		container.NewPadded(cardTypeLabel),
		container.NewPadded(cardType),
		widget.NewSeparator(),
		container.NewPadded(readCardButtonSized),
		widget.NewSeparator(),
		container.NewPadded(dataBlocks),
		widget.NewSeparator(),
		container.NewPadded(actionLabel),
		container.NewPadded(action),
		widget.NewSeparator(),
		container.NewPadded(buttonRow),
	)

	// Hotel / Residence Access Control Section - collapsible
	// Attack method selector
	attackMethodLabel := canvas.NewText("ATTACK METHOD", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	attackMethodLabel.TextSize = 11
	attackMethods := []string{"Autopwn", "Darkside", "Nested", "Hardnested", "Static Nested", "Bruteforce", "NACK Test"}
	attackMethod := widget.NewSelect(attackMethods, nil)
	attackMethod.SetSelectedIndex(0) // Default to Autopwn

	// Sniff keys button
	sniffKeysButton := newOutlinedButton("SNIFF KEYS", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			WriteStatusInfo("Starting key sniffing...")

			if ok, msg := checkProxmark3(); !ok {
				WriteStatusError(msg)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			WriteStatusSuccess("Proxmark3 connected")
			WriteStatusInfo("Place card on reader and use it at a reader to capture keys")

			pm3Binary, err := getPm3Path()
			if err != nil {
				WriteStatusError("Failed to find pm3 binary: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			device, err := getPm3Device()
			if err != nil {
				WriteStatusError("Failed to detect pm3 device: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			fmt.Println("hf sniff")
			fmt.Println()
			WriteStatusInfo("Sniffing will continue until you press the Proxmark3 button")
			WriteStatusInfo("Use 'data samples' to download captured data")
			WriteStatusInfo("Use 'data plot' to visualize captured data")

			cmd := exec.Command(pm3Binary, "-c", "hf sniff", "-p", device)
			output, cmdErr := cmd.CombinedOutput()
			outputStr := string(output)
			fmt.Println(outputStr)

			if cmdErr != nil {
				// Check if it's just the user pressing the button to stop
				if strings.Contains(outputStr, "button") || strings.Contains(outputStr, "Button") {
					WriteStatusSuccess("Sniffing stopped by user")
					WriteStatusInfo("Use buttons below to process captured data")
				} else {
					WriteStatusError("Sniff failed: %v", cmdErr)
				}
			} else {
				WriteStatusSuccess("Key sniffing completed")
				WriteStatusInfo("Use buttons below to process captured data")
			}

			// Extract sample count if available
			sampleRegex := regexp.MustCompile(`(\d+)\s+samples?`)
			if match := sampleRegex.FindStringSubmatch(outputStr); len(match) > 1 {
				WriteStatusInfo("Captured %s samples", match[1])
			}

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	// Dump file path input
	dumpFilePathLabel := canvas.NewText("DUMP FILE PATH", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	dumpFilePathLabel.TextSize = 11
	dumpFilePathEntry := widget.NewEntry()
	dumpFilePathEntry.SetPlaceHolder("/path/to/dump.bin")

	// Key file path input (optional)
	keyFilePathLabel := canvas.NewText("KEY FILE PATH (optional)", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	keyFilePathLabel.TextSize = 11
	keyFilePathEntry := widget.NewEntry()
	keyFilePathEntry.SetPlaceHolder("/path/to/key.bin")

	// Wipe card before writing checkbox
	wipeBeforeWrite := widget.NewCheck("Wipe card before writing", nil)
	wipeBeforeWrite.SetChecked(true) // Default to true for magic cards

	// Write from dump button
	writeFromDumpButton := newOutlinedButton("WRITE FROM DUMP", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()

		dumpPath := strings.TrimSpace(dumpFilePathEntry.Text)
		// If not specified, try to find the latest dump file
		if dumpPath == "" {
			latestDump := findLatestDumpFile()
			if latestDump != "" {
				dumpPath = latestDump
				fyne.Do(func() {
					dumpFilePathEntry.SetText(dumpPath)
				})
				WriteStatusInfo("Auto-selected latest dump file: %s", dumpPath)
			} else {
				WriteStatusError("Dump file path is required and no recent dump file found")
				return
			}
		}

		// Expand any tilde in path
		if strings.HasPrefix(dumpPath, "~") {
			homeDir, err := os.UserHomeDir()
			if err == nil {
				dumpPath = filepath.Join(homeDir, strings.TrimPrefix(dumpPath, "~"))
			}
		}

		// Convert to absolute path
		if !filepath.IsAbs(dumpPath) {
			absPath, err := filepath.Abs(dumpPath)
			if err == nil {
				dumpPath = absPath
			}
		}

		// Validate dump file exists
		if _, err := os.Stat(dumpPath); os.IsNotExist(err) {
			WriteStatusError("Dump file does not exist: %s", dumpPath)
			homeDir, _ := os.UserHomeDir()
			WriteStatusInfo("Searched locations: %s, %s/.proxmark3, current directory", homeDir, homeDir)
			// Try to find similar files
			if matches, _ := filepath.Glob(filepath.Join(filepath.Dir(dumpPath), filepath.Base(dumpPath)+"*")); len(matches) > 0 {
				WriteStatusInfo("Found similar files: %v", matches)
			}
			return
		}

		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			WriteStatusInfo("Writing card from dump file...")

			if ok, msg := checkProxmark3(); !ok {
				WriteStatusError(msg)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			WriteStatusSuccess("Proxmark3 connected")
			WriteStatusInfo("Place blank card on reader")

			pm3Binary, err := getPm3Path()
			if err != nil {
				WriteStatusError("Failed to find pm3 binary: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			device, err := getPm3Device()
			if err != nil {
				WriteStatusError("Failed to detect pm3 device: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			// Wipe card first if requested (recommended for magic cards)
			if wipeBeforeWrite.Checked {
				WriteStatusProgress("Wiping card to default state...")
				fmt.Println()
				fmt.Println("hf mf cwipe")
				fmt.Println()

				wipeCmd := exec.Command(pm3Binary, "-c", "hf mf cwipe", "-p", device)
				wipeOutput, wipeErr := wipeCmd.CombinedOutput()
				wipeOutputStr := string(wipeOutput)
				fmt.Println(wipeOutputStr)

				if wipeErr != nil {
					WriteStatusError("Wipe failed: %v", wipeErr)
					WriteStatusInfo("Continuing with write anyway...")
				} else {
					WriteStatusSuccess("Card wiped successfully")
				}
			}

			keyPath := strings.TrimSpace(keyFilePathEntry.Text)
			// If not specified, try to find the latest key file
			if keyPath == "" {
				latestKey := findLatestKeyFile()
				if latestKey != "" {
					keyPath = latestKey
					fyne.Do(func() {
						keyFilePathEntry.SetText(keyPath)
					})
					WriteStatusInfo("Auto-selected latest key file: %s", keyPath)
				}
			}

			// Expand any tilde in path
			if keyPath != "" && strings.HasPrefix(keyPath, "~") {
				homeDir, err := os.UserHomeDir()
				if err == nil {
					keyPath = filepath.Join(homeDir, strings.TrimPrefix(keyPath, "~"))
				}
			}

			// Convert to absolute path
			if keyPath != "" && !filepath.IsAbs(keyPath) {
				absPath, err := filepath.Abs(keyPath)
				if err == nil {
					keyPath = absPath
				}
			}

			// Validate key file exists if provided, otherwise skip it
			if keyPath != "" {
				if _, err := os.Stat(keyPath); os.IsNotExist(err) {
					WriteStatusError("Key file does not exist: %s", keyPath)
					WriteStatusInfo("Proceeding without key file...")
					keyPath = "" // Clear it so we don't use it
				}
			}

			var cmd *exec.Cmd
			var cmdStr string

			if keyPath != "" {
				cmdStr = fmt.Sprintf("hf mf restore -f %s -k %s", dumpPath, keyPath)
				cmd = exec.Command(pm3Binary, "-c", cmdStr, "-p", device)
				WriteStatusInfo("Using dump file: %s", dumpPath)
				WriteStatusInfo("Using key file: %s", keyPath)
			} else {
				cmdStr = fmt.Sprintf("hf mf restore -f %s", dumpPath)
				cmd = exec.Command(pm3Binary, "-c", cmdStr, "-p", device)
				WriteStatusInfo("Using dump file: %s (no key file)", dumpPath)
			}

			fmt.Println(cmdStr)
			fmt.Println()

			output, cmdErr := cmd.CombinedOutput()
			outputStr := string(output)
			fmt.Println(outputStr)

			if cmdErr != nil {
				WriteStatusError("Write failed: %v", cmdErr)
			} else {
				WriteStatusSuccess("Card written successfully from dump file")

				// Automatically verify the write
				WriteStatusProgress("Verifying card data...")
				fmt.Println()

				// Use the key file if available, otherwise try without
				var verifyCmd *exec.Cmd
				var verifyCmdStr string
				if keyPath != "" {
					verifyCmdStr = fmt.Sprintf("hf mf dump --ns -k %s", keyPath)
					verifyCmd = exec.Command(pm3Binary, "-c", verifyCmdStr, "-p", device)
					fmt.Println(verifyCmdStr)
				} else {
					verifyCmdStr = "hf mf dump --ns"
					verifyCmd = exec.Command(pm3Binary, "-c", verifyCmdStr, "-p", device)
					fmt.Println(verifyCmdStr)
				}
				fmt.Println()

				verifyOutput, verifyErr := verifyCmd.CombinedOutput()
				verifyOutputStr := string(verifyOutput)
				fmt.Println(verifyOutputStr)

				if verifyErr != nil {
					WriteStatusError("Verification dump failed: %v", verifyErr)
					WriteStatusInfo("Note: Some blocks may require different keys or may be protected")
				} else {
					// Read original dump file and extract UID
					var dumpUID, cardUID string
					var dumpATQA, dumpSAK, cardATQA, cardSAK string

					if dumpPath != "" {
						dumpData, err := os.ReadFile(dumpPath)
						if err == nil && len(dumpData) >= 16 {
							// MIFARE Classic UID is in block 0, bytes 0-3
							dumpUID = fmt.Sprintf("%02X%02X%02X%02X", dumpData[0], dumpData[1], dumpData[2], dumpData[3])
							// ATQA is typically in block 0, byte 6-7, SAK in byte 5
							if len(dumpData) > 7 {
								dumpSAK = fmt.Sprintf("%02X", dumpData[5])
								dumpATQA = fmt.Sprintf("%02X%02X", dumpData[6], dumpData[7])
							}
						}
					}

					// Extract UID from verification output (block 0)
					// Look for pattern: "   0 | XX XX XX XX ..." where first 4 bytes are UID
					block0Regex := regexp.MustCompile(`(?m)^\s+0\s+\|\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})`)
					block0Match := block0Regex.FindStringSubmatch(verifyOutputStr)
					if len(block0Match) == 5 {
						cardUID = strings.ToUpper(block0Match[1] + block0Match[2] + block0Match[3] + block0Match[4])
					}

					// Extract ATQA and SAK from block 0 if available
					block0FullRegex := regexp.MustCompile(`(?m)^\s+0\s+\|\s+([0-9A-F]{2}\s+){5}([0-9A-F]{2})\s+([0-9A-F]{2})\s+([0-9A-F]{2})`)
					block0FullMatch := block0FullRegex.FindStringSubmatch(verifyOutputStr)
					if len(block0FullMatch) >= 5 {
						cardSAK = strings.ToUpper(block0FullMatch[2])
						cardATQA = strings.ToUpper(block0FullMatch[3] + block0FullMatch[4])
					}

					// Compare and display results
					if dumpUID != "" && cardUID != "" {
						if dumpUID == cardUID {
							WriteStatusSuccess("✓ SUCCESS! Card UID matches dump file")
							WriteStatusInfo("UID: %s (matches)", cardUID)
						} else {
							WriteStatusError("UID mismatch! Dump: %s, Card: %s", dumpUID, cardUID)
						}

						// Show ATQA and SAK if available
						if dumpATQA != "" && cardATQA != "" {
							if dumpATQA == cardATQA {
								WriteStatusInfo("ATQA: %s (matches)", cardATQA)
							} else {
								WriteStatusInfo("ATQA: Dump=%s, Card=%s (mismatch)", dumpATQA, cardATQA)
							}
						}

						if dumpSAK != "" && cardSAK != "" {
							if dumpSAK == cardSAK {
								WriteStatusInfo("SAK: %s (matches)", cardSAK)
							} else {
								WriteStatusInfo("SAK: Dump=%s, Card=%s (mismatch)", dumpSAK, cardSAK)
							}
						}
					} else if cardUID != "" {
						WriteStatusSuccess("✓ Card verified successfully")
						WriteStatusInfo("Card UID: %s", cardUID)
						if cardATQA != "" {
							WriteStatusInfo("ATQA: %s", cardATQA)
						}
						if cardSAK != "" {
							WriteStatusInfo("SAK: %s", cardSAK)
						}
					}

					// Check for success indicators
					if strings.Contains(verifyOutputStr, "Succeeded in dumping all blocks") {
						okCount := strings.Count(verifyOutputStr, "( ok )")
						WriteStatusInfo("All %d blocks read successfully", okCount)
					}
				}
			}

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	// Start attack button (uses selected attack method)
	recoverKeysButton := newOutlinedButton("START ATTACK", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()

		selectedMethod := attackMethod.Selected
		if selectedMethod == "" {
			selectedMethod = "Autopwn"
		}

		// Map GUI method name to internal method name
		methodMap := map[string]string{
			"Autopwn":       "autopwn",
			"Darkside":      "darkside",
			"Nested":        "nested",
			"Hardnested":    "hardnested",
			"Static Nested": "staticnested",
			"Bruteforce":    "brute",
			"NACK Test":     "nack",
		}

		recoveryMethod := methodMap[selectedMethod]
		if recoveryMethod == "" {
			recoveryMethod = "autopwn"
		}

		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			// Pass callback to auto-populate file paths when recovery completes
			recoverHotelKey(recoveryMethod, func(dumpPath, keyPath string) {
				if dumpPath != "" {
					fyne.Do(func() {
						dumpFilePathEntry.SetText(dumpPath)
					})
				}
				if keyPath != "" {
					fyne.Do(func() {
						keyFilePathEntry.SetText(keyPath)
					})
				}
			})

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	// Size buttons consistently
	sniffKeysButtonSized := container.NewStack(sniffKeysButton)
	sniffKeysButtonSized.Resize(fyne.NewSize(120, 30))
	recoverKeysButtonSized := container.NewStack(recoverKeysButton)
	recoverKeysButtonSized.Resize(fyne.NewSize(120, 30))
	writeFromDumpButtonSized := container.NewStack(writeFromDumpButton)
	writeFromDumpButtonSized.Resize(fyne.NewSize(140, 30))

	// Analysis and utility buttons
	cardInfoButton := newOutlinedButton("CARD INFO", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			getCardInfo()

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	checkKeysButton := newOutlinedButton("CHECK KEYS", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
		keyPath := strings.TrimSpace(keyFilePathEntry.Text)
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			checkKeysFast(keyPath)

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	// UID input for magic card operations
	uidLabel := canvas.NewText("UID (for magic card)", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	uidLabel.TextSize = 11
	uidEntry := widget.NewEntry()
	uidEntry.SetPlaceHolder("11223344")

	setUIDButton := newOutlinedButton("SET UID", func() {
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()
		uid := strings.TrimSpace(uidEntry.Text)
		if uid == "" {
			WriteStatusError("UID is required")
			return
		}
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}
			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)
			setMagicCardUID(uid)

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done
		}()
	})

	// Size all buttons consistently
	cardInfoButtonSized := container.NewStack(cardInfoButton)
	cardInfoButtonSized.Resize(fyne.NewSize(120, 30))
	checkKeysButtonSized := container.NewStack(checkKeysButton)
	checkKeysButtonSized.Resize(fyne.NewSize(120, 30))
	setUIDButtonSized := container.NewStack(setUIDButton)
	setUIDButtonSized.Resize(fyne.NewSize(120, 30))

	hotelButtonRow := container.NewGridWithColumns(2,
		recoverKeysButtonSized,
		sniffKeysButtonSized,
	)

	hotelAnalysisRow := container.NewGridWithColumns(2,
		cardInfoButtonSized,
		checkKeysButtonSized,
	)

	// CARD ANALYSIS section label
	cardAnalysisLabel := canvas.NewText("CARD ANALYSIS", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	cardAnalysisLabel.TextSize = 11

	hotelSectionContent := container.NewVBox(
		// CARD ANALYSIS section at top
		container.NewPadded(cardAnalysisLabel),
		container.NewPadded(hotelAnalysisRow),
		widget.NewSeparator(),
		// ATTACK METHOD dropdown
		container.NewPadded(attackMethodLabel),
		container.NewPadded(attackMethod),
		// DUMP FILE PATH and KEY FILE PATH directly under attack dropdown
		container.NewPadded(dumpFilePathLabel),
		container.NewPadded(dumpFilePathEntry),
		container.NewPadded(keyFilePathLabel),
		container.NewPadded(keyFilePathEntry),
		// START ATTACK and SNIFF KEYS buttons after file paths
		container.NewPadded(hotelButtonRow),
		// WRITE FROM DUMP button and checkbox below START and SNIFF
		container.NewPadded(wipeBeforeWrite),
		container.NewPadded(writeFromDumpButtonSized),
		widget.NewSeparator(),
		// UID (for magic card) at the bottom
		container.NewPadded(uidLabel),
		container.NewPadded(uidEntry),
		container.NewPadded(setUIDButtonSized),
	)

	// Detect Card button - runs lf search and hf search
	detectCardButton := newOutlinedButton("DETECT CARD TYPE", func() {
		// Clear output
		currentStatusOutput.Clear()
		currentCommandOutput.Clear()

		// Run in goroutine to keep UI responsive
		go func() {
			statusWriter := &guiWriter{output: currentStatusOutput, scroll: statusScroll}

			oldStdout := os.Stdout
			oldStderr := os.Stderr
			r, w, _ := os.Pipe()
			os.Stdout = w
			os.Stderr = w

			done := make(chan bool, 1)
			go func() {
				defer func() { done <- true }()
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
			}()

			SetStatusWriter(statusWriter)

			WriteStatusInfo("Detecting card type...")

			// Check Proxmark3 connection
			if ok, msg := checkProxmark3(); !ok {
				WriteStatusError(msg)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			WriteStatusSuccess("Proxmark3 connected")

			pm3Binary, err := getPm3Path()
			if err != nil {
				WriteStatusError("Failed to find pm3 binary: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			device, err := getPm3Device()
			if err != nil {
				WriteStatusError("Failed to detect pm3 device: %v", err)
				w.Close()
				os.Stdout.Sync()
				os.Stderr.Sync()
				os.Stdout = oldStdout
				os.Stderr = oldStderr
				<-done
				return
			}

			// Always check both LF and HF to detect dual chip cards
			var lfFound bool
			var hfFound bool
			var lfCardType string
			var hfCardType string

			// Try LF search
			WriteStatusProgress("Checking Low Frequency (LF)...")
			fmt.Println("lf search")
			fmt.Println()

			lfCmd := exec.Command(pm3Binary, "-c", "lf search", "-p", device)
			lfOutput, _ := lfCmd.CombinedOutput()
			lfOutputStr := string(lfOutput)
			// Filter out "Searching for..." lines and show only results
			filteredLFOutput := filterSearchOutput(lfOutputStr)
			if filteredLFOutput != "" {
				fmt.Println(filteredLFOutput)
			}

			// Check if LF search found something (look for specific positive indicators)
			// Positive indicators: "Valid ... ID found", "Valid ... tag found", "Chipset..."
			// Negative indicators: "No known 125/134 kHz tags found", "No data found!"
			lfFound = (strings.Contains(lfOutputStr, "Valid") &&
				(strings.Contains(lfOutputStr, "ID found") || strings.Contains(lfOutputStr, "tag found"))) ||
				strings.Contains(lfOutputStr, "Chipset...")

			// Exclude only if we have explicit negative results
			if lfFound && (strings.Contains(lfOutputStr, "No known 125/134 kHz tags found") ||
				strings.Contains(lfOutputStr, "No data found!")) {
				lfFound = false
			}

			// Extract specific LF card type if found (check in order of specificity)
			if lfFound {
				// Check for specific card types
				if strings.Contains(lfOutputStr, "EM410x") || strings.Contains(lfOutputStr, "EM 410x") {
					lfCardType = "EM4100 / Net2"
				} else if strings.Contains(lfOutputStr, "HID Prox") {
					lfCardType = "HID Prox"
				} else if strings.Contains(lfOutputStr, "AWID") {
					lfCardType = "AWID"
				} else if strings.Contains(lfOutputStr, "Indala") {
					lfCardType = "Indala"
				} else if strings.Contains(lfOutputStr, "FDX-B") {
					lfCardType = "FDX-B"
				} else if strings.Contains(lfOutputStr, "FDX-A") || strings.Contains(lfOutputStr, "Destron") {
					lfCardType = "FDX-A Destron"
				} else if strings.Contains(lfOutputStr, "NEDAP") {
					lfCardType = "NEDAP"
				} else if strings.Contains(lfOutputStr, "IO Prox") {
					lfCardType = "IO Prox"
				} else if strings.Contains(lfOutputStr, "Pyramid") {
					lfCardType = "Pyramid"
				} else if strings.Contains(lfOutputStr, "Paradox") {
					lfCardType = "Paradox"
				} else if strings.Contains(lfOutputStr, "Idteck") {
					lfCardType = "Idteck"
				} else if strings.Contains(lfOutputStr, "KERI") {
					lfCardType = "KERI"
				} else if strings.Contains(lfOutputStr, "NexWatch") {
					lfCardType = "NexWatch"
				} else if strings.Contains(lfOutputStr, "PAC") || strings.Contains(lfOutputStr, "Stanley") {
					lfCardType = "PAC/Stanley"
				} else if strings.Contains(lfOutputStr, "Guardall") || strings.Contains(lfOutputStr, "G-Prox") {
					lfCardType = "Guardall G-Prox II"
				} else if strings.Contains(lfOutputStr, "Jablotron") {
					lfCardType = "Jablotron"
				} else if strings.Contains(lfOutputStr, "Viking") {
					lfCardType = "Viking"
				} else if strings.Contains(lfOutputStr, "Visa2000") {
					lfCardType = "Visa2000"
				} else if strings.Contains(lfOutputStr, "Presco") {
					lfCardType = "Presco"
				} else if strings.Contains(lfOutputStr, "Securakey") {
					lfCardType = "Securakey"
				} else if strings.Contains(lfOutputStr, "Noralsy") {
					lfCardType = "Noralsy"
				} else if strings.Contains(lfOutputStr, "Motorola") || strings.Contains(lfOutputStr, "FlexPass") {
					lfCardType = "Motorola FlexPass"
				} else if strings.Contains(lfOutputStr, "COTAG") {
					lfCardType = "COTAG"
				} else if strings.Contains(lfOutputStr, "EM4x50") {
					lfCardType = "EM4x50"
				} else if strings.Contains(lfOutputStr, "EM4x05") || strings.Contains(lfOutputStr, "EM4x69") {
					lfCardType = "EM4x05/EM4x69"
				} else if strings.Contains(lfOutputStr, "EM4x70") {
					lfCardType = "EM4x70"
				} else if strings.Contains(lfOutputStr, "Paxton") {
					lfCardType = "Paxton"
				} else if strings.Contains(lfOutputStr, "Hitag") {
					lfCardType = "Hitag"
				} else if strings.Contains(lfOutputStr, "Gallagher") {
					lfCardType = "Gallagher (LF)"
				} else if strings.Contains(lfOutputStr, "T55xx") {
					lfCardType = "T55xx"
				} else {
					lfCardType = "LF"
				}
			}

			// Always try HF search (for dual chip detection)
			WriteStatusProgress("Checking High Frequency (HF)...")
			fmt.Println()
			fmt.Println("hf search")
			fmt.Println()

			hfCmd := exec.Command(pm3Binary, "-c", "hf search", "-p", device)
			hfOutput, hfErr := hfCmd.CombinedOutput()
			hfOutputStr := string(hfOutput)
			// Filter out "Searching for..." lines and show only results
			filteredHFOutput := filterSearchOutput(hfOutputStr)
			if filteredHFOutput != "" {
				fmt.Println(filteredHFOutput)
			}

			// Extract magic capabilities and PRNG info for MIFARE cards
			var magicCapabilities []string
			var prngInfo string
			var specificMifareType string

			// Look for specific MIFARE type from "Possible types:" line
			// Pattern: "[+] Possible types: MIFARE Classic 1K"
			mifareTypeRegex := regexp.MustCompile(`(?i)Possible types:\s*MIFARE\s+(Classic\s+)?(\d+K|Mini|Plus|Ultralight|DESFire|NTAG[^\n]*)`)
			mifareTypeMatch := mifareTypeRegex.FindStringSubmatch(hfOutputStr)
			if len(mifareTypeMatch) > 0 {
				if strings.Contains(mifareTypeMatch[0], "Classic") {
					specificMifareType = "MIFARE Classic " + strings.TrimSpace(mifareTypeMatch[2])
				} else {
					specificMifareType = "MIFARE " + strings.TrimSpace(mifareTypeMatch[2])
				}
			}

			// Also check for "MIFARE Classic 1K" or "MIFARE Classic 4K" directly in the output
			if specificMifareType == "" {
				mifareDirectRegex := regexp.MustCompile(`(?i)MIFARE\s+Classic\s+(\d+K)`)
				mifareDirectMatch := mifareDirectRegex.FindStringSubmatch(hfOutputStr)
				if len(mifareDirectMatch) > 0 {
					specificMifareType = "MIFARE Classic " + mifareDirectMatch[1]
				}
			}

			// Look for magic capabilities
			magicRegex := regexp.MustCompile(`(?i)Magic capabilities\.\.\.\s+([^\n]+)`)
			magicMatches := magicRegex.FindAllStringSubmatch(hfOutputStr, -1)
			for _, match := range magicMatches {
				if len(match) > 1 {
					magicCapabilities = append(magicCapabilities, strings.TrimSpace(match[1]))
				}
			}

			// Look for PRNG detection
			prngRegex := regexp.MustCompile(`(?i)Prng detection\.\.\.\.\s+([^\n]+)`)
			prngMatch := prngRegex.FindStringSubmatch(hfOutputStr)
			if len(prngMatch) > 1 {
				prngInfo = strings.TrimSpace(prngMatch[1])
			}

			// Check if HF search found something and identify specific card type
			// MUST check for actual "Valid ... found" or "detected" messages, NOT search messages
			// Exclude negative results first
			hasNegativeResult := strings.Contains(hfOutputStr, "No known/supported 13.56 MHz tags found") ||
				(strings.Contains(hfOutputStr, "No known") && strings.Contains(hfOutputStr, "tags found"))

			if hasNegativeResult {
				hfFound = false
			} else {
				// Check for specific card types with their actual detection messages
				// Order matters - check more specific types first

				// MIFARE Classic - check for "Possible types: MIFARE Classic 1K" or "MIFARE Classic detected"
				if strings.Contains(hfOutputStr, "MIFARE Classic") &&
					(strings.Contains(hfOutputStr, "Possible types") || strings.Contains(hfOutputStr, "detected") ||
						strings.Contains(hfOutputStr, "Valid ISO 14443-A")) {
					hfFound = true
					if specificMifareType != "" {
						hfCardType = specificMifareType
					} else {
						hfCardType = "MIFARE Classic"
					}
				} else if strings.Contains(hfOutputStr, "MIFARE Plus") && strings.Contains(hfOutputStr, "detected") {
					hfFound = true
					hfCardType = "MIFARE Plus"
				} else if strings.Contains(hfOutputStr, "MIFARE DESFire") && strings.Contains(hfOutputStr, "detected") {
					hfFound = true
					hfCardType = "MIFARE DESFire"
				} else if strings.Contains(hfOutputStr, "MIFARE Ultralight") && strings.Contains(hfOutputStr, "detected") {
					hfFound = true
					hfCardType = "MIFARE Ultralight / NTAG"
				} else if strings.Contains(hfOutputStr, "NTAG 424") || strings.Contains(hfOutputStr, "NTAG424") {
					hfFound = true
					hfCardType = "NTAG 424 DNA"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "iCLASS tag / PicoPass tag") && strings.Contains(hfOutputStr, "found") {
					// Must have "Valid ... iCLASS tag / PicoPass tag ... found"
					hfFound = true
					hfCardType = "iCLASS / PicoPass"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "LEGIC Prime tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "LEGIC Prime"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "Topaz tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "Topaz (NFC Type 1)"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "LTO-CM tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "LTO-CM"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "TEXKOM tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "TEXKOM"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "Fuji/Xerox tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "Fuji/Xerox"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "ISO 14443-B tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "ISO 14443-B"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "ISO 15693 tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "ISO 15693"
				} else if strings.Contains(hfOutputStr, "Valid") && strings.Contains(hfOutputStr, "ISO 18092 / FeliCa tag") && strings.Contains(hfOutputStr, "found") {
					hfFound = true
					hfCardType = "ISO 18092 / FeliCa"
				} else if strings.Contains(hfOutputStr, "Valid ISO 14443-A tag found") {
					hfFound = true
					hfCardType = "ISO 14443-A"
				} else if strings.Contains(hfOutputStr, "UID:") && strings.Contains(hfOutputStr, "ATQA:") && strings.Contains(hfOutputStr, "SAK:") {
					// ISO14443-A info present (UID, ATQA, SAK) - this is a valid detection
					hfFound = true
					hfCardType = "ISO 14443-A"
				}
			}

			// Report findings
			if lfFound && hfFound {
				// Dual chip card detected
				WriteStatusSuccess("DUAL CHIP CARD DETECTED!")
				WriteStatusInfo("LF Chip: %s", lfCardType)
				WriteStatusInfo("HF Chip: %s", hfCardType)
				WriteStatusInfo("This card contains both Low Frequency and High Frequency chips")

				// Show specific MIFARE type if available
				if specificMifareType != "" && strings.Contains(hfCardType, "MIFARE") {
					WriteStatusInfo("MIFARE Type: %s", specificMifareType)
				}

				// Show magic capabilities if detected
				if len(magicCapabilities) > 0 {
					WriteStatusInfo("Magic Capabilities: %s", strings.Join(magicCapabilities, ", "))
				}
				if prngInfo != "" {
					WriteStatusInfo("PRNG Detection: %s", prngInfo)
				}

				// If MIFARE Classic detected, run hf mf info for more details
				if strings.Contains(hfCardType, "MIFARE Classic") {
					WriteStatusProgress("Getting detailed MIFARE information...")
					fmt.Println()
					fmt.Println("hf mf info")
					fmt.Println()

					infoCmd := exec.Command(pm3Binary, "-c", "hf mf info", "-p", device)
					infoOutput, infoErr := infoCmd.CombinedOutput()
					infoOutputStr := string(infoOutput)
					if infoErr == nil && infoOutputStr != "" {
						fmt.Println(infoOutputStr)

						// Extract additional details from hf mf info
						// Extract UID
						uidRegex1 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{2}(?:\s+[A-F0-9]{2})+)`)
						if uidMatch := uidRegex1.FindStringSubmatch(infoOutputStr); len(uidMatch) > 1 {
							uid := strings.ReplaceAll(uidMatch[1], " ", "")
							WriteStatusInfo("UID: %s", uid)
						} else {
							uidRegex2 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{8,14})`)
							if uidMatch := uidRegex2.FindStringSubmatch(infoOutputStr); len(uidMatch) > 1 {
								WriteStatusInfo("UID: %s", uidMatch[1])
							}
						}

						// Check for Saflok
						if strings.Contains(infoOutputStr, "Saflok") {
							WriteStatusInfo("Detected: Saflok hotel key card")
						}
					}
				}
			} else if lfFound {
				WriteStatusSuccess("✓ %s card detected (LF only)", lfCardType)
			} else if hfFound {
				WriteStatusSuccess("✓ %s card detected (HF only)", hfCardType)

				// Show specific MIFARE type if available
				if specificMifareType != "" && strings.Contains(hfCardType, "MIFARE") {
					WriteStatusInfo("MIFARE Type: %s", specificMifareType)
				}

				// Show magic capabilities if detected
				if len(magicCapabilities) > 0 {
					WriteStatusInfo("Magic Capabilities: %s", strings.Join(magicCapabilities, ", "))
				}
				if prngInfo != "" {
					WriteStatusInfo("PRNG Detection: %s", prngInfo)
				}

				// If MIFARE Classic detected, run hf mf info for more details
				if strings.Contains(hfCardType, "MIFARE Classic") {
					WriteStatusProgress("Getting detailed MIFARE information...")
					fmt.Println()
					fmt.Println("hf mf info")
					fmt.Println()

					infoCmd := exec.Command(pm3Binary, "-c", "hf mf info", "-p", device)
					infoOutput, infoErr := infoCmd.CombinedOutput()
					infoOutputStr := string(infoOutput)
					if infoErr == nil && infoOutputStr != "" {
						fmt.Println(infoOutputStr)

						// Extract additional details from hf mf info
						// Extract UID
						uidRegex1 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{2}(?:\s+[A-F0-9]{2})+)`)
						if uidMatch := uidRegex1.FindStringSubmatch(infoOutputStr); len(uidMatch) > 1 {
							uid := strings.ReplaceAll(uidMatch[1], " ", "")
							WriteStatusInfo("UID: %s", uid)
						} else {
							uidRegex2 := regexp.MustCompile(`UID\s*:\s*([A-F0-9]{8,14})`)
							if uidMatch := uidRegex2.FindStringSubmatch(infoOutputStr); len(uidMatch) > 1 {
								WriteStatusInfo("UID: %s", uidMatch[1])
							}
						}

						// Check for Saflok
						if strings.Contains(infoOutputStr, "Saflok") {
							WriteStatusInfo("Detected: Saflok hotel key card")
						}
					}
				}
			} else if hfErr != nil {
				WriteStatusError("HF detection failed: %v", hfErr)
			} else {
				WriteStatusInfo("No card detected. Make sure card is placed on reader.")
			}

			w.Close()
			os.Stdout.Sync()
			os.Stderr.Sync()
			os.Stdout = oldStdout
			os.Stderr = oldStderr
			<-done

			WriteStatusSuccess("Card detection completed")
		}()
	})

	// Size the detect button to match other buttons
	detectCardButtonSized := container.NewStack(detectCardButton)
	detectCardButtonSized.Resize(fyne.NewSize(120, 30))

	// Card Discovery section - only DETECT CARD TYPE
	cardDiscoverySectionContent := container.NewVBox(
		container.NewPadded(detectCardButtonSized),
	)

	// Create accordion for collapsible sections
	accordion := widget.NewAccordion(
		widget.NewAccordionItem("Card Discovery", cardDiscoverySectionContent),
		widget.NewAccordionItem("Corporate Access Control Cards", corporateSectionContent),
		widget.NewAccordionItem("Hotel / Residence Access Control", hotelSectionContent),
	)
	// Start with Corporate expanded, Hotel collapsed, Card Discovery collapsed
	accordion.Items[0].Open = false // Card Discovery collapsed
	accordion.Items[1].Open = true  // Corporate expanded
	accordion.Items[2].Open = false // Hotel collapsed

	// Make accordion mutually exclusive using a periodic check
	// Fyne's Accordion doesn't have OnChanged, so we monitor state changes
	var lastOpenState []bool
	for range accordion.Items {
		lastOpenState = append(lastOpenState, false)
	}
	lastOpenState[1] = true // Corporate starts open

	go func() {
		for {
			time.Sleep(50 * time.Millisecond)
			for i, item := range accordion.Items {
				if item.Open {
					if !lastOpenState[i] {
						// This item just opened, close others
						fyne.Do(func() {
							for j, otherItem := range accordion.Items {
								if j != i {
									otherItem.Open = false
									lastOpenState[j] = false
								}
							}
							lastOpenState[i] = true
							accordion.Refresh()
						})
						break
					}
				} else {
					lastOpenState[i] = false
				}
			}
		}
	}()

	leftColumnContent := container.NewVBox(
		header,
		widget.NewSeparator(),
		container.NewPadded(accordion),
		layout.NewSpacer(),
		container.NewPadded(versionText),
	)

	outputHeader := container.NewHBox(
		container.NewPadded(outputLabel),
		layout.NewSpacer(),
		container.NewPadded(launchPm3Button),
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

	// Add keyboard shortcut: Enter key triggers Execute (global)
	w.Canvas().AddShortcut(&desktop.CustomShortcut{KeyName: fyne.KeyEnter, Modifier: 0}, func(shortcut fyne.Shortcut) {
		executeCommand()
	})

	// Also handle Enter key in entry fields
	onEnterKey := func() {
		executeCommand()
	}
	facilityCode.OnSubmitted = func(s string) { onEnterKey() }
	cardNumber.OnSubmitted = func(s string) { onEnterKey() }
	hexData.OnSubmitted = func(s string) { onEnterKey() }
	uid.OnSubmitted = func(s string) { onEnterKey() }

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

// findLatestDumpFile finds the most recently modified dump file matching the pattern
func findLatestDumpFile() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	// Search in home directory and common locations
	searchDirs := []string{
		homeDir,
		filepath.Join(homeDir, ".proxmark3"),
		".",
	}

	var latestFile string
	var latestTime time.Time

	for _, dir := range searchDirs {
		// Try multiple patterns to catch all dump files
		patterns := []string{
			"hf-mf-*-dump-*.bin",
			"hf-mf-*-dump-*.eml",
			"*-dump-*.bin",
			"*-dump-*.eml",
		}

		for _, pattern := range patterns {
			matches, err := filepath.Glob(filepath.Join(dir, pattern))
			if err != nil {
				continue
			}

			for _, match := range matches {
				info, err := os.Stat(match)
				if err != nil {
					continue
				}
				// Only consider files that actually exist
				if !info.Mode().IsRegular() {
					continue
				}
				if info.ModTime().After(latestTime) {
					latestTime = info.ModTime()
					latestFile = match
				}
			}
		}
	}

	return latestFile
}

// findLatestKeyFile finds the most recently modified key file matching the pattern
func findLatestKeyFile() string {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return ""
	}

	// Search in home directory and common locations
	searchDirs := []string{
		homeDir,
		filepath.Join(homeDir, ".proxmark3"),
		".",
	}

	var latestFile string
	var latestTime time.Time

	for _, dir := range searchDirs {
		matches, err := filepath.Glob(filepath.Join(dir, "hf-mf-*-key.bin"))
		if err != nil {
			continue
		}

		for _, match := range matches {
			info, err := os.Stat(match)
			if err != nil {
				continue
			}
			if info.ModTime().After(latestTime) {
				latestTime = info.ModTime()
				latestFile = match
			}
		}
	}

	return latestFile
}
