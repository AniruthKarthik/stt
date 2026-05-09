#!/bin/bash

# STT Project Installer - Fedora Copilot-key offline speech-to-text
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="$PROJECT_DIR/bin/whisperstt"
MODEL_DIR="$PROJECT_DIR/models"
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin"

echo "--- STT Project Installer ---"

# 1. Ensure directories exist
mkdir -p "$PROJECT_DIR/tmp"
mkdir -p "$PROJECT_DIR/bin"
mkdir -p "$PROJECT_DIR/models"

# 2. Check dependencies
commands=("arecord" "ydotool" "xbindkeys" "zsh" "make" "g++" "cmake" "notify-send")
for cmd in "${commands[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Warning: $cmd is not installed. Please install it using your package manager (dnf on Fedora)."
        # We don't exit here for notify-send as it's optional but recommended
        [[ "$cmd" == "notify-send" ]] || exit 1
    fi
done

# 3. Build whisper.cpp if not built
if [ ! -f "$PROJECT_DIR/whisper.cpp/build/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cd "$PROJECT_DIR/whisper.cpp"
    mkdir -p build
    cd build
    cmake ..
    make -j$(nproc) whisper-cli
    cd "$PROJECT_DIR"
fi

# 4. Download model if missing
if [ ! -f "$MODEL_DIR/ggml-base.en.bin" ]; then
    echo "Downloading whisper model (ggml-base.en.bin)..."
    curl -L "$MODEL_URL" -o "$MODEL_DIR/ggml-base.en.bin"
fi

# 5. Configure ydotoold user service
echo "Configuring ydotoold user service..."
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/ydotoold.service <<EOF
[Unit]
Description=ydotoold - backend for ydotool
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/ydotoold --socket-path %t/.ydotool_socket
Restart=always

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now ydotoold.service

# 6. Configure xbindkeys
XBINDKEYS_CONF="$HOME/.xbindkeysrc"
BINDING="\"$BIN_PATH\"\n    c:201"

if [ -f "$XBINDKEYS_CONF" ]; then
    if grep -q "whisperstt" "$XBINDKEYS_CONF"; then
        echo "xbindkeys already configured for whisperstt."
    else
        echo -e "\n$BINDING" >> "$XBINDKEYS_CONF"
        echo "Added binding to $XBINDKEYS_CONF"
    fi
else
    echo -e "$BINDING" > "$XBINDKEYS_CONF"
    echo "Created $XBINDKEYS_CONF with binding."
fi

# 7. Ensure permissions (inform user)
echo "--------------------------------------------------"
echo "Checking /dev/uinput permissions..."
if [ ! -w /dev/uinput ]; then
    echo "IMPORTANT: You need write access to /dev/uinput."
    echo "Please run the following commands manually if you haven't already:"
    echo "  sudo usermod -aG input \$USER"
    echo "  sudo sh -c 'chown root:input /dev/uinput && chmod 0660 /dev/uinput'"
    echo "Then log out and log back in."
fi

# 8. Restart xbindkeys
pkill xbindkeys || true
xbindkeys -f "$XBINDKEYS_CONF"

echo "--------------------------------------------------"
echo "Installation complete!"
echo "The Copilot key should now trigger the STT tool."
echo "Check logs at: $PROJECT_DIR/tmp/stt.log"
echo "--------------------------------------------------"
