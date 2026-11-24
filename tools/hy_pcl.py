# tools/hy_pcl.py FILE [--last N] [--mem ADDR LEN]: read GB:AmiGB.pcl (HY_PCLOG test switch, hybrid.asm)
import struct, sys, collections
a = sys.argv[1:]
d = open(a[0], 'rb').read()
assert d[:4] == b'PCL2', d[:4]
n, size = struct.unpack('>II', d[4:12])
ring = d[12:12 + size * 32]
mem = d[12 + size * 32:12 + size * 32 + 0x10000]
rest = d[12 + size * 32 + 0x10000:]
ents = []
for i in range(max(0, n - size), n):
    e = ring[(i % size) * 32:(i % size) * 32 + 32]
    fr, pc, sp, af, bc, de, hl = struct.unpack('>IHHHHHH', e[:16])
    lcdc, stat, ly, iff, ie = e[16:21]
    ents.append((fr, pc, sp, af, bc, de, hl, lcdc, stat, ly, iff, ie, e[22:30]))
print(f'{n} entries, ring {size}')
last = int(a[a.index('--last') + 1]) if '--last' in a else 20
for e in ents[-last:]:
    fr, pc, sp, af, bc, de, hl, lcdc, stat, ly, iff, ie, st = e
    print(f'f{fr:5d} PC {pc:04X} SP {sp:04X} AF {af:04X} BC {bc:04X} DE {de:04X} HL {hl:04X} LCDC {lcdc:02X} STAT {stat:02X} LY {ly:3d} IF {iff:02X} IE {ie:02X} stk {st.hex()}')
c = collections.Counter(e[1] for e in ents)
print('PC histogram:', ', '.join(f'{k:04X}x{v}' for k, v in c.most_common(12)))
if '--mem' in a:
    i = a.index('--mem'); ad = int(a[i + 1], 16); ln = int(a[i + 2], 16)
    for o in range(ad, ad + ln, 16):
        print(f'{o:04X}: {mem[o:o+16].hex(" ")}')
