extends CanvasLayer

signal boosters_selected(booster_keys: Array)

@export var grid_path: NodePath
@export var max_selection: int = 3

var _grid: Node = null
var _selected := {}
var _legend_label: Label = null

var _booster_defs := [
	{
		"key": "color_bomb",
		"label": "Color Bomb",
		"description": "Destroys all tiles of the same color as the target tile"
	},
	{
		"key": "striped",
		"label": "Striped",
		"description": "Clears an entire row and column where the tile is located"
	},
	{
		"key": "bomb",
		"label": "Bomb",
		"description": "Destroys all tiles in a 3x3 area around the target tile"
	},
	{
		"key": "seeker",
		"label": "Seeker",
		"description": "Flies to the target tile and destroys it instantly"
	},
	{
		"key": "roller",
		"label": "Roller",
		"description": "Rolls across the row and column, converting tiles to striped pieces"
	},
	{
		"key": "hammer",
		"label": "Hammer",
		"description": "Smashes a single tile, destroying it instantly"
	},
	{
		"key": "free_swap",
		"label": "Free Swap",
		"description": "Allows you to swap any two tiles on the board freely"
	},
	{
		"key": "brush",
		"label": "Brush",
		"description": "Changes the color of a tile to match adjacent colors"
	},
	{
		"key": "ufo",
		"label": "UFO",
		"description": "Transforms random tiles on the board into bomb pieces"
	}
]

func _ready() -> void:
	add_to_group("next_level_booster_screen")
	_grid = get_node_or_null(grid_path)
	_legend_label = $Panel/VBox/LegendLabel
	if _legend_label:
		_legend_label.text = "Hover over a booster to see its effect"
	
	var list_node = $Panel/VBox/BoosterScroll/BoosterList
	for def in _booster_defs:
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 40)
		list_node.add_child(hbox)
		
		var cb = CheckBox.new()
		cb.name = def["key"]
		cb.text = def["label"]
		cb.custom_minimum_size = Vector2(150, 40)
		cb.toggled.connect(_on_booster_toggled.bind(def["key"]))
		hbox.add_child(cb)
		
		# Add hover to show description
		var info_btn = Button.new()
		info_btn.text = "?"
		info_btn.custom_minimum_size = Vector2(30, 30)
		info_btn.mouse_entered.connect(_on_booster_info_hover.bind(def))
		info_btn.mouse_exited.connect(_on_booster_info_exit)
		hbox.add_child(info_btn)
	
	_update_counter()

func _on_booster_info_hover(booster_def: Dictionary) -> void:
	if _legend_label:
		_legend_label.text = booster_def["description"]

func _on_booster_info_exit() -> void:
	if _legend_label:
		var count = _selected.size()
		_legend_label.text = "Selected: %d / %d" % [count, max_selection]

func _on_booster_toggled(pressed: bool, key: String) -> void:
	if pressed:
		if _selected.size() >= max_selection:
			# Limit reached: revert toggle
			var cb: CheckBox = $Panel/VBox/BoosterScroll/BoosterList.get_node(key)
			cb.button_pressed = false
			return
		_selected[key] = true
	else:
		_selected.erase(key)
	_update_counter()

func _update_counter() -> void:
	var count = _selected.size()
	var counter: Label = $Panel/VBox/CounterLabel
	counter.text = "Selected: %d / %d" % [count, max_selection]

func _on_ContinueButton_pressed() -> void:
	var chosen = _selected.keys()
	boosters_selected.emit(chosen)
	queue_free()
