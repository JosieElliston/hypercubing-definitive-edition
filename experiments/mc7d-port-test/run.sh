#!/opt/homebrew/bin/bash
# usage: run.sh [WINEDEBUG value]  -- launches the SharpDX port of mc7d in the test prefix; logs to /tmp/mc7dtest/run.log
C=/tmp/mc7dtest/Test.app/Contents
export DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=${1:--all}
cd "$C/SharedSupport/prefix/drive_c/Program Files/MC7D-KB-port"
exec $C/SharedSupport/wine/bin/wine 'C:\Program Files\MC7D-KB-port\mc7d.exe'
