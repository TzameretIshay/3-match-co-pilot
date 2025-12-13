Assets placeholder

This folder should contain tile images and sound effects that the game references.

Expected files (place your own art/sfx here):
- `tile_0.png` ... `tile_5.png` (64x64 PNGs recommended)
- `swap.wav` (small click/slide)
- `pop.wav` (short pop sound)
- `match_chain.wav` (pleasant rising tone for combos)

Placeholders included in this repo:
- `tile_0.svg` ... `tile_5.svg` — simple 64x64 SVG tile placeholders.
- `swap.wav`, `pop.wav`, `match_chain.wav` — placeholder text files named as WAVs. Replace with real WAV files (44.1kHz recommended).

Notes:
- The game will procedurally generate textures at runtime if `res://assets/tile_X.png` are not present; SVGs are provided as editable vector placeholders you can convert to PNG if desired.
- For best audio behavior, replace the placeholder `.wav` files with proper WAV files and re-import in Godot.
