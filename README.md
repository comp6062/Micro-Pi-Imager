# Micro Pi‑Imager

**Micro Pi‑Imager** is a small, simple tool for Raspberry Pi users who want to:

- Make a **bootable backup image** of a USB drive, SD card, or SSD  
- Only copy the **used partitions**, not the whole disk full of empty space  
- Optionally **shrink** the image as small as possible with **PiShrink**  
- Optionally **compress** the final image as **`.img.gz`** or **`.img.xz`** to save space  

It runs as a desktop GUI on Raspberry Pi OS / Debian (with a graphical environment).

---

## Key Features

- ✅ **Automatic size detection** – finds the last used partition and only copies up to that point  
- ✅ **Graphical drive picker** – choose your source drive from a dropdown (`/dev/sda`, `/dev/mmcblk0`, etc.)  
- ✅ **Progress bar** – see how far along the `dd` copy is  
- ✅ **PiShrink integration (optional)** – shrink the raw image so it only contains used filesystem space  
- ✅ **Built‑in compression (optional)** – compress the final image with **gzip** or **xz**  
- ✅ **Default backup folder** – saves images under `~/micro-pi-backups`  
- ✅ **Uninstaller** – remove everything with one command:  
  ```bash
  sudo micro_pi_imager --uninstall
  ```

---

## Requirements

- Raspberry Pi OS (or Debian‑based distro) with:
  - A **graphical desktop** (for the Tkinter GUI and pkexec password prompt)
  - `sudo` configured for your user
- Python 3 and Tkinter (installed automatically by the setup script)
- Internet access the first time you install (to fetch PiShrink and packages)

The setup script will automatically install:

- `python3`, `python3-tk`
- `parted`, `policykit-1`, `wget`, `xz-utils`
- `pishrink.sh` to `/usr/local/bin/pishrink.sh`

---

## Quick Install (remote one‑liner)

Once this project is uploaded to GitHub under  
`https://github.com/comp6062/micro-pi-imager`  
you can install it on a Pi with **one command**:

### Option 1 – `curl` (recommended)

```bash
curl -sL https://raw.githubusercontent.com/comp6062/micro-pi-imager/main/setup_micro_pi_imager.sh | bash
```

### Option 2 – `wget`

```bash
wget -qO- https://raw.githubusercontent.com/comp6062/micro-pi-imager/main/setup_micro_pi_imager.sh | bash
```

> 💡 Both commands:
> - Download `setup_micro_pi_imager.sh`
> - Run it as your regular user (it will use `sudo` only when needed)

---

## Manual Install (from downloaded ZIP)

1. Download or clone this repository to your Raspberry Pi.
2. Open a terminal in the project folder and run:

   ```bash
   chmod +x setup_micro_pi_imager.sh
   ./setup_micro_pi_imager.sh
   ```

3. When it finishes, you’ll see a message like:

   ```text
   Micro Pi-Imager Installed!
   Run from menu: Micro Pi-Imager
   Or run from terminal: micro-pi-imager
   ```

That’s it — the app is now installed.

---

## Using Micro Pi‑Imager

### 1. Start the app

You can start it in two ways:

- From the **Raspberry Pi menu** → *Accessories / System* → **Micro Pi‑Imager**  
- Or from a terminal:

  ```bash
  micro-pi-imager
  ```

A graphical password prompt will appear (from `pkexec`).  
Enter your password so the app can read drives and run `dd`.

---

### 2. Choose your source drive

In the **“Source drive”** dropdown you’ll see entries like:

- `/dev/sda (114.6G) Ultra`
- `/dev/mmcblk0 (119.1G)`

Pick the drive you want to back up.  
> ⚠ **Be 100% sure** you’ve selected the correct device, especially if you have external disks attached.

You can click **Refresh** if you plug in a new drive.

---

### 3. Optional settings

Below the main button you’ll see:

