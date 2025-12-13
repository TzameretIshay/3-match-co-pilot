extends Node2D
# GRID.GD - Core Match-3 Game Engine
# ===================================
# This script manages the entire game board, tile management, match detection,
# swapping, clearing, gravity/refill mechanics, chain reactions, and now
# configurable modes (swap/selection/fill) plus a simple board state machine.

# ===== SIGNALS =====
signal score_changed(new_score)
signal moves_changed(remaining_moves)
signal state_changed(previous: int, current: int)
signal swap_accepted(a_pos: Vector2i, b_pos: Vector2i)
signal swap_rejected(a_pos: Vector2i, b_pos: Vector2i)
signal consumed_sequences(sequences)
signal movement_consumed()
signal drag_started(pos: Vector2i)
signal drag_ended(pos: Vector2i)
signal slide_started(pos: Vector2i)
signal slide_ended(pos: Vector2i)

# ===== ENUMS =====
enum SwapMode {
	Adjacent,             # Orthogonal neighbors only
	AdjacentWithDiagonals,# Orthogonal + diagonal neighbors
	Row,                  # Same row swaps only
	Column,               # Same column swaps only
	Cross,                # Orthogonal neighbors; reserved for cross-specific rules
	Free                  # Any two tiles can be swapped
}

enum SelectionMode {
	Click,                # Select first tile, then target tile
	Drag,                 # Drag from a tile to a neighbor
	Slide                 # Slide a tile toward a direction
}

enum FillMode {
	FallDown,             # Standard gravity down
	SideFall,             # Allow diagonal side-fall
	InPlace               # No gravity; refill empties only
}

enum BoardState {
	WaitForInput,
	Consume,
	Fall,
	Fill
}

# ===== EXPORTED VARIABLES (adjustable in Godot Inspector) =====
@export var rows: int = 8
@export var cols: int = 8
@export var moves_limit: int = 30
@export var swap_mode: SwapMode = SwapMode.Adjacent
@export var selection_mode: SelectionMode = SelectionMode.Click
@export var fill_mode: FillMode = FillMode.FallDown
@export var board_config: Match3BoardConfig
@export var debug_mode: bool = false
@export var debug_ui_visible: bool = false
@export var goal_score: int = 1000  # Score needed to win

# ===== GAME CONSTANTS =====
const TILE_TYPES: int = 6             # 6 different tile colors (0-5)

# ===== GAME STATE VARIABLES =====
var grid := []                         # 2D array of Tile nodes [row][col]
var score: int = 0                     # Total score accumulated
var moves_left: int                    # Remaining moves in this game
var rng := RandomNumberGenerator.new() # Random number generator for tile spawning
var selected_tile: Node = null         # Currently selected tile (for UI feedback)
var current_state: BoardState = BoardState.WaitForInput
var _selected_pos: Vector2i = Vector2i(-1, -1) # Click-mode selection anchor

# ===== ASSET & ANIMATION VARIABLES =====
var tile_scene: PackedScene            # Tile.tscn template for instantiation
var auto_textures := {}                # Cache for generated placeholder textures
var particle_scene: PackedScene        # Match particle effect template

var default_rules := [
	Match3BoardConfig.Match3Rule.new("Horizontal", 4, false, 1, "line"),
	Match3BoardConfig.Match3Rule.new("Vertical", 4, false, 1, "line"),
	Match3BoardConfig.Match3Rule.new("Horizontal", 5, false, 2, "bomb"),
	Match3BoardConfig.Match3Rule.new("Vertical", 5, false, 2, "bomb"),
	Match3BoardConfig.Match3Rule.new("TShape", 4, false, 3, "bomb"),
	Match3BoardConfig.Match3Rule.new("LShape", 4, false, 3, "bomb")
]

var audio_player: AudioStreamPlayer
var audio_generator: AudioStreamGenerator
var sfx_match: AudioStreamPlayer
var sfx_swap: AudioStreamPlayer
var sfx_booster: AudioStreamPlayer

var debug_ui: Node = null
var selected_booster: String = ""
var selected_booster_tile: Node = null
var booster_in_progress: bool = false
var run_boosters: Array = []
var booster_inventory: Dictionary = {}  # {"booster_key": uses_remaining}
var booster_ui: Node = null  # In-game booster panel
var game_over_scene: PackedScene

func set_state(next: BoardState) -> void:
	if current_state == next:
		return
	var prev := current_state
	current_state = next
	state_changed.emit(prev, current_state)

func _ready() -> void:
	set_state(BoardState.WaitForInput)
	# Initialize game state
	rng.randomize()
	moves_left = moves_limit
	emit_signal("moves_changed", moves_left)

	if board_config == null:
		board_config = Match3BoardConfig.new()
		board_config.default_if_empty()
	if board_config.rules.is_empty():
		board_config.rules = default_rules.duplicate(true)
	
	# Load Tile.tscn template scene for instantiation
	tile_scene = load("res://scenes/Tile.tscn")
	particle_scene = load("res://scenes/MatchParticles.tscn")
	game_over_scene = load("res://scenes/GameOverScreen.tscn")
	
	# Setup audio (currently unused, but ready for SFX)
	audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = 44100
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_generator
	add_child(audio_player)
	
	# Setup sound effect players
	sfx_match = AudioStreamPlayer.new()
	sfx_swap = AudioStreamPlayer.new()
	sfx_booster = AudioStreamPlayer.new()
	add_child(sfx_match)
	add_child(sfx_swap)
	add_child(sfx_booster)
	
	# Spawn initial 8x8 grid ensuring no immediate matches
	init_grid()
	
	# Setup debug UI if enabled
	if debug_mode:
		_setup_debug_ui()

