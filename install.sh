#!/bin/bash

# STT Project Installer
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$PROJECT_DIR/bin/whisperstt"
DAEMON_PATH="$PROJECT_DIR/bin/stt-daemon"
MODEL_DIR="$PROJECT_DIR/models"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"

echo "--- STT Project Installer (Fresh Start) ---"

mkdir -p "$PROJECT_DIR/tmp"
mkdir -p "$PROJECT_DIR/bin"
mkdir -p "$PROJECT_DIR/models"

# Dependencies Check
commands=("arecord" "wl-copy" "evtest" "make" "g++" "cmake" "notify-send")
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Warning: $cmd is not installed."
        [[ "$cmd" == "notify-send" ]] || exit 1
    fi
done

if ! command -v wtype &> /dev/null; then
    echo "=========================================================="
    echo "wtype is NOT installed. Auto-pasting will fallback to clipboard only."
    echo "To enable direct typing, install wtype: sudo dnf install wtype"
    echo "=========================================================="
fi

# Build whisper.cpp
if [ ! -f "$PROJECT_DIR/whisper.cpp/build/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cd "$PROJECT_DIR/whisper.cpp"
    mkdir -p build && cd build && cmake .. && make -j$(nproc) whisper-cli
    cd "$PROJECT_DIR"
fi

# Download Model
if [ ! -f "$MODEL_DIR/ggml-base.en.bin" ]; then
    echo "Downloading whisper model..."
    curl -L "$MODEL_URL" -o "$MODEL_DIR/ggml-base.en.bin"
fi

# Permissions Check
if [ ! -w /dev/uinput ]; then
    # We do not strictly need uinput if we use wtype instead of ydotool, 
    # but we DO need input group access for evtest.
    if ! groups | grep -q input; then
        echo "IMPORTANT: You need to be in the 'input' group to read the Copilot key."
        echo "Run: sudo usermod -aG input \$USER"
        echo "Then log out and log back in."
    fi
fi

# Configure ydotoold system service (as root for uinput access)
echo "Configuring ydotoold system service..."
sudo bash -c "cat > /etc/systemd/system/ydotoold.service <<EOF
[Unit]
Description=ydotoold - backend for ydotool
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path /tmp/.ydotool_socket --socket-own 1000:1000
ExecStartPost=/usr/bin/chmod 666 /tmp/.ydotool_socket
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

sudo systemctl daemon-reload
sudo systemctl enable --now ydotoold.service

# Set up autostart stt-daemon (user service)
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/stt-daemon.service <<EOF
[Unit]
Description=STT Trigger Daemon (Copilot Key)
After=graphical-session.target

[Service]
Type=simple
ExecStart=$DAEMON_PATH
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now stt-daemon.service

echo "--------------------------------------------------"
echo "Installation complete!"
echo "The STT Daemon is running in the background."
echo "Press and HOLD the Copilot key to speak, release to transcribe."
echo "Check logs at: $PROJECT_DIR/tmp/stt.log"
echo "--------------------------------------------------"
