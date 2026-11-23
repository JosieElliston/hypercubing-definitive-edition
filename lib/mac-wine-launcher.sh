#!/bin/bash
# Launcher for a Windows program in the Hypercubing Definitive Edition.
# Installed as <App>.app/Contents/MacOS/launcher. Must stay compatible with macOS's /bin/bash 3.2.
# Why a shell launcher instead of Sikarugir's: one shared engine and prefix serve every app.
set -u
CONTENTS="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$CONTENTS/../.." && pwd)"
ENGINE="$ROOT/Support/engine"
# shellcheck source=/dev/null
. "$CONTENTS/Resources/program.conf"   # NAME (also its folder in C:\Program Files), EXE, optional KEEP

DATA="$HOME/Library/Application Support/Hypercubing"
export WINEPREFIX="$DATA/prefix"
# The engine's dylibs are found via rpath, but Wine dlopens some (e.g. freetype) by name.
export DYLD_FALLBACK_LIBRARY_PATH="$ENGINE:/usr/lib"
export WINEDEBUG="${WINEDEBUG:--all}" WINEMSYNC=1
# Gecko (the HTML engine) is stripped from the engine to save 200 MB; don't prompt for it.
export WINEDLLOVERRIDES="mshtml=d${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
WINE="$ENGINE/wine/bin/wine"
LOG="$DATA/logs/$NAME.log"
mkdir -p "$DATA/logs"

notify() { osascript -e "display notification \"$1\" with title \"Hypercubing\"" >/dev/null 2>&1 || true; }

# Serialize prefix creation and payload syncing between apps launched at the same time.
LOCK="$DATA/.lock"
until mkdir "$LOCK" 2>/dev/null; do
  # Stale lock from a crashed launcher: older than 5 minutes.
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then rmdir "$LOCK"; fi
  sleep 0.2
done
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

if [ ! -f "$WINEPREFIX/system.reg" ]; then
  notify "Setting up Windows environment (first launch only, about 30 seconds)…"
  "$WINE" wineboot -u >"$DATA/logs/wineboot.log" 2>&1
  "$ENGINE/wine/bin/wineserver" -w
  # Let Windows programs see the Mac Desktop, like Documents/Downloads already are.
  U="$WINEPREFIX/drive_c/users/crossover"
  if [ -d "$U/Desktop" ] && [ ! -L "$U/Desktop" ]; then rmdir "$U/Desktop" 2>/dev/null && ln -s "$HOME/Desktop" "$U/Desktop"; fi
fi

# Copy the program into the prefix when the bundled version changes. Files the program created
# itself (settings, saves) survive: no --delete, and shipped files listed in KEEP are skipped.
DEST="$WINEPREFIX/drive_c/Program Files/$NAME"
STAMP="$(cat "$CONTENTS/Resources/stamp")"
if [ "$(cat "$DEST/.hde-stamp" 2>/dev/null)" != "$STAMP" ]; then
  mkdir -p "$DEST"
  # KEEP (optional, from program.conf) lists shipped files the program also saves user settings
  # into; once they exist in the prefix, updates must not overwrite them.
  EXCLUDES=()
  for f in ${KEEP[@]+"${KEEP[@]}"}; do [ -e "$DEST/$f" ] && EXCLUDES+=(--exclude "/$f"); done
  rsync -a ${EXCLUDES[@]+"${EXCLUDES[@]}"} "$CONTENTS/Resources/program/" "$DEST/"
  echo "$STAMP" >"$DEST/.hde-stamp"
fi
rmdir "$LOCK"; trap - EXIT

cd "$DEST" || exit 1
exec "$WINE" "C:\\Program Files\\$NAME\\$EXE" "$@" >"$LOG" 2>&1
