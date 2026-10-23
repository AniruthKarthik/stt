# Cursor aware STT (Speech-to-Text)

A lightweight, offline, and secure Speech-to-Text solution optimized for Linux (Arch, Fedora, Ubuntu/Debian, and others). This tool allows you to transcribe speech locally and inject it directly into any active application.

## Key Features
- **Zero Idle Memory:** Uses **0 MB RAM** when idle. Runs strictly on-demand, transcribes, injects, and **kills itself** immediately.
- **Single-Instance Enforcement:** Protected by kernel-level `flock` locks so only one instance runs at any given moment.
- **100% Offline:** Uses `whisper.cpp` for local inference (no data leaves your machine).
- **Inline Feedback & Notifications:** Displays `recording...` at your cursor and optional desktop notifications.
- **Fast Injection:** Uses `ydotool` and clipboard synchronization for virtual input across Wayland and X11.

## Prerequisites

This project is compatible with most **Linux distributions** (Arch, Fedora, Ubuntu, Debian, openSUSE).

The installer will attempt to automatically install dependencies for:
- **Arch Linux** (`pacman -S alsa-utils wl-clipboard evtest make gcc cmake libnotify ydotool git curl`)
- **Fedora** (`dnf`)
- **Ubuntu/Debian** (`apt`)
- **openSUSE** (`zypper`)

If you are on a different distribution, ensure you have these installed:
`alsa-utils`, `wl-clipboard`, `evtest`, `cmake`, `gcc/g++`, `make`, `libnotify`, `ydotool`, `git`, `curl`.

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AniruthKarthik/stt ~/stt
   cd ~/stt
   ```

2. **Run the installer:**
   ```bash
   make install
   ```
   *Note: The installer will automatically:*
   - Detect your distribution and install missing dependencies.
   - Clone and build `whisper.cpp` (`whisper-cli`).
   - Download the base English model (`ggml-base.en.bin`).
   - Install the `stt` command into `~/.local/bin/stt`.
   - Set up permissions and udev rules.

3. **Finalize Permissions:**
   If the installer added you to the `input` group, you **must** log out and log back in (or run `newgrp input`) for the group permissions to take effect.

## Usage

### 1. On-Demand Toggle (Recommended - 0 MB Idle RAM)
Run `stt` directly from your terminal or bind it to a hotkey in your window manager:
- **First trigger:** Starts recording.
- **Second trigger:** Stops recording, transcribes with `whisper.cpp`, types/pastes into your active window, and **kills itself**.

```bash
stt          # Toggles recording on/off
stt status   # Displays current state (Idle / Recording)
stt cancel   # Cancels active recording without transcribing
```

### 2. Window Manager Keybinds

#### Hyprland (`~/.config/hypr/hyprland.conf`)
- **Toggle Mode (Press F8 to record, press F8 again to transcribe):**
  ```ini
  bind = , F8, exec, stt
  ```
- **Hold-to-Talk Mode (Hold F8 to record, release F8 to transcribe):**
  ```ini
  bind = , F8, exec, stt start
  bindr = , F8, exec, stt stop
  ```

#### Sway / i3 (`~/.config/sway/config` or `~/.config/i3/config`)
```ini
bindsym F8 exec stt
```

### 3. Optional Background Daemon
If you prefer a global hardware event listener instead of a compositor keybind:
```bash
systemctl --user enable --now stt-daemon.service
```

## Architecture & Minimal Memory Footprint

- **Single Process at a Time:** Every invocation is protected by `flock`. If a trigger is pressed while transcription is ongoing, redundant instances immediately exit.
- **Self-Terminating:** Once audio is captured and transcribed, `whisper-cli` terminates, immediately releasing the model memory back to the OS.
- **Socket Resolution:** Automatically resolves `ydotool` across user services (`$XDG_RUNTIME_DIR/.ydotool_socket`) and system services (`/tmp/.ydotool_socket`).

## Troubleshooting

- **No Typing:**
  - On **Arch Linux**, verify the user service is running:
    ```bash
    systemctl --user status ydotool.service
    ```
  - On **Fedora/Ubuntu**, verify the system service is running:
    ```bash
    systemctl status ydotoold.service
    ```
- **Permission Denied:** Verify your user is in the `input` group:
  ```bash
  groups
  ```
- **Logs:** Check detailed output here:
  ```bash
  tail -f ~/stt/tmp/stt.log
  ```
