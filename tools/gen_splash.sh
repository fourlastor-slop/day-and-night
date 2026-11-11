#!/usr/bin/env bash
# Renders assets/gfx/splash.png, the boot splash, from the game itself. Needs xvfb.
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 1920x1080 res://tests/splash.tscn 2>&1 | grep -E "wrote|SCRIPT ERROR|Parse Error|Invalid"
