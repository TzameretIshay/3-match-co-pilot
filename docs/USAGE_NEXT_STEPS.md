Next steps performed and how to test them

What I added in this pass:
- Procedural 64x64 placeholder tile textures generated at runtime when `res://assets/tile_X.png` are not present.
- Tween-based swap animations (using `create_tween`).
- Falling tweens for refill and pop tweens when clearing tiles.
- Basic power-ups:
  - Match of 4 creates a line-clearing power-up (horizontal or vertical depending on match orientation).
  - Match of 5 or more creates a "bomb" type (currently represented by `powerup_type = "bomb"` on the tile).
- Simple audio generator nodes are created to allow adding programmatic beeps if desired (no external WAV files required).

Manual test checklist:
- Open Godot 4.5.1 and run the project `scenes/Main.tscn`.
- Click tiles to swap. Valid swaps animate and if they make matches, tiles pop and the column refills with a falling animation.
- Create a match of 4 or 5 to see a power-up created (the tile scales briefly to indicate power-up). Clearing a power-up expands the cleared area.

If you want I can next:
- Implement distinct visuals for power-ups (overlay icons) and bomb explosion VFX.
- Generate and add real PNG tile assets and WAV files into the `assets/` folder.
- Wire the audio generator to play a short beep on swap/pop events (currently set up but not emitting sounds).

How to generate raster PNGs from the SVG placeholders (automated):

1. In Godot Editor, open this project (Godot 4.5.1).
2. Open the script `tools/generate_tiles.gd` in the Script editor and press the "Run" button (or run EditorScript via the Script -> Execute Editor Script menu). This will create `res://assets/tile_0.png` ... `tile_5.png`.
3. After running, refresh the FileSystem dock in Godot. The new PNGs will be available and the game will prefer them over SVGs.

If you want, I can also generate WAV SFX programmatically and add them into `assets/`.
