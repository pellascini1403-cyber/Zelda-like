#!/usr/bin/env bash
# Browser preview of the game (Godot Web export served statically).
# Used by .claude/launch.json. Serves build/web on $PORT (default 8080) right
# away and exports the project first if there is no build yet
# (REBUILD=1 forces a fresh export).
# The Web export runs the Compatibility renderer; it is for quick play-tests,
# not a performance reference (use the Android build for that).
set -euo pipefail
cd "$(dirname "$0")/.."
PORT="${PORT:-8080}"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/Godot_v4.4.1-stable_linux.x86_64)}"
mkdir -p build/web
python3 -m http.server "$PORT" --directory build/web --bind 0.0.0.0 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
if [ ! -f build/web/index.html ] || [ -n "${REBUILD:-}" ]; then
	python3 tools/fetch_export_templates.py version.txt web_nothreads_debug.zip web_nothreads_release.zip
	"$GODOT" --headless --import >/dev/null 2>&1 || true
	"$GODOT" --headless --export-debug "Web Preview" build/web/index.html
fi
wait $SERVER
