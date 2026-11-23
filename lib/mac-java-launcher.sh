#!/bin/bash
# Launcher for a Java program in the Hypercubing Definitive Edition.
# Installed as <App>.app/Contents/MacOS/launcher. Must stay compatible with macOS's /bin/bash 3.2.
set -u
CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CONTENTS/../.." && pwd)"
RES="$CONTENTS/Resources"   # JAVA_ARGS refers to bundled files as $RES/...
# shellcheck source=/dev/null
. "$RES/program.conf"   # NAME, JAVA_ARGS (array); see "Payloads" in build.sh
DATA="$HOME/Library/Application Support/Hypercubing"
WORK="$DATA/$NAME"
mkdir -p "$DATA/logs" "$WORK"
# Copy bundled data files (Contents/Resources/data) when the bundled version changes, for programs
# that keep files next to their jar. User-created files survive (no --delete).
STAMP="$(cat "$CONTENTS/Resources/stamp")"
if [ -d "$CONTENTS/Resources/data" ] && [ "$(cat "$WORK/.hde-stamp" 2>/dev/null)" != "$STAMP" ]; then
  rsync -a "$CONTENTS/Resources/data/" "$WORK/"
  echo "$STAMP" >"$WORK/.hde-stamp"
fi
# Programs that write files relative to the working directory write them here, not into the bundle.
cd "$WORK" || exit 1
exec "$ROOT/Support/jre/bin/java" -Xdock:name="$NAME" \
  -Xdock:icon="$CONTENTS/Resources/app.icns" "${JAVA_ARGS[@]}" "$@" >"$DATA/logs/$NAME.log" 2>&1
