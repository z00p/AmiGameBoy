# Game Boy Color: work in progress

This branch holds the start of Game Boy Color support. It is not a release: the menu
build is unchanged, and builds without the switches below are byte-identical to 1.0.

## Switches

| Switch | What it adds |
|---|---|
| `HY_GBC` | The colour engine (`src/engine/gbc.s`): CGB mode from the cartridge header, VRAM bank 1 (VBK) with read hooks and the mode-3 lock, WRAM banks 1-7 (SVBK), BG and OBJ palette RAM, double speed (KEY1 + STOP), HDMA (general and HBlank) |
| `GBC_RENDER` | A chunky line renderer (`src/hybrid/gbc_line.s`): bank-1 tile attributes, 8 BG + 8 OBJ palettes, CGB OBJ priority, a decoded tile-row cache, no drawing on skipped frames |
| `GBC_RTG` | A 16-bit Picasso96 test display (`src/hybrid/gbc_rtg.s`), integer scale up to 4x, centred, double-buffered (flip in the vertical blank) |
| `GBC_NODBUF` | With `GBC_RTG`: single buffer instead (for comparison) |
| `GBC_CC` | Colour correction like Mesen's default (a table built at start, no per-pixel cost); raw colours without it |

Test build with a cartridge inside (RTG screen needed):

```
VASMDEFS="-DHY_GBC -DGBC_RENDER -DGBC_RTG" sh build.sh hybrid game.gbc
```

## State

- **Engine:** checked against Mesen 2 in CGB mode, engine state frame by frame.
  - With no input, three titles match on more than 99% of 1800 frames.
  - LY reads 144 before the VBlank interrupt is raised, as on the hardware. Rebound needs this at its level start.
- **Pictures:** several titles match Mesen pixel for pixel at the frames compared. Five games have been tried on a PiStorm A1200; four play.
- **Speed:** the renderer is faster than in the first commit but not optimised yet. Infinity (double speed) is the slowest title.
- **Known gaps:**
  - Infinity's game state drifts from Mesen early on (some text and sprites missing). Not traced yet.
  - Gameplay with input drifts from Mesen after a few hundred frames in most titles (interrupt timing within a line).
  - HDMA is not paused during HALT.
  - The Picasso96 display has only been tried in WinUAE and on a PiStorm.

## Next

1. Renderer speed.
2. The Infinity divergence.
3. Game Boy carts in colour mode.
4. Menu integration and a colour profile.
