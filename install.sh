#!/bin/bash
# ============================================================
# UTH SEB Linux - Installer (called by setup.sh)
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${CYAN}[...]${NC} $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ ! ]${NC} $*"; }

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"
LIB="$HOME/.local/lib"

# --- Build Docker image ---
if docker image inspect uth-seb:latest &>/dev/null 2>&1; then
    ok "Docker image: uth-seb:latest"
else
    info "Building Docker image..."
    docker build -t uth-seb:latest "$DIR/" 2>&1 | tail -3
    ok "Docker image built"
fi

# --- Init wine prefix ---
if [ -d "$HOME/.wine/drive_c/windows" ]; then
    ok "Wine prefix"
else
    info "Initializing wine prefix..."
    WINEARCH=win64 WINEPREFIX="$HOME/.wine" WINEDEBUG=-all wineboot --init 2>/dev/null || true
    ok "Wine prefix created"
fi

# --- Install SEB ---
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
if [ -f "$SEB_EXE" ]; then
    ok "SEB installed"
else
    info "Installing SEB..."
    INNO=$(find "$HOME/Downloads" -maxdepth 1 -name "uth.exe" -type f 2>/dev/null | head -1)
    if [ -z "$INNO" ]; then
        info "Downloading uth.exe..."
        INNO="/tmp/uth.exe"
        curl -sL "https://github.com/Hhanguu/studio-web/releases/download/v1.0/uth.exe" -o "$INNO"
        [ -s "$INNO" ] || { warn "Cannot download uth.exe"; INNO=""; }
    fi
    if [ -n "$INNO" ]; then
        WINEPREFIX="$HOME/.wine" wine "$INNO" /VERYSILENT /NORESTART 2>/dev/null || true
        ok "SEB installed"
    fi
fi

# --- Install WebView2 ---
WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
if [ -n "$WV2" ]; then
    ok "WebView2"
else
    info "Installing WebView2..."
    curl -sL "https://go.microsoft.com/fwlink/p/?LinkId=2124703" -o /tmp/wv2.exe
    WINEPREFIX="$HOME/.wine" wine /tmp/wv2.exe /silent 2>/dev/null &
    for i in $(seq 1 30); do
        sleep 1
        WV2=$(find "$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application" -name "msedgewebview2.exe" 2>/dev/null | head -1)
        [ -n "$WV2" ] && break
    done
    wait 2>/dev/null || true
    [ -n "$WV2" ] && ok "WebView2" || warn "WebView2 needs more time"
fi

# --- Install xdotool ---
if [ -f "$BIN/xdotool" ] && LD_LIBRARY_PATH="$LIB" "$BIN/xdotool" --version &>/dev/null 2>&1; then
    ok "xdotool"
else
    info "Installing xdotool..."
    mkdir -p "$BIN" "$LIB"
    TMP=$(mktemp -d)
    (cd "$TMP" && apt-get download xdotool libxdo3 2>/dev/null && for d in *.deb; do dpkg-deb -x "$d" "$TMP/e" 2>/dev/null; done)
    if [ -f "$TMP/e/usr/bin/xdotool" ]; then
        cp "$TMP/e/usr/bin/xdotool" "$BIN/xdotool"
        chmod +x "$BIN/xdotool"
        cp "$TMP/e/usr/lib/x86_64-linux-gnu/libxdo.so.3"* "$LIB/" 2>/dev/null || true
        ok "xdotool installed"
    else
        warn "xdotool failed"
    fi
    rm -rf "$TMP"
fi

# --- Copy scripts ---
mkdir -p "$HOME/.uth-seb"
for f in seb-lock.sh toggle_gemini.sh; do
    [ -f "$DIR/$f" ] && cp "$DIR/$f" "$HOME/.uth-seb/"
done
chmod +x "$HOME/.uth-seb/"*.sh 2>/dev/null || true
ok "Scripts"

# --- Create uth launcher ---
mkdir -p "$BIN"
cat > "$BIN/uth" << 'EOF'
#!/bin/bash
export LD_LIBRARY_PATH="$HOME/.local/lib:${LD_LIBRARY_PATH:-}"
exec bash "$HOME/.uth-seb/seb-lock.sh" "$@"
EOF
chmod +x "$BIN/uth"
ok "Launcher: uth"

# --- PATH ---
if ! echo "$PATH" | grep -q "$BIN"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$BIN:$PATH"
fi

# --- Desktop shortcut ---
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/uth-seb.desktop" << EOF
[Desktop Entry]
Name=UTH SEB Linux
Comment=Safe Exam Browser for Linux
Exec=$BIN/uth
Icon=applications-education
Terminal=true
Type=Application
Categories=Education;
EOF
ok "Desktop shortcut"

xhost +local:docker 2>/dev/null || true

echo ""
echo -e "${GREEN}Done! Run: uth${NC}"
echo ""
