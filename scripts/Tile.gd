extends Area2D
# TILE.GD - Individual Tile Behavior
# ===================================
# Represents a single Match-3 tile on the grid
# Handles click detection and tile properties

signal tile_clicked(tile)

# ===== TILE PROPERTIES =====
@export var tile_type: int = 0           # Type 0-5 (determines color)
var row: int = -1                        # Row index on grid (0-7)
var col: int = -1                        # Col index on grid (0-7)
var is_powerup: bool = false             # True if this tile is a power-up
var powerup_type: String = ""            # Power-up type: "line" or "bomb"

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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)
