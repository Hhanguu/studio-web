#!/bin/bash
# ============================================================
# UTH SEB Linux - Setup
# curl -sL <url> | bash
# ============================================================
set -euo pipefail

GITHUB="https://github.com/Hhanguu/studio-web"
DIR="$HOME/.uth-seb"

echo ""
echo "========================================"
echo "  UTH SEB Linux Setup"
echo "========================================"
echo ""

# Docker
command -v docker &>/dev/null || { echo "[...] Installing Docker..."; curl -fsSL https://get.docker.com | sh; }
docker info &>/dev/null 2>&1 || sudo systemctl start docker 2>/dev/null || true
echo "[OK] Docker"

# Display
if [ -z "${DISPLAY:-}" ]; then
    [ -S "/tmp/.X11-unix/X0" ] && export DISPLAY=":0" || { echo "No display"; exit 1; }
fi
echo "[OK] Display: $DISPLAY"

# Clone or update repo
if [ -d "$DIR/.git" ]; then
    echo "[...] Updating..."
    git -C "$DIR" pull --ff-only 2>/dev/null || true
else
    echo "[...] Cloning..."
    rm -rf "$DIR"
    git clone "$GITHUB" "$DIR"
fi
echo "[OK] Repo"

# Run install
chmod +x "$DIR/install.sh"
exec bash "$DIR/install.sh" "${1:-}"
