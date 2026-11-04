#!/usr/bin/env bash
# Dev helper: plays the stop under a virtual display and saves screenshots. Needs xvfb.
# usage: tools/run_shots.sh out_dir
cd "$(dirname "$0")/.."
. tools/godot.sh
timeout 400 xvfb-run -a -s "-screen 0 1920x1080x24" "$GODOT_BIN" --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 1920x1080 res://tests/shot.tscn -- "$1" 2>&1 | grep -E "wrote|SCRIPT ERROR|Parse Error|Invalid|ERROR: .*res://"
