# Game Boy Color: work in progress

This branch holds the start of Game Boy Color support. It is not a release: the menu
build is unchanged, and builds without the switches below are byte-identical to 1.0.

## Switches

| Switch | What it adds |
|---|---|
| `HY_GBC` | The colour engine (`src/engine/gbc.s`): CGB mode from the cartridge header, VRAM bank 1 (VBK), WRAM banks 1-7 (SVBK), BG and OBJ palette RAM, double speed (KEY1 + STOP), HDMA (general and HBlank) |
| `GBC_RENDER` | A chunky line renderer (`src/hybrid/gbc_line.s`): bank-1 tile attributes, 8 BG + 8 OBJ palettes, CGB OBJ priority |
| `GBC_RTG` | A 16-bit Picasso96 test display (`src/hybrid/gbc_rtg.s`), integer scale up to 4x, centred |

Test build with a cartridge inside (RTG screen needed):

```
VASMDEFS="-DHY_GBC -DGBC_RENDER -DGBC_RTG" sh build.sh hybrid game.gbc
```

## State

- **Engine:** checked against Mesen 2 in CGB mode, engine state frame by frame. With no input, three titles match on more than 99% of 1800 frames. With input, most titles drift from Mesen after 450 to 970 frames; the one traced so far comes down to interrupt timing within a line.
- **Pictures:** five titles match Mesen pixel for pixel at the frames compared.
- **Speed:** the renderer is not optimised yet. On a fast 68040 under WinUAE it costs about twice the CPU emulation.
- **Known gaps:**
  - VRAM is not locked from the CPU while the screen draws a line.
  - HDMA is not paused during HALT.
  - Colours have no colour correction.
  - The Picasso96 display has only been tried in WinUAE.

## Next

1. Renderer speed.
2. VRAM read hooks (bank 1 and the lock).
3. Game Boy carts in colour mode.
4. Menu integration and a colour profile.
