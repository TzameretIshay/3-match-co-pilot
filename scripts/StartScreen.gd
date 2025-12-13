extends CanvasLayer

@export var grid_path: NodePath
@export var max_selection: int = 3

var _grid: Node = null
var _selected := {}

var _booster_defs := [
	{"key": "color_bomb", "label": "Color Bomb"},
	{"key": "striped", "label": "Striped"},
	{"key": "bomb", "label": "Bomb"},
	{"key": "seeker", "label": "Seeker"},
	{"key": "roller", "label": "Roller"},
	{"key": "hammer", "label": "Hammer"},
	{"key": "free_swap", "label": "Free Swap"},
	{"key": "brush", "label": "Brush"},
	{"key": "ufo", "label": "UFO"}
]

func _ready() -> void:
	_grid = get_node_or_null(grid_path)
	var list_node = $Panel/VBox/BoosterList
	for def in _booster_defs:
		var cb = CheckBox.new()
		cb.name = def["key"]
		cb.text = def["label"]
		cb.toggled.connect(_on_booster_toggled.bind(def["key"]))
		list_node.add_child(cb)
	_update_counter()
	$Panel/VBox/StartButton.disabled = true

func _on_booster_toggled(pressed: bool, key: String) -> void:
	if pressed:
		if _selected.size() >= max_selection:
			# Limit reached: revert toggle
			var cb: CheckBox = $Panel/VBox/BoosterList.get_node(key)
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
	$Panel/VBox/StartButton.disabled = count == 0

func _on_StartButton_pressed() -> void:
	var chosen = _selected.keys()
	if _grid:
		_grid.set_run_boosters(chosen)
		_grid.reset_game()
	hide()
