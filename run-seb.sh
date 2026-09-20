#!/bin/bash
# UTH SEB Linux - Launch with .seb config
# Tắt màn hình phụ, chạy SEB với config, bật lại màn hình

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/uth-seb-config.seb"
HOST_WINE="$HOME/.wine"

echo "=== UTH SEB Linux ==="
echo "Config: $CONFIG_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found!"
    exit 1
fi

# Save and disable extra monitors
SAVED_OUTPUTS=()
while IFS= read -r line; do
    output=$(echo "$line" | awk '{print $2}')
    if ! echo "$line" | grep -q '\*'; then
        SAVED_OUTPUTS+=("$output")
        xrandr --output "$output" --off 2>/dev/null
        echo "Tat: $output"
    fi
done < <(xrandr --listmonitors | grep -v "^Monitors:")

echo "Monitors sau khi tat:"
xrandr --listmonitors 2>/dev/null

# Copy config file to wine prefix
WINE_DESKTOP="$HOST_WINE/drive_c/users/$USER/Desktop"
mkdir -p "$WINE_DESKTOP" 2>/dev/null
cp "$CONFIG_FILE" "$WINE_DESKTOP/uth-seb-config.seb" 2>/dev/null

# Run SEB via Docker
echo "Dang chay SEB..."
timeout 60 docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$HOST_WINE:/home/user/.wine" \
  -v "$HOME/.cache/uth-seb:/home/user/.cache" \
  -v "$CONFIG_FILE:/home/user/uth-seb-config.seb:ro" \
  -v "/tmp/.X11-unix:/tmp/.X11-unix" \
  -e DISPLAY="$DISPLAY" \
  -e HOME="/home/user" \
  -e LIBGL_ALWAYS_SOFTWARE=1 \
  uth-seb:latest bash -c '
    export HOME=/home/user
    export FONTCONFIG_PATH=/tmp
    export DISPLAY='"$DISPLAY"'
    chmod -R u+rwX /home/user/.wine 2>/dev/null || true
    mkdir -p /home/user/.cache 2>/dev/null || true

    # Try to run SEB with config
    echo "Launching SEB with config..."
    wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" "/home/user/uth-seb-config.seb" 2>&1 | \
        grep -vE "fixme:|fontconfig|Fontconfig|loader_init|get_stub_manager|err:service|err:ntoskrnl|err:nls|err:wgl|amdgpu|mesa_shader|ALSA|PulseAudio|err:winediag|err:module|ThreadPowerThrottling|ProcessCycleTime|NtQueryInformationToken|TokenSecurityAttributes|RoGetActivationFactory|WerRegisterCustomMetadata|RtlGetDeviceFamilyInfoEnum|PerfCreateInstance|PerfSetCounterRefValue|SetProcessShutdownParameters|RtlSetHeapInformation|GetProfileType|NetGetJoinInformation|NetGetAadJoinInformation|NetFreeAadJoinInformation|EtwEventSetInformation|EtwRegisterTraceGuidsW|NtQuerySystemInformation|SetEntriesInAcl|NtFilterToken|NtSetInformationToken|NtSetInformationJobObject|GetProcessMitigationPolicy|validate_proc_thread_attribute|qmgr:BackgroundCopyJob|NtUserGetWindowDisplayAffinity|SetWindowDisplayAffinity|IsWindowArranged|inputpane2_TryHide|secur32:GetUserNameExW" | tail -30
    echo "Exit: $?"
  ' 2>&1

# Re-enable extra monitors
for output in "${SAVED_OUTPUTS[@]}"; do
    xrandr --output "$output" --auto 2>/dev/null
    echo "Bat lai: $output"
done

echo "SEB da thoat."
