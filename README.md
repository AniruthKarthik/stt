# Fedora Copilot-key Offline Speech-to-Text (STT)

An efficient, offline speech-to-text solution for Fedora Linux, triggered by the Copilot key.

## Architecture

1.  **Hotkey Trigger**: `xbindkeys` listens for the Copilot key (keycode 201).
2.  **Audio Recording**: `arecord` captures 5 seconds of audio from the default microphone.
3.  **Local Inference**: `whisper.cpp` (OpenAI Whisper) transcribes the audio locally using the `ggml-base.en` model.
4.  **Text Injection**: `ydotool` (via `ydotoold` user service) injects the transcribed text into the currently focused application as keyboard input.
5.  **Notifications**: `notify-send` provides real-time feedback (Listening, Transcribing, Result).

## Prerequisites

-   Fedora Linux
-   `zsh` (script shell)
-   `alsa-utils` (for `arecord`)
-   `ydotool` (for text injection)
-   `xbindkeys` (for hotkey management)
-   `libnotify` (for `notify-send`)
-   `cmake`, `g++`, `make` (for building `whisper.cpp`)

## Installation

1.  Clone the repository to `~/stt`.
2.  Run the installer:
    ```bash
    ./install.sh
    ```
3.  **Permissions**: Ensure your user has access to `/dev/uinput` for `ydotool` to work:
    ```bash
    sudo usermod -aG input $USER
    sudo sh -c 'chown root:input /dev/uinput && chmod 0660 /dev/uinput'
    ```
    *Note: You may need to log out and back in for group changes to take effect.*

## Usage

1.  Press the **Copilot key**.
2.  Wait for the "Listening..." notification.
3.  Speak clearly.
4.  After 5 seconds, the "Transcribing..." notification will appear.
5.  The text will be automatically typed into your active window.

## Configuration

-   **Recording Duration**: Modify `RECORD_DURATION` in `bin/whisperstt`.
-   **Model**: The project uses `ggml-base.en.bin`. You can change this in `bin/whisperstt` if you download a different model to the `models/` directory.

## Troubleshooting

-   **Check Logs**: `tail -f ~/stt/tmp/stt.log`
-   **Verify ydotoold**: `systemctl --user status ydotoold.service`
-   **Verify xbindkeys**: `ps aux | grep xbindkeys`
-   **Microphone Issues**: Ensure your default microphone is selected and unmuted in system settings.

## Uninstallation

Run the uninstaller:
```bash
./uninstall.sh
```
