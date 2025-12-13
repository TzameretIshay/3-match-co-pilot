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

var grid := []
var score: int = 0
var moves_left: int
var rng := RandomNumberGenerator.new()
var selected_tile: Node = null

var tile_scene: PackedScene
var auto_textures := {}

var audio_player: AudioStreamPlayer
var audio_generator: AudioStreamGenerator

func _ready() -> void:
	rng.randomize()
	moves_left = moves_limit
	emit_signal("moves_changed", moves_left)
	tile_scene = load("res://scenes/Tile.tscn")
	audio_generator = AudioStreamGenerator.new()
	audio_generator.mix_rate = 44100
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = audio_generator
	add_child(audio_player)
	init_grid()

func init_grid() -> void:
	grid = []
	for r in range(rows):
		grid.append([])
		for c in range(cols):
			var t = spawn_tile(r, c, rng.randi_range(0, TILE_TYPES - 1))
			grid[r].append(t)
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
	var tile = tile_scene.instantiate()
	$Tiles.add_child(tile)
	tile.position = Vector2(c * 64, r * 64)
	tile.set_tile(type_idx, r, c)
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
		if not auto_textures.has(type_idx):
			auto_textures[type_idx] = _make_placeholder_texture(type_idx)
		if tile.has_node("Sprite"):
			tile.get_node("Sprite").texture = auto_textures[type_idx]
	tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
	return tile

func replace_tile(r: int, c: int, type_idx: int) -> void:
	var old_tile = grid[r][c]
	if old_tile:
		old_tile.queue_free()
	var new_tile = spawn_tile(r, c, type_idx)
	grid[r][c] = new_tile

func find_matches_with_groups() -> Dictionary:
	var matches := []
	var groups := {}
	var visited := {}
	
	# Horizontal matches
	for r in range(rows):
		var c = 0
		while c < cols:
			var run_start = c
			var run_length = 1
			while c + 1 < cols and grid[r][c].tile_type == grid[r][c + 1].tile_type:
				c += 1
				run_length += 1
			
			if run_length >= 3:
				var run_group = []
				for i in range(run_start, c + 1):
					var tile = grid[r][i]
					matches.append([r, i])
					run_group.append(tile)
					if not visited.has(tile):
						visited[tile] = true
				groups[run_group[0]] = {"type": "horizontal", "length": run_length}
			c += 1
	
	# Vertical matches
	for c in range(cols):
		var r = 0
		while r < rows:
			var run_start = r
			var run_length = 1
			while r + 1 < rows and grid[r][c].tile_type == grid[r + 1][c].tile_type:
				r += 1
				run_length += 1
			
			if run_length >= 3:
				var run_group = []
				for i in range(run_start, r + 1):
					var tile = grid[i][c]
					matches.append([i, c])
					run_group.append(tile)
					if not visited.has(tile):
						visited[tile] = true
				groups[run_group[0]] = {"type": "vertical", "length": run_length}
			r += 1
	
	# Deduplicate matches
	var dedup := {}
	for match in matches:
		var key = "%d_%d" % [match[0], match[1]]
		dedup[key] = match
	matches = dedup.values()
	
	return {"matches": matches, "groups": groups}

func _on_tile_clicked(tile: Node) -> void:
	if moves_left <= 0:
		return
	
	# If no tile selected yet, select this one
	if selected_tile == null:
		selected_tile = tile
		# Visual feedback: scale up the selected tile
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_tile, "scale", Vector2(1.2, 1.2), 0.15)
		return
	
	# If same tile clicked, deselect it
	if tile == selected_tile:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(selected_tile, "scale", Vector2(1.0, 1.0), 0.15)
		selected_tile = null
		return
	
	# Check if clicked tile is adjacent to selected tile
	var selected_row = selected_tile.row
	var selected_col = selected_tile.col
	var clicked_row = tile.row
	var clicked_col = tile.col
	
	var distance = abs(selected_row - clicked_row) + abs(selected_col - clicked_col)
	
	if distance == 1:
		# Adjacent tile: attempt swap
		var temp_selected = selected_tile
		# First deselect the visual highlight
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(temp_selected, "scale", Vector2(1.0, 1.0), 0.15)
		await tween.finished
		selected_tile = null
		
		# Now perform the swap
		await try_swap(temp_selected, tile)
	else:
		# Not adjacent: change selection to clicked tile
		var old_selected = selected_tile
		var tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(old_selected, "scale", Vector2(1.0, 1.0), 0.15)
		tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.15)
		await tween.finished
		selected_tile = tile

