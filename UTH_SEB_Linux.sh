#!/bin/bash
# ============================================================
# UTH SEB Linux - Launcher
# Double-click to install and run UTH Safe Exam Browser on Linux
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

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[...]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
fail()  { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

echo ""
echo "========================================"
echo "  UTH SEB Linux - Kiem tra moi truong"
echo "========================================"
echo ""

# --- Check Docker ---
command -v docker &>/dev/null || fail "Chua cai Docker! Chay: curl -fsSL https://get.docker.com | sh"
docker info &>/dev/null 2>&1 || fail "Docker daemon chua chay! Chay: sudo systemctl start docker"
ok "Docker"

# --- Check DISPLAY ---
if [ -z "${DISPLAY:-}" ]; then
    if [ -S "/tmp/.X11-unix/X0" ]; then
        export DISPLAY=":0"
    else
        fail "Khong co display (GUI)."
    fi
fi
ok "Display: $DISPLAY"

# --- Clone or update repo ---
if [ -d "$INSTALL_DIR/.git" ]; then
    info "Cap nhat repo..."
    git -C "$INSTALL_DIR" pull --ff-only 2>/dev/null || warn "Khong cap nhat duoc, dung phien ban cu."
    ok "Repo updated."
else
    info "Cloning $REPO..."
    rm -rf "$INSTALL_DIR"
    git clone "$REPO" "$INSTALL_DIR" 2>/dev/null || fail "Clone that bai. Kiem tra internet."
    ok "Repo cloned."
fi

# --- Run installer from repo ---
chmod +x "$INSTALL_DIR/UTH_SEB_Linux.sh"
exec bash "$INSTALL_DIR/UTH_SEB_Linux.sh" "${1:-}"
