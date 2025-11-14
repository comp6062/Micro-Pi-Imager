#!/bin/bash
set -e

APP_DIR="$HOME/micro-pi-imager"
BIN="/usr/local/bin/micropi-imager"
DESKTOP_FILE="$HOME/.local/share/applications/micropi-imager.desktop"
BACKUP_DIR="$HOME/micro-pi-backups"

echo "======================================"
echo " Installing Micro Pi-Imager"
echo "======================================"
echo

sudo apt update
sudo apt install -y python3 python3-tk python3-pip jq xz-utils gzip

mkdir -p "$APP_DIR"
mkdir -p "$BACKUP_DIR"

##############################################
# 1. Install PiShrink
##############################################
echo "[INFO] Installing PiShrink..."
cat << 'EOF' > "$APP_DIR/pishrink.sh"
#!/bin/bash
# --- PiShrink Embedded Version ---
set -e

img="$1"

if [ ! -f "$img" ]; then
    echo "ERROR: Image not found: $img"
    exit 1
fi

# Resize and shrink
echo "[PiShrink] Shrinking image..."
e2fsck -fy "$img"
resize2fs -M "$img"
EOF

chmod +x "$APP_DIR/pishrink.sh"

##############################################
# 2. Install the Micro Pi-Imager GUI
##############################################
echo "[INFO] Installing GUI..."

cat << 'EOF' > "$APP_DIR/micropi-imager.py"
#!/usr/bin/env python3
import os
import subprocess
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

APP_DIR = os.path.expanduser("~/micro-pi-imager")
BACKUP_DIR = os.path.expanduser("~/micro-pi-backups")
PISHRINK = f"{APP_DIR}/pishrink.sh"

def list_drives():
    try:
        output = subprocess.check_output(
            "lsblk -o NAME,TYPE,SIZE,MOUNTPOINT -J", shell=True
        ).decode()
        data = __import__("json").loads(output)

        drives = []
        for blk in data['blockdevices']:
            if blk['type'] == 'disk':
                drives.append(f"/dev/{blk['name']} ({blk['size']})")
        return drives
    except:
        return []

def run_dd():
    drive = drive_var.get().split()[0]
    img_path = os.path.join(BACKUP_DIR, os.path.basename(drive) + ".img")

    log.insert(tk.END, f"Creating image from {drive}\n")
    log.update()

    cmd = ["sudo", "dd", f"if={drive}", f"of={img_path}", "bs=4M", "status=progress"]

    try:
        subprocess.run(cmd, check=True)
    except Exception as e:
        messagebox.showerror("Error", str(e))
        return

    log.insert(tk.END, f"Image saved: {img_path}\n")
    log.update()

    if shrink_var.get():
        log.insert(tk.END, "Shrinking with PiShrink...\n")
        log.update()
        try:
            subprocess.run([PISHRINK, img_path], check=True)
        except:
            messagebox.showerror("Error", "PiShrink failed")

    if compress_var.get() != "none":
        comp = compress_var.get()
        log.insert(tk.END, f"Compressing image using {comp}...\n")
        log.update()

        if comp == "gzip":
            subprocess.run(["gzip", "-f", img_path], check=True)
        elif comp == "xz":
            subprocess.run(["xz", "-f", img_path], check=True)

    messagebox.showinfo("Done", "Backup completed!")

root = tk.Tk()
root.title("Micro Pi-Imager")
root.geometry("560x450")

# DARK THEME FIX
style = ttk.Style()
style.theme_use("clam")
style.configure("TCombobox", foreground="black", fieldbackground="#e3e3e3")

drive_var = tk.StringVar()
shrink_var = tk.BooleanVar()
compress_var = tk.StringVar(value="none")

ttk.Label(root, text="Source drive:").pack(anchor="w", padx=10, pady=5)

drive_box = ttk.Combobox(root, textvariable=drive_var, width=45)
drive_box['values'] = list_drives()
drive_box.pack(padx=10)

def refresh():
    drive_box['values'] = list_drives()

ttk.Button(root, text="Refresh", command=refresh).pack(pady=5)

ttk.Button(root, text="Create Image", command=run_dd).pack(pady=10)

ttk.Checkbutton(root, text="Shrink with PiShrink after creation", variable=shrink_var).pack()

ttk.Label(root, text="Compression:").pack()
ttk.Combobox(root, textvariable=compress_var,
             values=["none", "gzip", "xz"], width=15).pack()

log = tk.Text(root, height=15)
log.pack(fill="both", expand=True, padx=10, pady=10)

root.mainloop()
EOF

chmod +x "$APP_DIR/micropi-imager.py"

##############################################
# 3. Install launcher
##############################################
echo "[INFO] Installing launcher..."

sudo bash -c "cat << 'EOF' > $BIN
#!/bin/bash
python3 $APP_DIR/micropi-imager.py
EOF"

sudo chmod +x "$BIN"

##############################################
# 4. Desktop Entry
##############################################
mkdir -p "$(dirname "$DESKTOP_FILE")"

cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Micro Pi-Imager
Exec=sudo micropi-imager
Icon=drive-harddisk
Terminal=false
Categories=Utility;
EOF

echo
echo "========================================"
echo "  Micro Pi-Imager installation done!"
echo "========================================"
echo
echo "Run with:"
echo "  sudo micropi-imager"
echo
echo "Uninstall with:"
echo "  sudo micropi-imager --uninstall"
