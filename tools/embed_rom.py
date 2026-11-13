"""Write a Game Boy ROM in the layout Juan's menu builds after loading (DirCart):
$80 bytes, then each 16 KB page followed by $80 zero bytes (the per-page overflow area).

  python tools/embed_rom.py ROM OUT.bin
A .zip is accepted (first .gb/.gbc inside). A 512-byte copier header is dropped.
"""
import sys, zipfile

src, out = sys.argv[1], sys.argv[2]
if src.lower().endswith('.zip'):
    z = zipfile.ZipFile(src)
    name = next(n for n in z.namelist() if n.lower().endswith(('.gb', '.gbc')))
    data = z.read(name)
else:
    data = open(src, 'rb').read()
if len(data) % 0x4000 == 0x200:
    data = data[0x200:]
if len(data) % 0x4000:
    data += b'\xff' * (0x4000 - len(data) % 0x4000)
pages = len(data) // 0x4000
if pages < 2:
    data += b'\xff' * (0x8000 - len(data))
    pages = 2
o = bytearray(0x80)
for i in range(pages):
    o += data[i * 0x4000:(i + 1) * 0x4000] + bytes(0x80)
open(out, 'wb').write(o)
print(f'{pages} pages, cart type {data[0x147]:02X}, ROM size code {data[0x148]:02X}, RAM {data[0x149]:02X}')
