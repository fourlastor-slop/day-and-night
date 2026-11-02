#!/usr/bin/env bash
# Plays the game.
cd "$(dirname "$0")/.."
. tools/godot.sh
exec "$GODOT_BIN" --path .
