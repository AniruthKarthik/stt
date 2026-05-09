# Linux STT (Speech-to-Text)

No offline STT solution available online worked properly on my PC, so I built my own. This is a lightweight, offline, and secure Speech-to-Text solution optimized for Linux. This tool allows you to transcribe speech locally and inject it directly into any active application.

## Key Features
- **Toggle Trigger:** Press and hold **F8** to record, release to transcribe.
- **100% Offline:** Uses `whisper.cpp` for local inference (no data leaves your machine).
- **Inline Feedback:** Displays `recording...` at your cursor while recording.
- **Fast Injection:** Uses `ydotool` for virtual keyboard input.
- **Lightweight:** Minimal background overhead using a low-level event daemon.

## Prerequisites

This project is compatible with most **Linux distributions** (Fedora, Ubuntu, Debian, Arch, etc.) using systemd.

The installer will attempt to automatically install dependencies for:
- **Fedora** (dnf)
- **Ubuntu/Debian** (apt)
- **Arch** (pacman)

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
   - Clone and build `whisper.cpp`.
   - Download the base English model.
   - Configure background services (`ydotoold` and `stt-daemon`).
   - Set up necessary permissions and udev rules.

3. **Finalize Permissions:**
   If the installer added you to the `input` group, you **must** log out and log back in for the changes to take effect.

## Usage

1. **Start the Service:**
   The installation script automatically enables the user service. If it's not running:
   ```bash
   systemctl --user enable --now stt-daemon.service
   ```

2. **Record & Transcribe:**
   - Open any text application (Terminal, Browser, Editor).
   - Press and **hold F8**.
   - You will see `recording...` appear at your cursor.
   - Speak clearly.
   - **Release F8**. The status text will be replaced by your transcription.

## Architecture & Configuration

- **Daemon:** `bin/stt-daemon` listens to `/dev/input/event*` for F8 events.
- **Logic:** `bin/whisperstt` handles the recording (`arecord`), transcription (`whisper.cpp`), and typing (`ydotool`).
- **Trigger Key:** F8 was chosen as the default to avoid conflicts with modern "Copilot" keys, which often send complex macros (Meta+Shift+F23) that can interfere with synthetic typing.

## Troubleshooting

- **No Typing:** Ensure `ydotoold` is running (`systemctl status ydotoold.service`).
- **Permission Denied:** Verify your user is in the `input` group (`groups`).
- **Logs:** Check detailed output here:
  ```bash
  tail -f ~/stt/tmp/stt.log
  ```
