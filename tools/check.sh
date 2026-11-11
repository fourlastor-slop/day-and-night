#!/usr/bin/env bash
# The check a build has to pass before it is published: bots play every stop through the real tick(),
# real key events run the real main scene and its menus, and every line the kids can read has an
# Italian version that fits. Any failed scenario, missing line or script error fails the check.
set -euo pipefail
cd "$(dirname "$0")/.."
. tools/godot.sh
# Registers any new class_name, which a headless run would otherwise not know about.
timeout 300 "$GODOT_BIN" --headless --import --path . >/dev/null 2>&1 || true

log=$(mktemp)
trap 'rm -f "$log"' EXIT
# The timeouts only catch a hang: the stops take a few minutes, longer on a slow machine.
timeout 900 "$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/stop.tscn 2>&1 | tee "$log"
timeout 120 "$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/live.tscn 2>&1 | tee -a "$log"
timeout 60 "$GODOT_BIN" --headless --audio-driver Dummy --path . res://tests/lang.tscn 2>&1 | tee -a "$log"
if grep -q "SCRIPT ERROR" "$log"; then
	echo "Script errors during the check." >&2
	exit 1
fi
if ! grep -q "stop: ok" "$log" || ! grep -q "live: ok" "$log" || ! grep -qE "^lang: .* ok$" "$log"; then
	exit 1
fi
