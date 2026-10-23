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
mkdir -p "$HOME/.local/bin"

# Make binaries executable and set up stt command
chmod +x "$PROJECT_DIR/bin/stt-daemon" "$PROJECT_DIR/bin/whisperstt" 2>/dev/null || true
ln -sf whisperstt "$PROJECT_DIR/bin/stt"
ln -sf "$PROJECT_DIR/bin/stt" "$HOME/.local/bin/stt"

# --- Distribution Detection & Dependency Installation ---
install_dependencies() {
    echo "Installing dependencies... This may require your password."
    if command -v pacman &> /dev/null; then
        echo "Detected Arch-based system (pacman)."
        sudo pacman -S --needed --noconfirm alsa-utils wl-clipboard evtest make gcc cmake libnotify ydotool git curl
    elif command -v dnf &> /dev/null; then
        echo "Detected Fedora/RHEL-based system (dnf)."
        sudo dnf install -y alsa-utils wl-clipboard evtest make gcc-c++ cmake libnotify ydotool git curl
    elif command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu-based system (apt)."
        sudo apt-get update
        sudo apt-get install -y alsa-utils wl-clipboard evtest make g++ cmake libnotify-bin ydotool git curl
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
commands=("arecord" "wl-copy" "evtest" "make" "cmake" "notify-send" "ydotool" "git" "curl")
MISSING=false
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING=true
        break
    fi
done

if ! command -v g++ &> /dev/null && ! command -v c++ &> /dev/null; then
    MISSING=true
fi

if [ "$MISSING" = true ]; then
    echo "Missing dependencies. Attempting to install..."
    install_dependencies
fi

# --- Core Logic Setup ---

# Clone whisper.cpp if missing or empty
if [ ! -f "$PROJECT_DIR/whisper.cpp/CMakeLists.txt" ]; then
    echo "Cloning whisper.cpp..."
    rm -rf "$PROJECT_DIR/whisper.cpp"
    git clone --depth 1 "$WHISPER_REPO" "$PROJECT_DIR/whisper.cpp"
fi

# Build whisper.cpp
if [ ! -f "$PROJECT_DIR/whisper.cpp/build/bin/whisper-cli" ] && [ ! -f "$PROJECT_DIR/whisper.cpp/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cd "$PROJECT_DIR/whisper.cpp"
    mkdir -p build && cd build
    cmake .. -DWHISPER_BUILD_TESTS=OFF
    cmake --build . --config Release --target whisper-cli -j$(nproc)
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
    echo "Warning: '$INPUT_GROUP' group not found. Proceeding with caution."
fi

# Check if user is in group in /etc/group
if ! id -nG "$USER" 2>/dev/null | grep -qw "$INPUT_GROUP"; then
    echo "Adding $USER to the '$INPUT_GROUP' group..."
    sudo usermod -aG "$INPUT_GROUP" "$USER"
    echo "Successfully added to group. NOTE: You MUST log out and back in for this to take effect."
fi

# Ensure uinput permissions (required for ydotool)
if [ ! -w /dev/uinput ]; then
    echo "Setting up uinput device permissions..."
    # Create a udev rule for persistence across reboots
    sudo bash -c "cat > /etc/udev/rules.d/80-stt-uinput.rules <<EOF
KERNEL==\"uinput\", GROUP=\"$INPUT_GROUP\", MODE=\"0660\", OPTIONS+=\"static_node=uinput\"
EOF"
    sudo udevadm control --reload-rules && sudo udevadm trigger || true
    # Immediate fix for current session
    sudo chmod 0660 /dev/uinput || true
    sudo chown root:"$INPUT_GROUP" /dev/uinput || true
fi

# --- Service Configuration ---

# Configure ydotool service
# On Arch Linux and systemd systems where ydotool user service exists, use it.
# Otherwise, fall back to a system-wide service.
if systemctl --user list-unit-files ydotool.service &>/dev/null; then
    echo "Enabling ydotool user service..."
    # Stop any conflicting system ydotoold service
    if systemctl is-active --quiet ydotoold.service 2>/dev/null; then
        sudo systemctl stop ydotoold.service 2>/dev/null || true
        sudo systemctl disable ydotoold.service 2>/dev/null || true
    fi
    systemctl --user daemon-reload
    systemctl --user enable --now ydotool.service
else
    echo "Configuring ydotoold system service..."
    YDOTOOLD_PATH=$(command -v ydotoold)
    if [ -z "$YDOTOOLD_PATH" ]; then
        echo "Error: ydotoold not found. Please ensure ydotool is installed."
        exit 1
    fi

    sudo systemctl stop ydotool.service ydotoold.service 2>/dev/null || true
    sudo rm -f /tmp/.ydotool_socket

    sudo bash -c "cat > /etc/systemd/system/ydotoold.service <<EOF
[Unit]
Description=ydotoold - backend for ydotool
After=network.target

[Service]
Type=simple
ExecStartPre=-/usr/bin/rm -f /tmp/.ydotool_socket
ExecStart=$YDOTOOLD_PATH --socket-path /tmp/.ydotool_socket --socket-own $(id -u):$(id -g) --socket-perm 0666
Restart=always

[Install]
WantedBy=multi-user.target
EOF"

    sudo systemctl daemon-reload
    sudo systemctl enable --now ydotoold.service
fi

# Install stt-daemon user service definition
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
Environment="PATH=$PATH"

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload

echo "--------------------------------------------------"
echo "Installation complete!"
echo ""
echo "The 'stt' command is now installed at: ~/.local/bin/stt"
echo ""
echo "On-Demand Usage (Zero RAM when idle):"
echo "  Run 'stt' once to start recording, run 'stt' again to stop and transcribe."
echo "  Once the job is done, it terminates and frees all memory."
echo ""
echo "Desktop Keybind (e.g. Hyprland):"
echo "  Toggle: bind = , F8, exec, stt"
echo "  Hold:   bind = , F8, exec, stt start"
echo "          bindr = , F8, exec, stt stop"
echo ""
echo "Optional persistent background daemon:"
echo "  systemctl --user enable --now stt-daemon.service"
echo "--------------------------------------------------"
if ! id -nG 2>/dev/null | grep -qw "$INPUT_GROUP"; then
    echo "IMPORTANT: Your current session does not yet have '$INPUT_GROUP' active."
    echo "Please log out and log back in (or run 'newgrp $INPUT_GROUP') for permissions to apply."
fi
