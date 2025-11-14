#!/usr/bin/env bash
set -e

echo "========================================"
echo "        Micro Pi-Imager Setup"
echo "========================================"
echo

# Safety: don't run as root
if [ "$(id -u)" -eq 0 ]; then
  echo "Please DO NOT run this script as root."
  echo "Run it as your normal user. The script will use sudo when needed."
  exit 1
fi

APP_DIR="$HOME/micro-pi-imager"
APP_FILE="$APP_DIR/micro_pi_imager.py"
BACKUP_DIR="$HOME/micro-pi-backups"
LAUNCHER="/usr/local/bin/micro-pi-imager"
CLI_LAUNCHER="/usr/local/bin/micro_pi_imager"
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/micro-pi-imager.desktop"

echo "[1/7] Installing dependencies..."
sudo apt update
sudo apt install -y python3 python3-tk parted policykit-1 wget xz-utils

echo "[2/7] Installing PiShrink..."
if ! command -v pishrink.sh >/dev/null 2>&1; then
  wget -O /tmp/pishrink.sh https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
  chmod +x /tmp/pishrink.sh
  sudo mv /tmp/pishrink.sh /usr/local/bin/pishrink.sh
  echo "PiShrink installed."
else
  echo "PiShrink already installed."
fi

echo "[3/7] Creating directories..."
mkdir -p "$APP_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$DESKTOP_DIR"

echo "[4/7] Writing GUI app to: $APP_FILE"
cat > "$APP_FILE" <<'PYAPP'
#!/usr/bin/env python3
import os
import re
import pwd
import subprocess
import threading
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

APP_TITLE = "Micro Pi-Imager"

def get_real_home():
    pk_uid = os.environ.get("PKEXEC_UID")
    if pk_uid:
        try:
            return pwd.getpwuid(int(pk_uid)).pw_dir
        except:
            pass
    return os.path.expanduser("~")

REAL_HOME = get_real_home()
DEFAULT_BACKUP_DIR = os.path.join(REAL_HOME, "micro-pi-backups")

def run_cmd(cmd):
    return subprocess.run(cmd, check=True, text=True,
                          stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE)

def get_block_devices():
    result = run_cmd(["lsblk", "-ndo", "NAME,SIZE,TYPE,MODEL"])
    devs = []
    for line in result.stdout.strip().splitlines():
        parts = line.split(None, 3)
        if len(parts) >= 3 and parts[2] == "disk":
            name, size = parts[0], parts[1]
            model = parts[3] if len(parts) == 4 else ""
            devs.append((f"/dev/{name}", f"/dev/{name}  ({size})  {model}"))
    return devs

def get_last_used_sector(devpath):
    result = run_cmd(["parted", devpath, "unit", "s", "print"])
    last = None
    for line in result.stdout.splitlines():
        if re.match(r"^\s*\d+\s", line):
            parts = line.split()
            if len(parts) >= 3 and parts[2].endswith("s"):
                try:
                    last = int(parts[2][:-1])
                except:
                    pass
    if last is not None:
        return last

    # fallback
    result = run_cmd(["fdisk", "-l", devpath])
    for line in result.stdout.splitlines():
        if line.startswith(f"Disk {devpath}:") and "sectors" in line:
            total = int(line.split("sectors")[0].split()[-1])
            return total - 1
    raise RuntimeError("Could not detect last used sector.")

