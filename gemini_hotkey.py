#!/usr/bin/env python3
"""
UTH SEB - R+Y hotkey toggle Gemini popup
Grab R+Y combo using XGrabKey with AnyModifier, running async
"""
import os
import sys
import time
import subprocess
from Xlib import display, X, Xatom

GEMINI_URL = "https://gemini.google.com"

# X11 keycodes
KEY_R = 27
KEY_Y = 29

d = display.Display()
root = d.screen().root

def get_all_windows():
    atom = d.intern_atom('_NET_CLIENT_LIST_STACKING')
    wins = root.get_full_property(atom, Xatom.WINDOW)
    return wins.value if wins else []

def get_window_name(wid):
    try:
        name_atom = d.intern_atom('WM_NAME')
        prop = wid.get_full_property(name_atom, Xatom.STRING)
        if prop:
            return prop.value.decode('utf-8', errors='replace')
    except:
        pass
    return ""

def find_browser_window():
    for wid in get_all_windows():
        name = get_window_name(wid)
        if any(k in name.lower() for k in ["gemini", "edge", "chrome", "msedge"]):
            return wid
    return None

def open_popup():
    wv2 = os.path.expanduser(
        "~/.wine/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/153.0.4234.48/msedgewebview2.exe"
    )
    if os.path.exists(wv2):
        subprocess.Popen(
            ["wine", wv2, "--new-window", GEMINI_URL],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    else:
        subprocess.Popen(
            ["wine", "cmd", "/c", "start", GEMINI_URL],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
    print(f"[OPEN] {GEMINI_URL}", flush=True)

def close_popup():
    wid = find_browser_window()
    if wid:
        subprocess.run(["pkill", "-f", "msedgewebview2"], capture_output=True)
        print("[CLOSE]", flush=True)
    else:
        print("[NO POPUP]", flush=True)

def toggle():
    if find_browser_window():
        close_popup()
    else:
        open_popup()

def main():
    print("R+Y hotkey daemon started", flush=True)
    print("Press R+Y to toggle Gemini, Ctrl+C to stop", flush=True)

    r_pressed = False

    # Grab keys with GrabModeAsync so other keys work normally
    root.grab_key(KEY_R, X.AnyModifier, True, X.GrabModeAsync, X.GrabModeAsync)
    root.grab_key(KEY_Y, X.AnyModifier, True, X.GrabModeAsync, X.GrabModeAsync)
    d.sync()
    print("Keys grabbed (async mode)", flush=True)

    try:
        while True:
            evt = d.next_event()
            if evt.type == X.KeyPress:
                if evt.detail == KEY_R:
                    r_pressed = True
                elif evt.detail == KEY_Y and r_pressed:
                    toggle()
                    r_pressed = False
                    time.sleep(0.3)
            elif evt.type == X.KeyRelease:
                if evt.detail == KEY_R:
                    r_pressed = False
    except KeyboardInterrupt:
        pass
    finally:
        root.ungrab_key(KEY_R, X.AnyModifier)
        root.ungrab_key(KEY_Y, X.AnyModifier)
        d.sync()
        print("Keys ungrabbed", flush=True)

if __name__ == "__main__":
    main()