func init_grid() -> void:
	# Clear any previous grid
	grid = []
	
	# Spawn tiles and add to grid array
	for r in range(rows):
		grid.append([])
		for c in range(cols):
			var t = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
			grid[r].append(t)
	
	# Ensure no immediate matches by replacing until clear
	# (prevents unfair starting position where matches are ready without user action)
	while true:
		var result = find_matches_with_groups()
		var matches = result["matches"]
		if matches.is_empty():
			break
		for matched in matches:
			var mr = matched[0]
			var mc = matched[1]
			var t = grid[mr][mc]
			replace_tile(mr, mc, rng.randi_range(0, TILE_TYPES - 1))

func spawn_tile(r: int, c: int, type_idx: int) -> Node:
	# Instantiate a new Tile from Tile.tscn
	var tile = tile_scene.instantiate()
	$Tiles.add_child(tile)
	
	# Set position (64x64 pixel tiles on grid)
	tile.position = Vector2(c * 64, r * 64)
	
	# Initialize tile properties (type, row, col, powerup flags)
	tile.set_tile(type_idx, r, c)
	
	# Try to assign texture in priority order: PNG > SVG > Procedural
	var png_path = "res://assets/tile_%d.png" % type_idx
	var svg_path = "res://assets/tile_%d.svg" % type_idx
	
	if ResourceLoader.exists(png_path):
		var tex = load(png_path)
		if tex and tile.has_node("Sprite"):
			tile.get_node("Sprite").texture = tex
	elif ResourceLoader.exists(svg_path):
		var tex2 = load(svg_path)
		if tex2 and tile.has_node("Sprite"):
			tile.get_node("Sprite").texture = tex2
	else:
		# Fallback: generate procedural texture (colored square with circle)
		if not auto_textures.has(type_idx):
			auto_textures[type_idx] = _make_placeholder_texture(type_idx)
		if tile.has_node("Sprite"):
			tile.get_node("Sprite").texture = auto_textures[type_idx]
	
	# Connect tile's click signal to grid's handler
	tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
	tile.connect("tile_dragged", Callable(self, "_on_tile_dragged"))
	return tile

func replace_tile(r: int, c: int, type_idx: int) -> void:
	# Remove old tile
	var old_tile = grid[r][c]
	if old_tile:
		old_tile.queue_free()
	
	# Spawn new tile (used during init to prevent matches)
	var new_tile = spawn_tile(r, c, type_idx)
	grid[r][c] = new_tile

func find_matches_with_groups() -> Dictionary:
	# Scan grid for runs of 3+ identical tiles (horizontal/vertical/diagonal) and detect T/L intersections.
	var matches := []
	var groups := {}
	var sequences := []
	var visited := {}
	var horizontal_runs := []
	var vertical_runs := []

	# ===== HORIZONTAL SCAN =====
	for r in range(rows):
		var c = 0
		while c < cols:
			if grid[r][c] == null:
				c += 1
				continue
			var run_start = c
			var run_length = 1
			while c + 1 < cols and grid[r][c + 1] != null and grid[r][c].tile_type == grid[r][c + 1].tile_type:
				c += 1
				run_length += 1
			if run_length >= 3:
				var run_group = []
				var run_cells: Array[Vector2i] = []
				for i in range(run_start, c + 1):
					var tile = grid[r][i]
					matches.append([r, i])
					run_group.append(tile)
					run_cells.append(Vector2i(i, r))
					if not visited.has(tile):
						visited[tile] = true
				groups[run_group[0]] = {"type": "horizontal", "length": run_length}
				horizontal_runs.append({"cells": run_cells, "length": run_length})
				sequences.append({"shape": "Horizontal", "cells": run_cells, "length": run_length})
			c += 1

	# ===== VERTICAL SCAN =====
	for c in range(cols):
		var r = 0
		while r < rows:
			if grid[r][c] == null:
				r += 1
				continue
			var run_start = r
			var run_length = 1
			while r + 1 < rows and grid[r + 1][c] != null and grid[r][c].tile_type == grid[r + 1][c].tile_type:
				r += 1
				run_length += 1
			if run_length >= 3:
				var run_group = []
				var run_cells: Array[Vector2i] = []
				for i in range(run_start, r + 1):
					var tile = grid[i][c]
					matches.append([i, c])
					run_group.append(tile)
					run_cells.append(Vector2i(c, i))
					if not visited.has(tile):
						visited[tile] = true
				groups[run_group[0]] = {"type": "vertical", "length": run_length}
				vertical_runs.append({"cells": run_cells, "length": run_length})
				sequences.append({"shape": "Vertical", "cells": run_cells, "length": run_length})
			r += 1

	# ===== DIAGONAL SCANS (simple) =====
	for r in range(rows):
		for c in range(cols):
			var diag_cells1: Array[Vector2i] = []
			var rr = r
			var cc = c
			while rr + 1 < rows and cc + 1 < cols and grid[rr][cc] != null and grid[rr + 1][cc + 1] != null and grid[rr][cc].tile_type == grid[rr + 1][cc + 1].tile_type:
				diag_cells1.append(Vector2i(cc, rr))
				rr += 1
				cc += 1
			if diag_cells1.size() >= 2:
				diag_cells1.append(Vector2i(cc, rr))
				if diag_cells1.size() >= 3:
					for cell in diag_cells1:
						matches.append([cell.y, cell.x])
					sequences.append({"shape": "Diagonal", "cells": diag_cells1.duplicate(), "length": diag_cells1.size()})
			var diag_cells2: Array[Vector2i] = []
			rr = r
			cc = c
			while rr + 1 < rows and cc - 1 >= 0 and grid[rr][cc] != null and grid[rr + 1][cc - 1] != null and grid[rr][cc].tile_type == grid[rr + 1][cc - 1].tile_type:
				diag_cells2.append(Vector2i(cc, rr))
				rr += 1
				cc -= 1
			if diag_cells2.size() >= 2:
				diag_cells2.append(Vector2i(cc, rr))
				if diag_cells2.size() >= 3:
					for cell in diag_cells2:
						matches.append([cell.y, cell.x])
					sequences.append({"shape": "Diagonal", "cells": diag_cells2.duplicate(), "length": diag_cells2.size()})

	# ===== T / L SHAPE DETECTION =====
	for h_run in horizontal_runs:
		for v_run in vertical_runs:
			for h_cell in h_run["cells"]:
				if v_run["cells"].has(h_cell):
					var combined: Array[Vector2i] = h_run["cells"].duplicate()
					for vc in v_run["cells"]:
						if not combined.has(vc):
							combined.append(vc)
					var h_first = h_run["cells"][0]
					var h_last = h_run["cells"][h_run["cells"].size() - 1]
					var v_first = v_run["cells"][0]
					var v_last = v_run["cells"][v_run["cells"].size() - 1]
					var shape_name := "TShape"
					if (h_cell == h_first or h_cell == h_last) and (h_cell == v_first or h_cell == v_last):
						shape_name = "LShape"
					sequences.append({"shape": shape_name, "cells": combined, "length": combined.size()})
					for cc in combined:
						matches.append([cc.y, cc.x])

	# ===== DEDUPLICATION =====
	var dedup := {}
	for match in matches:
		var key = "%d_%d" % [match[0], match[1]]
		dedup[key] = match
	matches = dedup.values()

	# ===== EXPAND MATCHES WITH ADJACENT SAME-COLOR TILES =====
	matches = _expand_matches_with_adjacent(matches)

	return {"matches": matches, "groups": groups, "sequences": sequences}

