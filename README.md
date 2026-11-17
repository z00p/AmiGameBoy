# AmiGameBoy

**AmiGameBoy 2.0, community version** (17 November 2026). Download: the LhA archive on the [Releases](https://github.com/z00p/AmiGameBoy/releases) page, or Aminet misc/emu/AmiGameBoyCE.lha.

AmiGameBoy is a Game Boy and Game Boy Color emulator for AGA Amigas, in
68020+ assembly. It plays .gb and .gbc cartridges with sound, battery
saves and a CD32 pad, on the AGA screen or on a graphics board (RTG).

It joins Juan Antonio Gómez Gálvez's AmiGameBoy (menu and display) with
the Game Boy engine of Wzonka-Lad by Ville Helin and Ventzislav Tzvetkov.
While a game runs it takes over the machine.

## Which icon to start
There are three programs. All three have the same menu.

```
  AGA       Game Boy and Game Boy Color on the AGA screen. For fast
            machines: PiStorm, BigMig, 68060 cards.
  AGA 030   Game Boy only, on the AGA screen. For an A1200 with a
            68030/50 and other machines too slow for colour.
  RTG       Game Boy and Game Boy Color on a graphics board (a 16-bit
            Picasso96 screen mode), with the screen surround on. For
            PiStorm RTG, BigMig and other graphics boards.
```

Mono cartridges look the same in AGA and AGA 030 (Juan's display);
RTG draws them in the menu's palette. Coming from 1.0 on a 68030/50:
AGA 030 is the program to start now (AGA is the colour one).

## Requirements
- An AGA Amiga (A1200, A4000 or an AGA FPGA core) with AmigaOS 3.0 or
  later.
- A 68020 or better. AGA 030: a 68030 at 50 MHz or faster for full
  speed. AGA and RTG: a much faster machine (a PiStorm runs colour
  games at full speed).
- RTG: Picasso96 and a 16-bit screen mode. The program picks the mode
  itself (960x540 first, then 640x480, then the smallest that fits).
- Memory: about twice the size of the cartridge plus 256 KB, fast RAM
  for preference (a 1 MB cartridge needs about 2.3 MB free).
- asl.library (part of AmigaOS).

## Starting a game
Workbench: start one of the programs. In the menu choose Insert, pick a
cartridge, then Power ON. The Insert requester lists drawers and .gb /
.gbc files only; change the pattern in the requester to see other names.

Shell: AGA game.gb (or AGA 030, or RTG, in quotes when the name has a
space: "AGA 030" game.gb)

Project icons: give a cartridge an icon whose default tool is one of
the programs (with its path); a double click then starts the game.

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

## The settings file
Each program writes the file AmiGameBoy.config beside itself the first
time it starts, and reads it each time it starts. Edit it with any text
editor; delete it to get the defaults back. The settings below are only
in this file for now, not in the menu. One setting a line:

```
  Red = A        what a pad button does. Buttons: Red, Blue, Green,
                 Yellow, L, R, Play. Choices: A, B, Select, Start, Up,
                 Down, Left, Right, Nothing.
  Pad = CD32 pad how the CD32 pad is read. CD32 pad is the usual way;
                 KTRL CD32+ is another way for pads and adapters whose
                 buttons flicker or drop out with the first.
  Blend = On     RTG: each picture mixed with the one before, as the
                 LCD did, so games that flicker sprites look steady.
  Bezel = On     RTG: a screen surround round the picture.
  Scanlines = Off  RTG: On darkens the last screen line of each picture
                 line, like a CRT.
```

CD32 pads tried on an A1200: a KTRL CD32 with "CD32 pad"; a Mega Multi
adapter in CD32 mode with "KTRL CD32+" (its Start button does not come
through: use Help on the keyboard).

## Battery saves
A game that saves keeps its battery RAM in a .sav file beside the
cartridge, with the cartridge's name (Game.gb, Game.sav). Saves of up
to 128 KB are kept. The file is loaded when the cartridge is inserted.
When you insert another cartridge or quit and the save has changed, the
program asks before it writes the file. So to keep a save: Esc to the
menu, then Quit or Insert, and answer Save. Don't switch off or reset
from inside a game.

## The menu
LCD fade is the choice of palette for mono games: Grey, Green, Blue or
Red. Save Prefs writes the settings to S:AmiGameBoy.prefs.

## Not supported
- AGA 030: Game Boy Color-only cartridges (refused with a message);
  dual-mode cartridges run in mono.
- Cartridges over 2 MB (refused).
- The link cable, the Game Boy Camera and the Game Boy Printer.
- Super Game Boy features (borders, palettes).
- From the original menu, not connected in this version: frozen games
  (snapshots), cheats, the monitor, and the joystick type setting
  (keyboard, joystick and CD32 pad are always active).
- AGA: a picture with more than 255 colours at once loses some (rare).
Cartridge types MBC1, MBC2, MBC3 (with the clock) and MBC5 are handled.

## Known issues
- Final Fantasy Legend II and Mega Man V run slower on a 68030/50.
- AGA and AGA 030: a thin light line can show down the left edge of the
  picture (cosmetic).

## Credits
- Juan Antonio Gómez Gálvez: AmiGameBoy, the menu and the display.
- Ville Helin and Ventzislav Tzvetkov: Wzonka-Lad, the Game Boy engine.
- Multivac: icons and graphics in Juan's original.
- z00p: the community version, sound, Game Boy Color.
- Afrotechmods / FAmiga: the CD32 pad read.

## Licence and source
AmiGameBoy is free software under the GNU General Public License,
version 2 (see COPYING). It comes with no warranty. Juan's code is used
and relicensed with his consent; Wzonka-Lad is GPL-2. The CD32 pad
reader (cd32pad.s, cd32read.s) is under the MIT licence, see
cd32pad.LICENSE in the source.

The full source is in the Source drawer (see its ReadMe.txt), and at
https://github.com/z00p/AmiGameBoy where problems can be reported too:
please give the game, the program (AGA, AGA 030 or RTG), your machine
and what you saw.

## History
Juan began AmiGameBoy in 1996-97; his last public version, 0.96, is on
Aminet (misc/emu/AmiGameBoy.lha). In 2026 he sent his sources for the
community to carry on. Version 1.0 kept his menu and his AGA display
and ran the games on Wzonka-Lad's engine, which added the timer, the
memory controllers, battery saves and four-channel sound. Version 2.0
adds Game Boy Color on AGA and RTG, saves of up to 128 KB, a steadier
CD32 pad read and a choice of two ways to read it.

## Source and building

```
Licence: GNU GPL version 2 (COPYING). The CD32 pad reader
(src/hybrid/cd32pad.s, and cd32read.s with FAmiga's changes by
Afrotechmods) is under the MIT licence (src/hybrid/cd32pad.LICENSE).

  src/                 Juan Antonio Gómez Gálvez's AmiGameBoy (menu,
                       GadToolsBox window code, graphics in data/)
  src/engine/          the Game Boy engine, from Wzonka-Lad 1.03 by
                       Ville Helin and Ventzislav Tzvetkov
  src/hybrid/          the community version: Juan's display on the
                       engine, sound, CD32 pad, the menu's glue, and
                       Game Boy Color (gbc_*.s: the colour engine, the
                       line renderer, the AGA and RTG displays)
  build.sh             the build script
  tools/embed_rom.py   for the test builds with a cartridge inside

Building: vasm 68k, Motorola syntax (vasmm68k_mot, not included, from
http://sun.hasenbraten.de/vasm/), expected as tools/vasmm68k_mot.exe;
edit build.sh for another name. Then

  sh build.sh rel build/rel

gives the three released programs: build/rel/AGA, build/rel/AGA 030 and
build/rel/RTG. The switches each one uses are listed in build.sh.
src/hybrid/hybrid.asm is the main file.
```
