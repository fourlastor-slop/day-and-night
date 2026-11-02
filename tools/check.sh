#!/usr/bin/env bash
# The check a build has to pass: bots play the stop through the real tick(), real key events run
# the real main scene, and any failed scenario or script error fails the check.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/godot.sh

log=$(mktemp)
trap 'rm -f "$log"' EXIT
timeout 120 "$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/stop.tscn 2>&1 | tee "$log"
timeout 60 "$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/live.tscn 2>&1 | tee -a "$log"
if grep -q "SCRIPT ERROR" "$log"; then
	echo "Script errors during the check." >&2
	exit 1
fi
if ! grep -q "stop: ok" "$log" || ! grep -q "live: ok" "$log"; then
	exit 1
fi
