#!/bin/bash
# run.sh <name> <machine> <tos.img> <seconds> [extra hatari options]
# Headless Hatari run (no display), one screenshot per second into out/<name>/.
# Environment: HD = folder mounted as drive C: (default ../build/SSPRINT),
#              PRG = program started automatically (default SSPRINT.PRG),
#              KEYS = "t:scancode ..." ST keys pressed at second t (decimal, e.g. "22:59" = F1).
# Note: ST keys sent this way bypass Hatari's joystick emulation; use runx.sh
# to drive joysticks.
N=$1; M=$2; T=$3; D=$4; shift 4
R=$(cd "$(dirname "$0")" && pwd)
HD=${HD:-$R/../build/SSPRINT}; PRG=${PRG:-SSPRINT.PRG}
O=$R/out/$N; rm -rf "$O"; mkdir -p "$O"; F=$O/fifo
export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
hatari --configfile /dev/null --machine "$M" --tos "$T" --harddrive "$HD" --gemdos-drive C \
  --auto "C:\\$PRG" --screenshot-dir "$O" --cmd-fifo "$F" --sound off --fast-boot yes \
  --confirm-quit no --statusbar no --drive-led no "$@" > "$O/log.txt" 2>&1 &
P=$!
for i in $(seq 1 "$D"); do
  sleep 1; [ -p "$F" ] || continue
  for k in $KEYS; do
    if [ "${k%%:*}" = "$i" ]; then
      echo "hatari-event keydown ${k##*:}" > "$F"; sleep 0.2; echo "hatari-event keyup ${k##*:}" > "$F"
    fi
  done
  echo "hatari-shortcut screenshot" > "$F"
done
echo "hatari-shortcut quit" > "$F" 2>/dev/null; sleep 1; kill $P 2>/dev/null; wait $P 2>/dev/null
echo "$(ls "$O" | grep -c png) screenshots in $O"
