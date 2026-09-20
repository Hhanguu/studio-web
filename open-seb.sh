#!/bin/bash
# UTH SEB Linux - Mo file .seb tu giao vien
# Su dung: ./open-seb.sh <path-to-file.seb>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_WINE="$HOME/.wine"

if [ $# -eq 0 ]; then
    echo "Su dung: $0 <file.seb>"
    echo "Vi du: $0 ~/Downloads/kythi.seb"
    exit 1
fi

SEB_FILE="$(realpath "$1")"

if [ ! -f "$SEB_FILE" ]; then
    echo "Loi: Khong tim thay file $SEB_FILE"
    exit 1
fi

echo "=== UTH SEB Linux ==="
echo "File: $SEB_FILE"

# Tat man hinh phu
SAVED_OUTPUTS=()
while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $2}')
    if ! echo "$line" | grep -q '\*'; then
        SAVED_OUTPUTS+=("$output")
        xrandr --output "$output" --off 2>/dev/null
        echo "Tat: $output"
    fi
done < <(xrandr --listmonitors | grep -v "^Monitors:")

# Chay SEB
echo "Dang chay SEB..."
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$HOST_WINE:/home/user/.wine" \
  -v "$HOME/.cache/uth-seb:/home/user/.cache" \
  -v "$SEB_FILE:/home/user/input.seb:ro" \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -e DISPLAY="$DISPLAY" \
  -e HOME="/home/user" \
  -e LIBGL_ALWAYS_SOFTWARE=1 \
  uth-seb:latest bash -c '
    export HOME=/home/user
    export FONTCONFIG_PATH=/tmp
    chmod -R u+rwX /home/user/.wine 2>/dev/null || true
    mkdir -p /home/user/.cache 2>/dev/null || true
    wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" /home/user/input.seb
  ' 2>&1 | grep -vE "fixme:|fontconfig|Fontconfig|loader_init"

# Bat lai man hinh
for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null
    echo "Bat lai: $output"
done
