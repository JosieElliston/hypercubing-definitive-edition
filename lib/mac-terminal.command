#!/bin/bash
# Terminal opens this file when the app icon is clicked.
RES="$(cd "$(dirname "$0")" && pwd)"
. "$RES/program.conf"
exec "$RES/$BIN" "$@"
