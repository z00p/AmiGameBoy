# AmiGameBoy

**AmiGameBoy 1.0, community version** (14 November 2026). Download: the LhA archive on the [Releases](https://github.com/z00p/AmiGameBoy/releases) page, or Aminet misc/emu/AmiGameBoyCE.lha.

AmiGameBoy is a Game Boy emulator for AGA Amigas, in 68020+ assembly. It
plays the games of the original mono Game Boy (.gb files) with sound,
battery saves and a CD32 pad. It is written for an A1200 with a 68030/50
and faster machines.

It joins Juan Antonio Gómez Gálvez's AmiGameBoy (menu and display) with
the Game Boy engine of Wzonka-Lad by Ville Helin and Ventzislav Tzvetkov.
While a game runs it takes over the machine and drives the AGA chips
directly.

## Which icon to start
There is one program: AGA. It suits an A1200 with a 68030/50 and any
faster machine (PiStorm, BigMig, Minimig, 68040/68060 cards).

## Requirements
- An AGA Amiga (A1200, A4000 or an AGA FPGA core) with AmigaOS 3.0 or
```
  later.
```
- A 68020 or better. A 68030 at 50 MHz or faster is recommended for full
```
  speed.
```
- Memory: about twice the size of the cartridge plus 256 KB, fast RAM
```
  for preference (a 1 MB cartridge needs about 2.3 MB free).
```
- asl.library (part of AmigaOS).

## Starting a game
Workbench: start AGA. In the menu choose Insert, pick a cartridge, then
Power ON. The Insert requester lists drawers and .gb / .gbc files only;
change the pattern in the requester to see other names.

Shell: `AGA game.gb`

Project icons: give a cartridge an icon whose default tool is AGA (with
its path); a double click then starts the game.

Esc goes back to the menu, Continue carries on with the game. No games
are included: use cartridge images you may legally have.

## Controls
Keyboard (always active):
```
  Cursor keys                Up, Down, Left, Right
  Left Amiga or Left Shift   A
  Left Alt or Space          B
  Del                        Select
  Help                       Start
  Esc                        back to the menu
```

Joystick in port 2: fire = A, second fire = B. Use the keyboard for the
other buttons.

CD32 pad in port 2:
```
  Red      A
  Blue     B
  Green    B
  Yellow   Select
  Play     Start
  A shoulder button held with Play goes back to the menu.
```

The pad's buttons can be changed in the file AmiGameBoy.config, which the
program writes beside itself the first time it starts. One button a line,
for example "Green = Start". Buttons: Red, Blue, Green, Yellow, L, R,
Play. Choices: A, B, Select, Start, Up, Down, Left, Right, Nothing. The
file is read when the program starts; delete it to get the defaults back.

The Help page in the menu still shows the original pad layout; the list
above is the one in use.

## Battery saves
A game that saves keeps its battery RAM in a .sav file beside the
cartridge, with the cartridge's name (Game.gb, Game.sav). It is loaded
when the cartridge is inserted. When you insert another cartridge or
quit and the save has changed, the program asks before it writes the
file. So to keep a save: Esc to the menu, then Quit or Insert, and
answer Save. Don't switch off or reset from inside a game.

## The menu
LCD fade is the choice of screen palette: Grey, Green, Blue or Red.
Save Prefs writes the settings to S:AmiGameBoy.prefs.

## Not supported
- Game Boy Color-only cartridges: refused with a message.
- The colour mode of dual-mode cartridges: they run in mono.
- The link cable.
- Super Game Boy features (borders, palettes).
- From the original menu, not connected in this version: frozen games
```
  (snapshots), cheats, the monitor, and the joystick type setting
  (keyboard, joystick and CD32 pad are always active).
```
Cartridge types MBC1, MBC2, MBC3 and MBC5 up to 2 MB are handled.

## Known issues
- Infinity hangs before its title.
- Last Crown Warriors: the story pages show a grey background (cosmetic).
- Chantey: a white band in the intro (cosmetic).
- Final Fantasy Legend II and Mega Man V run slower on a 68030/50.
- Cartridges with a 128 KB save (e.g. Last Crown Warriors) are untested.

## Credits
- Juan Antonio Gómez Gálvez: AmiGameBoy, the menu and the display.
- Ville Helin and Ventzislav Tzvetkov: Wzonka-Lad, the Game Boy engine.
- Multivac: icons and graphics in Juan's original.
- z00p: the community version, sound.

## Licence and source
AmiGameBoy is free software under the GNU General Public License,
version 2 (see COPYING). It comes with no warranty. Juan's code is used
and relicensed with his consent; Wzonka-Lad is GPL-2. The CD32 pad
reader (cd32pad.s) is under the MIT licence, see cd32pad.LICENSE in the
source.

Problems: please open an issue with the game, your machine and what you saw.

## History
Juan began AmiGameBoy in 1996-97; his last public version, 0.96, is on
Aminet (misc/emu/AmiGameBoy.lha). In 2026 he sent his sources for the
community to carry on. Version 1.0 keeps his menu and his AGA display
and runs the games on Wzonka-Lad's engine, which adds the timer, the
memory controllers, battery saves and four-channel sound.

## Source and building

```
Licence: GNU GPL version 2 (COPYING). src/hybrid/cd32pad.s is under the
MIT licence (src/hybrid/cd32pad.LICENSE).

  src/                 Juan Antonio Gómez Gálvez's AmiGameBoy (menu,
                       GadToolsBox window code, graphics in data/)
  src/engine/          the Game Boy engine, from Wzonka-Lad 1.03 by
                       Ville Helin and Ventzislav Tzvetkov
  src/hybrid/          the community version: Juan's display on the
                       engine, sound, CD32 pad, the menu's glue
  build.sh             the build script
  tools/embed_rom.py   for the test builds with a cartridge inside

Building: vasm 68k, Motorola syntax (vasmm68k_mot, not included, from
http://sun.hasenbraten.de/vasm/), expected as tools/vasmm68k_mot.exe;
edit build.sh for another name. Then

  sh build.sh hymenu build/AGA

gives the released program. src/hybrid/hybrid.asm is the main file.
```
