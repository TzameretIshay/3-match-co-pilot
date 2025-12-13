extends Node2D

signal score_changed(new_score)
signal moves_changed(remaining_moves)

const DEFAULT_ROWS: int = 8
const DEFAULT_COLS: int = 8
const TILE_TYPES: int = 6
const MOVE_LIMIT: int = 30

@export var rows: int = DEFAULT_ROWS
@export var cols: int = DEFAULT_COLS
@export var moves_limit: int = MOVE_LIMIT

var grid := [] # 2D array of Tile nodes
var score: int = 0
var moves_left: int
var rng := RandomNumberGenerator.new()

const TileScene: PackedScene = preload("res://scenes/Tile.tscn")

func _ready() -> void:
	rng.randomize()
	moves_left = moves_limit
	emit_signal("moves_changed", moves_left)
	init_grid()

func init_grid() -> void:
	grid = []
	for r in range(rows):
		grid.append([])
		for c in range(cols):
			var t = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
			grid[r].append(t)

	# Ensure initial board has no immediate matches
	while true:
		var matches = find_matches()
		if matches.empty():
			break
		# Replace matched tiles randomly until no immediate matches
		for matched in matches:
			var (mr, mc) = matched
			var t = grid[mr][mc]
			replace_tile(mr, mc, rng.randi_range(0, TILE_TYPES - 1))

func spawn_tile(r: int, c: int, type_idx: int) -> Node:
	var tile = TileScene.instantiate()
	add_child(tile)
	$Tiles.add_child(tile)
	tile.position = Vector2(c * 64, r * 64)
	tile.set_tile(type_idx, r, c)
	# Placeholder: assign a texture if assets available at res://assets/tile_TYPE.png
	var tex_path = "res://assets/tile_%d.png".format(type_idx)
	if ResourceLoader.exists(tex_path):
		var tex = load(tex_path)
		if tex:
			if tile.has_node("Sprite"):
				tile.get_node("Sprite").texture = tex
	# Connect click
	tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
	return tile

func replace_tile(r: int, c: int, type_idx: int) -> void:
	# Remove old tile and spawn a new one at same place
	var old = grid[r][c]
	if old:
		old.queue_free()
	var nt = spawn_tile(r, c, type_idx)
	grid[r][c] = nt

var selected_tile = null

func _on_tile_clicked(tile) -> void:
	if selected_tile == null:
		selected_tile = tile
		# Could add visual highlight here
	else:
		# If same tile clicked, deselect
		if tile == selected_tile:
			selected_tile = null
			return
		# If adjacent, attempt swap
		if is_adjacent(selected_tile, tile):
			try_swap(selected_tile, tile)
		else:
			selected_tile = tile

func is_adjacent(a, b) -> bool:
	return abs(a.row - b.row) + abs(a.col - b.col) == 1

func try_swap(a, b) -> void:
	# Do swap visually and in grid; if no match, swap back
	perform_swap(a, b)
	var matches = find_matches()
	if matches.empty():
		# animate swap back (placeholder) then swap back
		perform_swap(a, b)
		# consume a move even if invalid? Here we do not consume moves for invalid swap
	else:
		# Commit swap, then handle matches and chain reactions
		moves_left -= 1
		emit_signal("moves_changed", moves_left)
		handle_matches_and_refill()

func perform_swap(a, b) -> void:
	# swap internal grid references and update positions & row/col
	var ar = a.row; var ac = a.col
	var br = b.row; var bc = b.col
	# swap in grid
	grid[ar][ac] = b
	grid[br][bc] = a
	# swap row/col
	a.row = br; a.col = bc
	b.row = ar; b.col = ac
	# animate positions (instant for now)
	var apos = a.position; var bpos = b.position
	a.position = bpos
	b.position = apos

func find_matches() -> Array:
	# Returns array of tuples (row, col) that are in matches
	var to_clear := {}
	# Horizontal
	for r in range(rows):
		var run_type = -1
		var run_start = 0
		for c in range(cols):
			var t = grid[r][c]
			var typ = t.tile_type
			if typ == run_type:
				# continue
				pass
			else:
				if c - run_start >= 3 and run_type != -1:
					for x in range(run_start, c):
						to_clear["%d_%d".format(r, x)] = [r, x]
				run_start = c
				run_type = typ
		# end row: check tail
		if cols - run_start >= 3 and run_type != -1:
			for x in range(run_start, cols):
				to_clear["%d_%d".format(r, x)] = [r, x]

	# Vertical
	for c in range(cols):
		var run_type = -1
		var run_start = 0
		for r in range(rows):
			var t = grid[r][c]
			var typ = t.tile_type
			if typ == run_type:
				pass
			else:
				if r - run_start >= 3 and run_type != -1:
					for y in range(run_start, r):
						to_clear["%d_%d".format(y, c)] = [y, c]
				run_start = r
				run_type = typ
		if rows - run_start >= 3 and run_type != -1:
			for y in range(run_start, rows):
				to_clear["%d_%d".format(y, c)] = [y, c]

	var arr = []
	for k in to_clear.keys():
		arr.append(to_clear[k])
	return arr

func handle_matches_and_refill() -> void:
	var total_cleared = 0
	while true:
		var matches = find_matches()
		if matches.empty():
			break
			# Clear tiles
		for pos in matches:
			var r = pos[0]; var c = pos[1]
			var t = grid[r][c]
			if t:
				# scoring: base 10 per tile
				score += 10
				t.queue_free()
				grid[r][c] = null
			total_cleared += matches.size()
		# collapse columns
		for c in range(cols):
			var write_row = rows - 1
			for r in range(rows - 1, -1, -1):
				var t = grid[r][c]
				if t != null:
					# move to write_row
					if write_row != r:
						grid[write_row][c] = t
						t.row = write_row
						t.position = Vector2(c * 64, write_row * 64)
					grid[r][c] = null
					write_row -= 1
			# spawn new tiles for empty slots at top
			for r in range(write_row, -1, -1):
				var newt = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
				grid[r][c] = newt
		# notify score change
		emit_signal("score_changed", score)
		# small delay to simulate animations chaining
		await get_tree().create_timer(0.18).timeout

func reset_game() -> void:
	# clear children
	$Tiles.clear()
	for child in get_children():
		if child != $Tiles:
			pass
	init_grid()
	score = 0
	moves_left = moves_limit
	emit_signal("score_changed", score)
	emit_signal("moves_changed", moves_left)
