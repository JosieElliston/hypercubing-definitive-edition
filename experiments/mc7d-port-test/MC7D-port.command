#!/bin/bash
# Launches the SharpDX port of MC7D-KB (net48, wine-mono) from the test copy of the MagicTile wrapper.
# Pass "net8" as the first argument to launch the self-contained .NET 8 build instead.
C=/tmp/mc7dtest/Test.app/Contents
export DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=-all
DIR="MC7D-KB-port"; [ "$1" = net8 ] && DIR="MC7D-KB-net8"
cd "$C/SharedSupport/prefix/drive_c/Program Files/$DIR"
exec "$C/SharedSupport/wine/bin/wine" "C:\\Program Files\\$DIR\\mc7d.exe"
