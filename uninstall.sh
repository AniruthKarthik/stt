#!/bin/bash

# STT Uninstaller
# This script removes services and configuration files created by install.sh

set -e

# Ensure we are not running as root, but can use sudo
if [ "$EUID" -eq 0 ]; then
  echo "Please do not run this script as root/sudo directly. It will ask for sudo when needed."
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- STT Uninstaller ---"

# 1. Stop and disable stt-daemon user service
if systemctl --user is-active --quiet stt-daemon.service 2>/dev/null || systemctl --user is-enabled --quiet stt-daemon.service 2>/dev/null; then
    echo "Stopping and disabling stt-daemon user service..."
    systemctl --user stop stt-daemon.service || true
    systemctl --user disable stt-daemon.service || true
    rm -f ~/.config/systemd/user/stt-daemon.service
    systemctl --user daemon-reload
fi

# 2. Stop and disable ydotool user service if running
if systemctl --user is-active --quiet ydotool.service 2>/dev/null; then
    echo "Stopping ydotool user service..."
    systemctl --user stop ydotool.service || true
    systemctl --user disable ydotool.service || true
fi

# 3. Stop and disable ydotoold system service if installed
if systemctl is-active --quiet ydotoold.service 2>/dev/null || systemctl is-enabled --quiet ydotoold.service 2>/dev/null; then
    echo "Stopping and disabling ydotoold system service..."
    sudo systemctl stop ydotoold.service || true
    sudo systemctl disable ydotoold.service || true
    sudo rm -f /etc/systemd/system/ydotoold.service
    sudo systemctl daemon-reload
fi

# 4. Remove udev rules
if [ -f /etc/udev/rules.d/80-stt-uinput.rules ]; then
    echo "Removing udev rules..."
    sudo rm -f /etc/udev/rules.d/80-stt-uinput.rules
    sudo udevadm control --reload-rules && sudo udevadm trigger || true
fi

# 5. Cleanup temporary files and sockets
rm -rf "$PROJECT_DIR/tmp"
sudo rm -f /tmp/.ydotool_socket 2>/dev/null || true

# 6. Kill any stray processes
echo "Killing any remaining STT processes..."
pkill -f "stt-daemon" || true
pkill -f "whisperstt" || true

echo "--------------------------------------------------"
echo "Uninstallation complete!"
echo ""
echo "Note:"
echo "- The 'input' group membership was NOT removed for your user."
echo "- whisper.cpp source and model files were NOT removed."
echo ""
echo "To completely remove STT, you can now delete the directory:"
echo "  rm -rf $PROJECT_DIR"
echo "--------------------------------------------------"
