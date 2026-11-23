#!/opt/homebrew/bin/bash
# usage: time.sh <app> <windows exe path under C:\> <runs>  -- first run after wineserver -k ("cold"), rest with wineserver kept ("warm")
APP=$1; EXE=$2; N=${3:-3}; C=$APP/Contents
export DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=-all
W=$C/SharedSupport/wine/bin
$W/wineserver -k 2>/dev/null; while pgrep -f "$C/SharedSupport/wine" >/dev/null; do sleep 0.2; done
cd "$(dirname "$C/SharedSupport/prefix/drive_c/${EXE//\\//}")"
for i in $(seq 1 $N); do
  t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  ($W/wine "C:\\$EXE" >/dev/null 2>&1 &)
  n=0; while ! /tmp/mt-scripts/wl | grep -q mc7d; do sleep 0.1; n=$((n+1)); [ $n -gt 600 ] && { echo timeout; break; }; done
  perl -MTime::HiRes=time -e "printf \"run $i window %.3f\n\", time-$t0"
  sleep 4; pkill -f 'winetemp.*mc7d.exe'
  while pgrep -f 'winetemp.*mc7d.exe' >/dev/null || /tmp/mt-scripts/wl | grep -q mc7d; do sleep 0.2; done; sleep 2
done
$W/wineserver -k
