#!/bin/bash
# UTH SEB Docker launcher
export HOME=/home/user
export FONTCONFIG_PATH=/tmp

mkdir -p "$HOME/.cache" 2>/dev/null
chmod -R u+rwX "$HOME/.wine" 2>/dev/null

wine "/home/user/.wine/drive_c/Program Files/UTH/SEB/UTHSEB.exe" 2>&1
