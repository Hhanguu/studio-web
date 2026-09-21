#!/bin/bash
# UTH SEB Linux - Install on new machine (Ubuntu/Debian)
set -euo pipefail

echo "=== UTH SEB Linux - Install ==="

# 1. Install wine
if ! command -v wine &>/dev/null; then
    echo "[...] Installing wine..."
    sudo dpkg --add-architecture i386
    sudo mkdir -pm755 /etc/apt/keyrings
    sudo wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key 2>/dev/null
    sudo wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/$(lsb_release -cs)/winehq-$(lsb_release -cs).sources 2>/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq --install-recommends winehq-staging 2>/dev/null || \
    sudo apt-get install -y -qq wine wine64 2>/dev/null
    echo "[OK] Wine: $(wine --version)"
else
    echo "[OK] Wine: $(wine --version)"
fi

# 2. Init wine prefix
if [ ! -d "$HOME/.wine/drive_c/windows" ]; then
    echo "[...] Initializing wine prefix..."
    WINEARCH=win64 WINEDEBUG=-all wineboot --init 2>/dev/null || true
fi

# 3. Install SEB
SEB_EXE="$HOME/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe"
if [ ! -f "$SEB_EXE" ]; then
    echo "[...] Downloading UTH SEB..."
    INNO="/tmp/uth.exe"
    curl -L --retry 3 -o "$INNO" \
        "https://github.com/Hhanguu/studio-web/releases/download/v1.0/uth.exe" 2>&1
    if [ -s "$INNO" ]; then
        echo "[...] Installing SEB (may take a minute)..."
        WINEDEBUG=-all wine "$INNO" /VERYSILENT /NORESTART 2>/dev/null || true
        rm -f "$INNO"
    else
        echo "[WARN] SEB download failed"
        rm -f "$INNO"
    fi
fi
[ -f "$SEB_EXE" ] && echo "[OK] SEB" || echo "[WARN] SEB install failed"

# 4. Install WebView2
WV2="$HOME/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView"
if [ ! -d "$WV2" ]; then
    echo "[...] Downloading WebView2..."
    WV2_SETUP="/tmp/wv2_setup.exe"
    curl -L --retry 3 -o "$WV2_SETUP" \
        "https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/1c9db68b-8343-4d70-85c2-d3e3735cdf15/MicrosoftEdgeWebview2Setup.exe" 2>&1
    if [ -s "$WV2_SETUP" ]; then
        echo "[...] Installing WebView2..."
        WINEDEBUG=-all wine "$WV2_SETUP" /silent 2>/dev/null || true
        rm -f "$WV2_SETUP"
    else
        echo "[WARN] WebView2 download failed"
        rm -f "$WV2_SETUP"
    fi
fi
[ -d "$WV2" ] && echo "[OK] WebView2" || echo "[WARN] WebView2 install failed"

# 5. Install xfce4-panel (for keyboard locking)
if ! command -v xfconf-query &>/dev/null; then
    echo "[...] Installing xfce4..."
    sudo apt-get install -y -qq xfce4 xfce4-panel 2>/dev/null
fi

# 6. Copy scripts
mkdir -p "$HOME/.uth-seb"
SCRIPT_DIR="$HOME/.uth-seb"
curl -sL "https://raw.githubusercontent.com/Hhanguu/studio-web/main/seb-lock.sh" -o "$SCRIPT_DIR/seb-lock.sh"
curl -sL "https://raw.githubusercontent.com/Hhanguu/studio-web/main/toggle_gemini.sh" -o "$SCRIPT_DIR/toggle_gemini.sh"
chmod +x "$SCRIPT_DIR"/*.sh

# 7. Create launcher
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/uth" << 'UTH'
#!/bin/bash
exec bash "$HOME/.uth-seb/seb-lock.sh" "$@"
UTH
chmod +x "$HOME/.local/bin/uth"

# 8. PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

echo ""
echo "=== Done! Run: uth ==="
echo ""
