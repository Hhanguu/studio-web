#!/bin/bash
# ============================================================
# UTH SEB Linux - Self-Extracting Installer & Launcher
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

INSTALL_DIR="$HOME/.uth-seb"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
DOTFILES="$HOME/.local/share/applications"

# ============================================================
# INSTALL
# ============================================================
do_install() {
    info "Starting installation..."

    # --- Check Docker ---
    command -v docker &>/dev/null || fail "Docker not found. Install Docker first."
    docker info &>/dev/null 2>&1 || fail "Docker daemon not running. Start Docker first."
    ok "Docker found and running."

    # --- Check DISPLAY ---
    if [ -z "${DISPLAY:-}" ]; then
        if [ -S "/tmp/.X11-unix/X0" ]; then
            export DISPLAY=":0"
            warn "Auto-detected DISPLAY=$DISPLAY"
        else
            fail "No display detected. Set DISPLAY or run in a graphical session."
        fi
    fi
    ok "Display: $DISPLAY"

    # --- Check wine prefix ---
    if [ -d "$HOME/.wine" ]; then
        ok "Wine prefix: ~/.wine exists"
    else
        info "Tao wine prefix..."
        WINEARCH=win64 WINEPREFIX="$HOME/.wine" wineboot --init 2>/dev/null || true
        ok "Wine prefix created."
    fi

    # --- Check SEB installed in wine ---
    SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
    if [ -f "$SEB_EXE" ]; then
        ok "SEB installed: UTHSEB.exe found"
    else
        info "Installing SEB into wine prefix..."
        INNO_EXE=$(find "$HOME/Downloads" "$HOME" -maxdepth 2 -name "uth.exe" -type f 2>/dev/null | head -1)
        if [ -n "$INNO_EXE" ]; then
            WINEPREFIX="$HOME/.wine" wine "$INNO_EXE" /VERYSILENT /NORESTART 2>/dev/null || true
            ok "SEB installed from $INNO_EXE"
        else
            warn "uth.exe not found in ~/Downloads. Download from UTH and run again."
        fi
    fi

    # --- Check WebView2 runtime in wine ---
    WV2_EXE=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
    if [ -n "$WV2_EXE" ]; then
        ok "WebView2 runtime: found"
    else
        info "WebView2 not found. SEB may not render pages correctly."
        warn "Install WebView2 from: https://developer.microsoft.com/en-us/microsoft-edge/webview2/"
    fi

    # --- Check Docker image ---
    if docker image inspect uth-seb:latest &>/dev/null 2>&1; then
        ok "Docker image: uth-seb:latest"
    else
        info "Building Docker image..."
    fi

    # --- Check xhost for X11 forwarding ---
    if xhost +local:docker &>/dev/null 2>&1; then
        ok "X11 forwarding: xhost configured"
    else
        warn "Run: xhost +local:docker (if SEB can't display)"
    fi

    # --- Check ffmpeg (optional, for screen recording in SEB) ---
    if command -v ffmpeg &>/dev/null; then
        ok "ffmpeg: found"
    else
        warn "ffmpeg not found (optional, needed for SEB screen recording)"
    fi

    # --- Create directories ---
    mkdir -p "$INSTALL_DIR" "$LOCAL_BIN" "$LOCAL_LIB" "$DOTFILES"
    ok "Directories created."

    # --- Extract embedded files ---
    local script_file
    script_file="$(realpath "$0")"

    for name in Dockerfile launch.sh seb-lock.sh toggle_gemini.sh; do
        info "Extracting $name..."
        sed -n "/^#===BEGIN ${name}===$/,/^#===END ${name}===$/p" "$script_file" | sed '1d;$d' > "$INSTALL_DIR/$name"
        ok "$name extracted."
    done
    chmod +x "$INSTALL_DIR/launch.sh" "$INSTALL_DIR/seb-lock.sh" "$INSTALL_DIR/toggle_gemini.sh"

    # --- Build Docker image ---
    info "Building Docker image uth-seb:latest (may take a while)..."
    docker build -t uth-seb:latest "$INSTALL_DIR/" 2>&1
    ok "Docker image built."

    # --- Install xdotool (no sudo) ---
    info "Installing xdotool (user-level)..."
    if [ -f "$LOCAL_BIN/xdotool" ] && LD_LIBRARY_PATH="$LOCAL_LIB" "$LOCAL_BIN/xdotool" --version &>/dev/null; then
        ok "xdotool already installed."
    else
        local tmpdir
        tmpdir=$(mktemp -d)
        (
            cd "$tmpdir"
            apt-get download xdotool libxdo3 2>/dev/null || true
            for deb in *.deb; do
                [ -f "$deb" ] && dpkg-deb -x "$deb" "$tmpdir/extracted" 2>/dev/null
            done
        )
        if [ -f "$tmpdir/extracted/usr/bin/xdotool" ]; then
            cp "$tmpdir/extracted/usr/bin/xdotool" "$LOCAL_BIN/xdotool"
            chmod +x "$LOCAL_BIN/xdotool"
            cp "$tmpdir/extracted/usr/lib/x86_64-linux-gnu/libxdo.so.3"* "$LOCAL_LIB/" 2>/dev/null || true
            ok "xdotool installed."
        else
            warn "Could not download xdotool. Lock mode may not work."
        fi
        rm -rf "$tmpdir"
    fi

    # --- Create uth launcher ---
    info "Creating launcher 'uth'..."
    cat > "$LOCAL_BIN/uth" << 'UTHEOF'
#!/bin/bash
set -euo pipefail
INSTALL_DIR="$HOME/.uth-seb"
LOCAL_LIB="$HOME/.local/lib"
SEB_LOCK="$INSTALL_DIR/seb-lock.sh"

export LD_LIBRARY_PATH="$LOCAL_LIB:${LD_LIBRARY_PATH:-}"

SEB_FILE=""
if [ -n "${1:-}" ]; then
    if [ -f "$1" ]; then
        SEB_FILE="$(realpath "$1")"
    elif [ -f "$HOME/Downloads/$1" ]; then
        SEB_FILE="$(realpath "$HOME/Downloads/$1")"
    fi
fi

if [ -z "$SEB_FILE" ]; then
    SEB_FILE=$(ls -t "$HOME"/Downloads/*.seb 2>/dev/null | head -1)
fi

if [ -z "$SEB_FILE" ]; then
    echo "No .seb file found. Usage: uth [file.seb]"
    exit 1
fi

exec bash "$SEB_LOCK" "$SEB_FILE"
UTHEOF
    chmod +x "$LOCAL_BIN/uth"
    ok "Launcher created at $LOCAL_BIN/uth."

    # --- Ensure ~/.local/bin is in PATH ---
    if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
        export PATH="$LOCAL_BIN:$PATH"
        warn "Added $LOCAL_BIN to PATH for this session."
        warn "Add to ~/.bashrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    # --- Desktop shortcut ---
    info "Creating desktop shortcut..."
    cat > "$DOTFILES/uth-seb.desktop" << DEOF
[Desktop Entry]
Name=UTH SEB Linux
Comment=University of Transport HCMC - Safe Exam Browser
Exec=$LOCAL_BIN/uth
Icon=applications-education
Terminal=true
Type=Application
Categories=Education;
DEOF
    chmod +x "$DOTFILES/uth-seb.desktop"
    ok "Desktop shortcut created."

    echo ""
    echo -e "${GREEN}============================================================${NC}"
    echo -e "${GREEN}  Installation complete!${NC}"
    echo -e "${GREEN}============================================================${NC}"
    echo ""
    echo "  Usage:  uth [file.seb]"
    echo "          uth ~/Downloads/exam.seb"
    echo "          (auto-finds latest .seb in ~/Downloads/)"
    echo ""
    echo "  Desktop shortcut: ~/.local/share/applications/uth-seb.desktop"
    echo ""
    echo "  Launching SEB now..."
    echo ""
    exec bash "$LOCAL_BIN/uth" "${1:-}"
}

# ============================================================
# RUN SEB
# ============================================================
do_run() {
    exec "$LOCAL_BIN/uth" "${1:-}"
}

# ============================================================
# MAIN
# ============================================================
needs_install() {
    [ ! -f "$LOCAL_BIN/uth" ] || ! docker image inspect uth-seb:latest &>/dev/null 2>&1
}

if needs_install; then
    do_install
else
    do_run "${1:-}"
fi

#===BEGIN Dockerfile===
FROM tobix/wine:staging

RUN apt-get update -qq && apt-get install -y -qq \
    xvfb wget cabextract procps \
    libegl-dev libgl1-mesa-dri libgbm1 libdrm2 \
    libxcomposite1 libxdamage1 libxrandr2 \
    libasound2t64 libpulse0 libpango-1.0-0 libcairo2 libatspi2.0-0t64 \
    libfontconfig1 libfreetype6 libx11-xcb1 libxcb1 libxfixes3 \
    libxkbcommon0 libxkbfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    -O /usr/local/bin/winetricks && chmod +x /usr/local/bin/winetricks

COPY launch.sh /launch.sh
RUN chmod +x /launch.sh

ENTRYPOINT ["/launch.sh"]
#===END Dockerfile===

#===BEGIN launch.sh===
#!/bin/bash
export HOME=/home/user
export FONTCONFIG_PATH=/tmp

mkdir -p "$HOME/.cache" 2>/dev/null
chmod -R u+rwX "$HOME/.wine" 2>/dev/null

wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" 2>&1
#===END launch.sh===

#===BEGIN seb-lock.sh===
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
#===END seb-lock.sh===

#===BEGIN toggle_gemini.sh===
#!/bin/bash
export LD_LIBRARY_PATH="$HOME/.local/lib:$LD_LIBRARY_PATH"
XDOTOOL="$HOME/.local/bin/xdotool"
URL="https://gemini.google.com"
PID_FILE="/tmp/gemini_popup.pid"

if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    rm -f "$PID_FILE"
    echo "[CLOSE]"
else
    rm -f "$PID_FILE"
    firefox --new-window "$URL" --width 400 --height 600 &>/dev/null &
    echo $! > "$PID_FILE"
    echo "[OPEN]"
fi
#===END toggle_gemini.sh===