func _expand_matches_with_adjacent(initial_matches: Array) -> Array:
	# Expand matched tiles to include adjacent same-color tiles using flood-fill
	var matched_set := {}
	var to_process := []
	
	# Initialize with all matched positions
	for match_pos in initial_matches:
		var key = "%d_%d" % [match_pos[0], match_pos[1]]
		matched_set[key] = match_pos
		to_process.append(match_pos)
	
	# Flood-fill: check all 4 directions for same-color neighbors
	while to_process.size() > 0:
		var current = to_process.pop_back()
		var r = current[0]
		var c = current[1]
		
		if r < 0 or r >= rows or c < 0 or c >= cols:
			continue
		if grid[r][c] == null:
			continue
		
		var current_color = grid[r][c].tile_type
		var directions = [[0, 1], [0, -1], [1, 0], [-1, 0]]  # right, left, down, up
		
		for dir in directions:
			var nr = r + dir[0]
			var nc = c + dir[1]
			var key = "%d_%d" % [nr, nc]
			
			if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
				continue
			if matched_set.has(key):
				continue
			if grid[nr][nc] == null:
				continue
			
			if grid[nr][nc].tile_type == current_color:
				matched_set[key] = [nr, nc]
				to_process.append([nr, nc])
	
	return matched_set.values()

func _on_tile_clicked(tile: Node) -> void:
	# Handle tile selection and swapping based on selection_mode and swap_mode
	if current_state != BoardState.WaitForInput:
		return
	if moves_left <= 0:
		return

	# If in debug mode and no game selection, allow booster tile selection
	if debug_mode and selected_tile == null and selected_booster_tile == null:
		selected_booster_tile = tile
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_booster_tile, "scale", Vector2(1.3, 1.3), 0.15)
		print("DEBUG: Selected tile at [%d, %d] for booster" % [tile.row, tile.col])
		return

	# Deselect booster tile if clicking it again
	if debug_mode and selected_booster_tile == tile:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_booster_tile, "scale", Vector2(1.0, 1.0), 0.15)
		selected_booster_tile = null
		print("DEBUG: Deselected booster tile")
		return

	if selection_mode != SelectionMode.Click:
		# Drag/Slide hooks will be added in later phases
		return

	# ===== CLICK 1: SELECT A TILE =====
	if selected_tile == null:
		selected_tile = tile
		_selected_pos = Vector2i(tile.col, tile.row)
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_tile, "scale", Vector2(1.2, 1.2), 0.15)
		return

	# ===== CLICK 2A: DESELECT (click same tile) =====
	if tile == selected_tile:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_tile, "scale", Vector2(1.0, 1.0), 0.15)
		selected_tile = null
		_selected_pos = Vector2i(-1, -1)
		return

	# ===== CLICK 2B: ATTEMPT SWAP (mode-aware) =====
	var a_pos = Vector2i(selected_tile.col, selected_tile.row)
	var b_pos = Vector2i(tile.col, tile.row)

	if can_swap_positions(a_pos, b_pos):
		var temp_selected = selected_tile
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(temp_selected, "scale", Vector2(1.0, 1.0), 0.15)
		await tween.finished
		selected_tile = null
		_selected_pos = Vector2i(-1, -1)
		swap_accepted.emit(a_pos, b_pos)
		set_state(BoardState.Consume)
		await try_swap(temp_selected, tile)
	else:
		swap_rejected.emit(a_pos, b_pos)
		var old_selected = selected_tile
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(old_selected, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.15)
		await tween.finished
		selected_tile = tile
		_selected_pos = Vector2i(tile.col, tile.row)

