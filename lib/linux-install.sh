#!/bin/bash
# Adds the hypercubing programs to your application menu, or removes them.
#
#   ./install.sh              add (run it again after moving this folder)
#   ./install.sh --uninstall  remove
#
# This only writes small .desktop files into ~/.local/share/applications; the programs themselves
# stay in this folder.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS"
rm -f "$APPS"/hypercubing-*.desktop

if [ "${1:-}" = --uninstall ]; then
  echo "Removed the hypercubing programs from the application menu."
else
  # Desktop entry Exec values: quote the path, escaping ", `, $ and \.
  esc() { printf '%s' "$1" | sed 's/[\\"`$]/\\&/g'; }
  n=0
  for run in "$ROOT"/*/run; do
    dir=$(dirname "$run") name=$(basename "$(dirname "$run")")
    slug=$(printf '%s' "$name" | tr 'A-Z' 'a-z' | tr -c 'a-z0-9\n' '-')
    {
      echo '[Desktop Entry]'
      echo 'Type=Application'
      echo "Name=$name"
      echo "Exec=\"$(esc "$run")\""
      echo "Icon=$dir/icon.png"
      echo 'Categories=Game;LogicGame;'
      echo 'Terminal=false'
    } >"$APPS/hypercubing-$slug.desktop"
    n=$((n + 1))
  done
  echo "Added $n programs to the application menu."
fi
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
