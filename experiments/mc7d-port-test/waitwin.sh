#!/opt/homebrew/bin/bash
# usage: waitwin.sh <t0 epoch float> -- waits up to 90s for an mc7d window; prints elapsed
t0=$1; n=0
while ! /tmp/mt-scripts/wl | grep -q mc7d; do sleep 0.1; n=$((n+1)); [ $n -gt 900 ] && { echo timeout; exit 1; }; done
perl -MTime::HiRes=time -e "printf \"window %.3f\n\", time-$t0"
