package main

import (
	"fmt"
	"image/color"
	"os"
	"os/exec"
	"strings"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/driver/desktop"
	"fyne.io/fyne/v2/layout"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	"github.com/creack/pty"
	"github.com/fyne-io/terminal"
)

// Fixed width layout
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

// Custom outlined button
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
	// Background with semi-transparent orange
	b.bg = canvas.NewRectangle(color.RGBA{R: 226, G: 88, B: 34, A: 20})
	b.bg.CornerRadius = 5

	// Border rectangle - orange outline
	b.border = canvas.NewRectangle(color.RGBA{R: 0, G: 0, B: 0, A: 0}) // Transparent fill
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

	// Position label in center
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

// Doppelgänger Arrow Dark Theme
type arrowDarkTheme struct{}

func (t *arrowDarkTheme) Color(name fyne.ThemeColorName, variant fyne.ThemeVariant) color.Color {
	switch name {
	case theme.ColorNameBackground:
		return color.RGBA{R: 12, G: 14, B: 16, A: 255} // #0c0e10
	case theme.ColorNameButton:
		return color.RGBA{R: 226, G: 88, B: 34, A: 255} // #e25822
	case theme.ColorNameDisabledButton:
		return color.RGBA{R: 100, G: 100, B: 100, A: 255}
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

	// Suppress Fyne thread checking warnings from terminal library
	// The fyne-io/terminal library updates UI from background threads,
	// which is safe in this context but triggers warnings
	os.Setenv("FYNE_DISABLE_CALL_CHECKING", "1")

	a := app.New()
	w := a.NewWindow("Doppelgänger Assistant")

	a.Settings().SetTheme(&arrowDarkTheme{})

	w.Resize(fyne.NewSize(1400, 800))
	w.CenterOnScreen()

	// Load bundled logo
	logo := canvas.NewImageFromResource(resourceDoppelgangerdmPng)
	logo.FillMode = canvas.ImageFillContain
	logo.SetMinSize(fyne.NewSize(200, 50))

	// Header with logo
	header := container.NewVBox(
		container.NewCenter(logo),
	)

	// Card Type selector
	cardTypeLabel := canvas.NewText("CARD TYPE", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	cardTypeLabel.TextSize = 11
	cardTypes := []string{"PROX", "iCLASS", "AWID", "Indala", "Avigilon", "EM4100", "PIV", "MIFARE"}
	cardType := widget.NewSelect(cardTypes, nil)

	// Bit Length selector
	bitLengthLabel := canvas.NewText("BIT LENGTH", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	bitLengthLabel.TextSize = 11
	bitLength := widget.NewSelect([]string{}, nil)

	// Input fields
	facilityCode := widget.NewEntry()
	facilityCode.SetPlaceHolder("Facility Code")
	cardNumber := widget.NewEntry()
	cardNumber.SetPlaceHolder("Card Number")
	hexData := widget.NewEntry()
	hexData.SetPlaceHolder("Hex Data")
	uid := widget.NewEntry()
	uid.SetPlaceHolder("UID")

	// Data blocks container
	dataBlocks := container.NewVBox()

	// Action selector (defined early so it can be used in updateDataBlocks)
	actionLabel := canvas.NewText("ACTION", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	actionLabel.TextSize = 11
	action := widget.NewSelect([]string{"Generate Command", "Write & Verify", "Simulate Card"}, nil)

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
		// Reset to first option to avoid selecting an option that no longer exists
		action.SetSelectedIndex(0)
		action.Refresh()

		dataBlocks.Refresh()
	}

	cardType.OnChanged = updateDataBlocks

	// Create terminal widget
	term := terminal.New()
	var currentTerm *terminal.Terminal = term

	// Execute command function
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

		// Build command arguments
		var args []string
		args = append(args, "-t", cardTypeCmd)

		switch cardTypeCmd {
		case "prox", "iclass", "awid", "indala", "avigilon":
			if facilityCodeValue == "" || cardNumberValue == "" {
				currentTerm.Write([]byte("Error: Facility Code and Card Number are required\n"))
				return
			}
			args = append(args, "-bl", bitLengthValue, "-fc", facilityCodeValue, "-cn", cardNumberValue)
		case "em":
			if hexDataValue == "" {
				currentTerm.Write([]byte("Error: Hex Data is required\n"))
				return
			}
			args = append(args, "--hex", hexDataValue)
		case "mifare", "piv":
			if uidValue == "" {
				currentTerm.Write([]byte("Error: UID is required\n"))
				return
			}
			args = append(args, "--uid", uidValue)
		}

		// Add action flags
		switch actionValue {
		case "Write & Verify":
			args = append(args, "-w", "-v")
		case "Simulate Card":
			args = append(args, "-s")
		}

		// Run command with PTY in terminal
		go func() {
			// Recover from any panics in the terminal widget
			defer func() {
				if r := recover(); r != nil {
					errMsg := fmt.Sprintf("\n\n[Terminal Error] The terminal widget encountered an error: %v\nThe command may have completed successfully. Check your Proxmark3 device.\n", r)
					// Try to write error to terminal if possible
					defer func() { recover() }() // Catch any panic from this write too
					currentTerm.Write([]byte(errMsg))
				}
			}()

			// Get the path of the currently running executable
			execPath, err := os.Executable()
			if err != nil {
				errMsg := fmt.Sprintf("Error getting executable path: %v\n", err)
				currentTerm.Write([]byte(errMsg))
				return
			}

			cmd := exec.Command(execPath, args...)

			// Start the command with a pty
			ptmx, err := pty.Start(cmd)
			if err != nil {
				errMsg := fmt.Sprintf("Error starting command: %v\n", err)
				currentTerm.Write([]byte(errMsg))
				return
			}
			defer ptmx.Close()

			// Connect the PTY to the terminal
			currentTerm.RunWithConnection(ptmx, ptmx)

			// Wait for command to complete
			cmd.Wait()
		}()
	}

	// Custom outlined buttons
	submit := newOutlinedButton("EXECUTE", executeCommand)
	reset := newOutlinedButton("RESET", func() {
		cardType.SetSelectedIndex(0)
		bitLength.SetSelectedIndex(0)
		facilityCode.SetText("")
		cardNumber.SetText("")
		hexData.SetText("")
		uid.SetText("")
		action.SetSelectedIndex(0)
		updateDataBlocks(cardTypes[0])
	})

	// Right column - Terminal with clear button
	terminalLabel := canvas.NewText("TERMINAL OUTPUT", color.RGBA{R: 169, G: 182, B: 201, A: 255})
	terminalLabel.TextSize = 11

	// Terminal container that we can update
	terminalContainer := container.NewMax(term)

	// Copy terminal output - Note: Terminal widget doesn't support programmatic content access
	// Users can manually select text in the terminal and use Cmd+C/Ctrl+C to copy

	clearTerminal := newOutlinedButton("CLEAR TERMINAL", func() {
		// Recover from any crashes during terminal clear
		defer func() {
			if r := recover(); r != nil {
				// Silently recover - terminal may be in bad state
			}
		}()

		// Stop any running process and clear terminal
		if currentTerm != nil {
			currentTerm.Exit()
		}
		// Create a fresh terminal instance
		newTerm := terminal.New()
		currentTerm = newTerm
		// Replace the terminal in the container
		terminalContainer.Objects = []fyne.CanvasObject{newTerm}
		terminalContainer.Refresh()
	})

	// Make buttons less tall by constraining their size
	submitSized := container.NewStack(submit)
	submitSized.Resize(fyne.NewSize(100, 30))

	resetSized := container.NewStack(reset)
	resetSized.Resize(fyne.NewSize(80, 30))

	buttonRow := container.NewHBox(
		layout.NewSpacer(),
		submitSized,
		resetSized,
	)

	// Version text at bottom
	versionText := canvas.NewText("v"+Version, color.RGBA{R: 169, G: 182, B: 201, A: 128})
	versionText.TextSize = 11
	versionText.Alignment = fyne.TextAlignCenter

	// Left column - Input form with fixed width
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

	// Terminal header with clear button
	terminalHeader := container.NewBorder(
		nil, nil,
		container.NewPadded(terminalLabel),
		container.NewPadded(clearTerminal),
	)

	// Add dark grey background with orange border to terminal area
	terminalBg := canvas.NewRectangle(color.RGBA{R: 24, G: 26, B: 27, A: 255})
	terminalBg.CornerRadius = 8

	// Orange border - subtle
	terminalBorder := canvas.NewRectangle(color.RGBA{R: 0, G: 0, B: 0, A: 0}) // Transparent fill
	terminalBorder.StrokeColor = color.RGBA{R: 226, G: 88, B: 34, A: 80}      // Orange with lower opacity
	terminalBorder.StrokeWidth = 1
	terminalBorder.CornerRadius = 8

	terminalWithBg := container.NewStack(
		terminalBorder,
		terminalBg,
		container.NewPadded(terminalContainer),
	)

	rightColumn := container.NewBorder(
		terminalHeader,
		nil, nil, nil,
		terminalWithBg,
	)

	// Main content with two columns - left side fixed width, not resizable
	// Create a fixed-width wrapper using a custom container
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

	// Initialize after content is set (so widgets have window context)
	cardType.SetSelectedIndex(0)
	action.SetSelectedIndex(0)
	updateDataBlocks(cardTypes[0])

	w.ShowAndRun()
}

// Helper function to join args with proper spacing
func joinArgs(args []string) string {
	result := ""
	for i, arg := range args {
		if i > 0 {
			result += " "
		}
		// Quote args with spaces
		if len(arg) > 0 && (arg[0] == '-' || arg == strings.TrimSpace(arg)) {
			result += arg
		} else {
			result += fmt.Sprintf("\"%s\"", arg)
		}
	}
	return result
}
