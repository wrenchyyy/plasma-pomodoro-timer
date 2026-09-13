#!/usr/bin/env bash
# Pomodoro Timer - Plasma 6 plasmoid installer
set -euo pipefail

WIDGET_ID="com.pomodoro.minimal"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/$WIDGET_ID"

if [ ! -d "$SRC" ]; then
    echo "error: widget source not found at $SRC" >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$WIDGET_ID"; then
    echo "==> Upgrading $WIDGET_ID ..."
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC"
else
    echo "==> Installing $WIDGET_ID ..."
    kpackagetool6 --type Plasma/Applet --install "$SRC"
fi

# Fallback icon for places that only look up the system icon theme
# (e.g. the Configure dialog's About page): the widget browser itself
# uses the icon bundled at contents/icons/pomodoro.svg instead.
ICON_SRC="$SRC/contents/icons/pomodoro.svg"
ICON_DEST_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"
if [ -f "$ICON_SRC" ]; then
    echo "==> Installing fallback icon ..."
    mkdir -p "$ICON_DEST_DIR"
    cp "$ICON_SRC" "$ICON_DEST_DIR/$WIDGET_ID.svg"
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo ""
echo "Done! Add it to your top bar:"
echo "  Right-click the top panel -> Edit Panel -> Add Widgets -> search 'Pomodoro Timer'"
echo ""
echo "Use: left-click toggles start/pause, middle-click resets."
echo "Config (50/10/20 defaults): right-click widget -> Configure."
