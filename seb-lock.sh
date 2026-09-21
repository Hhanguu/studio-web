#!/bin/bash
set -e

SEB_FILE=""
if [ -n "${1:-}" ]; then
    if [ -f "$1" ]; then
        SEB_FILE="$(realpath "$1")"
    elif [ -f ~/Downloads/"$1" ]; then
        SEB_FILE="$(realpath ~/Downloads/"$1")"
    fi
fi

if [ -z "$SEB_FILE" ]; then
    SEB_FILE=$(ls -t ~/Downloads/*.seb 2>/dev/null | head -1)
fi

echo "=== UTH SEB - Full Lock Mode ==="
[ -n "$SEB_FILE" ] && echo "File: $SEB_FILE" || echo "Direct launch"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Khoa phim va taskbar..."

ORIG_PANEL_POS=$(xfconf-query -c xfce4-panel -p "/panels/panel-1/position" 2>/dev/null || true)
ORIG_ALT_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" 2>/dev/null || true)
ORIG_ALT_SHIFT_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" 2>/dev/null || true)
ORIG_SUPER_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" 2>/dev/null || true)
ORIG_CTRL_ALT_G=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" 2>/dev/null || true)

[ -f "$SCRIPT_DIR/toggle_gemini.sh" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -n -t string -s "$SCRIPT_DIR/toggle_gemini.sh" 2>/dev/null || true

xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Escape>" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Escape>" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Super_L" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>e" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>p" -n -t string -s "true" 2>/dev/null || true
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" -n -t string -s "true" 2>/dev/null || true

xmodmap -e "keycode 133 = NoSymbol" 2>/dev/null || true
xmodmap -e "keycode 134 = NoSymbol" 2>/dev/null || true

xfconf-query -c xfce4-panel -p "/panels/panel-1/position" -s "p=-1000;x=0;y=0" 2>/dev/null || true

echo "Da khoa!"

restore_all() {
    echo ""
    echo "Khoi phuc..."
    [ -n "$ORIG_ALT_TAB" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -s "$ORIG_ALT_TAB" 2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -r 2>/dev/null || true
    [ -n "$ORIG_ALT_SHIFT_TAB" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" -s "$ORIG_ALT_SHIFT_TAB" 2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" -r 2>/dev/null || true
    [ -n "$ORIG_SUPER_TAB" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" -s "$ORIG_SUPER_TAB" 2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" -r 2>/dev/null || true
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Escape>" -r 2>/dev/null || true
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Escape>" -r 2>/dev/null || true
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>" -r 2>/dev/null || true
    [ -n "$ORIG_CTRL_ALT_G" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -s "$ORIG_CTRL_ALT_G" 2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -r 2>/dev/null || true
    [ -n "$ORIG_PANEL_POS" ] && xfconf-query -c xfce4-panel -p "/panels/panel-1/position" -s "$ORIG_PANEL_POS" 2>/dev/null || true
    xmodmap -e "keycode 133 = Super_L" 2>/dev/null || true
    xmodmap -e "keycode 134 = Super_R" 2>/dev/null || true
    echo "Da khoi phuc."
}
trap restore_all EXIT

SAVED_OUTPUTS=()
while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $2}')
    if ! echo "$line" | grep -q '\*'; then
        SAVED_OUTPUTS+=("$output")
        xrandr --output "$output" --off 2>/dev/null || true
    fi
done < <(xrandr --listmonitors 2>/dev/null | grep -v "^Monitors:")

echo "Chay SEB..."
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
export WINEARCH=win64 WINEDEBUG=-all

if [ -n "$SEB_FILE" ]; then
    wine "$SEB_EXE" "$SEB_FILE" 2>/dev/null
else
    wine "$SEB_EXE" 2>/dev/null
fi

for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null || true
done
