# HexOhm ΤΑΒΛΙ 48K — v61

Greek backgammon-family game for the ZX Spectrum 48K, using NIRVANA+ multicolour display rendering and the ULA beeper for dice sounds.

**This repository includes only v61, the currently approved baseline.** Previous versions and experimental releases are not included.

## Files

- `HexOhm_Tavli48K_v61.tap` — executable tape image for a ZX Spectrum 48K emulator such as Fuse.
- `HexOhm_Tavli48K_v61.asm` — complete editable Z80 game/menu/input/graphics-control source (ORG 43000).
- `HexOhm_Tavli48K_Z80_assembler.py` — Python Z80 assembler used for this source.
- `build.py` — rebuilds `HexOhm_Tavli48K_v61_rebuilt.tap` and checks it exactly matches the bundled v61 TAP.

## Play

Configure your emulator for **ZX Spectrum 48K**, then load `HexOhm_Tavli48K_v61.tap`.

## Rebuild

Requires Python 3, no third-party Python packages:

```bash
python build.py
```

The full tape contains the original loader, NIRVANA+ raster engine and static screen data in separate binary blocks. Those blocks are preserved from the included TAP; only the Z80 program code is reassembled from the `.asm` source.

## Status and distribution

v61 is the user-approved release. Comprehensive testing of gameplay rules across all five variants remains in progress. No licence for third-party NIRVANA+ components is asserted here; please verify applicable redistribution permissions before publishing the repository publicly.
