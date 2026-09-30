#!/bin/bash
# runx.sh <name> <machine> <tos.img> <seconds> <key_script> [extra hatari options]
# Hatari on a virtual X display (Xvfb); keys are sent with xdotool, so they go
# through Hatari's joystick emulation. Key script lines: "t down|up|tap key".
# Joystick keys (see joy4.cfg):
#   port 0 = W A S D + Q, port 1 = I J K L + U,
#   STE joypad A = Y B N M + V, STE joypad B = 6 7 9 8 + 0,
#   parallel port, "joystick 3" socket = T F G H + R,
#   parallel port, "joystick 4" socket = 1 3 2 4 + 5.
# Hatari ignores joystick keys while Shift is held down.
# Environment: HD (drive C:, default ../build/SSPRINT), PRG (default
# SSPRINT.PRG), CFG (Hatari config, default joy4.cfg).
# Needs: hatari, Xvfb, xdotool. One screenshot per second into out/<name>/.
N=$1; M=$2; T=$3; D=$4; S=$5; shift 5
R=$(cd "$(dirname "$0")" && pwd)
HD=${HD:-$R/../build/SSPRINT}; PRG=${PRG:-SSPRINT.PRG}; CFG=${CFG:-$R/joy4.cfg}
O=$R/out/$N; rm -rf "$O"; mkdir -p "$O"; F=$O/fifo
export DISPLAY=:77 SDL_AUDIODRIVER=dummy
pgrep -x Xvfb >/dev/null || { Xvfb :77 -screen 0 1024x768x24 >/dev/null 2>&1 & sleep 1; }
hatari --configfile "$CFG" --machine "$M" --tos "$T" --harddrive "$HD" --gemdos-drive C \
  --auto "C:\\$PRG" --screenshot-dir "$O" --cmd-fifo "$F" --sound off --fast-boot yes \
  --confirm-quit no --statusbar no --drive-led no "$@" > "$O/log.txt" 2>&1 &
P=$!; sleep 2
W=$(xdotool search --name hatari | head -1); xdotool windowfocus "$W" 2>/dev/null
for i in $(seq 1 "$D"); do
  awk -v t="$i" '$1==t' "$S" | while read -r t a k; do
    case $a in
      down) xdotool keydown "$k";;
      up)   xdotool keyup "$k";;
      tap)  xdotool keydown "$k"; sleep 0.15; xdotool keyup "$k";;
    esac
  done
  sleep 1; [ -p "$F" ] && echo "hatari-shortcut screenshot" > "$F"
done
echo "hatari-shortcut quit" > "$F" 2>/dev/null; sleep 1; kill $P 2>/dev/null; wait $P 2>/dev/null
echo "$(ls "$O" | grep -c png) screenshots in $O"