func _on_tile_dragged(tile: Node, direction: Vector2) -> void:
	if current_state != BoardState.WaitForInput:
		return
	if moves_left <= 0:
		return
	if selection_mode not in [SelectionMode.Drag, SelectionMode.Slide]:
		return

	var a_pos = Vector2i(tile.col, tile.row)
	var dir := Vector2i(int(sign(direction.x)), int(sign(direction.y)))
	if dir == Vector2i.ZERO:
		return
	var b_pos = a_pos + dir
	if not _in_bounds(b_pos):
		swap_rejected.emit(a_pos, b_pos)
		return
	var target_tile: Node = grid[b_pos.y][b_pos.x]
	if target_tile == null:
		swap_rejected.emit(a_pos, b_pos)
		return
	if not can_swap_positions(a_pos, b_pos):
		swap_rejected.emit(a_pos, b_pos)
		return

	if selection_mode == SelectionMode.Drag:
		drag_started.emit(a_pos)
		swap_accepted.emit(a_pos, b_pos)
		set_state(BoardState.Consume)
		await try_swap(tile, target_tile)
		drag_ended.emit(b_pos)
	elif selection_mode == SelectionMode.Slide:
		slide_started.emit(a_pos)
		swap_accepted.emit(a_pos, b_pos)
		set_state(BoardState.Consume)
		await try_swap(tile, target_tile)
		slide_ended.emit(b_pos)

func try_swap(tile_a: Node, tile_b: Node) -> void:
	# Attempt a swap between two tiles
	# If no matches result, revert swap and refund move
	# Otherwise, handle clearing and cascading matches

	# Decrement moves
	moves_left -= 1
	emit_signal("moves_changed", moves_left)
	movement_consumed.emit()
	
	# Animate swap
	await animate_swap(tile_a, tile_b)
	
	# Check if swap created any matches
	var result = find_matches_with_groups()
	var matches = result["matches"]
	
	if matches.is_empty():
		# No matches: revert swap
		await animate_swap(tile_a, tile_b)
		moves_left += 1  # Refund the move
		emit_signal("moves_changed", moves_left)
		set_state(BoardState.WaitForInput)
		return
	
	# Matches found: proceed with clearing and refilling
	await handle_matches_and_refill(result)

func animate_swap(tile_a: Node, tile_b: Node) -> void:
	# Swap positions in grid and animate tiles sliding 0.18s
	var row_a = tile_a.row
	var col_a = tile_a.col
	var row_b = tile_b.row
	var col_b = tile_b.col
	
	# Swap grid references
	grid[row_a][col_a] = tile_b
	grid[row_b][col_b] = tile_a
	
	# Update tile's row/col properties
	tile_a.row = row_b
	tile_a.col = col_b
	tile_b.row = row_a
	tile_b.col = col_a
	
	# Calculate target positions (64x64 pixels per tile)
	var target_a = Vector2(col_b * 64, row_b * 64)
	var target_b = Vector2(col_a * 64, row_a * 64)
	
	# Animate both tiles simultaneously (parallel)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile_a, "position", target_a, 0.18)
	tween.tween_property(tile_b, "position", target_b, 0.18)
	_play_swap_sound()
	await tween.finished

func handle_matches_and_refill(result: Dictionary) -> void:
	# Clear matches -> apply gravity/fill according to fill_mode -> cascade
	set_state(BoardState.Consume)

	var to_clear = []
	var to_clear_set = {}
	var sequences: Array = result.get("sequences", [])

	for match in result["matches"]:
		var r = match[0]
		var c = match[1]
		var key = "%d_%d" % [r, c]
		if not to_clear_set.has(key):
			to_clear_set[key] = true
			to_clear.append([r, c])

	_apply_rules(sequences, to_clear, to_clear_set)
	consumed_sequences.emit(sequences)

	# Pop animation
	var pop_tweens = []
	for tile_data in to_clear:
		var tr = tile_data[0]
		var tc = tile_data[1]
		var t = grid[tr][tc]
		if t:
			_spawn_match_particles(t.position, t.tile_type)
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN)
			tween.tween_property(t, "scale", Vector2(0.1, 0.1), 0.12)
			pop_tweens.append(tween)

	if pop_tweens.size() > 0:
		await pop_tweens[0].finished

	# Remove tiles
	for tile_data in to_clear:
		var tr = tile_data[0]
		var tc = tile_data[1]
		var t = grid[tr][tc]
		if t:
			t.queue_free()
			grid[tr][tc] = null

	# Update score
	score += to_clear.size() * 10
	emit_signal("score_changed", score)
	_play_match_sound(to_clear.size())

	# Gravity & refill according to fill_mode
	set_state(BoardState.Fall)
	var fall_tweens = []

	match fill_mode:
		FillMode.InPlace:
			# No gravity; just refill empties in place
			for r in range(rows):
				for c in range(cols):
					if grid[r][c] == null:
						var new_tile = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
						new_tile.position = Vector2(c * 64, r * 64)
						grid[r][c] = new_tile
		FillMode.FallDown, FillMode.SideFall:
			for c in range(cols):
				var write_r = rows - 1
				for read_r in range(rows - 1, -1, -1):
					if grid[read_r][c] != null:
						var t = grid[read_r][c]
						grid[write_r][c] = t
						t.row = write_r
						var target_y = write_r * 64
						var tween = create_tween()
						tween.set_trans(Tween.TRANS_SINE)
						tween.set_ease(Tween.EASE_OUT)
						tween.tween_property(t, "position", Vector2(t.position.x, target_y), 0.18)
						fall_tweens.append(tween)
						write_r -= 1
				# Spawn new tiles above
				for r in range(write_r, -1, -1):
					var new_type = rng.randi_range(0, TILE_TYPES - 1)
					var new_tile = spawn_tile(r, c, new_type)
					new_tile.position = Vector2(c * 64, -64)
					grid[r][c] = new_tile
					var target_y = r * 64
					var tween2 = create_tween()
					tween2.set_trans(Tween.TRANS_SINE)
					tween2.set_ease(Tween.EASE_OUT)
					tween2.tween_property(new_tile, "position", Vector2(c * 64, target_y), 0.22)
					fall_tweens.append(tween2)
			if fill_mode == FillMode.SideFall:
				_side_fall_pass(fall_tweens)

	if fall_tweens.size() > 0:
		await fall_tweens[0].finished

	set_state(BoardState.Fill)

	# Check for cascades
	var new_result = find_matches_with_groups()
	if not new_result["matches"].is_empty():
		await handle_matches_and_refill(new_result)
	else:
		set_state(BoardState.WaitForInput)
		_check_game_over()