class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("680x450")

        self.columnconfigure(0, weight=1)
        self.rowconfigure(2, weight=1)

        self.devices = []
        self.selected_dev = tk.StringVar()
        self.shrink_var = tk.BooleanVar(value=False)
        self.comp_var = tk.StringVar(value="none")

        self.build_ui()
        self.load_devices()

    def build_ui(self):
        style = ttk.Style(self)
        style.configure("Visible.TCombobox",
                        foreground="black",
                        fieldbackground="white")

        top = ttk.Frame(self)
        top.grid(row=0, column=0, padx=10, pady=5, sticky="ew")
        top.columnconfigure(1, weight=1)

        ttk.Label(top, text="Source drive:").grid(row=0, column=0, sticky="w")

        self.combo = ttk.Combobox(top, textvariable=self.selected_dev,
                                  state="readonly", style="Visible.TCombobox")
        self.combo.grid(row=0, column=1, sticky="ew")
        ttk.Button(top, text="Refresh", command=self.load_devices).grid(
            row=0, column=2, padx=5)

        mid = ttk.Frame(self)
        mid.grid(row=1, column=0, padx=10, pady=5, sticky="ew")
        mid.columnconfigure(0, weight=1)

        self.btn = ttk.Button(mid, text="Create Image from Used Partitions",
                              command=self.start)
        self.btn.grid(row=0, column=0, sticky="ew")

        ttk.Checkbutton(mid, text="Shrink image with PiShrink after creation",
                        variable=self.shrink_var).grid(row=1, column=0, sticky="w")

        comp_frame = ttk.Frame(mid)
        comp_frame.grid(row=2, column=0, sticky="w", pady=3)

        ttk.Label(comp_frame, text="Compression:").grid(row=0, column=0)
        comp_box = ttk.Combobox(comp_frame, textvariable=self.comp_var,
                                state="readonly",
                                values=["none", "gzip", "xz"],
                                width=10)
        comp_box.grid(row=0, column=1, padx=5)
        comp_box.current(0)

        self.progress = ttk.Progressbar(mid, mode="determinate", maximum=100)
        self.progress.grid(row=3, column=0, sticky="ew", pady=5)

        log_frame = ttk.LabelFrame(self, text="Log")
        log_frame.grid(row=2, column=0, padx=10, pady=5, sticky="nsew")
        log_frame.rowconfigure(0, weight=1)
        log_frame.columnconfigure(0, weight=1)

        self.log = tk.Text(log_frame, wrap="word", state="disabled")
        self.log.grid(row=0, column=0, sticky="nsew")
        sb = ttk.Scrollbar(log_frame, orient="vertical",
                           command=self.log.yview)
        sb.grid(row=0, column=1, sticky="ns")
        self.log.configure(yscrollcommand=sb.set)

        info = ttk.Label(self,
                         text=(
                             f"Images are saved to: {DEFAULT_BACKUP_DIR}\n"
                             "• PiShrink (optional): Reduce the size of the raw image.\n"
                             "• Compression (optional): Save the final image as .gz or .xz."
                         ),
                         anchor="w", justify="left")
        info.grid(row=3, column=0, padx=10, pady=(0, 5), sticky="w")

    def log_write(self, s):
        self.log.configure(state="normal")
        self.log.insert("end", s+"\n")
        self.log.see("end")
        self.log.configure(state="disabled")

    def set_progress(self, value):
        self.progress["value"] = value

    def load_devices(self):
        try:
            self.devices = get_block_devices()
        except Exception as e:
            messagebox.showerror("Error", str(e))
            return

        labels = [lbl for _, lbl in self.devices]
        self.combo["values"] = labels
        if labels:
            self.combo.current(0)
        self.log_write("Detected drives:\n" + ("\n".join(labels) if labels else "(none)"))

    def get_dev(self):
        idx = self.combo.current()
        if idx < 0 or idx >= len(self.devices):
            return None
        return self.devices[idx][0]

    def start(self):
        dev = self.get_dev()
        if not dev:
            messagebox.showwarning("No drive selected", "Please select a source drive.")
            return

        os.makedirs(DEFAULT_BACKUP_DIR, exist_ok=True)

        default = os.path.basename(dev) + ".img"
        outfile = filedialog.asksaveasfilename(
            title="Save Image As",
            initialdir=DEFAULT_BACKUP_DIR,
            initialfile=default,
            defaultextension=".img"
        )
        if not outfile:
            return

        if not messagebox.askyesno("Confirm", f"Create image from {dev}?\n\nSave to:\n{outfile}"):
            return

        self.btn.config(state="disabled")
        self.combo.config(state="disabled")
        self.set_progress(0)

        threading.Thread(target=self.worker, args=(dev, outfile),
                         daemon=True).start()

    def worker(self, dev, outfile):
        final_path = outfile
        try:
            self.log_write(f"Source: {dev}")
            last = get_last_used_sector(dev)
            sectors = last + 1
            total_bytes = sectors * 512

            self.log_write(f"Last used sector: {last}")
            self.log_write("Running dd...")

            cmd = ["dd", f"if={dev}", f"of={outfile}",
                   "bs=512", f"count={sectors}",
                   "status=progress", "conv=fsync"]
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True)

            for line in proc.stdout:
                line = line.strip()
                if not line:
                    continue
                m = re.search(r"(\d+)\s+bytes", line)
                if m:
                    try:
                        pct = int(int(m.group(1))*100 / total_bytes)
                        self.set_progress(min(100, pct))
                    except:
                        pass
                self.log_write(line)

            if proc.wait() != 0:
                self.log_write("dd failed.")
                messagebox.showerror("Error", "dd failed.")
                return

            self.set_progress(100)
            self.log_write("dd completed.")
            self.log_write(f"Image saved: {outfile}")

            # PiShrink
            if self.shrink_var.get():
                self.log_write("Shrinking image with PiShrink...")
                proc2 = subprocess.Popen(["pishrink.sh", outfile],
                                         stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT, text=True)
                for line in proc2.stdout:
                    self.log_write(line.strip())
                if proc2.wait() != 0:
                    messagebox.showerror("Error", "PiShrink failed.")
                    return

            # Compression
            comp = self.comp_var.get()
            if comp in ("gzip", "xz"):
                self.log_write(f"Compressing ({comp})...")
                if comp == "gzip":
                    comp_cmd = ["gzip", "-9", outfile]
                    final_path = outfile + ".gz"
                else:
                    comp_cmd = ["xz", "-9e", outfile]
                    final_path = outfile + ".xz"

                proc3 = subprocess.Popen(comp_cmd,
                                         stdout=subprocess.PIPE,
                                         stderr=subprocess.STDOUT,
                                         text=True)
                for line in proc3.stdout:
                    self.log_write(line.strip())
                if proc3.wait() != 0:
                    messagebox.showerror("Error", "Compression failed.")
                    return

                self.log_write(f"Compression complete: {final_path}")

            messagebox.showinfo("Complete", f"Image created:\n{final_path}")

        except Exception as e:
            self.log_write(f"Error: {e}")
            messagebox.showerror("Error", str(e))
        finally:
            self.btn.config(state="normal")
            self.combo.config(state="readonly")

