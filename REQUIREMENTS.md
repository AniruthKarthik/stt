# STT Project Requirements

## Overview
A lightweight, offline, secure Speech-to-Text (STT) solution for Linux (specifically Fedora with Wayland/XWayland). It allows the user to press a dedicated hardware key (e.g., the Copilot key) to start recording voice, and upon releasing the key (or toggling), transcribes the audio locally using `whisper.cpp` and injects the text into the currently active application window.

## Core Features
1. **Offline Transcription:** Must run entirely locally without cloud dependencies.
2. **Hardware Key Trigger:** Must reliably detect a specific hardware key (like Copilot/F23, Meta, or a custom shortcut) to start and stop recording.
3. **Audio Capture:** Must capture audio from the default microphone efficiently while the key is active or toggled.
4. **Text Injection:** Must reliably type the transcribed text into the active window (using tools like `ydotool` or `wtype`).
5. **Visual Feedback (Optional but preferred):** Provide a status indication (e.g., typing "recording..." and erasing it, or using notifications) so the user knows it's working.
6. **Hallucination Filtering:** Must ignore empty or silent audio transcriptions (e.g., "[BLANK_AUDIO]").

## Technical Stack
- **STT Engine:** `whisper.cpp` (C++ port of OpenAI's Whisper)
- **Model:** `ggml-base.en.bin` (or similar lightweight English model)
- **Audio Capture:** `arecord` (ALSA)
- **Text Injection:** `wtype` (Wayland native) or `ydotool` (generic virtual input). Given previous ydotool issues, an alternative or robust setup is required.
- **Key Binding/Triggering:** Wayland-compatible global shortcut handler. Since `xinput` and `xbindkeys` are unreliable on pure Wayland, we need a robust solution. Options include:
  - `evtest` / reading `/dev/input/` devices directly (requires `input` group permissions).
  - Desktop Environment specific shortcuts (GNOME Settings -> Custom Shortcuts) calling a toggle script.
  - `actkbd` or `interception-tools` for low-level key mapping.

## Fresh Start Execution Plan
1. **Cleanup:** Remove all existing binaries, logs, temporary files, and user systemd services (e.g., `ydotoold`).
2. **Key Detection Strategy:** Determine the exact evdev code for the target key (Copilot key). Implement a robust background daemon or rely on native DE shortcuts to handle the trigger.
3. **Text Injection Strategy:** Ensure `ydotool` or `wtype` is correctly configured and has the necessary permissions.
4. **Script Rewrite:** Create a clean, robust toggle script that handles state safely (no race conditions) and cleans up spawned processes.
5. **Installation & Setup:** Provide an idempotent `install.sh` and `Makefile`.
6. **Testing:** Verify the entire pipeline end-to-end.
