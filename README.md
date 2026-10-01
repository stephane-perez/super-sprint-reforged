# Super Sprint Reforged

*[Version française](README_FR.md)*

Reverse engineering, patches and tools for **Super Sprint** (Electric Dreams, 1986) on the Atari ST, using the methods and tools of [IK+ Reforged](../README.md):

- **hard disk install**: the remaining protection (a read of the floppy's boot sector) is removed; the game runs from a hard disk (tested under EmuTOS, on ST and STE);
- **4th player**: the green car, which was always driven by the computer (the "drone"), can be driven by a human;
- **new controls** for every car: a joystick on a **parallel-port adapter** (two sockets) and the **STE joypads** A and B.

> ## ⚠️ Disclaimer
>
> *Super Sprint* © 1986 Atari Games, Atari ST version © 1986 Electric Dreams Software. This project is **not affiliated with, endorsed by or connected to** these companies or any other rights holder.
>
> **This repository contains no part of the game**: no program, graphics or data, whether original or modified. It only contains original code and tools. They modify, **on your own computer**, a copy of the game that **you** provide. You alone are responsible for making sure you have the right to use that copy, for example by owning an original. Only the version described below (MD5 of `SUPER2.DAT`) is accepted.
>
> Everything is provided "as is", without any warranty. Use it at your own risk, including on real hardware.

## Usage

- **F1**: options. **F2**, **F3**, **F4**: controls of the blue, red and yellow cars; **F5**: the **green** car. Its control is shown at the bottom, on the "F5 - GREEN CAR" line.
- Available controls: `keyboard`, `none`, `joystick 0`, `joystick 1`, `joystick 2`, `joystick 3`, `joypad a`, `joypad b`.
- The green car starts on `none`: it stays a drone. Give it a control with F5, then press that control's accelerator during "PREPARE TO RACE" to join the race.

| Control | Hardware | Directions | Accelerate |
|---|---|---|---|
| `joystick 2` | parallel adapter, "joystick 3" socket | D4–D7 | BUSY |
| `joystick 3` | parallel adapter, "joystick 4" socket | D0–D3 | STROBE |
| `joypad a` / `joypad b` | STE and Falcon joypad ports (the Mega STE has none) | D-pad | button A |

The parallel adapter is the one used by *Gauntlet II*, *Leatherneck* or *Dynabusters+*. The joypads are only read when the `_MCH` cookie reports an STE or a Falcon.

**Green car**: its score, wrenches and lap are shown on the bottom line ("GREEN CAR"). The "prepare to race", track selection and initials screens have 4 columns; it can continue after a race, enter its initials, and the game goes on as long as one car is human.

**Current limits**: the green car cannot start a game from the title screen, only join one; two cars set to `none` are refused ("can't have two controls the same"). See [docs/fr/METHODOLOGIE.md](docs/fr/METHODOLOGIE.md) §5.

## Building

Requirements: `make`, a C compiler (for vasm), `python3`, `curl` or `git`.

```sh
cd super-sprint
make                                 # 4th player code: build/p4.bin
make game GAME=/path/to/SSPRINT      # patches YOUR copy
make check                           # checks the result
```

`GAME` is the folder that holds `SUPER2.DAT`, `SUPER.DAT`, `SUPER1.DAT`, `INIT.DAT`, `SSPRINT.HSC` (and `SSPRINT.SEQ`). The result, `build/SSPRINT/`, holds `SSPRINT.PRG` and the data files: copy that folder to the Atari and run `SSPRINT.PRG`. The `AUTO/SUPER.PRG` loader is no longer needed.

| File to provide | MD5 |
|---|---|
| `SUPER2.DAT` | `2d828d5478e14b7e7b7bbb820ade4cfd` |

| Result | MD5 |
|---|---|
| `SSPRINT.PRG` (default) | `84741f2036433e4ee06602ac3134207b` |
| `SSPRINT.PRG` with `P4=0` (hard disk fix only) | `c98082d03fdc9f2ba12e6321a8e83188` |

## Study

- `tools/trace_ss.py`: a recursive disassembler for this PRG (relocations, jump table, a4 variables). `make listing GAME=…` → `work/ss.lst`; `tools/show.py <start> <end>` prints an extract. Needs `pip install capstone`.
- `tools/patch_ss.py`: applies the patches (checks the MD5 and every original byte), appends the code of `src/p4.s` to the TEXT segment and rewrites the relocation table.
- `hatari/run.sh` (headless) and `hatari/runx.sh` (Xvfb + xdotool, with joysticks, STE joypads and the parallel port, see `joy4.cfg`). EmuTOS is enough: no Atari ROM is needed.
- `docs/fr/`: methodology, findings, code map (in French).
