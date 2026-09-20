#!/bin/bash
# ============================================================
# UTH SEB Linux - Full Installer
# Check environment, install everything, create launcher
# ============================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[...]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
DOTFILES="$HOME/.local/share/applications"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "========================================"
echo "  UTH SEB Linux - Full Installer"
echo "========================================"
echo ""

# --- Check Docker ---
command -v docker &>/dev/null || fail "Chua cai Docker! Chay: curl -fsSL https://get.docker.com | sh"
docker info &>/dev/null 2>&1 || fail "Docker daemon chua chay! Chay: sudo systemctl start docker"
ok "Docker $(docker --version | grep -oP '\d+\.\d+\.\d+')"

# --- Check DISPLAY ---
if [ -z "${DISPLAY:-}" ]; then
    if [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=":0"
    else
        fail "Khong co display (GUI)."
    fi
fi
ok "Display: $DISPLAY"

# --- Create wine prefix ---
if [ -d "$HOME/.wine" ]; then
    ok "Wine prefix"
else
    info "Tao wine prefix..."
    WINEARCH=win64 WINEPREFIX="$HOME/.wine" wineboot --init 2>/dev/null || true
    ok "Wine prefix created"
fi

# --- Install SEB ---
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
if [ -f "$SEB_EXE" ]; then
    ok "SEB: UTHSEB.exe"
else
    info "Installing SEB..."
    INNO_EXE=$(find "$HOME/Downloads" "$HOME" -maxdepth 2 -name "uth.exe" -type f 2>/dev/null | head -1)
    if [ -z "$INNO_EXE" ]; then
        info "Downloading uth.exe from GitHub..."
        INNO_EXE="/tmp/uth.exe"
        curl -sL "https://github.com/Hhanguu/studio-web/releases/download/v1.0/uth.exe" -o "$INNO_EXE"
        [ -s "$INNO_EXE" ] || fail "Cannot download uth.exe"
    fi
    WINEPREFIX="$HOME/.wine" wine "$INNO_EXE" /VERYSILENT /NORESTART 2>/dev/null || true
    [ -f "$SEB_EXE" ] && ok "SEB installed" || warn "SEB install may have failed"
fi

# --- Install WebView2 ---
WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
if [ -n "$WV2" ]; then
    ok "WebView2"
else
    info "Installing WebView2..."
    curl -sL "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o /tmp/wv2_setup.exe
    WINEPREFIX="$HOME/.wine" wine /tmp/wv2_setup.exe /silent 2>/dev/null &
    sleep 8
    WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
    [ -n "$WV2" ] && ok "WebView2" || warn "WebView2 install may need more time"
fi

# --- Build Docker image ---
if docker image inspect uth-seb:latest &>/dev/null 2>&1; then
    ok "Docker image: uth-seb:latest"
else
    info "Building Docker image..."
    docker build -t uth-seb:latest "$SCRIPT_DIR/" 2>&1 | tail -3
    ok "Docker image built"
fi

# --- Install xdotool ---
if [ -f "$LOCAL_BIN/xdotool" ] && LD_LIBRARY_PATH="$LOCAL_LIB" "$LOCAL_BIN/xdotool" --version &>/dev/null 2>&1; then
    ok "xdotool"
else
    info "Installing xdotool..."
    mkdir -p "$LOCAL_BIN" "$LOCAL_LIB"
    TMPDIR=$(mktemp -d)
    (cd "$TMPDIR" && apt-get download xdotool libxdo3 2>/dev/null && for deb in *.deb; do dpkg-deb -x "$deb" "$TMPDIR/extracted" 2>/dev/null; done)
    if [ -f "$TMPDIR/extracted/usr/bin/xdotool" ]; then
        cp "$TMPDIR/extracted/usr/bin/xdotool" "$LOCAL_BIN/xdotool"
        chmod +x "$LOCAL_BIN/xdotool"
        cp "$TMPDIR/extracted/usr/lib/x86_64-linux-gnu/libxdo.so.3"* "$LOCAL_LIB/" 2>/dev/null || true
        ok "xdotool installed"
    else
        warn "xdotool install failed (lock mode may not work)"
    fi
    rm -rf "$TMPDIR"
fi

# --- Create launcher ---
mkdir -p "$LOCAL_BIN"
cat > "$LOCAL_BIN/uth" << LAUNCHER
#!/bin/bash
exec bash "$SCRIPT_DIR/seb-lock.sh" "\$@"
LAUNCHER
chmod +x "$LOCAL_BIN/uth"
ok "Launcher: uth"

# --- Ensure PATH ---
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
    export PATH="$LOCAL_BIN:$PATH"
    warn "Added ~/.local/bin to PATH (restart terminal)"
fi

# --- Desktop shortcut ---
mkdir -p "$DOTFILES"
cat > "$DOTFILES/uth-seb.desktop" << DESKTOP
[Desktop Entry]
Name=UTH SEB Linux
Comment=Safe Exam Browser for Linux
Exec=$LOCAL_BIN/uth
Icon=applications-education
Terminal=true
Type=Application
Categories=Education;
DESKTOP
chmod +x "$DOTFILES/uth-seb.desktop"
ok "Desktop shortcut: ~/.local/share/applications/uth-seb.desktop"

# --- xhost for Docker X11 ---
xhost +local:docker 2>/dev/null || true

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Install complete! Chay SEB ngay...${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# --- Run SEB ---
exec bash "$SCRIPT_DIR/seb-lock.sh" "${1:-}"
