#!/bin/bash
# ============================================================
# UTH SEB Linux - Offline Setup
# Extract wine prefix + SEB + WebView2, create launcher
# Run this after downloading from Google Drive
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

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_LIB="$HOME/.local/lib"
DOTFILES="$HOME/.local/share/applications"

echo ""
echo "========================================"
echo "  UTH SEB Linux - Offline Setup"
echo "========================================"
echo ""

# --- Check Docker ---
command -v docker &>/dev/null || fail "Chua cai Docker! Chay: curl -fsSL https://get.docker.com | sh"
docker info &>/dev/null 2>&1 || fail "Docker daemon chua chay! Chay: sudo systemctl start docker"
ok "Docker"

# --- Check DISPLAY ---
if [ -z "${DISPLAY:-}" ]; then
    [ -S "/tmp/.X11-unix/X0" ] && export DISPLAY=":0" || fail "Khong co display."
fi
ok "Display: $DISPLAY"

# --- Extract wine prefix ---
WINE_ARCHIVE="$SCRIPT_DIR/uth-seb-wine.tar.gz"
if [ -f "$WINE_ARCHIVE" ]; then
    info "Extracting wine prefix + SEB + WebView2 (may take a while)..."
    tar -xzf "$WINE_ARCHIVE" -C "$HOME/" 2>/dev/null
    ok "Wine prefix extracted"
else
    fail "Cannot find uth-seb-wine.tar.gz in $SCRIPT_DIR"
fi

# --- Fix wine permissions ---
chmod -R u+rwX "$HOME/.wine" 2>/dev/null || true
ok "Wine permissions fixed"

# --- Check SEB ---
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
[ -f "$SEB_EXE" ] && ok "SEB: UTHSEB.exe" || fail "SEB not found after extract"

# --- Check WebView2 ---
WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
[ -n "$WV2" ] && ok "WebView2" || warn "WebView2 not found"

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
        warn "xdotool install failed"
    fi
    rm -rf "$TMPDIR"
fi

# --- Create launcher ---
mkdir -p "$LOCAL_BIN"
cat > "$LOCAL_BIN/uth" << 'LAUNCHER'
#!/bin/bash
exec bash "$HOME/.uth-seb/seb-lock.sh" "$@"
LAUNCHER
chmod +x "$LOCAL_BIN/uth"
ok "Launcher: uth"

# --- Copy scripts to ~/.uth-seb ---
mkdir -p "$HOME/.uth-seb"
for f in seb-lock.sh toggle_gemini.sh install.sh; do
    [ -f "$SCRIPT_DIR/$f" ] && cp "$SCRIPT_DIR/$f" "$HOME/.uth-seb/"
done
chmod +x "$HOME/.uth-seb/"*.sh 2>/dev/null
ok "Scripts copied"

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
ok "Desktop shortcut"

# --- xhost ---
xhost +local:docker 2>/dev/null || true

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Setup complete! Chay SEB ngay...${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""

# --- Run SEB ---
exec bash "$HOME/.uth-seb/seb-lock.sh" "${1:-}"
