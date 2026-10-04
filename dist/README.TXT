SUPER SPRINT REFORGED - Atari ST
================================

Super Sprint (c) 1986 Atari Games. Atari ST version (c) 1986 Electric
Dreams Software, by State of the Art. This modified version is not
affiliated with, or endorsed by, any rights holder.

Project: https://github.com/stephane-perez/super-sprint-reforged
Reverse engineering and code: Stephane Perez, with Claude (Anthropic AI).


STARTING THE GAME
-----------------

Copy the SSPRINT folder to a hard disk or a floppy and run SSPRINT.PRG.
The AUTO\SUPER.PRG loader of the original disk is not needed.
Colour display, 512 KB of memory or more.


DIFFERENCES FROM THE ORIGINAL GAME
----------------------------------

1. Installation

- Hard disk: the original checks the boot sector of the floppy in drive
  A: before each race. This check is removed: the game runs from a hard
  disk or any floppy, and lap records are saved.
- RESET button: the original installs its own reset routine, which locks
  up the machine. It is no longer installed: RESET restarts TOS normally.

2. Fourth player: the green car

- The green car was always driven by the computer (the "drone"). It can
  now be driven by a human, like the blue, red and yellow cars.
- F5 in the options screen chooses its control. It starts on "none": it
  then stays a drone. To play, give it a control and press accelerate
  during "PREPARE TO RACE".
- The green car can join a game, continue after a race, choose its
  upgrades ("customize car"), and enter its initials. The game goes on
  as long as one of the four cars is driven by a human.
- Its upgrades are cleared when a new game starts.

3. Controls

- New controls for every car:
    joystick 2  parallel port adapter, "joystick 3" socket
    joystick 3  parallel port adapter, "joystick 4" socket
    joypad a    STE / Falcon joypad port A (fire = button A)
    joypad b    STE / Falcon joypad port B
  The adapter is the one used by Gauntlet II, Leatherneck or Dynabusters+.
  The joypads are only read on an STE or a Falcon (the Mega STE has no
  joypad ports).
- "mouse", which could never be used, is replaced by "none". The rule
  "can't have the mouse and joystick 0 at the same time" is gone.

4. Screens

- Title screen: "AI WORK BY CLAUDE".
- Options screen: four cars (the green one included), car names and
  controls in four columns, help text on two lines.
- Track selection, "prepare to race", initials: four columns.
- Race: when the green car is driven by a human, the top line shows four
  columns (blue, red, yellow, green): name or DRONE, wrenches, score and
  lap. The green car's name and score are in bright green. The score of
  the leading car blinks, the green car's included. The bottom line
  ("TRACK n", "DRONE LAP n") is cleared.
- "Prepare to race": "customized car includes" for the green car too.
- Podium and "customize car": the green car, in bright green.

5. Sound

- The sound driver has three voices for four cars: with four human
  players, the engine sounds share the voices.

6. Test key

- Numeric keypad "*" during a race: 5 more wrenches for every car.


KNOWN LIMITS
------------

- The green car cannot start a game from the title screen; it joins one
  started by another car.
- Two cars cannot have the same control, "none" included (rule of the
  original game).


FILES
-----

The modified program, SSPRINT.PRG, is built from your own copy of the
game. The data files are copied unchanged and must be these ones (not
packed):

    SUPER2.DAT    74355 bytes   MD5 2d828d5478e14b7e7b7bbb820ade4cfd
    SUPER.DAT    212650 bytes   MD5 3692bea1615e36f003cec5e14bc54669
    SUPER1.DAT    17024 bytes   MD5 b3c2e08bb9fd5ab92eab39b45fd713a1
    INIT.DAT       5139 bytes   MD5 68d72c8952f071b6b0ca513d8bf1c989
    SSPRINT.HSC     295 bytes   (lap records, any content)

Provided "as is", without any warranty. Use at your own risk.