func apply_booster_clear(destroy_list: Array) -> void:
	# Clear arbitrary positions (from boosters), then apply gravity/refill and cascades
	if destroy_list.is_empty():
		return
	set_state(BoardState.Consume)

	var to_clear = []
	var to_clear_set = {}
	for pos in destroy_list:
		if pos is Array and pos.size() >= 2:
			var r = int(pos[0])
			var c = int(pos[1])
			var key = "%d_%d" % [r, c]
			if not to_clear_set.has(key):
				to_clear_set[key] = true
				to_clear.append([r, c])

	var pop_tweens = []
	for tile_data in to_clear:
		var tr = tile_data[0]
		var tc = tile_data[1]
		if tr >= 0 and tr < rows and tc >= 0 and tc < cols:
			var t = grid[tr][tc]
			if t:
				var tween = create_tween()
				tween.set_trans(Tween.TRANS_SINE)
				tween.set_ease(Tween.EASE_IN)
				tween.tween_property(t, "scale", Vector2(0.1, 0.1), 0.12)
				pop_tweens.append(tween)

	if pop_tweens.size() > 0:
		await pop_tweens[0].finished

	for tile_data in to_clear:
		var tr = tile_data[0]
		var tc = tile_data[1]
		if tr >= 0 and tr < rows and tc >= 0 and tc < cols:
			var t = grid[tr][tc]
			if t:
				t.queue_free()
				grid[tr][tc] = null

	score += to_clear.size() * 10
	emit_signal("score_changed", score)

	var fall_tweens = []
	match fill_mode:
		FillMode.InPlace:
			for r in range(rows):
				for c in range(cols):
					if grid[r][c] == null:
						var new_tile = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
						new_tile.position = Vector2(c * 64, r * 64)
						grid[r][c] = new_tile
		FillMode.FallDown, FillMode.SideFall:
			for c in range(cols):
				var write_r = rows - 1
				for read_r in range(rows - 1, -1, -1):
					if grid[read_r][c] != null:
						var t = grid[read_r][c]
						grid[write_r][c] = t
						t.row = write_r
						var target_y = write_r * 64
						var tween = create_tween()
						tween.set_trans(Tween.TRANS_SINE)
						tween.set_ease(Tween.EASE_OUT)
						tween.tween_property(t, "position", Vector2(t.position.x, target_y), 0.18)
						fall_tweens.append(tween)
						write_r -= 1
				for r in range(write_r, -1, -1):
					var new_type = rng.randi_range(0, TILE_TYPES - 1)
					var new_tile = spawn_tile(r, c, new_type)
					new_tile.position = Vector2(c * 64, -64)
					grid[r][c] = new_tile
					var target_y2 = r * 64
					var tween2 = create_tween()
					tween2.set_trans(Tween.TRANS_SINE)
					tween2.set_ease(Tween.EASE_OUT)
					tween2.tween_property(new_tile, "position", Vector2(c * 64, target_y2), 0.22)
					fall_tweens.append(tween2)
			if fill_mode == FillMode.SideFall:
				_side_fall_pass(fall_tweens)

	if fall_tweens.size() > 0:
		await fall_tweens[0].finished

	set_state(BoardState.Fill)

	var new_result = find_matches_with_groups()
	if not new_result["matches"].is_empty():
		await handle_matches_and_refill(new_result)
	else:
		set_state(BoardState.WaitForInput)
		_check_game_over()

func _side_fall_pass(fall_tweens: Array) -> void:
	# Allow diagonal pulls into gaps for SideFall mode
	var changed := true
	while changed:
		changed = false
		for r in range(rows - 1, -1, -1):
			for c in range(cols):
				if grid[r][c] != null:
					continue
				var source_row: int = r - 1
				for offset in [-1, 1]:
					var source_col: int = c + offset
					if source_row < 0 or source_col < 0 or source_col >= cols:
						continue
					if grid[source_row][source_col] == null:
						continue
					var t = grid[source_row][source_col]
					grid[source_row][source_col] = null
					grid[r][c] = t
					t.row = r
					t.col = c
					var target_pos = Vector2(c * 64, r * 64)
					var tween = create_tween()
					tween.set_trans(Tween.TRANS_SINE)
					tween.set_ease(Tween.EASE_OUT)
					tween.tween_property(t, "position", target_pos, 0.14)
					fall_tweens.append(tween)
					changed = true
					break

