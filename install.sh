#!/usr/bin/env bash
# Pomodoro Timer - Plasma 6 plasmoid installer
#   ./install.sh              install, or upgrade if already installed
#   ./install.sh --uninstall  remove the widget and its fallback icon
set -euo pipefail

WIDGET_ID="com.pomodoro.minimal"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/$WIDGET_ID"

# Fallback icon for places that only look up the system icon theme
# (e.g. the Configure dialog's About page): the widget browser itself
# uses the icon bundled at contents/icons/pomodoro.svg instead.
ICON_SRC="$SRC/contents/icons/pomodoro.svg"
ICON_DEST_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"
ICON_DEST="$ICON_DEST_DIR/$WIDGET_ID.svg"

# Whole-line match on the saved listing. Piping the listing into grep -q
# can fail under pipefail once it gets long, and a regex match would also
# hit longer ids. "--show <id>" is no use here: run from this directory
# it finds the source folder of the same name.
is_installed() {
    local list
    list="$(kpackagetool6 --type Plasma/Applet --list 2>/dev/null)" || return 1
    grep -Fxq "$WIDGET_ID" <<<"$list"
}

case "${1:-}" in
    "")
        ;;
    --uninstall)
        if is_installed; then
            echo "==> Removing $WIDGET_ID ..."
            # From / so the id is never taken for the source folder.
            (cd / && kpackagetool6 --type Plasma/Applet --remove "$WIDGET_ID")
        else
            echo "==> $WIDGET_ID is not installed."
        fi
        if [ -f "$ICON_DEST" ]; then
            echo "==> Removing fallback icon ..."
            rm -f "$ICON_DEST"
            kbuildsycoca6 >/dev/null 2>&1 || true
        fi
        exit 0
        ;;
    *)
        echo "usage: $0 [--uninstall]" >&2
        exit 1
        ;;
esac

if [ ! -d "$SRC" ]; then
    echo "error: widget source not found at $SRC" >&2
    exit 1
fi

if is_installed; then
    echo "==> Upgrading $WIDGET_ID ..."
    kpackagetool6 --type Plasma/Applet --upgrade "$SRC"
else
    echo "==> Installing $WIDGET_ID ..."
    kpackagetool6 --type Plasma/Applet --install "$SRC"
fi

if [ -f "$ICON_SRC" ]; then
    echo "==> Installing fallback icon ..."
    mkdir -p "$ICON_DEST_DIR"
    cp "$ICON_SRC" "$ICON_DEST"
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo ""
echo "Done! Add it to your top bar:"
echo "  Right-click the top panel -> Edit Panel -> Add Widgets -> search 'Pomodoro Timer'"
echo ""
echo "Use: left-click toggles start/pause, middle-click resets."
echo "Durations default to 50/10/20; change them with right-click widget -> Configure."
echo "Remove it again with: ./install.sh --uninstall"
