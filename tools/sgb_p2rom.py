"""Build the Super Game Boy two-player pad test: a mono cart with the SGB header flags that asks for
two pads (MLT_REQ $89 $01) and then, every frame, reads both the way the games do (Pan Docs: $30 =
the pad's ID in the low nibble, $20 = its directions, $10 = its buttons, then $30 again: P15 going
low to high selects the next pad). Our own cartridge (no third-party data, no Nintendo logo).

  python -I tools/sgb_p2rom.py OUT.gb

The screen: row "1" = player 1, row "2" = player 2, eight boxes each: Right Left Up Down A B
Select Start, filled while pressed; a box after them filled when that row's ID read was not the
expected one ($F for pad 1, $E for pad 2). LCDC $91, BGP $E4.
WRAM (the SGB_DUMP builds record $C000-$C010): $C000 frames (wraps), $C001/$C004 the ID reads
(raw P1 values), $C002/$C005 directions, $C003/$C006 buttons (raw, low active), $C007-$C00A
everything ever pressed (1 = pressed: p1 directions, p1 buttons, p2 directions, p2 buttons),
$C00B the frames with a wrong ID, $C00C the MLT_REQ packets sent.
"""
import sys

code = bytearray()
labels = {}
rel_fix, abs_fix = [], []
BASE = 0x150


def L(name):
    assert name not in labels, name
    labels[name] = len(code)


def b(*v):
    code.extend(v)


def jr(op, name):            # 0x18 jr, 0x20 nz, 0x28 z, 0x30 nc, 0x38 c
    b(op, 0)
    rel_fix.append((len(code) - 1, name))


def jp(op, name):            # 0xC3 jp, 0xCD call
    b(op, 0, 0)
    abs_fix.append((len(code) - 2, name))


def ld16(op, v):             # 0x01 bc, 0x11 de, 0x21 hl, 0x31 sp
    b(op, v & 255, v >> 8)


def tile2(rows):
    out = bytearray()
    for r in rows:
        lo = hi = 0
        for x, ch in enumerate(r):
            c = '.123'.index(ch)
            lo |= (c & 1) << (7 - x)
            hi |= (c >> 1 & 1) << (7 - x)
        out += bytes([lo, hi])
    return out


TILES = (tile2(['........'] * 8) +
         tile2(['33333333', '3......3', '3......3', '3......3', '3......3', '3......3', '3......3', '33333333']) +
         tile2(['33333333', '32222223', '32222223', '32222223', '32222223', '32222223', '32222223', '33333333']) +
         tile2(['...33...', '..333...', '...33...', '...33...', '...33...', '...33...', '..3333..', '........']) +
         tile2(['..3333..', '.33..33.', '.....33.', '....33..', '...33...', '..33....', '.333333.', '........']))
MLT2 = bytes([0x89, 0x01] + [0] * 14)

ROW1, ROW2 = 0x9800 + 5 * 32 + 3, 0x9800 + 9 * 32 + 3

# ---- start
b(0xF3)                                                      # di
ld16(0x31, 0xDFFE)
jp(0xCD, 'waitvb')
b(0xAF, 0xE0, 0x40)                                          # LCD off
ld16(0x21, 0xC000); b(0x06, 16, 0xAF)
L('cw'); b(0x22, 0x05); jr(0x20, 'cw')                       # WRAM $C000-$C00F = 0
ld16(0x21, 0x9800); ld16(0x01, 0x400)
L('cm'); b(0xAF, 0x22, 0x0B, 0x78, 0xB1); jr(0x20, 'cm')     # map clear
ld16(0x11, 0); abs_fix.append((len(code) - 2, '@tiles'))
ld16(0x21, 0x8000); b(0x06, len(TILES))
L('ct'); b(0x1A, 0x22, 0x13, 0x05); jr(0x20, 'ct')           # tiles
b(0x3E, 3, 0xEA, (ROW1 - 2) & 255, (ROW1 - 2) >> 8)          # "1", "2"
b(0x3E, 4, 0xEA, (ROW2 - 2) & 255, (ROW2 - 2) >> 8)
b(0x3E, 0xE4, 0xE0, 0x47)                                    # BGP
b(0x3E, 0x91, 0xE0, 0x40)                                    # LCD on: tiles $8000, map $9800
b(0x06, 30)
L('w0'); jp(0xCD, 'frame'); b(0x05); jr(0x20, 'w0')
ld16(0x21, 0); abs_fix.append((len(code) - 2, '@mlt'))
jp(0xCD, 'send')                                             # MLT_REQ: two pads
b(0x21, 0x0C, 0xC0, 0x34)                                    # ld hl,$C00C; inc (hl)
b(0x06, 6)
L('w1'); jp(0xCD, 'frame'); b(0x05); jr(0x20, 'w1')

# ---- each frame: both pads, then the boxes
L('loop')
jp(0xCD, 'frame')
b(0x21, 0x00, 0xC0, 0x34)                                    # frames
ld16(0x21, 0xC001)
jp(0xCD, 'pad')                                              # pad 1 -> $C001-$C003
jp(0xCD, 'pad')                                              # pad 2 -> $C004-$C006
# everything ever pressed: $C007 |= ~$C002 & $F, ... (4 bytes)
ld16(0x11, 0xC002); ld16(0x21, 0xC007)
for src in (0xC002, 0xC003, 0xC005, 0xC006):
    b(0xFA, src & 255, src >> 8, 0x2F, 0xE6, 0x0F, 0xB6, 0x22)   # ld a,(src); cpl; and $F; or (hl); ld (hl+),a
