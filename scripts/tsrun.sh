#!/opt/homebrew/bin/bash
# usage: tsrun.sh <app path> <windows exe path> <window substring> <logfile> [WINEDEBUG]
APP=$1; EXE=$2; WIN=$3; LOG=$4; C=$APP/Contents
export DYLD_FALLBACK_LIBRARY_PATH=$C/Frameworks:/usr/lib WINEPREFIX=$C/SharedSupport/prefix WINEDEBUG=${5:--all} WINEESYNC=${ESYNC:-1} WINEMSYNC=${MSYNC:-1}
$C/SharedSupport/wine/bin/wineserver -k 2>/dev/null; while pgrep -f "$C/SharedSupport/wine" >/dev/null; do sleep 0.2; done
cd "$(dirname "$C/SharedSupport/prefix/drive_c/$EXE")"
t0=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
( $C/SharedSupport/wine/bin/wine "C:\\$EXE" 2>&1 | perl -MTime::HiRes=time -ne "BEGIN{\$|=1} printf '%7.3f %s', time-$t0, \$_" > "$LOG" & )
while ! "$(dirname "$0")"/wl | grep -q "$WIN"; do sleep 0.1; done
perl -MTime::HiRes=time -e "printf \"window visible %.3f\n\", time-$t0"
