# Changes

## 2.1

AmiGameBoy 2.1, community version: a Game Boy and Game Boy Color emulator for AGA
Amigas, on the AGA screen or a graphics board. By Juan Antonio Gómez Gálvez
(AmiGameBoy: menu and display), Ville Helin (Wzonka-Lad: the Game Boy engine)
and z00p (community version: sound, Game Boy Color). Also on Aminet:
misc/emu/AmiGameBoyCE.lha.

**Three programs** (as in 2.0)
- **AGA**: Game Boy and Game Boy Color on the AGA screen, for fast machines
  (PiStorm, BigMig, 68060 cards).
- **AGA 030**: Game Boy only, for an A1200 with a 68030/50.
- **RTG**: Game Boy and Game Boy Color on a 16-bit Picasso96 screen.

**What is new**
- **Colours**: Game Boy Color games show LCD colours by default, softened as
  the Game Boy Color's own screen showed them. `Colours = Raw` in
  AmiGameBoy.config shows them as the game sets them.
- **Options menu**: LCD Colours tick in AGA and RTG; Bezel and Scanlines ticks
  in RTG. A tick changes the line in AmiGameBoy.config.
- **Sound**: the four channels at the Game Boy's own balance, quieter than 2.0
  and level with other Amiga emulators.
- **Speed**: Final Fantasy Legend II and Mega Man V faster on a 68030/50.
- **Pad test**: PadTest.gb, beside the programs, shows each Game Boy button as
  the emulator sees it (keyboard, joystick or CD32 pad).
- **Fixed**: the light line at the left edge of the AGA picture (mono and
  colour); Dangan GB2's first stage.
- **Credits**: Juan Antonio Gómez Gálvez, Ville Helin and z00p alike in the
  screen title and the main window; Wzonka-Lad credited to its author, Ville
  Helin.

**Upgrading from 2.0**: unpack over it. An AmiGameBoy.config from 2.0 has no
Colours line, so colour games start in LCD colours; untick LCD Colours in the
Options menu, or add `Colours = Raw`, for 2.0's colours.

**Requirements**: AGA and AmigaOS 3.0 or later. AGA 030: 68020 or better, a
68030/50 for full speed. AGA and RTG: a PiStorm-class machine; RTG also needs
Picasso96 and a 16-bit screen mode. Memory: about twice the cartridge's size
plus 256 KB.

**Not supported**: cartridges over 2 MB, the link cable, the Game Boy Camera and
Printer, Super Game Boy features. AGA 030 refuses colour-only cartridges and
runs dual-mode ones in mono. AGA: more than 255 colours in one picture are
capped (rare).

**Known issues**: none.

**Tested** on an A1200 with a PiStorm (AGA, AGA 030 and RTG) and in WinUAE
(68020 and 68030 settings).

**Install**: unpack AmiGameBoy-2.1.lha and start AGA, AGA 030 or RTG in the
AmiGameBoy drawer. ReadMe.txt and AmiGameBoy.guide have the keys, the pad, the
settings and the saves. No games are included: use cartridge images you may
legally have.

