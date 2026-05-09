# Fedora Copilot STT

A lightweight, offline, and secure Speech-to-Text (STT) solution for Fedora Linux. Triggered by the **Copilot key**, it transcribes your speech locally and injects the text into your active application.

## Key Features
- Toggle Trigger: Press the key once to start recording, then press it again to stop and transcribe.
- 100% Offline: Uses whisper.cpp for local inference.
- Fast Injection: Uses ydotool for virtual keyboard input.
- Visual Feedback: Real-time status text typed into your active application.
- Lightweight: No heavy background daemons or RAM usage when idle.

## Prerequisites

This project is specifically designed and tested on Fedora Linux. While it may work on other distributions, the dependency names and system configurations are tailored for Fedora.

You will need the following dependencies:

```bash
sudo dnf install -y alsa-utils ydotool xbindkeys zsh cmake gcc-c++ make libnotify libinput-utils xinput
```

## Installation

1. Clone the repository:
   ```bash
   git clone <your-repo-url> ~/stt
   cd ~/stt
   ```

2. Run the installer:
   ```bash
   make install
   ```

3. Set Permissions:
   To allow ydotool to type without root, your user must be in the input group and have access to /dev/uinput:
   ```bash
   sudo usermod -aG input $USER
   sudo sh -c 'chown root:input /dev/uinput && chmod 0660 /dev/uinput'
   ```
   Note: You must log out and log back in for the group changes to take effect.

## Usage

- Press the **Copilot key (keycode 201)** to **start recording**.
- Speak clearly into your microphone. There is no time limit.
- Press the key again to **stop recording** and start transcription.
- The transcribed text will be automatically typed into your focused window.

## Troubleshooting

**TODO: Fix Copilot keymapping. Keycode 201 may be incorrect for all hardware.**

Check the logs for detailed error messages:
```bash
tail -f ~/stt/tmp/stt.log
```
Ensure your default microphone is correctly set in your system sound settings.