func _apply_rules(sequences: Array, to_clear: Array, to_clear_set: Dictionary) -> void:
	if board_config == null:
		return
	var rules: Array = board_config.rules
	if rules.is_empty():
		rules = default_rules
	# Sort by priority descending
	rules.sort_custom(func(a, b): return a.priority > b.priority)

	for seq in sequences:
		var length: int = seq.get("length", seq.get("cells", []).size())
		var shape: String = seq.get("shape", "")
		var cells: Array = seq.get("cells", [])
		if cells.is_empty():
			continue
		for rule in rules:
			if rule.shape != shape:
				continue
			if rule.strict_size and length != rule.min_size:
				continue
			if not rule.strict_size and length < rule.min_size:
				continue
			var spawn_cell: Vector2i = _pick_spawn_cell(cells)
			if spawn_cell == Vector2i(-1, -1):
				continue
			var r := spawn_cell.y
			var c := spawn_cell.x
			var tile = grid[r][c]
			if tile:
				tile.is_powerup = rule.piece_to_spawn != ""
				tile.powerup_type = String(rule.piece_to_spawn)
			_add_area_for_rule(rule, spawn_cell, to_clear, to_clear_set)
			break

func _pick_spawn_cell(cells: Array) -> Vector2i:
	if cells.is_empty():
		return Vector2i(-1, -1)
	var idx := cells.size() / 2
	var cell = cells[idx]
	if typeof(cell) == TYPE_VECTOR2I:
		return cell
	return Vector2i(-1, -1)

func _add_area_for_rule(rule: Match3BoardConfig.Match3Rule, anchor: Vector2i, to_clear: Array, to_clear_set: Dictionary) -> void:
	var r = anchor.y
	var c = anchor.x
	match String(rule.piece_to_spawn):
		"line":
			for cc in range(cols):
				var k = "%d_%d" % [r, cc]
				if not to_clear_set.has(k):
					to_clear_set[k] = true
					to_clear.append([r, cc])
			for rr in range(rows):
				var k2 = "%d_%d" % [rr, c]
				if not to_clear_set.has(k2):
					to_clear_set[k2] = true
					to_clear.append([rr, c])
		"bomb":
			for rr in range(max(0, r - 1), min(rows, r + 2)):
				for cc in range(max(0, c - 1), min(cols, c + 2)):
					var k = "%d_%d" % [rr, cc]
					if not to_clear_set.has(k):
						to_clear_set[k] = true
						to_clear.append([rr, cc])
		_:
			# Default: clear the matched cells only
			var kdef = "%d_%d" % [r, c]
			if not to_clear_set.has(kdef):
				to_clear_set[kdef] = true
				to_clear.append([r, c])

# ===== FINDER HELPERS =====
func get_cell(pos: Vector2i) -> Node:
	if not _in_bounds(pos):
		return null
	return grid[pos.y][pos.x]

func neighbours_of(pos: Vector2i) -> Dictionary:
	return {
		"up": get_cell(Vector2i(pos.x, pos.y - 1)),
		"down": get_cell(Vector2i(pos.x, pos.y + 1)),
		"left": get_cell(Vector2i(pos.x - 1, pos.y)),
		"right": get_cell(Vector2i(pos.x + 1, pos.y))
	}

func diagonal_neighbours_of(pos: Vector2i) -> Dictionary:
	return {
		"top_left": get_cell(Vector2i(pos.x - 1, pos.y - 1)),
		"top_right": get_cell(Vector2i(pos.x + 1, pos.y - 1)),
		"bottom_left": get_cell(Vector2i(pos.x - 1, pos.y + 1)),
		"bottom_right": get_cell(Vector2i(pos.x + 1, pos.y + 1))
	}

func row_cells(row: int) -> Array:
	if row < 0 or row >= rows:
		return []
	var cells: Array = []
	for c in range(cols):
		cells.append(grid[row][c])
	return cells

func column_cells(col: int) -> Array:
	if col < 0 or col >= cols:
		return []
	var cells: Array = []
	for r in range(rows):
		cells.append(grid[r][col])
	return cells

func empty_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(rows):
		for c in range(cols):
			if grid[r][c] == null:
				out.append(Vector2i(c, r))
	return out

