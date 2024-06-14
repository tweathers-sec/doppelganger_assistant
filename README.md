# doppelganger_assistant
Card calculator and Proxmark3 Plugin for writing and/or simulating every card type that Doppelgagner Pro, Stealth, and MFAS support.

## Officially Supported Card Types:
* HID H10301 26-bit
* Indala 26-bit (requires Indala module/reader)
* Indala 27-bit (requires Indala module/reader)
* 2804 WIEGAND 28-bit
* Indala 29-bit (requires Indala module/reader)
* ATS Wiegand 30-bit
* HID ADT 31-Bit
* EM4102 / Wiegand 32-bit
* HID D10202 33-bit
* HID H10306 34-bit
* HID Corporate 1000 35-bit
* HID Simplex 36-bit (S12906)
* HID H10304 37-bit
* HID Corporate 1000 48-bit
* C910 PIVKey (Depends on Reader Capabilities)
* MIFARE (Various - Depends on Reader Capabilities)

## Installation

1) Grab your desired package from the releases page.
2) Ensure that you have the [Iceman fork of the Proxmark3](https://github.com/RfidResearchGroup/proxmark3?tab=readme-ov-file#proxmark3-installation-and-overview) software installed.
3) Run the application...

## Examples

### Generating commands for writing iCLASS cards

This command will generate the commands needed to write captured iCLASS (Legacy/SE/Seos) card data to an iCLASS 2k card:

```
 ./doppelganger_assistant_darwin_arm64 -t iclass -bl 26 -fc 123 -cn 4567    

 Write the following values to an iCLASS 2k card: 
  
 hf iclass wrbl --blk 6 -d 030303030003E014 --ki 0 
 hf iclass wrbl --blk 7 -d 0000000006f623ae --ki 0 
 hf iclass wrbl --blk 8 -d 0000000000000000 --ki 0 
 hf iclass wrbl --blk 9 -d 0000000000000000 --ki 0 
```

By adding the —w (write) and —v (verify) flags, the application will use your PM3 installation to write and verify the card data.

```
 ./doppelganger_assistant_darwin_arm64 -t iclass -bl 26 -fc 123 -cn 4567 -w -v   

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
[=]   0/0x00 | 28 66 8B 15 FE FF 12 E0 | (f..��.� |   | CSN 
[=]   1/0x01 | 12 FF FF FF 7F 1F FF 3C | .���..�< |   | Config
[=]   2/0x02 | FF FF FF FF D9 FF FF FF | �������� |   | E-purse
[=]   3/0x03 | 84 3F 76 67 55 B8 DB CE | .?vgU��� |   | Debit
[=]   4/0x04 | FF FF FF FF FF FF FF FF | �������� |   | Credit
[=]   5/0x05 | FF FF FF FF FF FF FF FF | �������� |   | AIA
[=]   6/0x06 | 03 03 03 03 00 03 E0 14 | ......�. |   | User / HID CFG 
[=]   7/0x07 | 00 00 00 00 06 F6 23 AE | .....�#� |   | User / Cred 
[=]   8/0x08 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]   9/0x09 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]  10/0x0A | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  11/0x0B | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  12/0x0C | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  13/0x0D | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  14/0x0E | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  15/0x0F | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  16/0x10 | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  17/0x11 | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  18/0x12 | FF FF FF FF FF FF FF FF | �������� |   | User
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
[=]   0/0x00 | 28 66 8B 15 FE FF 12 E0 | (f..��.� |   | CSN 
[=]   ......
[=]   6/0x06 | 03 03 03 03 00 03 E0 14 | ......�. |   | User / HID CFG 
[=]   7/0x07 | 00 00 00 00 06 F6 23 AE | .....�#� |   | User / Cred 
[=]   8/0x08 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]   9/0x09 | 00 00 00 00 00 00 00 00 | ........ |   | User / Cred 
[=]  10/0x0A | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  11/0x0B | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  12/0x0C | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  13/0x0D | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  14/0x0E | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  15/0x0F | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  16/0x10 | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  17/0x11 | FF FF FF FF FF FF FF FF | �������� |   | User
[=]  18/0x12 | FF FF FF FF FF FF FF FF | �������� |   | User
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

