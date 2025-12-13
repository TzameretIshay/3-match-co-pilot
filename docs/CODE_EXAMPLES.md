# Code Examples & Patterns

## Match Detection Algorithm

### How It Works

```gdscript
func find_matches_with_groups() -> Dictionary:
	# Scan each row for consecutive matching tiles
	for r in range(rows):
		var c = 0
		while c < cols:
			var run_start = c
			var run_length = 1
			
			# Count how many consecutive same-type tiles
			while c + 1 < cols and grid[r][c].tile_type == grid[r][c + 1].tile_type:
				c += 1
				run_length += 1
			
			# If 3+, it's a match!
            if run_length >= 3:
                for i in range(run_start, c + 1):
                    matches.append([r, i])
            c += 1
```

### Example Execution

**Board:**
```
Red  Red  Red  Blue
Blue Blue Green Green
```

**Row 0 scan:**
- c=0: run_start=0, count 3 Red tiles → match! Add [0,0], [0,1], [0,2]
- c=3: run_start=3, count 1 Blue → no match

**Row 1 scan:**
- c=0: run_start=0, count 2 Blue → no match
- c=2: run_start=2, count 2 Green → no match

**Result:** One 3-match at positions [0,0], [0,1], [0,2]

---

## Selection System Example

```gdscript
func _on_tile_clicked(tile: Node) -> void:
    # CLICK 1: No selection yet
    if selected_tile == null:
        selected_tile = tile
        tile.scale = Vector2(1.2, 1.2)  # Highlight
        return
    
    # CLICK 2a: Same tile → deselect
    if tile == selected_tile:
        tile.scale = Vector2(1.0, 1.0)
        selected_tile = null
        return
    
    # CLICK 2b: Different tile → check distance
    var distance = abs(selected_tile.row - tile.row) + abs(selected_tile.col - tile.col)
    
    if distance == 1:
        # Adjacent! Swap it
        await try_swap(selected_tile, tile)
    else:
        # Not adjacent, change selection
        selected_tile.scale = Vector2(1.0, 1.0)
        selected_tile = tile
        tile.scale = Vector2(1.2, 1.2)
```

### Visual Example

```
Grid before clicking:
[R] [G] [B]
[Y] [M] [C]
[R] [G] [B]

Click [R] at (0,0):
[R*][G] [B]     (* = selected, 1.2× scale)
[Y] [M] [C]
[R] [G] [B]

Click [G] at (0,1) (adjacent):
SWAP! Animate both tiles sliding

Click [B] at (0,2) (not adjacent):
[R] [G] [B*]    (* = new selection)
[Y] [M] [C]
[R] [G] [B]
```

---

## Swap Attempt Flow

```gdscript
func try_swap(tile_a: Node, tile_b: Node) -> void:
    moves_left -= 1
    await animate_swap(tile_a, tile_b)
    
    var matches = find_matches_with_groups()["matches"]
    
    if matches.is_empty():
        # No matches found - UNDO the swap!
        await animate_swap(tile_a, tile_b)
        moves_left += 1  # Refund the move
        return
    
    # Matches found - proceed!
    await handle_matches_and_refill()
```

### Timeline Example

```
T=0s:    Player clicks adjacent tiles
         moves_left = 30

T=0.18s: Swap animation completes
         Check for matches
         No matches → animate back

T=0.36s: Swap reverted
         moves_left = 30 (refunded)

OR if matches:

T=0.18s: Swap animation completes
         Check for matches
         Found 3-match!

T=0.18s-0.30s: Pop animation (0.12s)
T=0.30s: Remove tiles
T=0.30s-0.48s: Gravity fall (0.18s)
T=0.48s-0.70s: Refill spawn (0.22s)
T=0.70s: Check for chain reactions
```

---

## Chain Reaction Example

**Initial Board:**
```
[R] [B] [G]
[R] [B] [M]
[R] [G] [M]
```

**Player swaps (0,1) and (1,1):**
```
[R] [B] [G]       [R] [R] [G]
[R] [B] [M]  -->  [R] [B] [M]
[R] [G] [M]       [R] [G] [M]
```

**Step 1: Find matches**
- Column 0: R, R, R = 3-match! Clear
```
[X] [R] [G]
[X] [B] [M]
[X] [G] [M]
```

