#!/bin/bash

# STT Project Uninstaller
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XBINDKEYS_CONF="$HOME/.xbindkeysrc"

echo "--- STT Project Uninstaller ---"

# 1. Stop and disable ydotoold user service
echo "Disabling ydotoold user service..."
systemctl --user stop ydotoold.service || true
systemctl --user disable ydotoold.service || true
rm -f ~/.config/systemd/user/ydotoold.service
systemctl --user daemon-reload

# 2. Remove xbindkeys binding
if [ -f "$XBINDKEYS_CONF" ]; then
    echo "Removing binding from $XBINDKEYS_CONF..."
    # Remove the block matching whisperstt
    # This is a bit tricky with sed, we'll use a temporary file
    grep -v "whisperstt" "$XBINDKEYS_CONF" | grep -v "c:201" > "${XBINDKEYS_CONF}.tmp" || true
    mv "${XBINDKEYS_CONF}.tmp" "$XBINDKEYS_CONF"
fi

# 3. Stop xbindkeys
pkill xbindkeys || true
# Restart it if it was previously used for other things (optional, but safer to just leave it killed if we don't know)
# xbindkeys

# 4. Cleanup tmp files
rm -rf "$PROJECT_DIR/tmp"

echo "--------------------------------------------------"
echo "Uninstallation complete!"
echo "Note: whisper.cpp and the model file were not removed."
echo "You can manually delete $PROJECT_DIR if you want to remove everything."
echo "--------------------------------------------------"
