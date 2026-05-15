#!/bin/bash

# STT Installer
# A distribution-agnostic installer for STT.
set -e

# Ensure we are not running as root, but can use sudo
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run this script as root/sudo directly. It will ask for sudo when needed."
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$PROJECT_DIR/bin/whisperstt"
DAEMON_PATH="$PROJECT_DIR/bin/stt-daemon"
MODEL_DIR="$PROJECT_DIR/models"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"
WHISPER_REPO="https://github.com/ggerganov/whisper.cpp"

echo "--- STT Installer (Linux Universal) ---"

mkdir -p "$PROJECT_DIR/tmp"
mkdir -p "$PROJECT_DIR/bin"
mkdir -p "$PROJECT_DIR/models"

# --- Distribution Detection & Dependency Installation ---
install_dependencies() {
    echo "Installing dependencies... This may require your password."
    if command -v dnf &> /dev/null; then
        echo "Detected Fedora/RHEL-based system (dnf)."
        sudo dnf install -y alsa-utils wl-clipboard evtest make gcc-c++ cmake libnotify ydotool git curl
    elif command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu-based system (apt)."
        sudo apt-get update
        sudo apt-get install -y alsa-utils wl-clipboard evtest make g++ cmake libnotify-bin ydotool git curl
    elif command -v pacman &> /dev/null; then
        echo "Detected Arch-based system (pacman)."
        sudo pacman -S --needed --noconfirm alsa-utils wl-clipboard evtest make gcc cmake libnotify ydotool git curl
    elif command -v zypper &> /dev/null; then
        echo "Detected openSUSE-based system (zypper)."
        sudo zypper install -y alsa-utils wl-clipboard evtest make gcc-c++ cmake libnotify ydotool git curl
    else
        echo "Unknown distribution. Please ensure you have the following installed:"
        echo "alsa-utils, wl-clipboard, evtest, make, g++, cmake, libnotify, ydotool, git, curl"
        echo "Press Enter to continue if you have installed these manually, or Ctrl+C to abort."
        read -r
    fi
}

# Check for missing commands and trigger installation if needed
commands=("arecord" "wl-copy" "evtest" "make" "g++" "cmake" "notify-send" "ydotool" "git" "curl")
MISSING=false
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        # Check for g++ specifically as it might be named gcc-c++
        if [[ "$cmd" == "g++" ]] && command -v g++ &> /dev/null; then continue; fi
        MISSING=true
        break
    fi
done

if [ "$MISSING" = true ]; then
    echo "Missing dependencies. Attempting to install..."
    install_dependencies
fi

# --- Core Logic Setup ---

# Clone whisper.cpp if missing
if [ ! -d "$PROJECT_DIR/whisper.cpp" ]; then
    echo "Cloning whisper.cpp..."
    git clone "$WHISPER_REPO" "$PROJECT_DIR/whisper.cpp"
fi

# Build whisper.cpp
if [ ! -f "$PROJECT_DIR/whisper.cpp/build/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cd "$PROJECT_DIR/whisper.cpp"
    mkdir -p build && cd build
    cmake .. -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF
    make -j$(nproc) whisper-cli
    cd "$PROJECT_DIR"
fi

# Download Model
if [ ! -f "$MODEL_DIR/ggml-base.en.bin" ]; then
    echo "Downloading whisper model..."
    curl -L "$MODEL_URL" -o "$MODEL_DIR/ggml-base.en.bin"
fi

# --- Permissions & Groups ---

# Handle the 'input' group (common for evdev access)
INPUT_GROUP="input"
if ! getent group "$INPUT_GROUP" > /dev/null; then
    # Some distros might use a different group, but 'input' is the standard kernel convention
    echo "Warning: '$INPUT_GROUP' group not found. Proceeding with caution."
fi

if ! groups | grep -q "$INPUT_GROUP"; then
    echo "Adding $USER to the '$INPUT_GROUP' group..."
    sudo usermod -aG "$INPUT_GROUP" "$USER"
    echo "Successfully added to group. NOTE: You MUST log out and back in for this to take effect."
fi

# Ensure uinput permissions (required for ydotool)
if [ ! -w /dev/uinput ]; then
    echo "Setting up uinput device permissions..."
    # Create a udev rule for persistence across reboots
    sudo bash -c "cat > /etc/udev/rules.d/80-stt-uinput.rules <<EOF
KERNEL==\"uinput\", GROUP=\"$INPUT_GROUP\", MODE=\"0660\"
EOF"
    sudo udevadm control --reload-rules && sudo udevadm trigger
    # Immediate fix for current session
    sudo chmod 0660 /dev/uinput
    sudo chown root:"$INPUT_GROUP" /dev/uinput
fi

# --- Service Configuration ---

# Configure ydotoold system service
echo "Configuring ydotoold system service..."
YDOTOOLD_PATH=$(command -v ydotoold)
if [ -z "$YDOTOOLD_PATH" ]; then
    echo "Error: ydotoold not found. Please ensure ydotool is installed."
    exit 1
fi

# Stop any existing ydotool services to avoid conflicts
sudo systemctl stop ydotool.service ydotoold.service 2>/dev/null || true
sudo rm -f /tmp/.ydotool_socket

sudo bash -c "cat > /etc/systemd/system/ydotoold.service <<EOF
[Unit]
Description=ydotoold - backend for ydotool
After=network.target

[Service]
Type=simple
ExecStart=$YDOTOOLD_PATH --socket-path /tmp/.ydotool_socket --socket-own $(id -u):$(id -g)
# Wait for the socket to be created before changing permissions
ExecStartPost=/usr/bin/bash -c 'while [ ! -S /tmp/.ydotool_socket ]; do sleep 0.1; done; chmod 666 /tmp/.ydotool_socket'
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
echo "IMPORTANT: If you were just added to the 'input' group, please log out and log back in."
