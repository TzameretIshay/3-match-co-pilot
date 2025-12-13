extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var moves_label: Label = $MovesLabel

func _ready() -> void:
	# Find Grid manager in scene
	var grid = get_tree().get_root().get_node("Main").get_node_or_null("Grid")	# main scene assumption: Main.tscn is running at root:Main
	if grid:
		grid.connect("score_changed", Callable(self, "_on_score_changed"))
		grid.connect("moves_changed", Callable(self, "_on_moves_changed"))
	$RestartButton.pressed.connect(Callable(grid, "reset_game"))

func _on_score_changed(new_score):
	score_label.text = "Score: %d".format(new_score)

func _on_moves_changed(remaining_moves):
	moves_label.text = "Moves: %d".format(remaining_moves)