func _setup_booster_ui() -> void:
	# Remove old booster UI if it exists
	if booster_ui != null:
		booster_ui.queue_free()
		booster_ui = null
	
	if run_boosters.is_empty():
		return
	
	var ui_container = Control.new()
	ui_container.anchor_left = 1.0
	ui_container.anchor_top = 0.0
	ui_container.offset_left = -200
	ui_container.offset_right = 0
	ui_container.offset_bottom = 400
	add_child(ui_container)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	ui_container.add_child(vbox)

	var title = Label.new()
	title.text = "BOOSTERS"
	title.custom_minimum_size = Vector2(200, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var booster_labels = {
		"color_bomb": "Color Bomb",
		"striped": "Striped",
		"bomb": "Bomb",
		"seeker": "Seeker",
		"roller": "Roller",
		"hammer": "Hammer",
		"free_swap": "Free Swap",
		"brush": "Brush",
		"ufo": "UFO"
	}

	for booster_key in run_boosters:
		var btn = Button.new()
		var label = booster_labels.get(booster_key, booster_key)
		var uses = booster_inventory.get(booster_key, 0)
		btn.text = "%s (%d)" % [label, uses]
		btn.name = "btn_" + booster_key
		btn.custom_minimum_size = Vector2(200, 50)
		btn.disabled = uses <= 0
		btn.pressed.connect(_on_booster_ui_pressed.bind(booster_key))
		vbox.add_child(btn)

	booster_ui = ui_container

func _setup_debug_ui() -> void:
	var ui_container = Control.new()
	ui_container.anchor_left = 1.0
	ui_container.anchor_top = 0.0
	ui_container.offset_left = -250
	ui_container.offset_right = 0
	ui_container.offset_bottom = 800
	add_child(ui_container)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	ui_container.add_child(vbox)

	var title = Label.new()
	title.text = "DEBUG BOOSTERS"
	title.custom_minimum_size = Vector2(250, 30)
	vbox.add_child(title)

	var boosters = [
		["Color Bomb", "color_bomb"],
		["Striped", "striped"],
		["Bomb", "bomb"],
		["Seeker", "seeker"],
		["Roller", "roller"],
		["Hammer", "hammer"],
		["Free Swap", "free_swap"],
		["Brush", "brush"],
		["UFO", "ufo"]
	]

	for booster_name in boosters:
		var btn = Button.new()
		btn.text = booster_name[0]
		btn.custom_minimum_size = Vector2(250, 40)
		btn.pressed.connect(_on_debug_booster_pressed.bindv([booster_name[1]]))
		vbox.add_child(btn)

	debug_ui = ui_container

func _on_booster_ui_pressed(booster_key: String) -> void:
	if booster_in_progress:
		print("Booster already in use, wait...")
		return
	if current_state != BoardState.WaitForInput:
		print("Cannot use booster during board animation")
		return
	
	var uses = booster_inventory.get(booster_key, 0)
	if uses <= 0:
		print("No uses remaining for %s" % booster_key)
		return
	
	# Consume one use
	booster_inventory[booster_key] = uses - 1
	_update_booster_ui()
	
	# Trigger booster at a random tile (or first valid tile)
	var target_tile = _find_valid_booster_target()
	if target_tile == null:
		print("No valid target for booster")
		return
	
	booster_in_progress = true
	await _trigger_booster_on_tile(target_tile, booster_key)
	booster_in_progress = false

func _find_valid_booster_target() -> Node:
	# Find first non-null tile for booster application
	for r in range(rows):
		for c in range(cols):
			if grid[r][c] != null:
				return grid[r][c]
	return null

func _update_booster_ui() -> void:
	if booster_ui == null:
		return
	var booster_labels = {
		"color_bomb": "Color Bomb",
		"striped": "Striped",
		"bomb": "Bomb",
		"seeker": "Seeker",
		"roller": "Roller",
		"hammer": "Hammer",
		"free_swap": "Free Swap",
		"brush": "Brush",
		"ufo": "UFO"
	}
	# Find VBoxContainer child
	var vbox = null
	for child in booster_ui.get_children():
		if child is VBoxContainer:
			vbox = child
			break
	
	if vbox == null:
		return
	
	# Update button texts for each booster
	for booster_key in run_boosters:
		var btn = vbox.get_node_or_null("btn_" + booster_key)
		if btn:
			var label = booster_labels.get(booster_key, booster_key)
			var uses = booster_inventory.get(booster_key, 0)
			btn.text = "%s (%d)" % [label, uses]
			btn.disabled = uses <= 0

func _trigger_booster_on_tile(tile: Node, booster_key: String) -> void:
	var booster_enum = Booster.BoosterType.Striped
	match booster_key:
		"color_bomb": booster_enum = Booster.BoosterType.ColorBomb
		"striped": booster_enum = Booster.BoosterType.Striped
		"bomb": booster_enum = Booster.BoosterType.Bomb
		"seeker": booster_enum = Booster.BoosterType.Seeker
		"roller": booster_enum = Booster.BoosterType.Roller
		"hammer": booster_enum = Booster.BoosterType.Hammer
		"free_swap": booster_enum = Booster.BoosterType.FreeSwap
		"brush": booster_enum = Booster.BoosterType.Brush
		"ufo": booster_enum = Booster.BoosterType.UFO
	
	var booster = Booster.new(booster_enum, tile, self)
	_play_booster_sound()
	await booster.trigger()
	print("Booster %s activated at [%d, %d]" % [booster_key, tile.row, tile.col])

func _on_debug_booster_pressed(booster_type: String) -> void:
	if booster_in_progress:
		print("DEBUG: Booster already running; wait until it finishes.")
		return
	selected_booster = booster_type
	if selected_booster_tile == null:
		print("DEBUG: No tile selected for booster. Click a tile first!")
		return

	booster_in_progress = true
	var tile_ref: Node = selected_booster_tile
	var row: int = tile_ref.row
	var col: int = tile_ref.col
	print("Booster selected: %s on tile [%d, %d]" % [booster_type, row, col])
	await _trigger_debug_booster(tile_ref, booster_type, row, col)

	if is_instance_valid(tile_ref):
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(tile_ref, "scale", Vector2(1.0, 1.0), 0.15)

	selected_booster_tile = null
	selected_booster = ""
	booster_in_progress = false

func _trigger_debug_booster(tile: Node, booster_type: String, tile_row: int, tile_col: int) -> void:
	var booster_enum = Booster.BoosterType.Striped
	match booster_type:
		"color_bomb": booster_enum = Booster.BoosterType.ColorBomb
		"striped": booster_enum = Booster.BoosterType.Striped
		"bomb": booster_enum = Booster.BoosterType.Bomb
		"seeker": booster_enum = Booster.BoosterType.Seeker
		"roller": booster_enum = Booster.BoosterType.Roller
		"hammer": booster_enum = Booster.BoosterType.Hammer
		"free_swap": booster_enum = Booster.BoosterType.FreeSwap
		"brush": booster_enum = Booster.BoosterType.Brush
		"ufo": booster_enum = Booster.BoosterType.UFO
	
	var booster = Booster.new(booster_enum, tile, self)
	await booster.trigger()
	print("Booster triggered: %s on tile at [%d, %d]" % [booster_type, tile_row, tile_col])

func _make_placeholder_texture(type_idx: int) -> ImageTexture:
	# Generate a 64x64 procedural tile texture
	# Base color (background) with lighter colored circle in center
	
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	
	# Color palette: one unique color per tile type
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN
	]
	var color = colors[type_idx % colors.size()]
	var lighter = color.lightened(0.3)
	
	# Fill background with base color
	for y in range(64):
		for x in range(64):
			img.set_pixel(x, y, color)
	
	# Draw circle in center (radius 16) with lighter color
	for y in range(16, 48):
		for x in range(16, 48):
			var dx = x - 32
			var dy = y - 32
			if dx * dx + dy * dy <= 256:  # Circle equation: distance <= 16
				img.set_pixel(x, y, lighter)
	
	# Convert image to texture
	var texture = ImageTexture.create_from_image(img)
	return texture

