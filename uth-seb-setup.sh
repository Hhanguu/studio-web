#!/bin/bash
# ============================================================
# UTH SEB Linux - One-Click Setup
# Self-contained: installs Docker, wine, SEB, WebView2, xdotool
# Just run: bash uth-seb-setup.sh
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[...]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[ ! ]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

INSTALL_DIR="$HOME/.uth-seb"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
GITHUB="https://github.com/Hhanguu/studio-web"

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  UTH SEB Linux - One-Click Setup${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

# ============================================================
# 1. CHECK & INSTALL DOCKER
# ============================================================
if command -v docker &>/dev/null; then
    ok "Docker: $(docker --version | grep -oP '\d+\.\d+\.\d+')"
else
    info "Installing Docker..."
    curl -fsSL https://get.docker.com | sh 2>&1 | tail -3
    ok "Docker installed"
fi

if ! docker info &>/dev/null 2>&1; then
    info "Starting Docker daemon..."
    sudo systemctl start docker 2>/dev/null || sudo service docker start 2>/dev/null || true
    sleep 2
    docker info &>/dev/null 2>&1 || fail "Cannot start Docker. Run: sudo systemctl start docker"
fi
ok "Docker running"

# ============================================================
# 2. CHECK DISPLAY
# ============================================================
if [ -z "${DISPLAY:-}" ]; then
    [ -S "/tmp/.X11-unix/X0" ] && export DISPLAY=":0" || fail "No display."
fi
ok "Display: $DISPLAY"

# ============================================================
# 3. CREATE DIRECTORIES
# ============================================================
mkdir -p "$INSTALL_DIR" "$LOCAL_BIN" "$LOCAL_LIB" "$HOME/.cache/uth-seb"
ok "Directories"

# ============================================================
# 4. CREATE DOCKERFILE
# ============================================================
info "Writing Dockerfile..."
cat > "$INSTALL_DIR/Dockerfile" << 'DOCKERFILE'
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
DOCKERFILE

cat > "$INSTALL_DIR/launch.sh" << 'LAUNCHER'
#!/bin/bash
export HOME=/home/user
export FONTCONFIG_PATH=/tmp
mkdir -p "$HOME/.cache" 2>/dev/null
chmod -R u+rwX "$HOME/.wine" 2>/dev/null
wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" 2>&1
LAUNCHER
chmod +x "$INSTALL_DIR/launch.sh"
ok "Dockerfile ready"

# ============================================================
# 5. BUILD DOCKER IMAGE
# ============================================================
if docker image inspect uth-seb:latest &>/dev/null 2>&1; then
    ok "Docker image: uth-seb:latest"
else
    info "Building Docker image uth-seb:latest (may take 5-10 min)..."
    docker build -t uth-seb:latest "$INSTALL_DIR/" 2>&1 | tail -5
    ok "Docker image built"
fi

# ============================================================
# 6. INIT WINE PREFIX
# ============================================================
if [ -d "$HOME/.wine/drive_c/windows" ]; then
    ok "Wine prefix"
else
    info "Initializing wine prefix..."
    WINEARCH=win64 WINEPREFIX="$HOME/.wine" WINEDEBUG=-all wineboot --init 2>/dev/null || true
    ok "Wine prefix initialized"
fi

# ============================================================
# 7. INSTALL SEB INTO WINE
# ============================================================
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
if [ -f "$SEB_EXE" ]; then
    ok "SEB installed"
else
    info "Installing SEB..."
    # Try local uth.exe first
    INNO_EXE=$(find "$HOME/Downloads" -maxdepth 1 -name "uth.exe" -type f 2>/dev/null | head -1)
    if [ -z "$INNO_EXE" ]; then
        info "Downloading uth.exe from GitHub..."
        INNO_EXE="/tmp/uth.exe"
        curl -sL "$GITHUB/releases/download/v1.0/uth.exe" -o "$INNO_EXE"
        [ -s "$INNO_EXE" ] || fail "Cannot download uth.exe"
    fi
    WINEPREFIX="$HOME/.wine" wine "$INNO_EXE" /VERYSILENT /NORESTART 2>/dev/null || true
    [ -f "$SEB_EXE" ] && ok "SEB installed" || warn "SEB install may need more time"
fi

# ============================================================
# 8. INSTALL WEBVIEW2 INTO WINE
# ============================================================
WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
if [ -n "$WV2" ]; then
    ok "WebView2"
else
    info "Downloading WebView2..."
    curl -sL "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o /tmp/wv2_setup.exe
    info "Installing WebView2..."
    WINEPREFIX="$HOME/.wine" wine /tmp/wv2_setup.exe /silent 2>/dev/null &
    WV2_PID=$!
    # Wait up to 60s
    for i in $(seq 1 60); do
        sleep 1
        WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
        [ -n "$WV2" ] && break
    done
    wait $WV2_PID 2>/dev/null || true
    [ -n "$WV2" ] && ok "WebView2" || warn "WebView2 install may need more time"
fi

# ============================================================
# 9. INSTALL XDOTOOL
# ============================================================
if [ -f "$LOCAL_BIN/xdotool" ] && LD_LIBRARY_PATH="$LOCAL_LIB" "$LOCAL_BIN/xdotool" --version &>/dev/null 2>&1; then
    ok "xdotool"
else
    info "Installing xdotool..."
    TMPDIR=$(mktemp -d)
    (cd "$TMPDIR" && apt-get download xdotool libxdo3 2>/dev/null && for deb in *.deb; do dpkg-deb -x "$deb" "$TMPDIR/extracted" 2>/dev/null; done)
    if [ -f "$TMPDIR/extracted/usr/bin/xdotool" ]; then
        cp "$TMPDIR/extracted/usr/bin/xdotool" "$LOCAL_BIN/xdotool"
        chmod +x "$LOCAL_BIN/xdotool"
        cp "$TMPDIR/extracted/usr/lib/x86_64-linux-gnu/libxdo.so.3"* "$LOCAL_LIB/" 2>/dev/null || true
        ok "xdotool installed"
    else
        warn "xdotool install failed"
    fi
    rm -rf "$TMPDIR"
fi

# ============================================================
# 10. CREATE SEB-LOCK.SH
# ============================================================
cat > "$INSTALL_DIR/seb-lock.sh" << 'SEBLOCK'
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
[ -z "$SEB_FILE" ] && SEB_FILE=$(ls -t ~/Downloads/*.seb 2>/dev/null | head -1)

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
SEB_VOLUME=""
[ -n "$SEB_FILE" ] && SEB_VOLUME="-v $SEB_FILE:/home/user/input.seb:ro"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$HOME/.wine:/home/user/.wine" \
  -v "$HOME/.cache/uth-seb:/home/user/.cache" \
  $SEB_VOLUME \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -e DISPLAY="$DISPLAY" \
  -e HOME="/home/user" \
  uth-seb:latest bash -c "
    export HOME=/home/user
    export FONTCONFIG_PATH=/tmp
    chmod -R u+rwX /home/user/.wine 2>/dev/null || true
    mkdir -p /home/user/.cache 2>/dev/null || true
    wine '/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe' /home/user/input.seb 2>/dev/null
  " 2>&1 | grep -vE "fixme:|fontconfig|Fontconfig"

for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null || true
done
SEBLOCK
chmod +x "$INSTALL_DIR/seb-lock.sh"
ok "seb-lock.sh"

# ============================================================
# 11. CREATE TOGGLE_GEMINI.SH
# ============================================================
cat > "$INSTALL_DIR/toggle_gemini.sh" << 'GEMINI'
#!/bin/bash
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
GEMINI
chmod +x "$INSTALL_DIR/toggle_gemini.sh"
ok "toggle_gemini.sh"

# ============================================================
# 12. CREATE UTH LAUNCHER
# ============================================================
mkdir -p "$LOCAL_BIN"
cat > "$LOCAL_BIN/uth" << 'UTH'
#!/bin/bash
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
exec bash "$HOME/.uth-seb/seb-lock.sh" "$@"
UTH
chmod +x "$LOCAL_BIN/uth"
ok "Launcher: ~/.local/bin/uth"

# ============================================================
# 13. PATH + DESKTOP
# ============================================================
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$LOCAL_BIN:$PATH"
    warn "Added ~/.local/bin to PATH (restart terminal)"
fi

mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/uth-seb.desktop" << DESKTOP
[Desktop Entry]
Name=UTH SEB Linux
Comment=Safe Exam Browser for Linux
Exec=$LOCAL_BIN/uth
Icon=applications-education
Terminal=true
Type=Application
Categories=Education;
DESKTOP
ok "Desktop shortcut"

xhost +local:docker 2>/dev/null || true

# ============================================================
# DONE
# ============================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "  Chay:  ${BOLD}uth${NC}"
echo -e "  Hoac:  ${BOLD}uth ~/Downloads/exam.seb${NC}"
echo ""
