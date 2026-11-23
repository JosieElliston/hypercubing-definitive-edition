#!/opt/homebrew/bin/bash
# usage: warm.sh <app> <exe dir under drive_c> <exe> <window substr>: time cold launch, quit app only, time warm launch
APP=$1; C=$APP/Contents; export DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=-all; W=$C/SharedSupport/wine/bin
$W/wineserver -k 2>/dev/null; sleep 2
$W/wineserver -p600 & sleep 0.5
cd "$C/SharedSupport/prefix/drive_c/$2"
for run in cold warm; do
  t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
  ($W/wine "$3" >/dev/null 2>&1 &)
  n=0; while ! "$(dirname "$0")"/wl | grep -q "$4"; do sleep 0.1; n=$((n+1)); [ $n -gt 400 ] && { echo timeout; break; }; done
  perl -MTime::HiRes=time -e "printf \"$run window %.3f\n\", time-$t0"
  sleep 3; pkill -f "winetemp.*$3"; n=0; while "$(dirname "$0")"/wl | grep -q "$4"; do sleep 0.2; n=$((n+1)); [ $n -gt 50 ] && break; done; sleep 2
done
pgrep -fl "explorer.exe" | cut -c1-80
