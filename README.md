# AmiGameBoy

**AmiGameBoy 2.4, community version** (24 November 2026). Download: the LhA archive on the [Releases](https://github.com/z00p/AmiGameBoy/releases) page, or Aminet misc/emu/AmiGameBoyCE.lha.

AmiGameBoy is a Game Boy and Game Boy Color emulator for AGA Amigas, in
68020+ assembly. It plays .gb and .gbc cartridges with sound, battery
saves and a CD32 pad, on the AGA screen or on a graphics board (RTG).

It is by Juan Antonio Gómez Gálvez, Ville Helin and z00p: Juan's
AmiGameBoy (menu and display), Ville's Game Boy engine Wzonka-Lad, and
z00p's community version that joins them, with sound and Game Boy Color.
While a game runs it takes over the machine.

## Which icon to start
There are three programs. All three have the same menu.

```
  AGA       Game Boy and Game Boy Color on the AGA screen. For fast
            machines: PiStorm, BigMig, 68060 cards.
  AGA 030   Game Boy only, on the AGA screen. For an A1200 with a
            68030/50 and other machines too slow for colour.
  RTG       Game Boy and Game Boy Color on a graphics board (a 16-bit
            Picasso96 screen mode), with the screen surround on, and
            the Super Game Boy's colours and borders. For PiStorm RTG,
            BigMig and other graphics boards.
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
  for preference (a 1 MB cartridge needs about 2.3 MB free). The RTG
  program takes about 100 KB more.
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
other buttons. With a two-button joystick or pad, set Joy type to
Standard Joypad in the menu: the second fire can then never be taken
for CD32 pad buttons. A CD32 pad still works with that setting; if a
pad adapter loses its buttons with it, pick another Joy type.

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
editor; delete it to get the defaults back. Bezel, Scanlines and Super
Game Boy are in the RTG program's Options menu too, and LCD Colours in
the AGA and RTG programs' Options menu: a tick there changes the line
in the file (the bezel shows from the next Continue, Super Game Boy
from the next Power ON). One setting a line:

```
  Red = A        what a pad button does. Buttons: Red, Blue, Green,
                 Yellow, L, R, Play. Choices: A, B, Select, Start, Up,
                 Down, Left, Right, Nothing.
  Pad = CD32 pad how the CD32 pad is read. CD32 pad is the usual way;
                 KTRL CD32+ is another way for pads and adapters whose
                 buttons flicker or drop out with the first.
  Pad 2 = CD32 pad  RTG, two-player Super Game Boy games: the same
                 choice for the pad in port 1 (player 2). Not in the
                 file unless you add it; without it, CD32 pad.
  Blend = On     RTG: each picture mixed with the one before, as the
                 LCD did, so games that flicker sprites look steady.
  Bezel = On     RTG: a screen surround round the picture.
  Scanlines = Off  RTG: On darkens the last screen line of each picture
                 line, like a CRT.
  Colours = LCD  AGA and RTG, Game Boy Color games: LCD softens the
                 colours as the Game Boy Color's own screen showed
                 them; Raw shows them as the game sets them. A file
                 from 2.0 has no Colours line, so LCD: add the line
                 Colours = Raw to change it.
  Super Game Boy = Auto  RTG: Auto shows the Super Game Boy colours
                 and border of cartridges made for it; Off gives the
                 plain Game Boy look. A file from 2.2 or before has no
                 such line, so Auto. See Super Game Boy below.
```

CD32 pads tried on an A1200: a KTRL CD32 with "CD32 pad"; a Mega Multi
adapter in CD32 mode with "KTRL CD32+" (its Start button does not come
through: use Help on the keyboard).

Pad test: PadTest.gb, beside the programs, is a small test cartridge.
Load it from the menu like a game: it lists the Game Boy buttons with
the pad buttons that drive them by default, and each box fills while
the Game Boy sees that button held (keyboard, joystick or pad). If a
pad button flickers or does not fill its box, try the other Pad line.

## Super Game Boy
RTG program only. Cartridges made for the Super Game Boy send it their
colours and a border picture; the RTG program shows them as the Super
Game Boy did: the game in its colours, with the border round it in
place of the screen surround. The whole border is on the screen (the
game is drawn a size smaller where it would not fit).

Options menu, Super Game Boy: ticked (the default) is Auto, unticked
is Off, the plain Game Boy look. The tick writes the line
Super Game Boy = Auto (or Off) in AmiGameBoy.config and counts from
the next Power ON.

Cartridges made for both the Game Boy and the Game Boy Color that have
Super Game Boy extras run as a real Super Game Boy runs them: in mono,
with its colours and border. Untick Super Game Boy to play them as a
Game Boy Color game.

Two-player Super Game Boy games (Wario Blast, Bomberman GB and others)
read player 2 from port 1, the mouse port: a CD32 pad or a joystick
(fire = A, second button = B). Unplug the mouse first, or player 2
drifts. Player 1 stays on port 2 and the keyboard. With a Mega Multi
or similar adapter in port 1, add the line Pad 2 = KTRL CD32+. Players
3 and 4 read as nothing pressed.

The Super Game Boy's own sound is not played.

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
- AGA and AGA 030: Super Game Boy features. RTG: the Super Game Boy's
  own sound, and players 3 and 4 in its multi-player games.
- From the original menu, not connected in this version: frozen games
  (snapshots), cheats and the monitor. Keyboard, joystick and CD32 pad
  are always active, whatever the Joy type (Standard Joypad: see the
  joystick above).
- AGA: a picture with more than 255 colours at once loses some (rare).
Cartridge types MBC1, MBC2, MBC3 (with the clock) and MBC5 are handled.

## Credits
- Juan Antonio Gómez Gálvez: AmiGameBoy, the menu and the display.
- Ville Helin: Wzonka-Lad, the Game Boy engine.
- z00p: the community version, sound, Game Boy Color, Super Game Boy.
- Multivac: icons and graphics in Juan's original.
- Ventzislav Tzvetkov: later small fixes to Wzonka-Lad.
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
Version 2.1 shows Game Boy Color games in LCD colours (Raw is a tick
in the Options menu away), puts Bezel and Scanlines in the RTG menu,
sets the sound at the Game Boy's own balance (quieter than 2.0), runs
Final Fantasy Legend II and Mega Man V faster on a 68030/50, adds the
pad test cartridge, removes the light line at the left edge of the AGA
picture and fixes Dangan GB2's first stage.
Version 2.2 brings the processor fixes of Wzonka-Lad 1.10 and 1.11 by
Ville Helin (DAA, the half-carry flags, the stack pointer additions,
the delay after EI), removes a black band under Mega Man V's sliding
panel, and stops a two-button pad on Standard Joypad from sending the
game back to the menu.
Version 2.3 adds the Super Game Boy to the RTG program: the colours
and borders of cartridges made for it, with a tick in the Options menu
to turn it off.
Version 2.4 reads player 2 from port 1 in two-player Super Game Boy
games.

## Source and building

```
Licence: GNU GPL version 2 (COPYING). The CD32 pad reader
(src/hybrid/cd32pad.s, and cd32read.s with FAmiga's changes by
Afrotechmods) is under the MIT licence (src/hybrid/cd32pad.LICENSE).

  src/                 Juan Antonio Gómez Gálvez's AmiGameBoy (menu,
                       GadToolsBox window code, graphics in data/)
  src/engine/          the Game Boy engine, from Wzonka-Lad 1.03 by
                       Ville Helin
  src/hybrid/          the community version: Juan's display on the
                       engine, sound, CD32 pad, the menu's glue, and
                       Game Boy Color (gbc_*.s: the colour engine, the
                       line renderer, the AGA and RTG displays), the
                       Super Game Boy (sgb.s, RTG only)
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
