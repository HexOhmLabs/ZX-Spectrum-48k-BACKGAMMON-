#!/usr/bin/env python3
"""Rebuild v61 TAP using the bundled v61 loader, raster engine and static data."""
from pathlib import Path
import struct
from functools import reduce
import HexOhm_Tavli48K_Z80_assembler as assembler

p = Path(__file__).resolve().parent
source = p / "HexOhm_Tavli48K_v61.asm"
base = p / "HexOhm_Tavli48K_v61.tap"
out = p / "HexOhm_Tavli48K_v61_rebuilt.tap"
assembler.SRC = source
code, _ = assembler.assemble()
assert 43000 + len(code) < 53248

original = base.read_bytes()
blocks = []
pos = 0
while pos < len(original):
    assert pos + 2 <= len(original)
    size = struct.unpack_from("<H", original, pos)[0]
    block = original[pos+2:pos+2+size]
    assert len(block) == size and reduce(int.__xor__, block, 0) == 0
    blocks.append(block)
    pos += 2+size
assert pos == len(original) and len(blocks) == 8

def pack(flag, payload):
    body = bytes([flag]) + bytes(payload)
    return struct.pack("<H", len(body)+1) + body + bytes([reduce(int.__xor__, body, 0)])

header = bytes([3]) + b"HEX GAME  " + struct.pack("<HHH", len(code), 43000, 0)
assert len(header) == 17
result = b"".join(struct.pack("<H", len(b)) + b for b in blocks[:6]) + pack(0, header) + pack(255, code)
out.write_bytes(result)
print(f"Created: {out.name}")
print(f"Exact match to v61: {result == original}")
if result != original:
    raise SystemExit("Build does not match v61 TAP")