func try_swap(tile_a: Node, tile_b: Node) -> void:
	moves_left -= 1
	emit_signal("moves_changed", moves_left)
	
	await animate_swap(tile_a, tile_b)
	
	var result = find_matches_with_groups()
	var matches = result["matches"]
	
	if matches.is_empty():
		await animate_swap(tile_a, tile_b)
		moves_left += 1
		emit_signal("moves_changed", moves_left)
		return
	
	await handle_matches_and_refill(result)

func animate_swap(tile_a: Node, tile_b: Node) -> void:
	var row_a = tile_a.row
	var col_a = tile_a.col
	var row_b = tile_b.row
	var col_b = tile_b.col
	
	grid[row_a][col_a] = tile_b
	grid[row_b][col_b] = tile_a
	tile_a.row = row_b
	tile_a.col = col_b
	tile_b.row = row_a
	tile_b.col = col_a
	
	var target_a = Vector2(col_b * 64, row_b * 64)
	var target_b = Vector2(col_a * 64, row_a * 64)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(tile_a, "position", target_a, 0.18)
	tween.tween_property(tile_b, "position", target_b, 0.18)
	await tween.finished

func handle_matches_and_refill(result: Dictionary) -> void:
	var to_clear = []
	var to_clear_set = {}
	
	for match in result["matches"]:
		var r = match[0]
		var c = match[1]
		var key = "%d_%d" % [r, c]
		if not to_clear_set.has(key):
			to_clear_set[key] = true
			to_clear.append([r, c])
	
	# Check for power-ups and expand clear set
	for tile_data in result["groups"].values():
		if tile_data.has("length") and tile_data["length"] >= 4:
			var matched = result["matches"]
			for m_idx in range(0, matched.size()):
				var mr = matched[m_idx][0]
				var mc = matched[m_idx][1]
				var tile = grid[mr][mc]
				if tile_data["type"] == "horizontal":
					tile.is_powerup = true
					tile.powerup_type = "line"
					for extra_c in range(cols):
						var k = "%d_%d" % [mr, extra_c]
						if not to_clear_set.has(k):
							to_clear_set[k] = true
							to_clear.append([mr, extra_c])
				elif tile_data["type"] == "vertical":
					tile.is_powerup = true
					tile.powerup_type = "line"
					for extra_r in range(rows):
						var k = "%d_%d" % [extra_r, mc]
						if not to_clear_set.has(k):
							to_clear_set[k] = true
							to_clear.append([extra_r, mc])
	
	# Animate pop
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
	
	# Clear tiles
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
	
	# Apply gravity with falling tweens
	var fall_tweens = []
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
		
		# Fill from top
		for r in range(write_r, -1, -1):
			var new_type = rng.randi_range(0, TILE_TYPES - 1)
			var new_tile = spawn_tile(r, c, new_type)
			new_tile.position = Vector2(c * 64, -64)
			grid[r][c] = new_tile
			var target_y = r * 64
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(new_tile, "position", Vector2(c * 64, target_y), 0.22)
			fall_tweens.append(tween)
	
	if fall_tweens.size() > 0:
		await fall_tweens[0].finished
	
	# Check for chain reactions
	var new_result = find_matches_with_groups()
	if not new_result["matches"].is_empty():
		await handle_matches_and_refill(new_result)

func _make_placeholder_texture(type_idx: int) -> ImageTexture:
	var img = Image.create(64, 64, false, Image.FORMAT_RGB8)
	var colors = [
		Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN
	]
	var color = colors[type_idx % colors.size()]
	var lighter = color.lightened(0.3)
	
	for y in range(64):
		for x in range(64):
			img.set_pixel(x, y, color)
	
	for y in range(16, 48):
		for x in range(16, 48):
			var dx = x - 32
			var dy = y - 32
			if dx * dx + dy * dy <= 256:
				img.set_pixel(x, y, lighter)
	
	var texture = ImageTexture.create_from_image(img)
	return texture

func reset_game() -> void:
	for child in $Tiles.get_children():
		child.queue_free()
	grid = []
	init_grid()
	score = 0
	moves_left = moves_limit
	emit_signal("score_changed", score)
	emit_signal("moves_changed", moves_left)
