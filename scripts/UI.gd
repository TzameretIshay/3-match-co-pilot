extends CanvasLayer
# UI.GD - User Interface Controller
# =================================
# Manages UI labels and buttons
# Updates score and moves display based on Grid signals

# Cache references to UI nodes
@onready var score_label: Label = $ScoreLabel
@onready var moves_label: Label = $MovesLabel

func _ready() -> void:
	# Find the Grid node and connect its signals
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var grid = current.get_node_or_null("Grid")
	if grid:
		# Connect grid signals to UI update functions
		grid.connect("score_changed", Callable(self, "_on_score_changed"))
		grid.connect("moves_changed", Callable(self, "_on_moves_changed"))
		
		# Connect restart button to grid's reset function
		$RestartButton.pressed.connect(Callable(grid, "reset_game"))

func _on_score_changed(new_score):
	# Update score label when score changes
	score_label.text = "Score: %d" % new_score

func _on_moves_changed(remaining_moves):
	# Update moves label when moves_left changes
	moves_label.text = "Moves: %d" % remaining_moves
