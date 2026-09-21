#!/bin/bash
# ============================================================
# UTH SEB Linux - Offline Setup
# No Docker. Wine + SEB + WebView2.
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

# --- Check wine ---
command -v wine &>/dev/null || fail "Chua cai wine! Chay: sudo apt install wine64"
ok "Wine: $(wine --version 2>/dev/null || echo 'installed')"

# --- Check display ---
if [ -z "${DISPLAY:-}" ]; then
    [ -S "/tmp/.X11-unix/X0" ] && export DISPLAY=":0" || fail "Khong co display."
fi
ok "Display: $DISPLAY"

# --- Init wine prefix (creates windows/, fonts, etc.) ---
if [ -d "$HOME/.wine/drive_c/windows" ]; then
    ok "Wine prefix already exists"
else
    info "Initializing wine prefix..."
    WINEARCH=win64 WINEPREFIX="$HOME/.wine" WINEDEBUG=-all wineboot --init 2>/dev/null || true
    ok "Wine prefix initialized"
fi

# --- Extract SEB + WebView2 on top of wine prefix ---
WINE_ARCHIVE="$SCRIPT_DIR/uth-seb-wine.tar.gz"
if [ -f "$WINE_ARCHIVE" ]; then
    info "Extracting SEB + WebView2 into wine prefix..."
    tar -xzf "$WINE_ARCHIVE" -C "$HOME/"
    ok "SEB + WebView2 extracted"
else
    fail "Cannot find uth-seb-wine.tar.gz"
fi

# --- Fix permissions ---
chmod -R u+rwX "$HOME/.wine" 2>/dev/null || true
ok "Wine permissions"

# --- Check SEB ---
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
[ -f "$SEB_EXE" ] && ok "SEB: UTHSEB.exe" || fail "SEB not found"

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

# --- Copy scripts ---
mkdir -p "$HOME/.uth-seb"
for f in seb-lock.sh toggle_gemini.sh; do
    [ -f "$SCRIPT_DIR/$f" ] && cp "$SCRIPT_DIR/$f" "$HOME/.uth-seb/"
done
chmod +x "$HOME/.uth-seb/"*.sh 2>/dev/null || true
ok "Scripts copied"

# --- Create uth launcher ---
mkdir -p "$LOCAL_BIN"
cat > "$LOCAL_BIN/uth" << 'LAUNCHER'
#!/bin/bash
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
exec bash "$HOME/.uth-seb/seb-lock.sh" "$@"
LAUNCHER
chmod +x "$LOCAL_BIN/uth"
ok "Launcher: ~/.local/bin/uth"

# --- PATH ---
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
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

echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}  Done! Chay: uth${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
