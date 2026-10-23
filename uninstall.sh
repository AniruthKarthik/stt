#!/bin/bash

# STT Universal Uninstaller
# Removes services, rules, and configuration created by install.sh

set -e

# Ensure we are not running as root, but can use sudo
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run this script as root/sudo directly. It will ask for sudo when needed."
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- STT Uninstaller ---"

# 1. Stop and disable systemd user services if systemd is present
if command -v systemctl &>/dev/null; then
    if systemctl --user is-active --quiet stt-daemon.service 2>/dev/null || systemctl --user is-enabled --quiet stt-daemon.service 2>/dev/null; then
        echo "Stopping and disabling stt-daemon user service..."
        systemctl --user stop stt-daemon.service 2>/dev/null || true
        systemctl --user disable stt-daemon.service 2>/dev/null || true
        rm -f ~/.config/systemd/user/stt-daemon.service
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    if systemctl --user is-active --quiet ydotool.service 2>/dev/null; then
        echo "Stopping ydotool user service..."
        systemctl --user stop ydotool.service 2>/dev/null || true
        systemctl --user disable ydotool.service 2>/dev/null || true
    fi

    if systemctl is-active --quiet ydotoold.service 2>/dev/null || systemctl is-enabled --quiet ydotoold.service 2>/dev/null; then
        echo "Stopping and disabling ydotoold system service..."
        sudo systemctl stop ydotoold.service 2>/dev/null || true
        sudo systemctl disable ydotoold.service 2>/dev/null || true
        sudo rm -f /etc/systemd/system/ydotoold.service
        sudo systemctl daemon-reload 2>/dev/null || true
    fi
fi

# 2. Remove binary symlinks
rm -f ~/.local/bin/stt "$PROJECT_DIR/bin/stt"

# 3. Remove udev rules and modules load configs
if [ -f /etc/udev/rules.d/80-stt-uinput.rules ]; then
    echo "Removing udev rules..."
    sudo rm -f /etc/udev/rules.d/80-stt-uinput.rules
    sudo udevadm control --reload-rules 2>/dev/null || true
    sudo udevadm trigger 2>/dev/null || true
fi
if [ -f /etc/modules-load.d/uinput.conf ]; then
    sudo rm -f /etc/modules-load.d/uinput.conf
fi

# 4. Cleanup temporary files and sockets
rm -rf "$PROJECT_DIR/tmp"
sudo rm -f /tmp/.ydotool_socket "${XDG_RUNTIME_DIR:-/tmp}/.ydotool_socket" 2>/dev/null || true

# 5. Kill any stray processes
echo "Killing any remaining STT processes..."
pkill -f "stt-daemon" || true
pkill -f "whisperstt" || true

echo "--------------------------------------------------"
echo "Uninstallation complete!"
echo ""
echo "Note:"
echo "- Group memberships ('input' / 'uinput') were retained."
echo "- whisper.cpp source and models were retained."
echo ""
echo "To completely remove the directory, run:"
echo "  rm -rf $PROJECT_DIR"
echo "--------------------------------------------------"