# a wrong ID: pad 1 should read $F, pad 2 $E (low nibble)
b(0xFA, 0x01, 0xC0, 0xE6, 0x0F, 0xFE, 0x0F); jr(0x20, 'bad1')
b(0x3E, 0); jr(0x18, 'ok1')
L('bad1'); b(0x21, 0x0B, 0xC0, 0x34, 0x3E, 1)
L('ok1'); b(0xEA, 0x0D, 0xC0)                                # $C00D: pad 1 ID wrong this frame
b(0xFA, 0x04, 0xC0, 0xE6, 0x0F, 0xFE, 0x0E); jr(0x20, 'bad2')
b(0x3E, 0); jr(0x18, 'ok2')
L('bad2'); b(0x21, 0x0B, 0xC0, 0x34, 0x3E, 1)
L('ok2'); b(0xEA, 0x0E, 0xC0)
# the boxes (VRAM is free: the frame started at LY 144)
ld16(0x21, ROW1); b(0xFA, 0x02, 0xC0); jp(0xCD, 'draw4')
b(0xFA, 0x03, 0xC0); jp(0xCD, 'draw4')
b(0xFA, 0x0D, 0xC0); jp(0xCD, 'drawid')
ld16(0x21, ROW2); b(0xFA, 0x05, 0xC0); jp(0xCD, 'draw4')
b(0xFA, 0x06, 0xC0); jp(0xCD, 'draw4')
b(0xFA, 0x0E, 0xC0); jp(0xCD, 'drawid')
jp(0xC3, 'loop')

# hl = where to store: the ID read, directions, buttons; then $30 (P15 low -> high: the next pad)
L('pad')
b(0x3E, 0x30, 0xE0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0x22)     # $30: ID
b(0x3E, 0x20, 0xE0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0x22)   # $20: P14 low, directions
b(0x3E, 0x10, 0xE0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0xF0, 0x00, 0x22)   # $10: P15 low, buttons
b(0x3E, 0x30, 0xE0, 0x00, 0xC9)                              # $30: the next pad
# a = four bits, low active; boxes at hl, hl+1, ... (filled = pressed)
L('draw4'); b(0x4F, 0x06, 4)                                 # ld c,a; ld b,4
L('d4'); b(0xCB, 0x39, 0x3E, 1); jr(0x38, 'd4u')             # srl c; ld a,1; jr c
b(0x3E, 2)
L('d4u'); b(0x22, 0x05); jr(0x20, 'd4'); b(0xC9)
# a = 1: a filled box (the ID was wrong), else blank; one blank before it
L('drawid'); b(0x23, 0xB7); jr(0x28, 'di0'); b(0x3E, 2)
L('di0'); b(0x77, 0xC9)
L('waitvb'); b(0xF0, 0x44, 0xFE, 144); jr(0x38, 'waitvb'); b(0xC9)
L('frame')
L('f1'); b(0xF0, 0x44, 0xFE, 144); jr(0x28, 'f1')
L('f2'); b(0xF0, 0x44, 0xFE, 144); jr(0x20, 'f2'); b(0xC9)
L('send')                                                    # 16 bytes at hl
b(0xAF, 0xE0, 0x00, 0x3E, 0x30, 0xE0, 0x00)                  # the reset pulse
b(0x06, 16)
L('sb'); b(0x2A, 0x5F, 0x16, 8)
L('sbit'); b(0x3E, 0x10, 0xCB, 0x1B); jr(0x38, 'sone'); b(0x3E, 0x20)
L('sone'); b(0xE0, 0x00, 0x3E, 0x30, 0xE0, 0x00)
b(0x15); jr(0x20, 'sbit')
b(0x05); jr(0x20, 'sb')
b(0x3E, 0x20, 0xE0, 0x00, 0x3E, 0x30, 0xE0, 0x00, 0xC9)      # the stop bit (0)

place = {'@tiles': BASE + len(code), '@mlt': BASE + len(code) + len(TILES)}
blob = TILES + MLT2
for off, name in abs_fix:
    v = place[name] if name.startswith('@') else BASE + labels[name]
    code[off], code[off + 1] = v & 255, v >> 8
for off, name in rel_fix:
    d = labels[name] - (off + 1)
    assert -128 <= d < 128, name
    code[off] = d & 255

rom = bytearray(0x8000)
rom[0x100:0x104] = bytes([0x00, 0xC3, 0x50, 0x01])
rom[0x134:0x134 + 9] = b'SGBP2TEST'
rom[0x146] = 0x03
rom[0x14B] = 0x33
rom[0x144:0x146] = b'00'
c = 0
for i in range(0x134, 0x14D):
    c = (c - rom[i] - 1) & 255
rom[0x14D] = c
rom[BASE:BASE + len(code)] = code
rom[BASE + len(code):BASE + len(code) + len(blob)] = blob
g = sum(rom) - rom[0x14E] - rom[0x14F]
rom[0x14E], rom[0x14F] = g >> 8 & 255, g & 255
open(sys.argv[1], 'wb').write(rom)
print(f'{sys.argv[1]}: code {len(code)} bytes')
