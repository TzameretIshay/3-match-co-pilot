extends Resource
class_name Booster

enum BoosterType {
	ColorBomb,        # Destroys all pieces of a color
	Striped,          # Clears entire row/column
	Bomb,             # Clears 3x3 area
	Seeker,           # Flies to target and destroys it
	Roller,           # Rolls across line, creates striped pieces
	Hammer,           # External: destroys one piece
	FreeSwap,         # External: swap any two pieces
	Brush,            # External: change piece color
	UFO               # External: transforms random pieces to boosters
}

@export var booster_type: BoosterType = BoosterType.Striped
@export var source: String = "match"  # "match" or "tool"
@export var is_triggered: bool = false

var cell: Node = null
var grid: Node = null

func _init(type: BoosterType = BoosterType.Striped, _cell: Node = null, _grid: Node = null) -> void:
	booster_type = type
	cell = _cell
	grid = _grid

func trigger(target_cell: Node = null) -> void:
	if is_triggered:
		return
	is_triggered = true

	match booster_type:
		BoosterType.ColorBomb:
			await _trigger_color_bomb()
		BoosterType.Striped:
			await _trigger_striped()
		BoosterType.Bomb:
			await _trigger_bomb()
		BoosterType.Seeker:
			await _trigger_seeker(target_cell)
		BoosterType.Roller:
			await _trigger_roller()
		BoosterType.Hammer:
			await _trigger_hammer(target_cell)
		BoosterType.FreeSwap:
			await _trigger_free_swap(target_cell)
		BoosterType.Brush:
			await _trigger_brush(target_cell)
		BoosterType.UFO:
			await _trigger_ufo()

func _trigger_color_bomb() -> void:
	# Destroys all pieces matching the color
	if not grid or not cell:
		return
	var color_to_match = cell.tile_type
	var destroy_list = []
	for r in range(grid.rows):
		for c in range(grid.cols):
			var t = grid.grid[r][c]
			if t and t.tile_type == color_to_match:
				destroy_list.append([r, c])
	await _apply_destroy_with_effect(destroy_list, "color_bomb")
	print("Color Bomb: Destroyed all %d pieces of color %d" % [destroy_list.size(), color_to_match])

func _trigger_striped() -> void:
	# Clears row and column
	if not grid or not cell:
		return
	var r = cell.row
	var c = cell.col
	var destroy_list = []
	for cc in range(grid.cols):
		destroy_list.append([r, cc])
	for rr in range(grid.rows):
		destroy_list.append([rr, c])
	await _apply_destroy_with_effect(destroy_list, "striped")
	print("Striped: Cleared row %d and column %d" % [r, c])

func _trigger_bomb() -> void:
	# Clears 3x3 area
	if not grid or not cell:
		return
	var r = cell.row
	var c = cell.col
	var destroy_list = []
	for rr in range(max(0, r - 1), min(grid.rows, r + 2)):
		for cc in range(max(0, c - 1), min(grid.cols, c + 2)):
			destroy_list.append([rr, cc])
	await _apply_destroy_with_effect(destroy_list, "bomb")
	print("Bomb: Cleared 3x3 area around [%d, %d]" % [r, c])

func _trigger_seeker(target_cell: Node) -> void:
	# Flies to target and destroys it
	if not grid or not cell or not target_cell:
		return
	var destroy_list = [[target_cell.row, target_cell.col]]
	await _apply_destroy_with_effect(destroy_list, "seeker")
	print("Seeker: Destroyed target at [%d, %d]" % [target_cell.row, target_cell.col])

func _trigger_roller() -> void:
	# Rolls across line, creates striped pieces
	if not grid or not cell:
		return
	var r = cell.row
	var c = cell.col
	# Convert adjacent pieces in row and column to striped
	for cc in range(grid.cols):
		if grid.grid[r][cc]:
			grid.grid[r][cc].is_powerup = true
			grid.grid[r][cc].powerup_type = "striped"
	for rr in range(grid.rows):
		if grid.grid[rr][c]:
			grid.grid[rr][c].is_powerup = true
			grid.grid[rr][c].powerup_type = "striped"
	print("Roller: Converted row %d and column %d to striped pieces" % [r, c])

func _trigger_hammer(target_cell: Node) -> void:
	# Destroys single piece
	if not grid or not target_cell:
		return
	var destroy_list = [[target_cell.row, target_cell.col]]
	await _apply_destroy_with_effect(destroy_list, "hammer")
	print("Hammer: Destroyed single piece at [%d, %d]" % [target_cell.row, target_cell.col])

