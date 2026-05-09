#!/bin/bash

# STT Project Installer
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$PROJECT_DIR/bin/whisperstt"
DAEMON_PATH="$PROJECT_DIR/bin/stt-daemon"
MODEL_DIR="$PROJECT_DIR/models"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
WHISPER_REPO="https://github.com/ggerganov/whisper.cpp"

echo "--- STT Project Installer (Fresh Start) ---"

mkdir -p "$PROJECT_DIR/tmp"
mkdir -p "$PROJECT_DIR/bin"
mkdir -p "$PROJECT_DIR/models"

# Dependencies Check & Auto-install
commands=("arecord" "wl-copy" "evtest" "make" "g++" "cmake" "notify-send" "ydotool")
MISSING_DEPS=()
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Missing dependencies: ${MISSING_DEPS[*]}"
    if command -v dnf &> /dev/null; then
        echo "Detected Fedora. Attempting to install dependencies..."
        sudo dnf install -y alsa-utils wl-clipboard evtest make gcc-c++ cmake libnotify ydotool
    else
        echo "Please install the following packages: alsa-utils, wl-clipboard, evtest, cmake, gcc-c++, make, libnotify, ydotool"
        exit 1
    fi
fi

# Clone whisper.cpp if missing
if [ ! -d "$PROJECT_DIR/whisper.cpp" ]; then
    echo "Cloning whisper.cpp..."
    git clone "$WHISPER_REPO" "$PROJECT_DIR/whisper.cpp"
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
if ! groups | grep -q input; then
    echo "IMPORTANT: You need to be in the 'input' group to read the trigger key."
    echo "Attempting to add $USER to 'input' group..."
    sudo usermod -aG input "$USER"
    echo "Successfully added to group. You will need to log out and back in for this to take effect."
fi

# Ensure uinput permissions
if [ ! -w /dev/uinput ]; then
    echo "Setting up uinput permissions..."
    sudo sh -c 'chown root:input /dev/uinput && chmod 0660 /dev/uinput'
fi

# Configure ydotoold system service (as root for uinput access)
echo "Configuring ydotoold system service..."
# Find ydotoold path
YDOTOOLD_PATH=$(command -v ydotoold)
if [ -z "$YDOTOOLD_PATH" ]; then
    echo "Error: ydotoold not found. Please ensure ydotool is installed."
    exit 1
fi

sudo bash -c "cat > /etc/systemd/system/ydotoold.service <<EOF
[Unit]
Description=ydotoold - backend for ydotool
After=network.target

[Service]
Type=simple
ExecStart=$YDOTOOLD_PATH --socket-path /tmp/.ydotool_socket --socket-own $(id -u):$(id -g)
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
Description=STT Trigger Daemon (F8 Key)
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
echo "Press and HOLD F8 to speak, release to transcribe."
echo "Check logs at: $PROJECT_DIR/tmp/stt.log"
echo "--------------------------------------------------"
echo "NOTE: If this is your first time, please log out and back in to apply group changes."
