# Earned Booster System - Code additions for Grid.gd

# Add to Grid.gd variables section (around line 95):
var earned_boosters: Dictionary = {}  # {"booster_key": count}
var earned_booster_ui: Node = null

# Add to _ready() function after init_grid():
_setup_earned_booster_ui()

# Add these new functions to Grid.gd:

func _setup_earned_booster_ui() -> void:
	if earned_booster_ui != null:
		earned_booster_ui.queue_free()
	
	var ui_container = Control.new()
	ui_container.anchor_left = 1.0
	ui_container.anchor_top = 0.5
	ui_container.offset_left = -200
	ui_container.offset_top = -150
	ui_container.offset_right = 0
	ui_container.offset_bottom = 150
	add_child(ui_container)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	ui_container.add_child(vbox)

	var title = Label.new()
	title.text = "EARNED"
	title.custom_minimum_size = Vector2(200, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	earned_booster_ui = ui_container
	_update_earned_booster_ui()

func _update_earned_booster_ui() -> void:
	if earned_booster_ui == null:
		return
	
	var booster_labels = {
		"color_bomb": "Color Bomb",
		"striped": "Striped",
		"bomb": "Bomb",
		"seeker": "Seeker",
		"roller": "Roller",
		"hammer": "Hammer",
		"brush": "Brush",
		"ufo": "UFO"
	}
	
	var vbox = null
	for child in earned_booster_ui.get_children():
		if child is VBoxContainer:
			vbox = child
			break
	
	if vbox == null:
		return
	
	var vbox_children = vbox.get_children()
	for i in range(vbox_children.size() - 1, 0, -1):
		vbox_children[i].queue_free()
	
	for booster_key in earned_boosters.keys():
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(200, 35)
		vbox.add_child(hbox)

		var label = Label.new()
		label.text = booster_labels.get(booster_key, booster_key)
		label.custom_minimum_size = Vector2(140, 35)
		hbox.add_child(label)

		var count_label = Label.new()
		count_label.text = "x%d" % earned_boosters[booster_key]
		count_label.custom_minimum_size = Vector2(50, 35)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(count_label)

func _award_booster_for_match(match_size: int) -> void:
	var booster_types = [
		"color_bomb", "striped", "bomb", "seeker",
		"roller", "hammer", "brush", "ufo"
	]
	var random_booster = booster_types[randi() % booster_types.size()]
	
	if not earned_boosters.has(random_booster):
		earned_boosters[random_booster] = 0
	earned_boosters[random_booster] += 1
	
	print("Booster earned! %s (x%d)" % [random_booster, earned_boosters[random_booster]])
	_update_earned_booster_ui()

# Add this line in handle_matches_and_refill() after consumed_sequences.emit():
if to_clear.size() >= 4:
	_award_booster_for_match(to_clear.size())
