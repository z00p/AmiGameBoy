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
