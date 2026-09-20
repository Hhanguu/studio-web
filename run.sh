#!/bin/bash
# UTH SEB Linux - Final Launcher
# Tắt màn hình phụ trước khi chạy SEB

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_WINE="$HOME/.wine"
SEB_TARGET="$HOST_WINE/drive_c/Program Files/UTH/SEB"

echo "=== UTH SEB for Linux ==="

# Verify wine prefix
if [ ! -d "$HOST_WINE/drive_c" ]; then
    echo "Error: Wine prefix not found at $HOST_WINE"
    exit 1
fi

# Copy SEB files if needed
if [ ! -f "$SEB_TARGET/UTHSEB.exe" ]; then
    echo "Copying SEB files..."
    mkdir -p "$SEB_TARGET"
    cp -r "$SCRIPT_DIR/SEB"/* "$SEB_TARGET/"
fi

# Disable extra monitors
SAVED_OUTPUTS=()
while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $2}')
    # Skip primary monitor (marked with *)
    if ! echo "$line" | grep -q '\*'; then
        SAVED_OUTPUTS+=("$output")
        xrandr --output "$output" --off 2>/dev/null
        echo "Tắt: $output"
    fi
done < <(xrandr --listmonitors | grep -v "^Monitors:")

# Run SEB via Docker wine-staging
docker run --rm \
    --user "$(id -u):$(id -g)" \
    -v "$HOST_WINE:/home/user/.wine" \
    -v "$HOME/.cache/uth-seb:/home/user/.cache" \
    -v "/tmp/.X11-unix:/tmp/.X11-unix" \
    -e DISPLAY="$DISPLAY" \
    -e HOME="/home/user" \
    tobix/wine:staging bash -c '
        export HOME=/home/user
        export FONTCONFIG_PATH=/tmp
        chmod -R u+rwX /home/user/.wine 2>/dev/null || true
        mkdir -p /home/user/.cache 2>/dev/null || true
        wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" 2>&1 | \
            grep -vE "DpiHostingBehavior|fontconfig|Fontconfig"
    '

# Re-enable extra monitors
for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null
    echo "Bật lại: $output"
done

echo "SEB đã thoát."
