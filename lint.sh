#!/usr/bin/env bash
# Pomodoro Timer - checks run before a release (and by CI on every push):
# metadata.json and main.xml parse, and qmllint has no warnings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/com.pomodoro.minimal"

python3 -m json.tool "$SRC/metadata.json" > /dev/null
echo "metadata.json OK"
python3 -c "import sys, xml.dom.minidom; xml.dom.minidom.parse(sys.argv[1])" "$SRC/contents/config/main.xml"
echo "main.xml OK"

QMLLINT=""
for c in qmllint-qt6 qmllint6 qmllint /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint; do
    if command -v "$c" >/dev/null 2>&1; then
        QMLLINT="$c"
        break
    fi
done
if [ -z "$QMLLINT" ]; then
    echo "error: qmllint not found (install the Qt 6 declarative dev tools)" >&2
    exit 1
fi

# i18n() and friends are put into the QML context by Plasma at runtime, so
# qmllint always reports them as unqualified; every other warning fails.
status=0
out="$("$QMLLINT" "$SRC"/contents/ui/*.qml "$SRC"/contents/config/*.qml 2>&1)" || status=$?
python3 -c '
import re, sys

bad = 0
for line in sys.stdin.buffer.read().decode("utf-8", "replace").splitlines():
    if not line.startswith(("Warning:", "Error:")):
        continue
    m = re.match(r"\w+: (.+):(\d+):(\d+): ", line)
    if m:
        with open(m.group(1), encoding="utf-8") as f:
            src = f.read().splitlines()[int(m.group(2)) - 1]
        # qmllint columns count UTF-16 units, not characters
        rest = src.encode("utf-16-le")[2 * (int(m.group(3)) - 1):].decode("utf-16-le", "replace")
        if re.match(r"i18n[a-z]*\(", rest):
            continue
        print(line)
        print(src)
    else:
        print(line)
    bad = 1
sys.exit(bad)
' <<<"$out" || { echo "qmllint: warnings found" >&2; exit 1; }
if [ "$status" -ne 0 ]; then
    printf '%s\n' "$out" >&2
    echo "qmllint exited with status $status" >&2
    exit 1
fi
echo "qmllint OK"
