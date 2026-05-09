# Fedora Copilot STT (Hold-to-Talk)

A lightweight, offline, and secure Speech-to-Text (STT) solution for Fedora Linux. Triggered by holding the **Copilot key**, it transcribes your speech locally and injects the text into your active application.

## 🚀 Key Features
- **Hold-to-Talk**: Records only while you hold the key.
- **100% Offline**: Uses `whisper.cpp` for local inference (no data leaves your machine).
- **Fast Injection**: Uses `ydotool` for virtual keyboard input.
- **Visual Feedback**: Real-time notifications via `notify-send`.
- **Lightweight**: No heavy background daemons or RAM usage when idle.

## 📋 Prerequisites

You will need the following dependencies installed on your Fedora system:

```bash
sudo dnf install -y alsa-utils ydotool xbindkeys zsh cmake gcc-c++ make libnotify libinput-utils xinput
```

## 🛠️ Installation

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url> ~/stt
   cd ~/stt
   ```

2. **Run the installer**:
   ```bash
   make install
   ```

3. **Set Permissions**:
   To allow `ydotool` to type without root, your user must be in the `input` group and have access to `/dev/uinput`:
   ```bash
   sudo usermod -aG input $USER
   sudo sh -c 'chown root:input /dev/uinput && chmod 0660 /dev/uinput'
   ```
   **Important**: You must **log out and log back in** for the group changes to take effect.

## ⌨️ Usage

- **Hold the Copilot key** (or the key mapped to keycode 201) to start recording.
- **Speak** clearly while holding the key.
- **Release the key** to finish.
- The transcribed text will be automatically typed into your focused window.

## ⚙️ Customization

- **Change Keycode**: If your Copilot key uses a different code, update `KEY_CODE` in `bin/whisperstt` and your `~/.xbindkeysrc`.
- **Model Size**: By default, this uses the `base.en` model. You can download others from the [whisper.cpp models page](https://huggingface.co/ggerganov/whisper.cpp) and update `MODEL_PATH` in `bin/whisperstt`.

## 📂 Project Structure

- `bin/whisperstt`: The main logic script (Zsh).
- `models/`: Stores the Whisper model weights.
- `whisper.cpp/`: The optimized C++ inference engine.
- `tmp/`: Stores temporary audio clips and logs.
- `Makefile`: Automation for installation and cleanup.

## 🧹 Uninstallation

To remove the services and configurations:
```bash
make uninstall
```

## 📝 Troubleshooting

Check the logs for detailed error messages:
```bash
tail -f ~/stt/tmp/stt.log
```
Ensure your default microphone is correctly set in your system's Sound settings.
