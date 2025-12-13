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
	
	# Setup audio (currently unused, but ready for SFX)
	audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = 44100
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_generator
	add_child(audio_player)
	
	# Spawn initial 8x8 grid ensuring no immediate matches
	init_grid()

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

	return {"matches": matches, "groups": groups, "sequences": sequences}

func _on_tile_clicked(tile: Node) -> void:
	# Handle tile selection and swapping based on selection_mode and swap_mode
	if current_state != BoardState.WaitForInput:
		return
	if moves_left <= 0:
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
