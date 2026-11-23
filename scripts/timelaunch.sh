#!/opt/homebrew/bin/bash
# usage: timelaunch.sh <app path> <exe name substring> <window owner substring>
APP=$1; EXE=$2; WIN=$3; C=$APP/Contents
DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks WINEPREFIX=$C/SharedSupport/prefix $C/SharedSupport/wine/bin/wineserver -k 2>/dev/null
while pgrep -f "$C/SharedSupport/wine" >/dev/null; do sleep 0.2; done
t0=$(date +%s.%N); open "$APP"; ws=; ex=
while :; do
  t=$(date +%s.%N); d=$(echo "$t - $t0" | bc)
  [ -z "$ws" ] && pgrep -f "$C/SharedSupport/wine/lib/wine/../../bin/wineserver" >/dev/null && { ws=$d; echo "wineserver up  $d"; }
  [ -z "$ex" ] && pgrep -f "winetemp.*$EXE" >/dev/null && ! pgrep -f "start /unix" >/dev/null && { ex=$d; echo "exe running    $d"; }
  "$(dirname "$0")"/wl | grep -q "$WIN" && { echo "window visible $d"; break; }
  (( $(echo "$d > 120" | bc) )) && { echo timeout; break; }
  sleep 0.2
done
