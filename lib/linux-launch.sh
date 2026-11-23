#!/bin/bash
# Launcher for every program in the Linux edition of the Hypercubing Definitive Edition.
# Installed as hypercubing/Support/launch; each program folder's `run` calls it with that folder.
#
#   launch <program folder> [args...]
#
# Everything a program writes stays inside this "hypercubing" folder: the Wine prefix and logs in
# Support/, and each program's own files next to it in its folder.
set -u
APPDIR=$(cd "$1" && pwd); shift
ROOT=$(cd "$APPDIR/.." && pwd)
NAME=$(basename "$APPDIR")
# KIND (wine, java or native), then EXE (wine), JAVA_ARGS (java, an array) or BIN (native), and
# optionally DEFAULTS (an array, see below).
# shellcheck source=/dev/null
. "$APPDIR/app.conf"

say() {
  echo "$NAME: $1" >&2
  notify-send -a Hypercubing "Hypercubing" "$1" >/dev/null 2>&1 || true
}
fail() {
  say "$1"
  # Started from a desktop entry, nobody sees stderr; try a dialog too.
  if [ ! -t 2 ]; then
    zenity --error --title="$NAME" --text="$1" >/dev/null 2>&1 ||
      kdialog --title "$NAME" --error "$1" >/dev/null 2>&1 || true
  fi
  exit 1
}

LOGS="$ROOT/Support/logs"
mkdir -p "$LOGS" 2>/dev/null && [ -w "$LOGS" ] ||
  fail "Can't write to $ROOT/Support. Put the hypercubing folder somewhere your user can write to, such as your home folder."
LOG="$LOGS/$NAME.log"

# Files the program saves its settings into ship as <file>.default, so extracting a newer version
# over this folder doesn't reset them. The real file is created on first launch.
for f in ${DEFAULTS[@]+"${DEFAULTS[@]}"}; do
  [ -e "$APPDIR/$f" ] || cp "$APPDIR/$f.default" "$APPDIR/$f"
done

cd "$APPDIR" || exit 1
case "$KIND" in
  java)
    exec "$ROOT/Support/jre/bin/java" "${JAVA_ARGS[@]}" "$@" >"$LOG" 2>&1 ;;
  native)
    exec "$APPDIR/$BIN" "$@" >"$LOG" 2>&1 ;;
  wine)
    WINE=${WINE:-$(command -v wine || command -v wine64 || true)}
    [ -n "$WINE" ] || fail "Wine isn't installed. Install it with your distribution's package manager (the package is usually called \"wine\"), then try again."
    export WINEPREFIX="$ROOT/Support/wineprefix"
    export WINEDEBUG="${WINEDEBUG:--all}"
    # Gecko (Wine's HTML engine) isn't needed by any of these programs; don't offer to download it.
    export WINEDLLOVERRIDES="mshtml=d${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
    if [ ! -f "$WINEPREFIX/system.reg" ]; then
      say "Setting up Wine for the Windows programs (first launch only, about a minute)…"
      "$WINE" wineboot -u >"$LOGS/wineboot.log" 2>&1
    fi
    # Run straight from this folder (Wine maps / to Z:), so settings files land next to the exe,
    # as on Windows.
    exec "$WINE" "$APPDIR/$EXE" "$@" >"$LOG" 2>&1 ;;
  *) fail "Unknown program kind \"$KIND\" in $APPDIR/app.conf." ;;
esac
