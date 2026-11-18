"""Build a Game Boy pad test cartridge: each button's name, the CD32 button that drives it with the
default AmiGameBoy.config (red = A, blue/green = B, yellow = Select, Play = Start), and a box that fills while the
Game Boy sees it held. Our own cartridge (no third-party data, no Nintendo logo, as tools/snd_testrom.py).

  python -I tools/padtest_rom.py OUT.gb
"""
import sys

FONT = {   # 5x7, top row first
    ' ': ['.....'] * 7,
    '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
    'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
    'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
    'D': ['####.', '#...#', '#...#', '#...#', '#...#', '#...#', '####.'],
    'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
    'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
    'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.###.'],
    'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
    'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
    'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
    ':': ['.....', '..#..', '..#..', '.....', '..#..', '..#..', '.....'],
    'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#', '#...#'],
    'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
    'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
    'S': ['.###.', '#...#', '#....', '.###.', '....#', '#...#', '.###.'],
    'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
    'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '##.##', '#...#'],
    'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
}
EMPTY, FULL = 1, 2           # tile numbers of the boxes; letters follow
chars = sorted(FONT)
TILE = {c: 3 + i for i, c in enumerate(chars)}
TILE[' '] = 0


def tile(rows8):
    out = bytearray()
    for r in rows8:
        b = int(r.replace('#', '1').replace('.', '0'), 2)
        out += bytes([b, b])         # colour 3 (black) where set
    return out


tiles = bytearray(16)                                          # 0 blank
tiles += tile(['########', '#......#', '#......#', '#......#', '#......#', '#......#', '#......#', '########'])
tiles += tile(['########'] * 8)
for c in chars:
    tiles += tile(['.' + r + '..' for r in FONT[c]] + ['........'])

# screen (20 x 18): title and one line per button; box at column 18
# joypad bits after cpl: buttons 0 A, 1 B, 2 Select, 3 Start; directions 4 Right, 5 Left, 6 Up, 7 Down
LINES = [(2, 'A      RED', 0), (4, 'B      BLUE+GREEN', 1), (6, 'SELECT YELLOW', 2), (8, 'START  PLAY', 3),
         (10, 'UP', 6), (12, 'DOWN', 7), (14, 'LEFT', 5), (16, 'RIGHT', 4)]
screen = [[0] * 20 for _ in range(18)]


def text(row, col, s):
    for i, ch in enumerate(s):
        screen[row][col + i] = TILE[ch]


text(0, 6, 'PAD TEST')
for row, s, bit in LINES:
    text(row, 0, s)
    screen[row][18] = EMPTY
mapbytes = bytes(b for r in screen for b in r)

# ---- code (SM83) at $0150
code = bytearray()
labels, fix = {}, []


def L(name):
    labels[name] = len(code)


def jr(op, name):
    code.extend([op, 0])
    fix.append((len(code) - 1, name))


def ld_hl(v): code.extend([0x21, v & 255, v >> 8])
def ld_de(v): code.extend([0x11, v & 255, v >> 8])
def ld_bc(v): code.extend([0x01, v & 255, v >> 8])


