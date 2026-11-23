#!/opt/homebrew/bin/bash
# usage: poke.sh "cmd" ... -- runs the poke helper in the test prefix
C=/tmp/mc7dtest/Test.app/Contents
export POKE_SIZE=${POKE_SIZE:-774x634} DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=-all
$C/SharedSupport/wine/bin/wine 'C:\Program Files\MC7D-KB-port\poke.exe' "$@" 2>&1 | grep -v mvk
