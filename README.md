# Super Sprint Reforged

*[Version française](README_FR.md)*

Reverse engineering, patches and tools for **Super Sprint** (Electric Dreams, 1986) on the Atari ST, using the methods and tools of [IK+ Reforged](https://github.com/stephane-perez/ik-plus-reforged):

- **hard disk install**: the remaining protection (a read of the floppy's boot sector) is removed; the game runs from a hard disk (tested under EmuTOS, on ST and STE);
- **RESET button**: the game's reset routine (a picture, then back to TOS, which locked up the machine) is no longer installed; RESET restarts TOS normally;
- **4th player**: the green car, which was always driven by the computer (the "drone"), can be driven by a human;
- **new controls** for every car: a joystick on a **parallel-port adapter** (two sockets) and the **STE joypads** A and B.

> ## ⚠️ Disclaimer
>
> *Super Sprint* © 1986 Atari Games, Atari ST version © 1986 Electric Dreams Software. This project is **not affiliated with, endorsed by or connected to** these companies or any other rights holder.
>
> **This repository contains no part of the game**: no program, graphics or data, whether original or modified. It only contains original code and tools. They modify, **on your own computer**, a copy of the game that **you** provide. You alone are responsible for making sure you have the right to use that copy, for example by owning an original. Only the version described below (sizes and MD5 of the files) is accepted.
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

**Green car**: when it is driven by a human, the race header has 4 columns (blue, red, yellow, green: name or DRONE, wrenches, score, lap). The options, "prepare to race", track selection and initials screens have 4 columns; it can continue after a race, choose its upgrades, enter its initials, and the game goes on as long as one car is human. The full list of differences from the original game is in [dist/README.TXT](dist/README.TXT) (English) and [dist/LISEZMOI.TXT](dist/LISEZMOI.TXT) (French), copied next to `SSPRINT.PRG`.

**Current limits**: the green car cannot start a game from the title screen, only join one; two cars set to `none` are refused ("can't have two controls the same"). See [docs/fr/METHODOLOGIE.md](docs/fr/METHODOLOGIE.md) §6.

## Building

Requirements: `make`, a C compiler (for vasm), `python3`, `curl` or `git`.

```sh
git clone https://github.com/stephane-perez/super-sprint-reforged
cd super-sprint-reforged
make                                 # 4th player code: build/p4.bin
make game GAME=/path/to/SSPRINT      # patches YOUR copy
make check                           # checks the result
```

`GAME` is the folder that holds `SUPER2.DAT`, `SUPER.DAT`, `SUPER1.DAT`, `INIT.DAT`, `SSPRINT.HSC` (and `SSPRINT.SEQ`). The result, `build/SSPRINT/`, holds `SSPRINT.PRG`, the data files and `README.TXT` / `LISEZMOI.TXT`: copy that folder to the Atari and run `SSPRINT.PRG`. The `AUTO/SUPER.PRG` loader is no longer needed.

The files must be these ones, **not packed** (some cracked versions pack them: they are refused). `make game` checks them before building. `SSPRINT.HSC` (lap records) and `SSPRINT.SEQ` differ from one copy to another and are not checked. The patches were written for this `SUPER2.DAT`; it is very likely the original Electric Dreams file (the 42-crew crack leaves it untouched), but this could not be checked against an original disk.

| File to provide | Size (bytes) | MD5 |
|---|---|---|
| `SUPER2.DAT` | 74 355 | `2d828d5478e14b7e7b7bbb820ade4cfd` |
| `SUPER.DAT` | 212 650 | `3692bea1615e36f003cec5e14bc54669` |
| `SUPER1.DAT` | 17 024 | `b3c2e08bb9fd5ab92eab39b45fd713a1` |
| `INIT.DAT` | 5 139 | `68d72c8952f071b6b0ca513d8bf1c989` |
| `SSPRINT.HSC` | 295 | (not checked) |

| Result | MD5 |
|---|---|
| `SSPRINT.PRG` (default) | `4f3d1eab8225705843656bb97e756630` |
| `SSPRINT.PRG` with `P4=0` (hard disk fix only) | `65e5b04c48c3b07f4154a15d7a9f0c51` |

## Study

- `tools/trace_ss.py`: a recursive disassembler for this PRG (relocations, jump table, a4 variables). `make listing GAME=…` → `work/ss.lst`; `tools/show.py <start> <end>` prints an extract. Needs `pip install capstone`.
- `tools/check_data.py`: checks the size and MD5 of the data files (and tells a packed file apart). `tools/txt2st.py`: converts `dist/*.TXT` to the Atari ST character set (CR LF line ends).
- `tools/patch_ss.py`: applies the patches (checks the MD5 and every original byte), appends the code of `src/p4.s` to the TEXT segment and rewrites the relocation table.
- `hatari/run.sh` (headless) and `hatari/runx.sh` (Xvfb + xdotool, with joysticks, STE joypads and the parallel port, see `joy4.cfg`). EmuTOS is enough: no Atari ROM is needed.
- `docs/fr/`: methodology, findings, code map (in French).

## Credits

- *Super Sprint*: Atari Games (arcade, 1986); Atari ST version by State of the Art for Electric Dreams (programming: Nalin Sharma, Martin Green, Jon Steele; graphics: Chris Gibbs; sound: Mark Tisdale).
- [vasm](http://sun.hasenbraten.de/vasm/): Volker Barthelmann and Frank Wille.
- [Hatari](https://hatari.tuxfamily.org/) and [EmuTOS](https://emutos.sourceforge.io/): the emulator and the free TOS used for testing.
- [Capstone](https://www.capstone-engine.org/): the disassembly engine.

## License

The original code and documentation in this repository are released under the [MIT license](LICENSE). This license does not cover Super Sprint in any way.