data_fix = []        # (offset of a 16-bit operand, data name)
code += bytes([0xF3, 0x31, 0xFE, 0xFF])                         # di; ld sp,$FFFE
L('vb0'); code += bytes([0xF0, 0x44, 0xFE, 144]); jr(0x38, 'vb0')   # wait LY >= 144
code += bytes([0xAF, 0xE0, 0x40])                               # LCDC = 0 (off)
code += bytes([0x3E, 0xE4, 0xE0, 0x47])                         # BGP = $E4
code += bytes([0xAF, 0xE0, 0x42, 0xE0, 0x43])                   # SCY = SCX = 0
ld_hl(0x8000); code += bytes([0x11, 0, 0]); data_fix.append((len(code) - 2, 'tiles')); ld_bc(len(tiles))
L('cp1'); code += bytes([0x1A, 0x22, 0x13, 0x0B, 0x78, 0xB1]); jr(0x20, 'cp1')   # ld a,(de); ld (hl+),a; inc de; dec bc; ld a,b; or c
ld_hl(0x9800); ld_bc(0x400)
L('cl'); code += bytes([0xAF, 0x22, 0x0B, 0x78, 0xB1]); jr(0x20, 'cl')
ld_hl(0x9800); code += bytes([0x11, 0, 0]); data_fix.append((len(code) - 2, 'map'))
code += bytes([0x0E, 18])                                       # ld c,18 rows
L('row'); code += bytes([0x06, 20])                             # ld b,20
L('col'); code += bytes([0x1A, 0x22, 0x13, 0x05]); jr(0x20, 'col')
code += bytes([0x7D, 0xC6, 12, 0x6F, 0x7C, 0xCE, 0x00, 0x67])  # hl += 12
code += bytes([0x0D]); jr(0x20, 'row')
code += bytes([0x3E, 0x91, 0xE0, 0x40])                         # LCDC = $91: on, tiles $8000, map $9800, BG on
L('main')
L('w1'); code += bytes([0xF0, 0x44, 0xFE, 144]); jr(0x28, 'w1')     # wait LY != 144
L('w2'); code += bytes([0xF0, 0x44, 0xFE, 144]); jr(0x20, 'w2')     # then LY == 144 (vblank start)
code += bytes([0x3E, 0x20, 0xE0, 0x00, 0xF0, 0x00, 0xF0, 0x00])    # P1 = $20: directions
code += bytes([0xE6, 0x0F, 0xCB, 0x37, 0x47])                       # and $0F; swap a; ld b,a
code += bytes([0x3E, 0x10, 0xE0, 0x00] + [0xF0, 0x00] * 6)          # P1 = $10: buttons
code += bytes([0xE6, 0x0F, 0xB0, 0x2F, 0x47])                       # and $0F; or b; cpl; ld b,a (1 = held)
code += bytes([0x3E, 0x30, 0xE0, 0x00])                             # P1 = $30
for row, s, bit in LINES:
    addr = 0x9800 + row * 32 + 18
    code += bytes([0xCB, 0x40 | (bit << 3)])                        # bit n,b
    code += bytes([0x3E, EMPTY]); jr(0x28, 'z%d' % bit); code += bytes([0x3E, FULL])
    L('z%d' % bit); code += bytes([0xEA, addr & 255, addr >> 8])    # ld (addr),a
code += bytes([0xC3, 0, 0]); abs_fix = [(len(code) - 2, 'main')]   # jp main (too far for jr)
for at, name in abs_fix:
    v = 0x150 + labels[name]
    code[at], code[at + 1] = v & 255, v >> 8
for at, name in fix:
    d = labels[name] - (at + 1)
    assert -128 <= d < 128, name
    code[at] = d & 255

base = 0x150
tiles_at = base + len(code)
map_at = tiles_at + len(tiles)
for at, name in data_fix:
    v = tiles_at if name == 'tiles' else map_at
    code[at], code[at + 1] = v & 255, v >> 8

rom = bytearray(0x8000)
rom[0x100:0x104] = bytes([0x00, 0xC3, 0x50, 0x01])
rom[0x134:0x134 + 7] = b'PADTEST'
c = 0
for i in range(0x134, 0x14D):
    c = (c - rom[i] - 1) & 255
rom[0x14D] = c
rom[base:base + len(code)] = code
rom[tiles_at:tiles_at + len(tiles)] = tiles
rom[map_at:map_at + len(mapbytes)] = mapbytes
g = sum(rom) - rom[0x14E] - rom[0x14F]
rom[0x14E], rom[0x14F] = g >> 8 & 255, g & 255
open(sys.argv[1], 'wb').write(rom)
print(f'{sys.argv[1]}: code {len(code)} bytes, {len(tiles) // 16} tiles')
