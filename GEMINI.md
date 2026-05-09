# Gemini CLI Context - STT Project

## Project Overview
This project implements a hardware-triggered Speech-to-Text (STT) system for Fedora. It uses `evtest` to listen for global key events, `arecord` for capturing audio, `whisper.cpp` for local inference, and `ydotool` for text injection.

## Critical Architectural Decisions

### 1. Trigger Key: F8
- **Decision:** Use **F8** as the default trigger instead of the "Copilot" key.
- **Rationale:** Modern Copilot keys are implemented as hardware/firmware macros sending `Left Meta + Left Shift + F23`. Attempting to use `ydotool` to inject text while these physical modifiers are held leads to:
    - Garbage output (CSI u sequences) in terminals.
    - Accidental triggering of system shortcuts (e.g., Spectacle screenshots).
- **Fallback:** If a user wants to use a different key, it must be updated in `bin/stt-daemon`.

### 2. Daemon Implementation: evtest
- **Decision:** Use `evtest` listening to raw `/dev/input/event*` devices.
- **Rationale:** Polling `xinput` or using `xbindkeys` is unreliable on Wayland and doesn't handle "Hold vs Release" events as cleanly as raw input events.
- **Security:** Requires the user to be in the `input` group.

### 3. Feedback Mechanism: Inline Text
- **Decision:** Synthetic typing of `recording...` followed by 12 backspaces.
- **Synchronization:** The script includes `sleep 0.2` before typing to allow the physical key release to be processed by the OS, preventing modifier-key mixing.

## Development Workflow
- **Logs:** `~/stt/tmp/stt.log` contains combined logs for recording and whisper inference.
- **Services:**
    - `ydotoold.service` (Systemd system service): Required for virtual typing.
    - `stt-daemon.service` (Systemd user service): Listens for the trigger key.
