#!/bin/bash
# UTH SEB Linux - Full Lock Mode
# Khoa Alt+Tab, taskbar, workspace switch khi chay SEB

set -e

SEB_FILE=""
if [ -n "$1" ]; then
    if [ -f "$1" ]; then
        SEB_FILE="$(realpath "$1")"
    elif [ -f ~/Downloads/"$1" ]; then
        SEB_FILE="$(realpath ~/Downloads/"$1")"
    fi
fi

if [ -z "$SEB_FILE" ]; then
    SEB_FILE=$(ls -t ~/Downloads/*.seb 2>/dev/null | head -1)
fi

if [ -z "$SEB_FILE" ]; then
    echo "Khong tim thay file .seb"
    exit 1
fi

echo "=== UTH SEB - Full Lock Mode ==="
echo "File: $SEB_FILE"

# === LOCK ===
echo "Khoa phim va taskbar..."

# Save originals
ORIG_PANEL_POS=$(xfconf-query -c xfce4-panel -p "/panels/panel-1/position" 2>/dev/null)
ORIG_KEY133=$(xmodmap -pke | grep "keycode 133 ")
ORIG_KEY134=$(xmodmap -pke | grep "keycode 134 ")
ORIG_ALT_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" 2>/dev/null)
ORIG_ALT_SHIFT_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" 2>/dev/null)
ORIG_SUPER_TAB=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" 2>/dev/null)
ORIG_CTRL_ALT_G=$(xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" 2>/dev/null)

# Bind Ctrl+Alt+G -> toggle Gemini popup
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -n -t string -s "$SCRIPT_DIR/toggle_gemini.sh" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g/startup-notify" -n -t bool -s false 2>/dev/null

# Lock Alt+Tab, Super+Tab, Ctrl+Esc, etc.
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Escape>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Escape>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Left>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Right>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Up>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Down>" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/Super_L" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>e" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>p" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>r" -n -t string -s "true" 2>/dev/null
xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Alt><Super>s" -n -t string -s "true" 2>/dev/null

# X11 level: remove Super key from keymap
ORIG_KEY133=$(xmodmap -pke | grep "keycode 133")
ORIG_KEY134=$(xmodmap -pke | grep "keycode 134")
xmodmap -e "keycode 133 = NoSymbol" 2>/dev/null
xmodmap -e "keycode 134 = NoSymbol" 2>/dev/null

# Hide panel (taskbar)
xfconf-query -c xfce4-panel -p "/panels/panel-1/position" -s "p=-1000;x=0;y=0" 2>/dev/null

echo "Da khoa!"

# === RESTORE ===
restore_all() {
    echo ""
    echo "Khoi phuc..."
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt>Tab" -s "$ORIG_ALT_TAB" 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Shift>Tab" -s "$ORIG_ALT_SHIFT_TAB" 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>Tab" -s "$ORIG_SUPER_TAB" 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Escape>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Alt><Escape>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Left>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Right>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Up>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Control><Alt><Down>" -r 2>/dev/null
    xfconf-query -c xfce4-keyboard-shortcuts -p "/xfwm4/custom/<Super>" -r 2>/dev/null
    # Restore Ctrl+Alt+G
    [ -n "$ORIG_CTRL_ALT_G" ] && xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -s "$ORIG_CTRL_ALT_G" 2>/dev/null || xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Control><Alt>g" -r 2>/dev/null
    # Restore panel
    xfconf-query -c xfce4-panel -p "/panels/panel-1/position" -s "$ORIG_PANEL_POS" 2>/dev/null
    # Restore Super key at X11 level
    [ -n "$ORIG_KEY133" ] && xmodmap -e "$ORIG_KEY133" 2>/dev/null
    [ -n "$ORIG_KEY134" ] && xmodmap -e "$ORIG_KEY134" 2>/dev/null
    echo "Da khoi phuc."
}
trap restore_all EXIT

# === DISABLE MONITORS ===
SAVED_OUTPUTS=()
while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $2}')
    if ! echo "$line" | grep -q '\*'; then
        SAVED_OUTPUTS+=("$output")
        xrandr --output "$output" --off 2>/dev/null
    fi
done < <(xrandr --listmonitors | grep -v "^Monitors:")

# === RUN SEB ===
echo "Chay SEB..."
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$HOME/.wine:/home/user/.wine" \
  -v "$HOME/.cache/uth-seb:/home/user/.cache" \
  -v "$SEB_FILE:/home/user/input.seb:ro" \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -e DISPLAY="$DISPLAY" \
  -e HOME="/home/user" \
  uth-seb:latest bash -c '
    export HOME=/home/user
    export FONTCONFIG_PATH=/tmp
    export DISPLAY='"$DISPLAY"'
    chmod -R u+rwX /home/user/.wine 2>/dev/null || true
    mkdir -p /home/user/.cache 2>/dev/null || true
    wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" /home/user/input.seb 2>/dev/null
  ' 2>&1 | grep -vE "fixme:|fontconfig|Fontconfig"

# === RESTORE MONITORS ===
for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null
done
