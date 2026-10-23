# Cursor aware STT (Speech-to-Text)

A lightweight, offline, and secure Speech-to-Text solution optimized for **all Linux distributions** (Arch, Debian/Ubuntu, Fedora/RHEL, openSUSE, Alpine, Void, Gentoo, and others) across **Wayland** and **X11**.

## Key Features
- **Zero Idle Memory:** Uses **0 MB RAM** when idle. Runs strictly on-demand, transcribes, injects, and **kills itself** immediately.
- **Universal Linux Compatibility:** Works seamlessly across major distributions with auto-detection for package managers, input groups (`input` / `uinput`), and display servers (Wayland with `wl-copy`, X11 with `xclip` / `xsel`, and direct typing fallback).
- **Single-Instance Enforcement:** Protected by kernel-level `flock` locks so only one instance runs at any given moment.
- **100% Offline & Private:** Uses `whisper.cpp` for local inference (no data leaves your machine).
- **Inline Feedback & Desktop Notifications:** Displays `recording...` at your cursor and sends unobtrusive desktop notifications.
- **Auto-Managed Virtual Input:** Automatically discovers or starts the `ydotoold` daemon without requiring manual service setup.

## Prerequisites & Supported Distributions

The installer will automatically detect your distribution and install the necessary dependencies:

| Distribution | Package Manager Command |
| :--- | :--- |
| **Arch Linux / Manjaro** | `sudo pacman -S alsa-utils wl-clipboard xclip evtest make gcc cmake libnotify ydotool git curl` |
| **Debian / Ubuntu / Mint** | `sudo apt install alsa-utils wl-clipboard xclip evtest make g++ cmake libnotify-bin ydotool git curl` |
| **Fedora / RHEL / Rocky** | `sudo dnf install alsa-utils wl-clipboard xclip evtest make gcc-c++ cmake libnotify ydotool git curl` |
| **openSUSE** | `sudo zypper install alsa-utils wl-clipboard xclip evtest make gcc-c++ cmake libnotify-tools ydotool git curl` |
| **Alpine Linux** | `sudo apk add alsa-utils wl-clipboard xclip evtest make g++ cmake libnotify ydotool git curl bash` |
| **Void Linux** | `sudo xbps-install -Sy alsa-utils wl-clipboard xclip evtest make gcc cmake libnotify ydotool git curl` |
| **Gentoo** | `sudo emerge media-sound/alsa-utils gui-apps/wl-clipboard x11-misc/xclip app-misc/evtest dev-build/cmake app-misc/ydotool` |

If you are on another distribution, ensure you have:
`alsa-utils`, `wl-clipboard` (Wayland) or `xclip`/`xsel` (X11), `make`, `c++ compiler`, `cmake`, `ydotool`, `git`, `curl`.

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AniruthKarthik/stt ~/stt
   cd ~/stt
   ```

2. **Run the universal installer:**
   ```bash
   make install
   ```
   *The installer will:*
   - Detect your package manager and install any missing dependencies.
   - Clone and compile `whisper.cpp` (`whisper-cli`).
   - Download the base English model (`ggml-base.en.bin`).
   - Configure `/dev/uinput` permissions and group access (`input` / `uinput`).
   - Symlink the `stt` binary to `~/.local/bin/stt`.

3. **Finalize Permissions:**
   If the installer added your user to the `input` or `uinput` group, log out and log back in (or run `newgrp input`) for permissions to apply.

## Usage

### 1. On-Demand Toggle (Recommended - 0 MB Idle RAM)
Run `stt` directly from your terminal or bind it to a hotkey in your window manager or desktop environment:
- **First trigger:** Starts recording microphone audio.
- **Second trigger:** Stops recording, transcribes with `whisper.cpp`, types/pastes into your active window, and **kills itself immediately**.

```bash
stt          # Toggles recording on / off
stt status   # Displays current state (Idle / Recording)
stt record   # Interactive mode: records in terminal until Enter is pressed
stt cancel   # Cancels active recording without transcribing
```

### 2. Window Manager & Desktop Keybinds

#### Hyprland (`~/.config/hypr/hyprland.conf`)
- **Toggle Mode (Press F8 to record, press F8 again to paste):**
  ```ini
  bind = , F8, exec, stt
  ```
- **Hold-to-Talk Mode (Hold F8 to record, release F8 to paste):**
  ```ini
  bind = , F8, exec, stt start
  bindr = , F8, exec, stt stop
  ```

#### Sway / i3 (`~/.config/sway/config` or `~/.config/i3/config`)
```ini
bindsym F8 exec stt
```

#### GNOME / KDE / XFCE
Go to **Settings → Keyboard Shortcuts → Custom Shortcuts** and add:
- **Name:** Speech to Text
- **Command:** `stt`
- **Shortcut:** `F8` (or your preferred key)

### 3. Optional Background Daemon
If you prefer a global low-level hardware event listener across all applications without configuring a desktop keybind:
```bash
systemctl --user enable --now stt-daemon.service
```

## Architecture & Cross-Distro Portability

- **Single Process at a Time:** Every invocation is protected by a kernel `flock` lock to eliminate race conditions.
- **Self-Terminating:** Once audio is captured and transcribed, all processes exit, immediately releasing all memory back to the OS.
- **Display Agnostic:** Works across Wayland (`wl-copy`) and X11 (`xclip` / `xsel`) with automatic display environment resolution and direct typing fallback.
- **Socket Resolution:** Automatically resolves `ydotool` across systemd user units, system units, and user-space background daemons.

## Troubleshooting

- **No Typing:**
  - Verify `ydotoold` is running or has access to `/dev/uinput`:
    ```bash
    ydotool debug echo "test"
    ```
- **Permission Denied:**
  - Verify your user is in the `input` or `uinput` group:
    ```bash
    groups
    ```
- **Logs:**
  - Check detailed output at:
    ```bash
    tail -f ~/stt/tmp/stt.log
    ```
