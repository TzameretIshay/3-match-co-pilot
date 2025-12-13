Godot Match-3 Starter (Godot 4.5.1)

This repository contains a minimal Match-3 starter project intended for Godot 4.5.1.

Contents:
- `scenes/` - TSCN scenes: `Main.tscn`, `Grid.tscn`, `Tile.tscn`, `UI.tscn`.
- `scripts/` - GDScript files: `Grid.gd`, `Tile.gd`, `UI.gd`.
- `assets/` - placeholder folder for tile images and audio.
- `docs/` - markdown explanations of code and changes.

How to open:
1. Open Godot 4.5.1, choose "Import" or "Open" and point to this folder.
2. Open `scenes/Main.tscn` and run the scene.

Notes:
- Placeholder images are referenced as `res://assets/tile_0.png`...`tile_5.png` but not included. Add your own (64x64) PNGs with those names to see tile visuals.
- This starter focuses on core gameplay: grid generation, swap, match detection, gravity and refill. Use the docs in `docs/` to understand the code.
