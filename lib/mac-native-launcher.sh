#!/bin/bash
# Launcher for a native Mac program that reads/writes files relative to its working directory
# (e.g. circleguy's Puzzles/ and Configs/). Installed as <App>.app/Contents/MacOS/launcher.
# Must stay compatible with macOS's /bin/bash 3.2.
set -u
CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
. "$CONTENTS/Resources/program.conf"   # NAME, BIN (relative to Contents/Resources), optional TERMINAL (0/1)
if [ "${TERMINAL:-0}" = 1 ]; then
  if [ $# -eq 0 ] && [ ! -t 0 ]; then
    exec open -a Terminal "$CONTENTS/Resources/run.command"
  fi
  exec "$CONTENTS/Resources/$BIN" "$@"
fi

DATA="$HOME/Library/Application Support/Hypercubing"
WORK="$DATA/$NAME"
mkdir -p "$DATA/logs" "$WORK"
# Copy bundled data files when the bundled version changes; user-created files survive (no --delete).
STAMP="$(cat "$CONTENTS/Resources/stamp")"
if [ -d "$CONTENTS/Resources/data" ] && [ "$(cat "$WORK/.hde-stamp" 2>/dev/null)" != "$STAMP" ]; then
  rsync -a "$CONTENTS/Resources/data/" "$WORK/"
  echo "$STAMP" >"$WORK/.hde-stamp"
fi
cd "$WORK" || exit 1
exec "$CONTENTS/Resources/$BIN" "$@" >"$DATA/logs/$NAME.log" 2>&1
