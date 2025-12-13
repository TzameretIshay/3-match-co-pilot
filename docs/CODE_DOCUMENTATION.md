# Match-3 Game Code Documentation

## Overview

This is a complete Match-3 puzzle game implementation in Godot 4.5.1. The game features an 8×8 grid where players swap adjacent tiles to create matches of 3+ identical tiles. Matches clear the tiles, apply gravity, refill from the top, and trigger chain reactions automatically.

---

## Architecture

### Core Components

```
Main.tscn (Root Scene)
├── Grid (Node2D) - Grid.gd
│   ├── Tiles (Node2D) - Container for all tile instances
│   │   ├── Tile instances (instantiated at runtime from Tile.tscn)
└── UI (CanvasLayer) - UI.tscn instance
	├── ScoreLabel, MovesLabel, RestartButton (controlled by UI.gd)
```

### Script Hierarchy

1. **Grid.gd** - Main game engine (375 lines)
   - Manages 8×8 tile grid
   - Handles swapping, match detection, clearing, gravity, refill
   - Implements power-ups and chain reactions
   - Emits signals for UI updates

2. **Tile.gd** - Individual tile behavior (30 lines)
   - Represents a single grid tile
   - Stores tile properties (type, row, col, powerup flags)
   - Emits click signals to Grid

3. **UI.gd** - User interface controller (27 lines)
   - Updates score and moves display
   - Connects to Grid signals
   - Handles restart button

---

## Detailed Script Explanations

### GRID.GD - Game Engine

#### Constants & Variables

```gdscript
const DEFAULT_ROWS: int = 8
const DEFAULT_COLS: int = 8
const TILE_TYPES: int = 6              # Colors: RED, GREEN, BLUE, YELLOW, MAGENTA, CYAN
const MOVE_LIMIT: int = 30

var grid := []                         # 2D array of Tile nodes: grid[row][col]
var score: int = 0                     # Points accumulated
var moves_left: int                    # Remaining player moves
var selected_tile: Node = null         # Currently selected tile (for UI feedback)
```

#### Core Functions

##### `_ready() -> void`
- Called when scene loads
- Initializes game state (moves, score)
- Loads Tile.tscn template
- Sets up audio system
- Calls `init_grid()` to spawn initial board

##### `init_grid() -> void`
- Creates 8×8 grid with random tiles (types 0-5)
- Prevents immediate matches by replacing tiles until grid is clean
- Ensures fair starting position

##### `spawn_tile(r: int, c: int, type_idx: int) -> Node`
- Instantiates a Tile from Tile.tscn
- Positions at grid cell (r, c)
- Assigns texture (priority: PNG > SVG > Procedural)
- Connects click signal to Grid
- Returns tile reference

**Texture Loading Priority:**
```
1. res://assets/tile_0.png, tile_1.png, ... tile_5.png
2. res://assets/tile_0.svg, tile_1.svg, ... tile_5.svg
3. Procedurally generated 64×64 texture (fallback)
```

##### `find_matches_with_groups() -> Dictionary`
- Scans entire grid for matching runs
- Returns:
  ```gdscript
  {
	"matches": [[r,c], [r,c], ...],        # All matched tile positions
	"groups": {tile: {type, length}, ...}  # Run metadata for power-ups
  }
  ```
- **Horizontal scan**: For each row, find consecutive tiles of same type (3+)
- **Vertical scan**: For each column, find consecutive tiles of same type (3+)
- **Deduplication**: Remove duplicate positions (tile can match both H and V)

**Match Detection Logic:**
```
"Red Red Red Blue" → Match [Red, Red, Red]
"Red Blue Red" → No match (not consecutive)
"Red Red Red Red" → Match [Red, Red, Red, Red] → Power-up (4+)
"Red Red Red
 Red Green Blue" → Match [Red, Red, Red] (horizontal 3-run)
```

##### `_on_tile_clicked(tile: Node) -> void`
- **Two-Click Selection System:**
  - **Click 1**: Select a tile (scales up 1.2×)
  - **Click 2a**: Click same tile to deselect (scales back to 1.0×)
  - **Click 2b**: Click adjacent tile to swap
  - **Click 2c**: Click non-adjacent tile to change selection

- **Distance Calculation**: Manhattan distance = |row_a - row_b| + |col_a - col_b|
  - Distance 1 = Adjacent (up/down/left/right)
  - Distance > 1 = Not adjacent