func reset_game() -> void:
	# Clear board and reset game state for restart
	for child in $Tiles.get_children():
		child.queue_free()
	grid = []
	init_grid()
	score = 0
	moves_left = moves_limit
	emit_signal("score_changed", score)
	emit_signal("moves_changed", moves_left)
	set_state(BoardState.WaitForInput)
	print("Run boosters: %s" % [run_boosters])

func set_run_boosters(choices: Array) -> void:
	run_boosters = choices.duplicate()
	if run_boosters.size() > 3:
		run_boosters.resize(3)
	# Initialize inventory: 3 uses per booster
	booster_inventory.clear()
	for booster_key in run_boosters:
		booster_inventory[booster_key] = 3
	print("Selected boosters for run: %s" % [run_boosters])
	_setup_booster_ui()

func can_swap_positions(a: Vector2i, b: Vector2i) -> bool:
	if not _in_bounds(a) or not _in_bounds(b):
		return false
	if a == b:
		return false

	var delta: Vector2i = b - a
	var manhattan: int = abs(delta.x) + abs(delta.y)
	var diagonal: bool = abs(delta.x) == 1 and abs(delta.y) == 1
	var same_row: bool = a.y == b.y
	var same_col: bool = a.x == b.x

	match swap_mode:
		SwapMode.Adjacent:
			return manhattan == 1
		SwapMode.AdjacentWithDiagonals:
			return manhattan == 1 or diagonal
		SwapMode.Row:
			return same_row
		SwapMode.Column:
			return same_col
		SwapMode.Cross:
			return manhattan == 1
		SwapMode.Free:
			return true

	return false

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows

func _spawn_match_particles(pos: Vector2, tile_type: int) -> void:
	if particle_scene == null:
		return
	var particles = particle_scene.instantiate()
	particles.position = pos
	# Color particles based on tile type
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN
	]
	if tile_type >= 0 and tile_type < colors.size():
		particles.color = colors[tile_type]
	$Tiles.add_child(particles)
	particles.emitting = true
	# Auto-delete after lifetime
	await get_tree().create_timer(particles.lifetime + 0.1).timeout
	if is_instance_valid(particles):
		particles.queue_free()

func _play_match_sound(match_size: int) -> void:
	if sfx_match:
		var pitch = 1.0 + (match_size - 3) * 0.1
		sfx_match.pitch_scale = clamp(pitch, 0.8, 2.0)
		if not sfx_match.playing:
			sfx_match.play()

func _play_swap_sound() -> void:
	if sfx_swap and not sfx_swap.playing:
		sfx_swap.pitch_scale = 1.2
		sfx_swap.play()

func _play_booster_sound() -> void:
	if sfx_booster and not sfx_booster.playing:
		sfx_booster.pitch_scale = 0.9
		sfx_booster.play()

func _check_game_over() -> void:
	var is_victory = score >= goal_score
	var is_defeat = moves_left <= 0
	
	if is_victory or is_defeat:
		_show_game_over_screen(is_victory)

func _show_game_over_screen(victory: bool) -> void:
	if game_over_scene == null:
		return
	
	var game_over = game_over_scene.instantiate()
	game_over.is_victory = victory
	game_over.final_score = score
	game_over.goal_score = goal_score
	game_over.moves_used = moves_limit - moves_left
	game_over.moves_total = moves_limit
	get_parent().add_child(game_over)
	game_over.restart_requested.connect(_on_restart_requested)
	game_over.next_level_requested.connect(_on_next_level_requested)

func _on_restart_requested() -> void:
	reset_game()

func _on_next_level_requested() -> void:
	# Increase difficulty for next level
	goal_score = int(goal_score * 1.5)
	moves_limit = max(20, moves_limit - 2)
	reset_game()
