# Doppelgänger Assistant

A professional GUI application for calculating card data and automating Proxmark3 operations for every card type that Doppelgänger Core, Pro, Stealth, and MFAS support. This tool streamlines the card-writing process for physical penetration testing by providing an intuitive interface with an embedded terminal, eliminating the need to memorize complex Proxmark3 syntax or dig through notes.

![Doppelgänger Assistant GUI](https://github.com/tweathers-sec/doppelganger_assistant/blob/main/img/assistant_gui.png)

## Features

* **Modern GUI Interface**: Intuitive two-column layout with embedded terminal for real-time command execution
* **Integrated Terminal**: Full-featured terminal emulator with native ANSI color support and scrollback
* **Card Calculator**: Automatically generates Proxmark3 commands for writing and simulating cards
* **Direct Execution**: Execute, write, verify, and simulate card operations directly from the GUI
* **Professional Design**: Clean, modern interface with custom-styled buttons and controls
* **Cross-Platform**: Available for macOS, Linux, and Windows (via WSL)

## Doppelgänger Devices

You can purchase Doppelgänger Pro, Stealth, and MFAS from the [Physical Exploitation Store](https://store.physicalexploit.com/). For the open-source firmware, check out [Doppelgänger Core](https://github.com/mwgroup-io/Doppelganger_Core).

## Officially Supported Card Types

Below are the officially supported card types based on Doppelgänger version:

| Card Types                  | Community Edition | Pro | Stealth | MFAS | Notes                         |
| --------------------------- | ----------------- | --- | ------- | ---- | ----------------------------- |
| Keypad PIN Codes            |                   |     |         | X    |                               |
| HID H10301 26-bit           | X                 | X   | X       | X    |                               |
| Indala 26-bit               | X                 | X   | X       | X    | Requires Indala reader/module |
| Indala 27-bit               | X                 | X   | X       | X    | Requires Indala reader/module |
| 2804 WIEGAND 28-bit         |                   | X   | X       | X    |                               |
| Indala 29-bit               | X                 | X   | X       | X    | Requires Indala reader/module |
| ATS Wiegand 30-bit          |                   | X   | X       | X    |                               |
| HID ADT 31-Bit              |                   | X   | X       | X    |                               |
| EM4102 / Wiegand 32-bit     |                   |     | X       | X    |                               |
| HID D10202 33-bit           | X                 | X   | X       | X    |                               |
| HID H10306 34-bit           | X                 | X   | X       | X    |                               |
| HID Corporate 1000 35-bit   | X                 | X   | X       | X    |                               |
| HID Simplex 36-bit (S12906) |                   | X   | X       | X    |                               |
| HID H10304 37-bit           | X                 | X   | X       | X    |                               |
| HID H800002 46-bit          | X                 | X   | X       | X    |                               |
| HID Corporate 1000 48-bit   |                   | X   | X       | X    |                               |
| Avigilon 56-bit             | X                 | X   | X       | X    |                               |
| C910 PIVKey                 |                   |     | X       | X    |                               |
| MIFARE (Various Types)      |                   |     | X       | X    | UID Only                      |

Supported technologies include:

* iCLASS(Legacy/SE/Seos) *Note: Captured SE and Seos cards can only be written to iCLASS 2k cards*
* PROX
* Indala
* AWID
* Avigilon
* EM4102
* PIV
* MIFARE

## Project Structure

The Doppelganger Assistant project is organized as follows:

```
doppelganger_assistant/
├── src/                           # Go source code
│   ├── *.go                      # All Go source files
│   ├── go.mod                    # Go module definition
│   ├── go.sum                    # Go dependencies
│   └── Makefile                  # Installation Makefile
├── installers/                   # Installation scripts
│   ├── doppelganger_install_linux.sh
│   ├── doppelganger_install_macos.sh
│   └── doppelganger_install_windows.ps1
├── scripts/                      # Utility scripts
├── build.sh                      # Single-platform build script
├── build_all.sh                  # Multi-platform build script
└── Dockerfile                    # Docker container definition
```

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

1. **Select Card Type**: Choose from iCLASS, Prox, AWID, Indala, Avigilon, EM, PIV, or MIFARE
2. **Enter Card Data**: Input facility code, card number, bit length, or UID as required
3. **Choose Operation**:
   - **Generate**: Creates Proxmark3 commands for manual execution
   - **Write**: Generates and executes write commands on your Proxmark3
   - **Verify**: Write and verify the card data
   - **Simulate**: Simulate the card using your Proxmark3
4. **Execute**: Click the Execute button to run the operation
5. **Monitor Output**: View real-time command output in the integrated terminal

The embedded terminal provides full interactive support, allowing you to see exactly what's happening with your Proxmark3 in real-time, with native coloring and scrollback support.

### Video Demo

Below is a quick video demo of the usage:

[![Doppelgänger Assistant Demo](https://img.youtube.com/vi/RfWKgS-U8ws/0.jpg)](https://youtu.be/RfWKgS-U8ws)

### Commandline Usage Examples

#### Generating commands for writing iCLASS cards

This command will generate the commands needed to write captured iCLASS (Legacy/SE/Seos) card data to an iCLASS 2k card:

```sh
 doppelganger_assistant -t iclass -bl 26 -fc 123 -cn 4567    

 Write the following values to an iCLASS 2k card: 
  
 hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0 
 hf iclass wrbl --blk 7 -d 0000000006f623ae --ki 0 
 hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0 
 hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0 
```

#### Generating commands, writing card data, and verification of data

By adding the —w (write) and —v (verify) flags, the application will use your PM3 installation to write and verify the card data.

```sh
doppelganger_assistant -t iclass -bl 26 -fc 123 -cn 4567 -w -v   

 The following will be written to an iCLASS 2k card: 
  
 hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0 
 hf iclass wrbl --blk 7 -d 0000000006f623ae --ki 0 
 hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0 
 hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0 
  
 
Connect your Proxmark3 and place an iCLASS 2k card flat on the antenna. Press Enter to continue... 

 Writing block #6... 
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013815.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0
[+] Using key[0] AE A6 84 A6 DA B2 32 78 
[+] Wrote block 6 / 0x06 ( ok )


 Writing block #7... 
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013818.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass wrbl --blk 7 -d 0000000006f623ae --ki 0

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass wrbl --blk 7 -d 0000000006f623ae --ki 0
[+] Using key[0] AE A6 84 A6 DA B2 32 78 
[+] Wrote block 7 / 0x07 ( ok )


 Writing block #8... 
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013820.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0
[+] Using key[0] AE A6 84 A6 DA B2 32 78 
[+] Wrote block 8 / 0x08 ( ok )


 Writing block #9... 
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013821.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0
[+] Using key[0] AE A6 84 A6 DA B2 32 78 
[+] Wrote block 9 / 0x09 ( ok )

Verifying that the card data was successfully written. Set your card flat on the reader...
 
[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013825.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass dump --ki 0

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass dump --ki 0
[+] Using AA1 (debit) key[0] AE A6 84 A6 DA B2 32 78 
[=] Card has at least 2 application areas. AA1 limit 18 (0x12) AA2 limit 31 (0x1F)
.

[=] --------------------------- Tag memory ----------------------------

[=]  block#  | data                    | ascii    |lck| info
[=] ---------+-------------------------+----------+---+----------------
[=]   0/0x00 | 28 66 8B 15 FE FF 12 E0 | (f... |   | CSN 
[=]   1/0x01 | 12 FF FF FF 7F 1F FF 3C | ...< |   | Config
[=]   2/0x02 | FF FF FF FF D9 FF FF FF |  |   | E-purse
[=]   3/0x03 | 84 3F 76 67 55 B8 DB CE | .?vgU |   | Debit
[=]   4/0x04 | FF FF FF FF FF FF FF FF |  |   | Credit
[=]   5/0x05 | FF FF FF FF FF FF FF FF |  |   | AIA
[=]   6/0x06 | 03 03 03 03 00 03 E0 14 | ....... |   | User / HID CFG 
[=]   7/0x07 | 00 00 00 00 06 F6 23 AE | .....# |   | User / Cred 
[=]   8/0x08 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]   9/0x09 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]  10/0x0A | FF FF FF FF FF FF FF FF |  |   | User
[=]  11/0x0B | FF FF FF FF FF FF FF FF |  |   | User
[=]  12/0x0C | FF FF FF FF FF FF FF FF |  |   | User
[=]  13/0x0D | FF FF FF FF FF FF FF FF |  |   | User
[=]  14/0x0E | FF FF FF FF FF FF FF FF |  |   | User
[=]  15/0x0F | FF FF FF FF FF FF FF FF |  |   | User
[=]  16/0x10 | FF FF FF FF FF FF FF FF |  |   | User
[=]  17/0x11 | FF FF FF FF FF FF FF FF |  |   | User
[=]  18/0x12 | FF FF FF FF FF FF FF FF |  |   | User
[=] ---------+-------------------------+----------+---+----------------
[?] yellow = legacy credential

[+] saving dump file - 19 blocks read
[+] Saved 152 bytes to binary file `/Users/tweathers/hf-iclass-28668B15FEFF12E0-dump-008.bin`
[+] Saved to json file `/Users/tweathers/hf-iclass-28668B15FEFF12E0-dump-008.json`
[?] Try `hf iclass decrypt -f` to decrypt dump file
[?] Try `hf iclass view -f` to view dump file


[=] Session log /Users/tweathers/.proxmark3/logs/log_20240614013827.txt
[+] loaded `/Users/tweathers/.proxmark3/preferences.json`
[+] execute command from commandline: hf iclass view -f /Users/tweathers/hf-iclass-28668B15FEFF12E0-dump-008.json

[+] Using UART port /dev/tty.usbmodem101
[+] Communicating with PM3 over USB-CDC
[usb|script] pm3 --> hf iclass view -f /Users/tweathers/hf-iclass-28668B15FEFF12E0-dump-008.json
[+] loaded `/Users/tweathers/hf-iclass-28668B15FEFF12E0-dump-008.json`

[=] --------------------------- Card ---------------------------
[+]     CSN... 28 66 8B 15 FE FF 12 E0  uid
[+]  Config... 12 FF FF FF 7F 1F FF 3C  card configuration
[+] E-purse... FF FF FF FF D9 FF FF FF  card challenge, CC
[+]      Kd... 84 3F 76 67 55 B8 DB CE  debit key
[+]      Kc... FF FF FF FF FF FF FF FF  credit key ( hidden )
[+]     AIA... FF FF FF FF FF FF FF FF  application issuer area
[=] -------------------- Card configuration --------------------
[=]     Raw... 12 FF FF FF 7F 1F FF 3C 
[=]            12 (  18 ).............  app limit
[=]               FFFF ( 65535 )......  OTP
[=]                     FF............  block write lock
[=]                        7F.........  chip
[=]                           1F......  mem
[=]                              FF...  EAS
[=]                                 3C  fuses
[=]   Fuses:
[+]     mode......... Application (locked)
[+]     coding....... ISO 14443-2 B / 15693
[+]     crypt........ Secured page, keys not locked
[=]     RA........... Read access not enabled
[=]     PROD0/1...... Default production fuses
[=] -------------------------- Memory --------------------------
[=]  2 KBits/2 App Areas ( 256 bytes )
[=]     1 books / 1 pages
[=]  First book / first page configuration
[=]     Config | 0 - 5 ( 0x00 - 0x05 ) - 6 blocks 
[=]     AA1    | 6 - 18 ( 0x06 - 0x12 ) - 13 blocks
[=]     AA2    | 19 - 31 ( 0x13 - 0x1F ) - 18 blocks
[=] ------------------------- KeyAccess ------------------------
[=]  * Kd, Debit key, AA1    Kc, Credit key, AA2 *
[=]     Read AA1..... debit
[=]     Write AA1.... debit
[=]     Read AA2..... credit
[=]     Write AA2.... credit
[=]     Debit........ debit or credit
[=]     Credit....... credit

[=] --------------------------- Tag memory ----------------------------

[=]  block#  | data                    | ascii    |lck| info
[=] ---------+-------------------------+----------+---+----------------
[=]   0/0x00 | 28 66 8B 15 FE FF 12 E0 | (f... |   | CSN 
[=]   ......
[=]   6/0x06 | 03 03 03 03 00 03 E0 14 | ....... |   | User / HID CFG 
[=]   7/0x07 | 00 00 00 00 06 F6 23 AE | .....# |   | User / Cred 
[=]   8/0x08 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]   9/0x09 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]  10/0x0A | FF FF FF FF FF FF FF FF |  |   | User
[=]  11/0x0B | FF FF FF FF FF FF FF FF |  |   | User
[=]  12/0x0C | FF FF FF FF FF FF FF FF |  |   | User
[=]  13/0x0D | FF FF FF FF FF FF FF FF |  |   | User
[=]  14/0x0E | FF FF FF FF FF FF FF FF |  |   | User
[=]  15/0x0F | FF FF FF FF FF FF FF FF |  |   | User
[=]  16/0x10 | FF FF FF FF FF FF FF FF |  |   | User
[=]  17/0x11 | FF FF FF FF FF FF FF FF |  |   | User
[=]  18/0x12 | FF FF FF FF FF FF FF FF |  |   | User
[=] ---------+-------------------------+----------+---+----------------
[?] yellow = legacy credential

[=] Block 7 decoder
[+] Binary..................... 110111101100010001110101110
[=] Wiegand decode
[+] [H10301  ] HID H10301 26-bit                FC: 123  CN: 4567  parity ( ok )
[+] [ind26   ] Indala 26-bit                    FC: 1969  CN: 471  parity ( ok )
[=] found 2 matching formats

 
Verification successful: Facility Code and Card Number match.
```

#### Simulating PIV/MF Cards

Using the UID provided by Doppelgänger (v1.2.0 Doppelgänger Pro, Stealth, and MFAS), you can simulate the exact wiegand signal with a Proxmark3.

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

#### Generating commands for HID H800002 46-bit cards

This command will generate the commands needed to write HID H800002 46-bit card data:

```sh
doppelganger_assistant -t prox -bl 46 -fc 123 -cn 4567

Handling Prox card... 

Write the following values to a T5577 card: 

lf hid clone -w H800002 --fc 123 --cn 4567 
```

#### Generating commands for Avigilon 56-bit cards

This command will generate the commands needed to write Avigilon 56-bit card data:

```sh
doppelganger_assistant -t avigilon -bl 56 -fc 118 -cn 1603

Handling Avigilon card... 

Write the following values to a T5577 card: 

lf hid clone -w Avig56 --fc 118 --cn 1603 
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