**Step 2: Apply gravity**
```
[ ] [R] [G]
[ ] [B] [M]
[ ] [G] [M]
```

**Step 3: Refill (random tiles spawn)**
```
[Y] [R] [G]
[C] [B] [M]
[M] [G] [M]
```

**Step 4: Check for NEW matches**
- Column 2: G, M, M = No
- Column 1: R, B, G = No
- Row 2: M, G, M = No

**Result:** Chain reaction ended, back to player

---

## Power-Up Generation

```gdscript
// After clearing tiles, check group length
for tile_data in result["groups"].values():
    if tile_data["length"] >= 4:
        if tile_data["type"] == "horizontal":
            // Clear entire row (8 tiles)
            for extra_c in range(8):
                clear_tile(row, extra_c)
        
        elif tile_data["type"] == "vertical":
            // Clear entire column (8 tiles)
            for extra_r in range(8):
                clear_tile(extra_r, col)
```

### Example

**Match-4 Horizontal:**
```
[R] [R] [R] [R]  <-- 4-match, length=4
[B] [G] [Y] [M]
[C] [R] [G] [B]

Power-up generated! Clear entire row:
[X] [X] [X] [X]
[B] [G] [Y] [M]
[C] [R] [G] [B]
```

**Scoring:** 8 tiles × 10 = 80 points!

---

## Texture Loading Cascade

```gdscript
func spawn_tile(r: int, c: int, type_idx: int) -> Node:
    var tile = tile_scene.instantiate()
    
    # Priority 1: PNG files
    var png_path = "res://assets/tile_%d.png" % type_idx
    if ResourceLoader.exists(png_path):
        tile.texture = load(png_path)
        return tile
    
    # Priority 2: SVG files
    var svg_path = "res://assets/tile_%d.svg" % type_idx
    if ResourceLoader.exists(svg_path):
        tile.texture = load(svg_path)
        return tile
    
    # Priority 3: Procedural generation (cached)
    if not auto_textures.has(type_idx):
        auto_textures[type_idx] = _make_placeholder_texture(type_idx)
    tile.texture = auto_textures[type_idx]
    return tile
```

### Load Order

```
Load tile_0
├─ Check: res://assets/tile_0.png?
│  ├─ YES → Load PNG → Done
│  └─ NO → Continue
├─ Check: res://assets/tile_0.svg?
│  ├─ YES → Load SVG → Done
│  └─ NO → Continue
└─ Generate procedural texture
   ├─ Create 64×64 image
   ├─ Paint base color
   ├─ Paint circle in center
   ├─ Cache in auto_textures[0]
   └─ Done
```

---

## Gravity Simulation

```gdscript
for c in range(cols):
    var write_r = rows - 1  // Bottom position
    
    // Scan from bottom to top
    for read_r in range(rows - 1, -1, -1):
        if grid[read_r][c] != null:
            // Found a tile, move it down
            grid[write_r][c] = grid[read_r][c]
            grid[read_r][c] = null
            write_r -= 1  // Move write position up
    
    // Now fill empty spaces from top with new tiles
    for r in range(write_r, -1, -1):
        grid[r][c] = spawn_new_random_tile()
```

### Visual Example

**Before gravity:**
```
Col 0: [ ], [R], [ ], [B], [G]
```

**After gravity (tiles fall):**
```
Col 0: [ ], [ ], [ ], [R], [B], [G]
```

**After refill (new tiles spawn):**
```
Col 0: [Y], [M], [C], [R], [B], [G]
```

---

## Signal System

### Grid → UI Communication

```gdscript
// Grid.gd
signal score_changed(new_score)
signal moves_changed(remaining_moves)

// When score updates:
score += to_clear.size() * 10
emit_signal("score_changed", score)

// When moves decremented:
moves_left -= 1
emit_signal("moves_changed", moves_left)
```

```gdscript
// UI.gd
func _ready():
    var grid = get_tree().get_current_scene().get_node("Grid")
    grid.connect("score_changed", Callable(self, "_on_score_changed"))
    grid.connect("moves_changed", Callable(self, "_on_moves_changed"))

func _on_score_changed(new_score):
    score_label.text = "Score: %d" % new_score

func _on_moves_changed(remaining_moves):
    moves_label.text = "Moves: %d" % remaining_moves
```

### Flow

