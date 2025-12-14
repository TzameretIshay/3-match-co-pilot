extends Sprite2D
# BACKGROUNDMANAGER.GD - Level Background Manager
# ===============================================
# Manages cycling through 6 sea-themed backgrounds based on level

var background_texture: Texture2D
var current_level: int = 1
var backgrounds: Array[AtlasTexture] = []

# Background layout: 3 columns x 2 rows
const COLS = 3
const ROWS = 2
const TOTAL_BACKGROUNDS = 6

func _ready() -> void:
	# Load the background sprite sheet
	background_texture = load("res://assets/SeaTheme/sea_backgound.png")
	if background_texture == null:
		push_error("Failed to load sea_backgound.png")
		return
	
	# Get dimensions
	var sheet_width = background_texture.get_width()
	var sheet_height = background_texture.get_height()
	var bg_width = sheet_width / COLS
	var bg_height = sheet_height / ROWS
	
	# Slice backgrounds from sprite sheet (left-to-right, top-to-bottom)
	for row in ROWS:
		for col in COLS:
			var atlas = AtlasTexture.new()
			atlas.atlas = background_texture
			atlas.region = Rect2(col * bg_width, row * bg_height, bg_width, bg_height)
			backgrounds.append(atlas)
	
	# Set initial background
	set_background_for_level(1)
	
	# Scale background to fit window
	_scale_to_window()
	
	# Connect to Grid's level_changed signal
	var grid = get_tree().get_current_scene().get_node_or_null("Grid")
	if grid:
		grid.level_changed.connect(_on_level_changed)

func _scale_to_window() -> void:
	# Get viewport/window size
	var window_size = get_viewport_rect().size
	
	# Get current texture size
	if texture == null:
		return
	
	var texture_size = texture.get_size()
	
	# Calculate scale to cover entire window
	var scale_x = window_size.x / texture_size.x
	var scale_y = window_size.y / texture_size.y
	
	# Use the larger scale to ensure full coverage, then overscale slightly
	var scale_factor = max(scale_x, scale_y)
	# Overscale by 1% to avoid thin seams from rounding
	scale_factor *= 1.01
	
	scale = Vector2(scale_factor, scale_factor)
	print("Background scaled to %s (window: %s, texture: %s)" % [scale, window_size, texture_size])

func set_background_for_level(level: int) -> void:
	current_level = level
	# Cycle through the 6 backgrounds (levels 1-6 use backgrounds 0-5, then repeat)
	var bg_index = (level - 1) % TOTAL_BACKGROUNDS
	if bg_index < backgrounds.size():
		texture = backgrounds[bg_index]
		_scale_to_window()
		print("Background changed to index %d for level %d" % [bg_index, level])

func _on_level_changed(new_level: int) -> void:
	set_background_for_level(new_level)
