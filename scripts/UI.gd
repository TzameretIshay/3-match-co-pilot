extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var moves_label: Label = $MovesLabel

func _ready() -> void:
	# Find Grid manager in scene
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var grid = current.get_node_or_null("Grid")
	if grid:
		grid.connect("score_changed", Callable(self, "_on_score_changed"))
		grid.connect("moves_changed", Callable(self, "_on_moves_changed"))
		$RestartButton.pressed.connect(Callable(grid, "reset_game"))

func _on_score_changed(new_score):
	score_label.text = "Score: %d" % new_score

func _on_moves_changed(remaining_moves):
	moves_label.text = "Moves: %d" % remaining_moves
