#!/bin/bash
# UTH SEB - X11 Level Key Blocker
# Khoa Alt+Tab, Super+Tab, Ctrl+Alt+Del o cap do X11

# Luu ban go phim goc
cp /tmp/original_keymap.xmodmap /tmp/current_keymap.xmodmap 2>/dev/null

block_keys() {
    echo "Khoa phim tat..."
    
    # Disable Alt+Tab by removing Alt_L binding
    xmodmap -e "remove mod1 = Alt_L" 2>/dev/null
    xmodmap -e "remove mod4 = Super_L" 2>/dev/null
    
    # Disable Ctrl+Alt+Delete
    xmodmap -e "keycode 23 = NoSymbol" 2>/dev/null
    
    echo "Da khoa Alt, Super, Ctrl+Alt+Del"
}

restore_keys() {
    echo "Khoi phuc phim..."
    xmodmap /tmp/original_keymap.xmodmap 2>/dev/null
    echo "Da khoi phuc."
}

case "$1" in
    lock)
        block_keys
        ;;
    unlock)
        restore_keys
        ;;
    *)
        echo "Su dung: $0 {lock|unlock}"
        ;;
esac