func _trigger_free_swap(target_cell: Node) -> void:
	# Swap any two pieces (implementation in Grid)
	if not grid or not cell or not target_cell:
		return
	pass  # Grid handles this

func _trigger_brush(target_cell: Node) -> void:
	# Change piece color
	if not grid or not target_cell:
		return
	var old_type = target_cell.tile_type
	target_cell.tile_type = randi() % 6
	print("Brush: Changed color from %d to %d at [%d, %d]" % [old_type, target_cell.tile_type, target_cell.row, target_cell.col])

func _trigger_ufo() -> void:
	# Transforms random pieces to boosters
	if not grid:
		return
	var random_positions = []
	for _i in range(3):
		var r = randi() % grid.rows
		var c = randi() % grid.cols
		if grid.grid[r][c]:
			random_positions.append([r, c])
	for pos in random_positions:
		var t = grid.grid[pos[0]][pos[1]]
		if t:
			t.is_powerup = true
			t.powerup_type = "bomb"
	print("UFO: Transformed %d random pieces to bombs" % random_positions.size())

func _apply_destroy_with_effect(destroy_list: Array, effect_type: String) -> void:
	if not grid or destroy_list.is_empty():
		return

	var dedup := {}
	for pos in destroy_list:
		if pos is Array and pos.size() >= 2:
			var key = "%d_%d" % [pos[0], pos[1]]
			if not dedup.has(key):
				dedup[key] = [int(pos[0]), int(pos[1])]

	# Apply screen shake based on type
	match effect_type:
		"color_bomb":
			_screen_shake(0.3, 8.0)
		"striped":
			_screen_shake(0.15, 3.0)
		"bomb":
			_screen_shake(0.4, 12.0)
		"seeker":
			_screen_shake(0.1, 2.0)
		"hammer":
			_screen_shake(0.2, 5.0)
		_:
			pass

	# Let the grid own the clear/refill/cascade flow
	await grid.apply_booster_clear(dedup.values())
	print("Booster destroyed %d tiles" % dedup.size())

func _animate_destroy(destroy_list: Array) -> void:
	if not grid:
		return
	
	var pop_tweens = []
	var dedup := {}
	
	# Deduplicate positions
	for pos in destroy_list:
		var key = "%d_%d" % [pos[0], pos[1]]
		if not dedup.has(key):
			dedup[key] = pos
	
	# Pop animation
	for pos in dedup.values():
		var r = pos[0]
		var c = pos[1]
		if r >= 0 and r < grid.rows and c >= 0 and c < grid.cols:
			var t = grid.grid[r][c]
			if t:
				var tween = grid.create_tween()
				tween.set_trans(Tween.TRANS_SINE)
				tween.set_ease(Tween.EASE_IN)
				tween.tween_property(t, "scale", Vector2(0.1, 0.1), 0.12)
				pop_tweens.append(tween)
	
	# Wait for pop animation to finish
	if pop_tweens.size() > 0:
		pop_tweens[0].finished.connect(_on_destroy_animation_finished.bindv([dedup]))

func _on_destroy_animation_finished(dedup: Dictionary) -> void:
	if not grid:
		return
	
	# Remove tiles from grid
	for pos in dedup.values():
		var r = pos[0]
		var c = pos[1]
		if r >= 0 and r < grid.rows and c >= 0 and c < grid.cols:
			var t = grid.grid[r][c]
			if t:
				t.queue_free()
				grid.grid[r][c] = null
	
	# Update score
	grid.score += dedup.size() * 10
	grid.emit_signal("score_changed", grid.score)
	
	print("Booster destroyed %d tiles" % dedup.size())

func _screen_shake(duration: float, intensity: float) -> void:
	if not grid:
		return
	var original_pos = grid.position
	var shake_count = int(duration * 20)
	for _i in range(shake_count):
		var shake = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		grid.position = original_pos + shake
	grid.position = original_pos

func _slow_motion_hit_stop(duration: float) -> void:
	pass  # Placeholder for slow motion effect

func _particle_line_effect(destroy_list: Array) -> void:
	pass  # Placeholder for particle effects

func _pitch_escalation() -> void:
	pass  # Placeholder for audio pitch escalation

func _large_particle_burst() -> void:
	pass  # Placeholder for particle burst

func _elegant_movement_effect() -> void:
	pass  # Placeholder for movement effect

func _impact_dust_effect() -> void:
	pass  # Placeholder for dust effect