**Credits**: Juan Antonio Gómez Gálvez (AmiGameBoy: menu and display), Ville
Helin (Wzonka-Lad: the Game Boy engine) and z00p (community version, sound,
Game Boy Color); Multivac (icons and graphics in Juan's original), Ventzislav
Tzvetkov (later small fixes to Wzonka-Lad), Afrotechmods / FAmiga (CD32 pad
read).

**Problems**: please open an issue with the game, the program (AGA, AGA 030 or
RTG), your machine and what you saw.

SHA-256 of AmiGameBoy-2.1.lha: 67996252a695b615ad3b380291750dd212d3efaf745cb6686c0d340876a7d6ae

## 2.0

AmiGameBoy 2.0, community version: a Game Boy and Game Boy Color emulator for AGA
Amigas, on the AGA screen or a graphics board. Juan Antonio Gómez Gálvez's
AmiGameBoy (menu and display) with the Game Boy engine of Wzonka-Lad by Ville
Helin and Ventzislav Tzvetkov. Also on Aminet: misc/emu/AmiGameBoyCE.lha.

**Three programs**
- **AGA**: Game Boy and Game Boy Color on the AGA screen, for fast machines
  (PiStorm, BigMig, 68060 cards).
- **AGA 030**: Game Boy only, for an A1200 with a 68030/50 (in place of 1.0's AGA).
- **RTG**: Game Boy and Game Boy Color on a 16-bit Picasso96 screen.

**What is new**
- **Game Boy Color**: colour-only and dual-mode cartridges play in colour in AGA
  and RTG.
- **RTG**: screen mode picked automatically, picture at the largest whole scale.
  Settings in AmiGameBoy.config: `Bezel = On` (screen surround, default on),
  `Blend = On` (LCD blend, steadies flickering sprites, default on),
  `Scanlines = Off` (default off).
- **Saves**: battery saves of up to 128 KB (e.g. Last Crown Warriors).
- **CD32 pad**: a steadier read (all buttons solid on a KTRL CD32), and
  `Pad = KTRL CD32+` in AmiGameBoy.config for pads and adapters whose buttons
  flicker or drop out (e.g. a Mega Multi adapter in CD32 mode). Read based on
  FAmiga's, by Afrotechmods.
- **Fixed**: Infinity now runs (it needs Game Boy Color); Chantey's intro band
  and house room; Last Crown Warriors' story pages (black, as on the hardware);
  the menu's cartridge info reads the whole header; the Help page shows the pad
  layout in use; "(GPL-2)" in the menu.
- **Sound**: a wave-channel note restarts from the start of its waveform, as on
  the Game Boy (AGA and RTG).
- **Insert requester**: wider.

**Requirements**: AGA and AmigaOS 3.0 or later. AGA 030: 68020 or better, a
68030/50 for full speed. AGA and RTG: a PiStorm-class machine; RTG also needs
Picasso96 and a 16-bit screen mode. Memory: about twice the cartridge's size
plus 256 KB.

**Not supported**: cartridges over 2 MB, the link cable, the Game Boy Camera and
Printer, Super Game Boy features. AGA 030 refuses colour-only cartridges and
runs dual-mode ones in mono. AGA: more than 255 colours in one picture are
capped (rare).

**Known issues**
- Final Fantasy Legend II and Mega Man V run slower on a 68030/50.
- AGA and AGA 030: a thin light line can show down the left edge of the picture
  (cosmetic).

**Tested** on an A1200 with a PiStorm (AGA and RTG; KTRL CD32 and Mega Multi
pads) and in WinUAE (68020 and 68030 settings).

**Install**: unpack AmiGameBoy-2.0.lha and start AGA, AGA 030 or RTG in the
AmiGameBoy drawer. Upgrading from 1.0: unpack over it; on a 68030/50 start AGA
030 from now on. ReadMe.txt and AmiGameBoy.guide have the keys, the pad, the
settings and the saves. No games are included: use cartridge images you may
legally have.

**Credits**: Juan Antonio Gómez Gálvez (AmiGameBoy: menu and display), Ville
Helin and Ventzislav Tzvetkov (Wzonka-Lad: the Game Boy engine), Multivac (icons
and graphics in Juan's original), z00p (community version, sound, Game Boy
Color), Afrotechmods / FAmiga (CD32 pad read).

**Problems**: please open an issue with the game, the program (AGA, AGA 030 or
RTG), your machine and what you saw.

SHA-256 of AmiGameBoy-2.0.lha: 11e6a7e0993a5b602079b89e562cebd182ec1fff9e91e98497d90b7b41a1c62a

## 1.0

AmiGameBoy 1.0, community version: a Game Boy emulator for AGA Amigas, for an
A1200 with a 68030/50 and faster machines. Juan Antonio Gómez Gálvez's
AmiGameBoy (menu and display) with the Game Boy engine of Wzonka-Lad by Ville
Helin and Ventzislav Tzvetkov. Also on Aminet: misc/emu/AmiGameBoyCE.lha.

**What is new**
- **Engine**: Wzonka-Lad's Game Boy engine runs the games behind Juan's menu and
  AGA display. One program, AGA.
- **Sound**: four channels on Paula.
- **Cartridges**: MBC1, MBC2, MBC3 and MBC5 up to 2 MB. Battery saves in a .sav
  file beside the cartridge.
- **Controls**: keyboard, joystick and CD32 pad together. Pad defaults: red A,
  blue B, green B, yellow Select, play Start; a shoulder button with play goes
  back to the menu. Buttons editable in AmiGameBoy.config.
- **Starting**: Shell (`AGA game.gb`), project icons, or Insert in the menu. The
  Insert requester lists cartridges and drawers only.
- **Display**: palettes that change down the screen are followed line by line.
- **Speed**: waiting loops in games are skipped, for the 68030/50.
- **Source**: included, GPL-2.

**Requirements**: AGA, 68020 or better (68030/50 or faster recommended), about
twice the cartridge's size plus 256 KB of memory, AmigaOS 3.0 or later.

**Not supported**: Game Boy Color-only cartridges (refused with a message), the
colour mode of dual-mode cartridges (they run in mono), the link cable, Super
Game Boy features.

**Known issues**
- Infinity hangs before its title.
- Last Crown Warriors: the story pages show a grey background (cosmetic).
- Chantey: a white band in the intro (cosmetic).
- Final Fantasy Legend II and Mega Man V run slower on a 68030/50.
- Cartridges with a 128 KB save (e.g. Last Crown Warriors) are untested.

**Tested** on an A1200 with a PiStorm and in WinUAE (68020 and 68030 settings).

**Install**: unpack AmiGameBoy-1.0.lha, start AGA in the AmiGameBoy drawer.
ReadMe.txt and AmiGameBoy.guide have the keys, the pad and the saves. No games
are included: use cartridge images you may legally have.

**Credits**: Juan Antonio Gómez Gálvez (AmiGameBoy: menu and display), Ville
Helin and Ventzislav Tzvetkov (Wzonka-Lad: the Game Boy engine), Multivac (icons
and graphics in Juan's original), z00p (community version, sound).

**Problems**: please open an issue with the game, your machine and what you saw.

SHA-256 of AmiGameBoy-1.0.lha: 2b09d30fa7e22595a83dfb1f6f985e047dc24aeae53d8e478b2b408f74b7e42c
