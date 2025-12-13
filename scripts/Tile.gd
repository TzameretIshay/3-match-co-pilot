extends Area2D
# TILE.GD - Individual Tile Behavior
# ===================================
# Represents a single Match-3 tile on the grid
# Handles click detection and tile properties

signal tile_clicked(tile)
signal tile_dragged(tile, direction: Vector2)

# ===== TILE PROPERTIES =====
@export var tile_type: int = 0           # Type 0-5 (determines color)
var row: int = -1                        # Row index on grid (0-7)
var col: int = -1                        # Col index on grid (0-7)
var is_powerup: bool = false             # True if this tile is a power-up
var powerup_type: String = ""            # Power-up type: "line" or "bomb"
var _drag_start: Vector2 = Vector2.ZERO
var _dragging: bool = false

func _ready() -> void:
	# Ensure sprite is centered on the tile
	$Sprite.centered = true

func set_tile(type_idx: int, r: int, c: int) -> void:
	# Initialize tile with type, position, and reset powerup flags
	tile_type = type_idx
	row = r
	col = c
	is_powerup = false
	powerup_type = ""
	# Note: Sprite texture is assigned by Grid script via ResourceLoader

func _input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	# Handle mouse clicks on this tile
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_drag_start = event.position
			_dragging = true
			emit_signal("tile_clicked", self)
		elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _dragging:
			_dragging = false
			var delta = event.position - _drag_start
			if delta.length() > 8.0:
				_emit_drag(delta)
			_drag_start = Vector2.ZERO
	elif event is InputEventMouseMotion and _dragging:
		if event.pressure > 0 or event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0:
			var delta = event.position - _drag_start
			if delta.length() > 12.0:
				_emit_drag(delta)
				_dragging = false
				_drag_start = Vector2.ZERO

func _emit_drag(delta: Vector2) -> void:
	if delta == Vector2.ZERO:
		return
	var dir = delta.normalized()
	# Snap to cardinal directions
	if abs(dir.x) >= abs(dir.y):
		dir = Vector2(sign(dir.x), 0)
	else:
		dir = Vector2(0, sign(dir.y))
	emit_signal("tile_dragged", self, dir)
