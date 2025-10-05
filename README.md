# Doppelgänger Assistant

A professional GUI application for calculating card data and automating Proxmark3 operations for every card type that Doppelgänger Core and Stealth support. This tool streamlines the card-writing process for physical penetration testing by providing an intuitive interface with dual output displays, visual separators, and one-click clipboard copying, eliminating the need to memorize complex Proxmark3 syntax or dig through notes.

![Doppelgänger Assistant GUI](https://github.com/tweathers-sec/doppelganger_assistant/blob/main/img/assistant_gui.png)

## Features

* **Modern GUI Interface**: Intuitive two-column layout with dedicated status and command output displays
* **Card Operations**: Automatically generates and executes Proxmark3 commands for writing, verifying, and simulating cards
* **Direct Execution**: Execute write, verify, and simulate operations directly from the GUI with your Proxmark3
* **Cross-Platform**: Available for macOS, Linux, and Windows (via WSL)

## Doppelgänger Devices

You can purchase a Stealth reader, Doppelgänger Dev Board, or fully assembled long-range readers from the [Physical Exploitation Store](https://store.physicalexploit.com/). For the open-source firmware, check out [Doppelgänger Core](https://github.com/mwgroup-io/Doppelganger_Core).

## Officially Supported Card Types

Below are the officially supported card types based on Doppelgänger firmware:

| Card Types                  | Core | Stealth | Notes                         |
| --------------------------- | ---- | ------- | ----------------------------- |
| Keypad PIN Codes            |      | X       |                               |
| HID H10301 26-bit           | X    | X       |                               |
| Indala 26-bit               | X    | X       | Requires Indala reader/module |
| Indala 27-bit               | X    | X       | Requires Indala reader/module |
| 2804 WIEGAND 28-bit         | X    | X       |                               |
| Indala 29-bit               | X    | X       | Requires Indala reader/module |
| ATS Wiegand 30-bit          | X    | X       |                               |
| HID ADT 31-Bit              | X    | X       |                               |
| EM4102 / Wiegand 32-bit     | X    | X       |                               |
| HID D10202 33-bit           | X    | X       |                               |
| HID H10306 34-bit           | X    | X       |                               |
| HID Corporate 1000 35-bit   | X    | X       |                               |
| HID Simplex 36-bit (S12906) | X    | X       |                               |
| HID H10304 37-bit           | X    | X       |                               |
| HID H800002 46-bit          | X    | X       |                               |
| HID Corporate 1000 48-bit   | X    | X       |                               |
| Avigilon 56-bit             | X    | X       |                               |
| C910 PIVKey                 | X    | X       |                               |
| MIFARE (Various Types)      | X    | X       | UID Only                      |

Supported technologies include:

* iCLASS(Legacy/SE/Seos) *Note: Captured SE and Seos cards can only be written to iCLASS 2k cards*
* PROX
* Indala
* AWID
* Avigilon
* EM4102
* PIV (UID Only - As that is what is provided via the readers wiegand output)
* MIFARE (UID Only - As that is what is provided via the readers wiegand output)

## Installation

#### Manual Installation

1) Grab your desired package from the [release page](https://github.com/tweathers-sec/doppelganger_assistant/releases).
2) Ensure that you have the [Iceman fork of the Proxmark3](https://github.com/RfidResearchGroup/proxmark3?tab=readme-ov-file#proxmark3-installation-and-overview) software installed.
3) Install dependencies, if required (WSL).

#### Automated Installation

Alternatively, you can use one of the one-liners below to install on [Linux](https://github.com/tweathers-sec/doppelganger_assistant?tab=readme-ov-file#automated-linux-installation-recommend) and [Windows (WSL)](https://github.com/tweathers-sec/doppelganger_assistant?tab=readme-ov-file#installation-windows-wsl). These one-liners will install Doppelganger Assistant, any required dependencies, and the latest fork of the (Iceman) Proxmark3 software.

### Installation MacOS

#### Automated MacOS Installation (RECOMMENDED)

Run the following command in the terminal:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/installers/doppelganger_install_macos.sh)"
```

#### Manual MacOS Installation

Run the following command inside your preferred terminal application:

```bash
curl -sSL https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/installers/doppelganger_install_macos.sh | sudo bash
```

#### Alternative MacOS Installation

Download the application (.app) from the [release page](https://github.com/tweathers-sec/doppelganger_assistant/releases) and place it in the `/Applications` directory. You can create a symbolic link to run the application from the terminal or you create an alias in your shell profile.

```sh
Only choose one of the following options...

# Symbolic Link
sudo ln -s /Applications/doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant /usr/local/bin/doppelganger_assistant

# Profile Alias
alias doppelganger_assistant='/Applications/doppelganger_assistant.app/Contents/MacOS/doppelganger_assistant'
```

If you encounter an error stating that the **"doppelganger_assistant.app" is damaged and can't be opened. You should move it to the Trash.** Run the following command in the directory where the doppelganger assistant resides.

```sh
xattr -cr /Applications/doppelganger_assistant.app
```

### Installation Linux

#### Automated Linux Installation (RECOMMEND)

Run the following command inside your preferred terminal application:

```bash
curl -sSL https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/installers/doppelganger_install_linux.sh | sudo bash
```

#### Manual Linux Installation

Install Doppelganger Assistant Dependencies. *Note that this step should only be required if you encounter errors that prevent the deployment of doppelganger_assistant.*

```sh
sudo apt update 
sudo apt upgrade
sudo apt install libgl1 xterm git
```

Grab the Doppelganger Assistant and install it:

```sh
sudo apt install make
wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_{amd64/arm64}.tar.xz
tar xvf doppelganger_assistant_*
cd doppelganger_assistant
sudo make install

# Cleanup the directory, if desired
rm -rf usr/
rm doppelganger_assistant*
rm Makefile
```

To launch the Doppelganger Assistant GUI:

```sh
doppelganger_assistant
```

### Installation Windows (WSL)

#### Automated Installation of Doppelganger Assistant (RECOMMENDED)

This process will install WSL, Doppelganger Assistant, Proxmark3 software, and create a desktop shortcut.

Open **PowerShell as Administrator** and run:

```powershell
irm https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/installers/doppelganger_install_windows.ps1 | iex
```

**Note:** The installer will automatically clean up any previous installation attempts. If a reboot is required to enable WSL features, you'll be prompted. Simply run the same command again after rebooting.

**For nested VMs (Proxmox, Parallels, VMware, etc.):** Ensure nested virtualization is enabled in your hypervisor settings before running the installer.

#### Manual WSL Installation

If needed, create an Ubuntu WSL environment. From cmd.exe run:

```sh
wsl --install -d Ubuntu
```

Reboot Windows. When Windows starts up, WSL will finish setting up. When prompted, enter the Username and Password for your Ubuntu system.

Install Doppelganger Assistant Dependencies:

```sh
sudo apt update 
sudo apt upgrade
sudo apt install libgl1 xterm make git
```

Grab the Doppelganger Assistant and install it:

```sh
wget https://github.com/tweathers-sec/doppelganger_assistant/releases/latest/download/doppelganger_assistant_linux_{amd64/arm64}.tar.xz
tar xvf doppelganger_assistant_*
cd doppelganger_assistant
sudo make install

# Cleanup the directory, if desired
rm -rf usr/
rm doppelganger_assistant*
rm Makefile
```

To launch the Doppelganger Assistant GUI:

```sh
doppelganger_assistant
```

Install Proxmark3 Dependencies:

```sh
sudo apt install --no-install-recommends git ca-certificates build-essential pkg-config \
libreadline-dev gcc-arm-none-eabi libnewlib-dev qtbase5-dev \
libbz2-dev liblz4-dev libbluetooth-dev libpython3-dev libssl-dev libgd-dev
```

Clone the Proxmark3 Repo:

```sh
git clone https://github.com/RfidResearchGroup/proxmark3.git
cd proxmark3
```

If desired, modify the Makefile to support the Blueshark Device

```sh
cp Makefile.platform.sample Makefile.platform

#uncomment #PLATFORM_EXTRAS=BTADDON
nano Makefile.platform
```

Compile and Install Proxmark3 software

```sh
make clean && make -j
make install
```

Install USBipd to passthrough the Proxmark3 device to WSL. From cmd.exe run:

```sh
winget install --interactive --exact dorssel.usbipd-win
```

To Connect the Proxmark3 device to WSL. Open cmd.exe as an **Administrator** and run:

```sh
usbipd list // This will list the usb devices attach to your computer
usbipd bind --busid 9-1 // {9-1 Should be your Proxmark3's ID}
usbipd attach --wsl --busid 9-1 // {9-1 Should be your Proxmark3's ID}
```

## Uninstallation

### Uninstalling from Windows (WSL)

#### Automated Uninstall (Recommended)

Download and run the uninstaller directly from GitHub:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/tweathers-sec/doppelganger_assistant/main/scripts/uninstall.ps1 | iex"
```

#### Manual Uninstall

If you have Doppelganger Assistant installed, run the uninstall script:

```powershell
powershell -ExecutionPolicy Bypass -File C:\doppelganger_assistant\uninstall.ps1
```

The uninstaller will:
- Stop and unregister WSL distributions (Kali-doppelganger_assistant or Ubuntu-doppelganger_assistant)
- Remove all files from `C:\doppelganger_assistant`
- Delete the desktop shortcut
- Optionally uninstall usbipd

**Note:** The script automatically relocates itself to a temporary directory to ensure clean removal of the installation directory.

### Uninstalling from macOS

To uninstall from macOS:

```bash
sudo rm -rf /Applications/doppelganger_assistant.app
sudo rm /usr/local/bin/doppelganger_assistant
```

### Uninstalling from Linux

To uninstall from Linux:

```bash
sudo rm /usr/local/bin/doppelganger_assistant
sudo rm /usr/share/applications/doppelganger_assistant.desktop
sudo rm /usr/share/pixmaps/doppelganger_assistant.png
```

## Development

### Building from Source

To build Doppelganger Assistant from source:

```bash
# Clone the repository
git clone https://github.com/tweathers-sec/doppelganger_assistant.git
cd doppelganger_assistant

# Build for current platform
./build.sh

# Build for all platforms (requires Docker)
./build_all.sh
```

### Project Structure

- **`src/`** - Contains all Go source code and module files
- **`installers/`** - Platform-specific installation scripts
- **`scripts/`** - Utility scripts for WSL and Windows setup
- **`build.sh`** - Single-platform build script
- **`build_all.sh`** - Multi-platform build script using fyne-cross

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes in the `src/` directory
4. Test your changes with `./build.sh`
5. Submit a pull request

## Usage

### Launching the GUI

The Doppelgänger Assistant GUI launches by default when you run the application:

```sh
doppelganger_assistant
```

Or explicitly launch in GUI mode:

```sh
doppelganger_assistant -g
```

### GUI Workflow

1. **Select Card Type**: Choose from PROX, iCLASS, AWID, Indala, Avigilon, EM4100, PIV, or MIFARE
2. **Choose Bit Length**: Select the appropriate bit length for your card type (automatically filtered based on card type)
3. **Enter Card Data**: Input facility code, card number, hex data, or UID as required for the selected card type
4. **Choose Action**:
   - **Generate Only**: Displays Proxmark3 commands for manual execution without writing
   - **Write & Verify**: Writes card data to a blank card and verifies the result
   - **Simulate Card**: Simulates the card using your Proxmark3 device
5. **Execute**: Click the EXECUTE button to run the operation
6. **Monitor Output**: 
   - **Status Output** (top panel): Color-coded status messages with operation progress
   - **Command Output** (bottom panel): Detailed Proxmark3 command results with visual separators
7. **Copy Results**: Click COPY OUTPUT to copy all command results to your clipboard
8. **Reset**: Click RESET to clear all fields and start over

The dual output panels provide clear separation between status updates and command results, with visual spacers (e.g., `|----------- WRITE #1 -----------|`) making it easy to distinguish between multiple write attempts or verification steps.

### Video Demo

Below is a quick video demo of the usage:

[![Doppelgänger Assistant Demo](https://img.youtube.com/vi/RfWKgS-U8ws/0.jpg)](https://youtu.be/RfWKgS-U8ws)

### Commandline Usage Examples

#### Generating commands for writing iCLASS cards

This command will generate the command needed to encode iCLASS (Legacy/SE/Seos) card data to an iCLASS 2k card:

```sh
doppelganger_assistant -t iclass -bl 26 -fc 123 -cn 4567

[>>] Writing to iCLASS 2k card...
[>>] Command: hf iclass encode -w H10301 --fc 123 --cn 4567 --ki 0
```

#### Writing iCLASS card data with verification

By adding the `-w` (write) and `-v` (verify) flags, the application will use your Proxmark3 to write and verify the card data:

```sh
doppelganger_assistant -t iclass -bl 26 -fc 123 -cn 4567 -w -v

|----------- WRITE -----------|
[..] Encoding iCLASS card data...
[>>] Command: hf iclass encode -w H10301 --fc 123 --cn 4567 --ki 0

[=] Session log /Users/user/.proxmark3/logs/log_20250105120000.txt
[+] loaded `/Users/user/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass encode -w H10301 --fc 123 --cn 4567 --ki 0
[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[+] Encoding successful

[OK] Write complete - starting verification

|----------- VERIFICATION -----------|
[..] Verifying card data - place card flat on reader...

[=] Session log /Users/user/.proxmark3/logs/log_20250105120005.txt
[+] execute command from commandline: hf iclass rdbl --blk 7 --ki 0
[+] Using key[0] AE A6 84 A6 DA B2 32 78
[+] block   7/0x07 : 00 00 00 00 06 F6 23 AE

[OK] Verification successful - Block 7: 00 00 00 00 06 F6 23 AE
[OK] Card contains: 26-bit, FC: 123, CN: 4567
```

#### Simulating PIV/MF Cards

Using the UID provided by Doppelgänger (Core and Stealth), you can simulate the exact wiegand signal with a Proxmark3.

```sh
doppelganger_assistant -uid 5AF70D9D -s -t piv
 
Handling PIV card... 
 
Simulating the PIV card on your Proxmark3: 
 
Executing command: hf 14a sim -t 3 --uid 5AF70D9D 
  
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614152754.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf 14a sim -t 3 --uid 5AF70D9D

[+] Using UART port /dev/tty.usbmodem2134301

```

#### Writing HID Prox cards with multiple attempts

LF cards (Prox, AWID, Indala, Avigilon, EM) automatically perform 5 write attempts with visual separators:

```sh
doppelganger_assistant -t prox -bl 46 -fc 123 -cn 4567 -w

[..] Writing Prox card (5 attempts)...

|----------- WRITE #1 -----------|
[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[+] Wrote block successfully
[..] Move card slowly... Write attempt #1 complete

|----------- WRITE #2 -----------|
[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[+] Wrote block successfully
[..] Move card slowly... Write attempt #2 complete

|----------- WRITE #3 -----------|
... (continues for all 5 attempts)

[OK] All 5 write attempts complete
```

#### Writing Avigilon 56-bit cards

Avigilon cards are written with 5 attempts like other LF cards:

```sh
doppelganger_assistant -t avigilon -bl 56 -fc 118 -cn 1603 -w

[..] Writing Avigilon card (5 attempts)...

|----------- WRITE #1 -----------|
[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
lf hid clone -w Avig56 --fc 118 --cn 1603
[..] Move card slowly... Write attempt #1 complete

... (continues for all 5 attempts)
```

#### Simulating Avigilon cards

Using the Avigilon card data, you can simulate the exact signal with a Proxmark3:

```sh
doppelganger_assistant -t avigilon -bl 56 -fc 118 -cn 1603 -s

Simulating the Avigilon card on your Proxmark3: 

Executing command: lf hid sim -w Avig56 --fc 118 --cn 1603 

Simulation is in progress... If your Proxmark3 has a battery, you can remove the device and the simulation will continue. 

To end the simulation, press the `pm3 button`.
```

## Legal Notice

This application is intended for professional penetration testing and authorized security assessments only. Unauthorized or illegal use/possession of this software is the sole responsibility of the user. Mayweather Group LLC, Practical Physical Exploitation, and the creator are not liable for illegal application of this software.

## License

[![License: CC BY-NC-ND 4.0](https://img.shields.io/badge/License-CC%20BY--NC--ND%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-nd/4.0/)

This work is licensed under a [Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License](https://creativecommons.org/licenses/by-nc-nd/4.0/).

**You are free to:**
* **Share** — copy and redistribute the material in any medium or format

**Under the following terms:**
* **Attribution** — You must give appropriate credit, provide a link to the license, and indicate if changes were made.
* **NonCommercial** — You may not use the material for commercial purposes.
* **NoDerivatives** — If you remix, transform, or build upon the material, you may not distribute the modified material.

See the [LICENSE](LICENSE) file for the full license text.

## Support

For professional support and documentation, visit:
* [Practical Physical Exploitation Documentation](https://docs.physicalexploit.com/)
* [GitHub Issues](https://github.com/tweathers-sec/doppelganger_assistant/issues)
* [Professional Store](https://store.physicalexploit.com/)

## Credits

Developed by Travis Weathers ([@tweathers-sec](https://github.com/tweathers-sec))  
Copyright © 2025 Mayweather Group, LLC

---

*This software works in conjunction with [Doppelgänger Core](https://github.com/mwgroup-io/Doppelganger_Core) and Doppelgänger hardware devices.*
