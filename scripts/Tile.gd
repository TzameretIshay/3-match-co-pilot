extends Area2D

signal tile_clicked(tile)

@export var tile_type: int = 0
var row: int = -1
var col: int = -1
var is_powerup: bool = false
var powerup_type: String = "" # e.g., "row" or "col"

func _ready() -> void:
	$Sprite.centered = true

func set_tile(type_idx: int, r: int, c: int) -> void:
	tile_type = type_idx
	row = r
	col = c
	# Sprite texture is assigned by the Grid manager; it may set $Sprite.texture
	is_powerup = false
	powerup_type = ""

func _input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)
