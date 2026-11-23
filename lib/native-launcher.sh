#!/bin/bash
# Launcher for a native Mac program that reads/writes files relative to its working directory
# (e.g. circleguy's Puzzles/ and Configs/). Installed as <App>.app/Contents/MacOS/launcher.
# Must stay compatible with macOS's /bin/bash 3.2.
set -u
CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
. "$CONTENTS/Resources/program.conf"   # defines APPNAME, BIN (path relative to Contents/Resources), TERMINAL (0/1)
DATA="$HOME/Library/Application Support/Hypercubing"
WORK="$DATA/$APPNAME"
mkdir -p "$DATA/logs" "$WORK"
# Copy bundled data files when the bundled version changes; user-created files survive (no --delete).
STAMP="$(cat "$CONTENTS/Resources/stamp")"
if [ -d "$CONTENTS/Resources/data" ] && [ "$(cat "$WORK/.hde-stamp" 2>/dev/null)" != "$STAMP" ]; then
  rsync -a "$CONTENTS/Resources/data/" "$WORK/"
  echo "$STAMP" >"$WORK/.hde-stamp"
fi
cd "$WORK" || exit 1
if [ "${TERMINAL:-0}" = 1 ]; then
  # Terminal programs: open a Terminal window running the program in the data folder.
  CMD="$WORK/.run.command"
  printf '#!/bin/bash\ncd %q && exec %q\n' "$WORK" "$CONTENTS/Resources/$BIN" >"$CMD"
  chmod +x "$CMD"
  exec open -a Terminal "$CMD"
fi
exec "$CONTENTS/Resources/$BIN" "$@" >"$DATA/logs/$APPNAME.log" 2>&1
