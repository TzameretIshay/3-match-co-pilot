# Code explanations — Match-3 Godot 4.5.1 starter

This document explains the main scripts and scene structure added to the project.

Scenes
- `Main.tscn` — Root scene that instantiates the `Grid` and `UI` scenes. Place this at the project root as the main playable scene.
- `Grid.tscn` — Contains a `Node2D` named `Grid` which manages the tile `Node2D` child called `Tiles`. `Grid.gd` is attached and performs game logic.
- `Tile.tscn` — An `Area2D` representing one tile. It has a `Sprite2D` for visuals and a `CollisionShape2D` so clicks are detected.
- `UI.tscn` — A simple `CanvasLayer` UI with `Label`s for score and moves, and a `Button` to restart.

Scripts
- `scripts/Tile.gd`:
  - `extends Area2D` and exposes `tile_type`, plus `row` and `col` indices.
  - Emits `tile_clicked` when the player clicks the tile so `Grid.gd` can handle selection and swaps.
  - `set_tile(type_idx, r, c)` sets internal state. The `Grid` script assigns textures if `res://assets/tile_X.png` exists.

- `scripts/Grid.gd`:
  - Manages a 2D `grid` array of tile nodes and handles spawning, swapping, match detection, clearing, gravity and refilling.
  - Now also generates procedural placeholder textures when `res://assets/tile_X.png` is not present and provides simple generated SFX playback via an `AudioStreamGenerator`.
  - Swap animations use `create_tween()`.
  - Detects match groups and creates simple power-ups for matches of length 4 (line clear) and 5+ (bomb). Power-ups are stored on tiles as `is_powerup` and `powerup_type` and are expanded when cleared.
  - Key constants: `rows`, `cols`, `TILE_TYPES` (default 6), `moves_limit`.
  - `init_grid()` fills board and ensures there are no immediate matches at start.
  - `spawn_tile(r, c, type_idx)` creates a `Tile` instance, positions it, and assigns texture if present.
  - `_on_tile_clicked(tile)` handles tile selection; when two adjacent tiles are selected `try_swap` is invoked.
  - `try_swap(a, b)` swaps the two tiles in the grid, checks for matches and either commits the results or swaps back.
  - `find_matches()` scans rows and columns for runs >= 3 and returns the set of tile positions to clear.
  - `handle_matches_and_refill()` clears matched tiles, awards score, collapses the columns (gravity), spawns new tiles, and repeats while chain matches occur.
  - Signals: `score_changed(new_score)` and `moves_changed(remaining_moves)` are emitted for the UI.

- `scripts/UI.gd`:
  - Connects to `Grid` signals to update UI labels.
  - Connects the `Restart` button to `grid.reset_game()`.

Implementation notes and simplifications
- This starter uses instant swapping and position updates. For better polish, replace the instant position changes with `Tween` or `AnimationPlayer` animations.
- Tile textures are optional — if you add files named `res://assets/tile_0.png`...`tile_5.png` they will be assigned automatically when a tile is spawned.
- Scoring uses simple +10 per tile cleared. You can extend scoring for longer matches and combos.
- Power-ups are not yet fully implemented; the code is structured so you can detect `match length >= 4` and create special tiles.

Compatibility
- The code targets Godot 4.5.1 and uses GDScript 2.0 constructs. If you want Godot 3.5 compatibility, contact me and I can provide a compatibility branch with amended API usages and scene format.

Next steps suggestions
- Add Tween-based animations for swap, pop and gravity.
- Create or import tile PNGs and short sound effects and place them in `assets/`.
- Add a start screen, level progression, and a level objective (target score/time/moves).