if __name__ == "__main__":
    App().mainloop()
PYAPP

chmod +x "$APP_FILE"

echo "[5/7] Creating pkexec launcher..."
sudo bash -c "cat > '$LAUNCHER'" <<'LAUNCH'
#!/usr/bin/env bash
APP_FILE="$HOME/micro-pi-imager/micro_pi_imager.py"
exec pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTHORITY" PKEXEC_UID="$(id -u)" python3 "$APP_FILE"
LAUNCH
sudo chmod +x "$LAUNCHER"

echo "[6/7] Creating CLI helper..."
sudo bash -c "cat > '$CLI_LAUNCHER'" <<'CLI'
#!/usr/bin/env bash

if [ "$1" = "--uninstall" ]; then
  echo "Uninstalling Micro Pi-Imager..."
  USER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"

  rm -rf "$USER_HOME/micro-pi-imager"
  rm -f /usr/local/bin/micro-pi-imager
  rm -f /usr/local/bin/micro_pi_imager
  rm -f "$USER_HOME/.local/share/applications/micro-pi-imager.desktop"

  echo "Done. Backups in $USER_HOME/micro-pi-backups were kept."
  exit 0
fi

exec micro-pi-imager
CLI
sudo chmod +x "$CLI_LAUNCHER"

echo "[7/7] Creating desktop entry..."
cat > "$DESKTOP_FILE" <<'DESK'
[Desktop Entry]
Type=Application
Name=Micro Pi-Imager
Comment=Create bootable images from used partitions (with optional shrinking & compression)
Exec=micro-pi-imager
Icon=utilities-terminal
Terminal=false
Categories=Utility;System;
DESK

echo
echo "========================================"
echo "       Micro Pi-Imager Installed!"
echo "========================================"
echo
echo "Run from menu: Micro Pi-Imager"
echo "Or run from terminal: micro-pi-imager"
echo
echo "Uninstall with: sudo micro_pi_imager --uninstall"
echo
