#!/bin/bash
# ============================================================
# UTH SEB Linux - Launcher
# Double-click to install and run UTH Safe Exam Browser
# ============================================================

REPO="https://github.com/Hhanguu/studio-web.git"
INSTALL_DIR="$HOME/.uth-seb"

# Auto-open terminal if run from file manager
if [ -z "${TERM:-}" ] || [ ! -t 1 ]; then
    if command -v x-terminal-emulator &>/dev/null; then
        exec x-terminal-emulator -e bash "$0" "$@"
    elif command -v xfce4-terminal &>/dev/null; then
        exec xfce4-terminal -e bash "$0" "$@"
    elif command -v gnome-terminal &>/dev/null; then
        exec gnome-terminal -- bash "$0" "$@"
    elif command -v konsole &>/dev/null; then
        exec konsole -e bash "$0" "$@"
    elif command -v xterm &>/dev/null; then
        exec xterm -e bash "$0" "$@"
    else
        echo "Cannot detect terminal. Run from terminal: bash $0"
        exit 1
    fi
fi

set -euo pipefail

echo ""
echo "========================================"
echo "  UTH SEB Linux"
echo "========================================"
echo ""

# --- Check Docker ---
command -v docker &>/dev/null || { echo "Chua cai Docker! Chay: curl -fsSL https://get.docker.com | sh"; exit 1; }
docker info &>/dev/null 2>&1 || { echo "Docker daemon chua chay! Chay: sudo systemctl start docker"; exit 1; }
echo "[OK] Docker"

# --- Check DISPLAY ---
if [ -z "${DISPLAY:-}" ]; then
    if [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=":0"
    else
        echo "Khong co display."; exit 1
    fi
fi
echo "[OK] Display: $DISPLAY"

# --- Clone or update repo ---
if [ -d "$INSTALL_DIR/.git" ]; then
    echo "[...] Updating repo..."
    git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || true
else
    echo "[...] Cloning $REPO..."
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR" || { echo "Clone that bai."; exit 1; }
fi
echo "[OK] Repo ready"

# --- Run installer from repo ---
exec bash "$INSTALL_DIR/install.sh" "${1:-}"
