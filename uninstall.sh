#!/bin/bash

# STT Project Uninstaller
# This script removes services and configuration files created by install.sh

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- STT Project Uninstaller ---"

# 1. Stop and disable stt-daemon user service
if systemctl --user is-active --quiet stt-daemon.service 2>/dev/null || systemctl --user is-enabled --quiet stt-daemon.service 2>/dev/null; then
    echo "Stopping and disabling stt-daemon user service..."
    systemctl --user stop stt-daemon.service || true
    systemctl --user disable stt-daemon.service || true
    rm -f ~/.config/systemd/user/stt-daemon.service
    systemctl --user daemon-reload
fi

# 2. Stop and disable ydotoold system service
if systemctl is-active --quiet ydotoold.service 2>/dev/null || systemctl is-enabled --quiet ydotoold.service 2>/dev/null; then
    echo "Stopping and disabling ydotoold system service..."
    sudo systemctl stop ydotoold.service || true
    sudo systemctl disable ydotoold.service || true
    sudo rm -f /etc/systemd/system/ydotoold.service
    sudo systemctl daemon-reload
fi

# 3. Cleanup temporary files and logs
echo "Cleaning up temporary files and logs..."
rm -rf "$PROJECT_DIR/tmp"

# 4. Kill any stray processes associated with the project
echo "Killing any remaining STT processes..."
pkill -f "stt-daemon" || true
pkill -f "whisperstt" || true
# Note: we don't pkill evtest globally as it might be used elsewhere, 
# but stopping the service should have handled its children.

# 5. Optional: Clean up cloned whisper.cpp and models
# We keep these by default to avoid accidental deletion of large downloads,
# but we inform the user how to remove them.

echo "--------------------------------------------------"
echo "Uninstallation complete!"
echo ""
echo "Note:"
echo "- The 'input' group membership was NOT removed for your user."
echo "- whisper.cpp source and model files were NOT removed."
echo ""
echo "To completely remove the project, you can now delete the directory:"
echo "  rm -rf $PROJECT_DIR"
echo "--------------------------------------------------"
