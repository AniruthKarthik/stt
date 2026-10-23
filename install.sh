#!/bin/bash

# STT Installer
# Universal Linux installer supporting Arch, Debian/Ubuntu, Fedora/RHEL, openSUSE, Alpine, Void, etc.
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
NPROC=$(nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)

echo "--- STT Universal Linux Installer ---"

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
    echo "Installing dependencies... This may require your sudo password."
    if command -v pacman &> /dev/null; then
        echo "Detected Arch-based system (pacman)."
        sudo pacman -S --needed --noconfirm alsa-utils wl-clipboard xclip evtest make gcc cmake libnotify ydotool git curl
    elif command -v apt-get &> /dev/null; then
        echo "Detected Debian/Ubuntu-based system (apt)."
        sudo apt-get update
        sudo apt-get install -y alsa-utils wl-clipboard xclip evtest make g++ cmake libnotify-bin ydotool git curl
    elif command -v dnf &> /dev/null; then
        echo "Detected Fedora/RHEL-based system (dnf)."
        sudo dnf install -y alsa-utils wl-clipboard xclip evtest make gcc-c++ cmake libnotify ydotool git curl
    elif command -v zypper &> /dev/null; then
        echo "Detected openSUSE-based system (zypper)."
        sudo zypper install -y alsa-utils wl-clipboard xclip evtest make gcc-c++ cmake libnotify-tools ydotool git curl
    elif command -v apk &> /dev/null; then
        echo "Detected Alpine Linux (apk)."
        sudo apk add alsa-utils wl-clipboard xclip evtest make g++ cmake libnotify ydotool git curl bash
    elif command -v xbps-install &> /dev/null; then
        echo "Detected Void Linux (xbps)."
        sudo xbps-install -Sy alsa-utils wl-clipboard xclip evtest make gcc cmake libnotify ydotool git curl
    elif command -v emerge &> /dev/null; then
        echo "Detected Gentoo Linux (emerge)."
        sudo emerge --ask=n media-sound/alsa-utils gui-apps/wl-clipboard x11-misc/xclip app-misc/evtest sys-devel/make dev-build/cmake x11-libs/libnotify app-misc/ydotool dev-vcs/git net-misc/curl
    elif command -v eopkg &> /dev/null; then
        echo "Detected Solus Linux (eopkg)."
        sudo eopkg install -y alsa-utils wl-clipboard xclip evtest make g++ cmake libnotify ydotool git curl
    else
        echo "Unknown distribution package manager."
        echo "Please ensure the following packages are installed manually:"
        echo "  alsa-utils, wl-clipboard (or xclip), evtest, make, g++/c++, cmake, libnotify, ydotool, git, curl"
        echo "Press Enter to continue once installed, or Ctrl+C to abort."
        read -r
    fi
}

check_dependencies() {
    local missing=false

    for cmd in arecord make cmake git curl ydotool; do
        if ! command -v "$cmd" &> /dev/null; then
            missing=true
            break
        fi
    done

    if ! command -v g++ &>/dev/null && ! command -v c++ &>/dev/null && ! command -v clang++ &>/dev/null; then
        missing=true
    fi

    if [ "$missing" = true ]; then
        echo "Missing required system dependencies. Triggering installation..."
        install_dependencies
    else
        echo "All core build and runtime tools detected."
    fi
}

check_dependencies

# --- Core Logic Setup ---

# Clone whisper.cpp if missing or empty
if [ ! -f "$PROJECT_DIR/whisper.cpp/CMakeLists.txt" ]; then
    echo "Cloning whisper.cpp repository..."
    rm -rf "$PROJECT_DIR/whisper.cpp"
    git clone --depth 1 "$WHISPER_REPO" "$PROJECT_DIR/whisper.cpp"
fi