- ✅ **Shrink image with PiShrink after creation**  
  - If checked, Micro Pi‑Imager will run `pishrink.sh` on the raw `.img` file after copying.  
  - Result: an image that’s as small as possible, while still bootable.

- ✅ **Compression** dropdown:
  - `none` – leave the image as a plain `.img`
  - `gzip` – compress to `.img.gz` (good balance of speed and size)
  - `xz` – compress to `.img.xz` (smallest file, but slowest to create)

You can use PiShrink, compression, both, or neither.

---

### 4. Choose where to save the image

Click **“Create Image from Used Partitions”**.  
A file dialog will appear:

- Default folder: `~/micro-pi-backups`
- Default filename: something like `sda.img`

Pick a name and click **Save**.

---

### 5. Watch the progress

While the image is created:

- The **progress bar** shows how far along the `dd` copy is  
- The **Log** window shows:
  - Detected drives
  - The `dd` command being run
  - `dd` progress output
  - Any errors

After `dd` finishes:

- If PiShrink is enabled, you’ll see PiShrink output in the log
- If compression is enabled, you’ll see gzip/xz output and the final filename

When everything is done, a pop‑up will show you the final image path, e.g.:

```text
Image created:
/home/admin/micro-pi-backups/sda.img.xz
```

---

## Where are my backups stored?

By default, Micro Pi‑Imager saves images to:

```text
~/micro-pi-backups
```

For example, if your username is `admin`, that is:

```text
/home/admin/micro-pi-backups
```

You can change the folder in the “Save As…” dialog when creating an image.

---

## Uninstalling Micro Pi‑Imager

If you ever want to remove the app:

```bash
sudo micro_pi_imager --uninstall
```

This will:

- Remove:
  - `~/micro-pi-imager`
  - `/usr/local/bin/micro-pi-imager`
  - `/usr/local/bin/micro_pi_imager`
  - `~/.local/share/applications/micro-pi-imager.desktop`
- **Keep** your backup images in `~/micro-pi-backups`

---

## Safety Tips

- Always **double‑check** the selected source drive (`/dev/sda`, `/dev/mmcblk0`, etc.).
- If you are unsure which device is which, run:

  ```bash
  lsblk
  ```

  and look at sizes and mount points before using Micro Pi‑Imager.
- Keep your Raspberry Pi powered by a **reliable power supply** while imaging drives.

---

## FAQ

### Does this tool clone the entire disk?

No. Micro Pi‑Imager:

1. Reads the partition table with `parted`
2. Finds the **last used partition’s end sector**
3. Runs `dd` **only up to that point**, not the entire physical disk

This makes the image smaller and faster to create, while still being bootable.

---

### What is PiShrink and why would I enable it?

[PiShrink](https://github.com/Drewsif/PiShrink) is a script that:

- Shrinks the filesystem inside a Raspberry Pi image so it only contains used space
- Automatically makes the filesystem expand again on first boot

Use it when you want your backup image to be as small as possible, especially before uploading or archiving.

---

### Which compression should I choose?

- **none**  
  - Fastest, but biggest file (`.img`)
- **gzip**  
  - Good balance: `.img.gz`, smaller but still fairly quick
- **xz**  
  - Smallest file: `.img.xz`, but slowest to create

If you’re not sure, **gzip** is a good default.

---

### Can I restore an image created by Micro Pi‑Imager?

Yes. The image is a standard `.img` file (optionally shrunk and/or compressed).  

To restore:

1. If compressed, decompress it first (e.g. `gunzip` or `unxz`).
2. Use `dd`, `Raspberry Pi Imager`, or another imaging tool to write it back to a drive.

---

## Credits

- **Micro Pi‑Imager** – wrapper and GUI design for easier backup of Raspberry Pi / Linux drives  
- **PiShrink** – original image‑shrinking script by [Drewsif](https://github.com/Drewsif/PiShrink)

If this tool saved your bacon before a bad SD card or helped you move to a new drive more easily — mission accomplished ✅.
