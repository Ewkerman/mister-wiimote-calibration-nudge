# MiSTer Wii Remote Calibration Nudge

A CRT-friendly MiSTer script for making small aiming corrections to a calibrated Wii Remote used as a light gun.

## Features

- Adjust aim up, down, left, or right in 5-point steps.
- Make larger 25-point vertical adjustments.
- Keep separate adjustments for every calibrated console or arcade core.
- Automatically discover MiSTer Wii Remote calibration files.
- Browse long core lists in six-item pages that fit CRT overscan.
- Show the selected core and cumulative directional totals on screen.
- Preserve the original calibration in a companion backup file.

## Install

1. Copy `Wii_Remote_Calibration_Nudge.sh` to `/media/fat/Scripts/` on the MiSTer SD card.
2. Load a supported console or arcade core and start a game.
3. Open the MiSTer OSD and press `F10` to complete the normal light-gun calibration.
4. Run the script from the MiSTer Scripts menu.
5. Select the calibrated core and make the desired adjustment.
6. Press `B`, then confirm with `Y`, to reboot MiSTer and apply the saved calibration.

Calibrate each core separately. A core appears in the chooser after MiSTer creates its calibration file.

## Controls

| Key | Action |
| --- | --- |
| `U` or Up Arrow | Aim up 5 points |
| `D` or Down Arrow | Aim down 5 points |
| `L` or Left Arrow | Aim left 5 points |
| `R` or Right Arrow | Aim right 5 points |
| `3` | Aim up 25 points |
| `4` | Aim down 25 points |
| `C` | Return to core selection |
| `B` | Reboot and apply changes |
| `O` | Restore the original calibration |
| `Q` | Quit |

The core chooser uses `N` for the next page and `P` for the previous page when more than six calibration files are present.

## Compatibility

The script accepts MiSTer's 16-byte calibration files for Wii Remote USB/Bluetooth device IDs `057e:0306` and `057e:0330`. It works with console and arcade cores that support MiSTer's USB/Bluetooth light-gun input and create a standard calibration file.

It does not modify SNAC calibration or add light-gun support to cores that do not already provide it.

## Backups

Before the first adjustment, the script copies the selected calibration file and adds the suffix `.wii-nudge-original`. Pressing `O` restores that complete backup.

## Version

Initial public version: **v0.1.0**.