##### `try_swap(tile_a: Node, tile_b: Node) -> void`
- Decrements `moves_left` and emits signal
- Animates swap using tweens
- Checks if swap created matches
- **If no matches**: Reverts swap, refunds move
- **If matches**: Calls `handle_matches_and_refill()`

##### `animate_swap(tile_a: Node, tile_b: Node) -> void`
- Swaps positions in grid array
- Swaps row/col properties on tiles
- Animates both tiles sliding simultaneously (0.18s, SINE easing)
- Awaits completion before returning

##### `handle_matches_and_refill(result: Dictionary) -> void`
**This is the main game loop with 7 steps:**

**Step 1: Build Clear List**
- Collect all matched tile positions into `to_clear` array
- Use deduplication set to avoid duplicates

**Step 2: Power-Up Expansion**
- Check for groups with length ≥ 4
- Mark tiles as power-ups
- **Match-4 Horizontal**: Clear entire row
- **Match-4 Vertical**: Clear entire column
- **Match-5+**: Bomb (clears large area)

**Step 3: Pop Animation**
- Scale all tiles in `to_clear` from 1.0 to 0.1 over 0.12s
- Creates "pop" visual feedback

**Step 4: Remove Tiles**
- Queue freed all cleared tiles
- Set grid positions to null

**Step 5: Update Score**
- Add `to_clear.size() * 10` points
- Emit `score_changed` signal

**Step 6: Gravity & Refill**
- **For each column:**
  - Compact tiles downward (gravity)
  - Animate falling tiles (0.18s)
  - Spawn new random tiles at top
  - Animate new tiles falling (0.22s)

**Step 7: Check Chain Reactions**
- Call `find_matches_with_groups()` again
- If new matches found, recursively call `handle_matches_and_refill()`
- Enables cascading matches automatically

##### `_make_placeholder_texture(type_idx: int) -> ImageTexture`
- Generates 64×64 procedural tile texture
- Background color from palette (indexed by type_idx)
- Lighter circle in center for visual contrast
- Cached in `auto_textures` dict for reuse

##### `reset_game() -> void`
- Called by Restart button
- Clears all tiles from board
- Resets score to 0
- Resets moves_left to moves_limit (30)
- Calls `init_grid()` to spawn new board

---

### TILE.GD - Individual Tile

A simple data container + input handler for each tile.

```gdscript
@export var tile_type: int = 0           # Type 0-5 (determines color)
var row: int = -1                        # Row on grid
var col: int = -1                        # Column on grid
var is_powerup: bool = false             # Is this a power-up?
var powerup_type: String = ""            # "line" or "bomb"

signal tile_clicked(tile)                # Emitted when clicked
```

**Methods:**
- `_ready()`: Ensure sprite is centered
- `set_tile()`: Initialize tile properties
- `_input_event()`: Detect mouse clicks and emit signal

---

### UI.GD - User Interface

Connects Grid signals to UI labels. Signal-driven architecture means no polling needed.

```gdscript
func _ready() -> void:
	# 1. Find Grid node in scene tree
	# 2. Connect to "score_changed" signal → _on_score_changed()
	# 3. Connect to "moves_changed" signal → _on_moves_changed()
	# 4. Connect RestartButton.pressed → grid.reset_game()
```

**Signal Handlers:**
- `_on_score_changed(new_score)`: Update ScoreLabel.text
- `_on_moves_changed(remaining_moves)`: Update MovesLabel.text

---

## Game Flow

### Initialization
```
Scene loads → _ready() → init_grid()
					↓
		   Spawn 8×8 grid with random tiles
					↓
		   While matches exist, replace tiles
					↓
		   Game ready (no matches on board)
```

### Gameplay Loop
```
Player clicks Tile A → _on_tile_clicked()
					↓
		 Tile A selected (scale 1.2×)
					↓
Player clicks Tile B → _on_tile_clicked()
					↓
		 Distance check: is B adjacent to A?
					↓
		 YES: try_swap(A, B) → animate_swap()
					↓
		 Matches? NO: revert swap
					↓
		 Matches? YES: handle_matches_and_refill()
```

### Match Clearing Flow
```
find_matches_with_groups()
		   ↓
Build clear list + check power-ups
		   ↓
Pop animation (0.12s)
		   ↓
Remove tiles + update score
		   ↓
Gravity + Refill (animated)
		   ↓
Check for chain reactions
		   ↓
More matches? YES → repeat
		   ↓
More matches? NO → return to gameplay
```

---

## Key Design Patterns

### 1. Signal-Driven Architecture
- Grid emits `score_changed` and `moves_changed`
- UI connects and updates reactively
- No polling needed