# Build whisper.cpp
if [ ! -f "$PROJECT_DIR/whisper.cpp/build/bin/whisper-cli" ] && [ ! -f "$PROJECT_DIR/whisper.cpp/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cd "$PROJECT_DIR/whisper.cpp"
    mkdir -p build && cd build
    cmake .. -DWHISPER_BUILD_TESTS=OFF
    cmake --build . --config Release --target whisper-cli -j"$NPROC"
    cd "$PROJECT_DIR"
fi

# Download Model
if [ ! -f "$MODEL_DIR/ggml-base.en.bin" ]; then
    echo "Downloading whisper GGML model (base.en)..."
    curl -L "$MODEL_URL" -o "$MODEL_DIR/ggml-base.en.bin"
fi

# --- Permissions, Kernel Modules & Groups ---

# Determine the appropriate input group (input on Arch/Fedora, input/uinput on Debian/Ubuntu)
INPUT_GROUP="input"
if getent group input > /dev/null 2>&1; then
    INPUT_GROUP="input"
elif getent group uinput > /dev/null 2>&1; then
    INPUT_GROUP="uinput"
fi

# Add user to input groups if available
for grp in input uinput; do
    if getent group "$grp" > /dev/null 2>&1; then
        if ! id -nG "$USER" 2>/dev/null | grep -qw "$grp"; then
            echo "Adding $USER to '$grp' group..."
            sudo usermod -aG "$grp" "$USER" || true
        fi
    fi
done

# Ensure uinput kernel module is loaded if needed
if [ ! -c /dev/uinput ] && ! lsmod 2>/dev/null | grep -qw uinput; then
    echo "Loading uinput kernel module..."
    sudo modprobe uinput 2>/dev/null || true
    if [ -d /etc/modules-load.d ] && [ ! -f /etc/modules-load.d/uinput.conf ]; then
        echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf >/dev/null 2>&1 || true
    fi
fi

# Ensure /dev/uinput permissions
if [ ! -w /dev/uinput ]; then
    echo "Configuring uinput device permissions..."
    sudo bash -c "cat > /etc/udev/rules.d/80-stt-uinput.rules <<EOF
KERNEL==\"uinput\", GROUP=\"$INPUT_GROUP\", MODE=\"0660\", OPTIONS+=\"static_node=uinput\"
EOF"
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true
    sudo chmod 0660 /dev/uinput 2>/dev/null || true
    sudo chown root:"$INPUT_GROUP" /dev/uinput 2>/dev/null || true
fi

# --- Service & Daemon Configuration ---

# Configure ydotool service (systemd distros)
if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    if systemctl --user list-unit-files ydotool.service &>/dev/null; then
        echo "Enabling ydotool systemd user service..."
        if systemctl is-active --quiet ydotoold.service 2>/dev/null; then
            sudo systemctl stop ydotoold.service 2>/dev/null || true
            sudo systemctl disable ydotoold.service 2>/dev/null || true
        fi
        systemctl --user daemon-reload
        systemctl --user enable --now ydotool.service
    else
        echo "Configuring ydotoold system service..."
        YDOTOOLD_PATH=$(command -v ydotoold 2>/dev/null || echo "/usr/bin/ydotoold")
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

    # Install stt-daemon unit file for optional global background listening
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
else
    echo "Non-systemd or container environment detected. STT will auto-manage ydotoold on demand."
fi

echo "--------------------------------------------------"
echo "Installation complete!"
echo ""
echo "Command installed: ~/.local/bin/stt"
echo ""
echo "Recommended Usage (0 MB Idle RAM):"
echo "  Run 'stt' once to start recording."
echo "  Run 'stt' again to transcribe, inject text, and terminate."
echo ""
echo "Desktop Keybind Examples:"
echo "  Hyprland:  bind = , F8, exec, stt"
echo "  Sway/i3:   bindsym F8 exec stt"
echo "  GNOME/KDE: Map custom shortcut to: stt"
echo "--------------------------------------------------"
if ! id -nG 2>/dev/null | grep -qw "$INPUT_GROUP"; then
    echo "NOTE: If you were just added to group '$INPUT_GROUP', please log out"
    echo "and back in (or run 'newgrp $INPUT_GROUP') for permissions to apply."
fi