```
Grid changes score
    ↓
emit_signal("score_changed", 150)
    ↓
UI._on_score_changed() called
    ↓
score_label.text = "Score: 150"
    ↓
Player sees updated label
```

---

## Tween Animation Example

### Swap Animation

```gdscript
var tween = create_tween()
tween.set_parallel(true)  // Both tiles move at same time
tween.set_trans(Tween.TRANS_SINE)
tween.set_ease(Tween.EASE_IN_OUT)
tween.tween_property(tile_a, "position", target_a, 0.18)
tween.tween_property(tile_b, "position", target_b, 0.18)
await tween.finished
```

**Timeline:**
```
t=0ms:   Both tiles start moving
         tile_a position = current
         tile_b position = current

t=9ms:   Halfway (SINE curve is smooth)
         tile_a position = lerp(start, end, 0.5)
         tile_b position = lerp(start, end, 0.5)

t=18ms:  Animation complete
         tile_a position = target_a
         tile_b position = target_b
         tween.finished signal emitted
         Code continues
```

---

## Main Game Loop

```gdscript
func handle_matches_and_refill(result: Dictionary) -> void:
    // STEP 1: Build list of tiles to clear
    var to_clear = []
    for match in result["matches"]:
        to_clear.append(match)
    
    // STEP 2: Expand for power-ups
    for group in result["groups"]:
        if group.length >= 4:
            expand_clear_set(group, to_clear)
    
    // STEP 3: Pop animation
    for pos in to_clear:
        animate_pop(grid[pos[0]][pos[1]])
    
    // STEP 4: Remove tiles
    for pos in to_clear:
        grid[pos[0]][pos[1]].queue_free()
    
    // STEP 5: Score update
    score += to_clear.size() * 10
    emit_signal("score_changed", score)
    
    // STEP 6: Gravity & Refill
    apply_gravity()
    spawn_new_tiles()
    
    // STEP 7: Check chain reactions
    var new_result = find_matches_with_groups()
    if not new_result["matches"].is_empty():
        await handle_matches_and_refill(new_result)  // Recursive!
```

---

## Common Patterns

### Manhattan Distance (for adjacency)
```gdscript
var distance = abs(pos_a.x - pos_b.x) + abs(pos_a.y - pos_b.y)
if distance == 1:
    print("Adjacent!")
else:
    print("Not adjacent")
```

### Deduplication
```gdscript
var dedup := {}
for match in matches:
    var key = "%d_%d" % [match[0], match[1]]
    dedup[key] = match  // Only unique positions
matches = dedup.values()
```

### Cache Pattern
```gdscript
if not auto_textures.has(type_idx):
    auto_textures[type_idx] = _make_placeholder_texture(type_idx)
return auto_textures[type_idx]  // Reuse
```

---

## Performance Tips

### Why This Code is Fast

1. **Grid is only 8×8 = 64 items max**
   - Match detection: O(8 + 8) = linear
   - Gravity: O(64) = linear

2. **Tween animations use GPU**
   - No manual position calculations
   - Smooth 60 FPS animation

3. **Textures cached after generation**
   - First tile_0: generate (fast)
   - Next tile_0: load from cache (instant)

4. **No physics/collisions**
   - Just simple 2D grid math
   - Instant calculations

### Optimization Ideas

```gdscript
// Could add early exit in match detection:
if matches.size() > 20:
    break  // Large match found, stop scanning

// Could add tile pooling:
func get_tile_from_pool()
    return tile_pool.pop_front()  // Reuse instead of new

// Could add particle effects batching:
var batch_effect = spawn_effect_at_position(x, y)
```

---

## Debug Helper Functions

```gdscript
// Print grid state
func debug_print_grid():
    for r in range(rows):
        var row_str = ""
        for c in range(cols):
            var t = grid[r][c]
            row_str += str(t.tile_type) + " "
        print(row_str)

// Check no matches exist
func debug_assert_no_matches():
    var result = find_matches_with_groups()
    assert(result["matches"].is_empty(), "Board has matches!")

// Verify grid integrity
func debug_verify_grid():
    for r in range(rows):
        for c in range(cols):
            assert(grid[r][c] != null, "Null tile at %d,%d" % [r, c])
            assert(grid[r][c].row == r, "Row mismatch")
            assert(grid[r][c].col == c, "Col mismatch")
```

---

**These examples show the core logic patterns used throughout the game!**