### 2. Tween-Based Animation
- All animations use Godot's Tween system
- Parallel tweens for simultaneous animations
- Easing functions for smooth motion

### 3. Recursive Chain Reactions
- `handle_matches_and_refill()` calls itself recursively
- Base case: no new matches found
- Enables unlimited cascading

### 4. Two-Click Selection
- Clear visual feedback (tile scales up)
- Player has full control over which tiles to swap
- Can deselect and reselect

### 5. Cascading Clearing
- Each cleared tile triggers gravity
- New tiles spawn at top and fall
- Automatically checks for new matches
- Creates satisfying chain reactions

---

## Configuration

### Game Parameters (Editable in Inspector)
```gdscript
@export var rows: int = 8              # Grid height
@export var cols: int = 8              # Grid width
@export var moves_limit: int = 30      # Starting moves
```

### Animation Timings
- Swap: 0.18s (SINE INOUT)
- Pop: 0.12s (SINE IN)
- Fall: 0.18s (SINE OUT)
- Refill: 0.22s (SINE OUT)
- Selection: 0.15s (SINE OUT)

### Scoring
- Points: 10 per tile cleared
- Power-ups: Clear entire row/column (bonus points)

---

## Testing Checklist

- [ ] Grid initializes without immediate matches
- [ ] Tile selection works (click, scales up)
- [ ] Tile deselection works (click same tile)
- [ ] Swap only works with adjacent tiles
- [ ] Swap reverts if no match
- [ ] Matches clear after valid swap
- [ ] Score updates correctly (10 × tiles)
- [ ] Gravity works (tiles fall)
- [ ] Refill works (new tiles spawn)
- [ ] Chain reactions trigger
- [ ] Power-ups generate (match-4+)
- [ ] Power-ups expand clear area (full row/column)
- [ ] Moves counter decreases
- [ ] Restart button resets game
- [ ] Game ends when moves_left = 0

---

## Asset Files

### Required Assets
```
assets/
├── tile_0.png - 64×64 red tile (or auto-generated)
├── tile_1.png - 64×64 green tile
├── tile_2.png - 64×64 blue tile
├── tile_3.png - 64×64 yellow tile
├── tile_4.png - 64×64 magenta tile
├── tile_5.png - 64×64 cyan tile
├── swap.wav - Sound effect for tile swap (optional)
├── pop.wav - Sound effect for tile clear (optional)
└── match_chain.wav - Sound effect for chain reaction (optional)
```

### Fallback Strategy
- If PNG not found → Try SVG
- If SVG not found → Generate procedural texture
- Audio files optional (game works without)

---

## Future Enhancement Ideas

1. **Difficulty Levels**: Adjust move limit based on difficulty
2. **Special Tiles**: 
   - Frozen tiles (need 2 matches to clear)
   - Bonus tiles (worth 2× points)
3. **Visual Effects**: 
   - Particle effects on clear
   - Tile destruction animations
4. **Sound Effects**: 
   - Wire up audio playback to swap/clear/chain events
5. **Leaderboard**: 
   - Save high scores locally
6. **Tutorial**: 
   - In-game tutorial for new players
7. **Animations**: 
   - Tile spin on clear
   - Score popup floating away
8. **Power-Up Visuals**: 
   - Visual indicators for power-ups on tiles
   - Bomb explosion animation

---

## Performance Notes

- Grid is 8×8 = 64 tiles max (very efficient)
- Match detection: O(rows + cols) per scan (linear)
- Tween animations use GPU acceleration
- Procedural textures cached after first generation
- No heavy computations, suitable for mobile

---

## Debugging Tips

1. **Check matches aren't clearing**: Verify `find_matches_with_groups()` logic
2. **Swap not working**: Check adjacent tile detection (Manhattan distance)
3. **Moves not counting**: Verify `moves_left` is being decremented and signal emitted
4. **Chain reactions not triggering**: Check `handle_matches_and_refill()` recursion
5. **Textures not loading**: Check file paths in `spawn_tile()`, check Assets panel
6. **UI not updating**: Verify signal connections in UI.gd `_ready()`

---

## Code Statistics

- **Total Lines**: ~500 (across 3 scripts)
- **Grid.gd**: 400 lines (game logic)
- **Tile.gd**: 30 lines (data + input)
- **UI.gd**: 27 lines (signal handler)
- **Scenes**: Main.tscn, Grid.tscn, Tile.tscn, UI.tscn

---

**Last Updated**: December 13, 2025  
**Godot Version**: 4.5.1  
**Status**: Complete and Playable ✅
