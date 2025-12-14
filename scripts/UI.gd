extends CanvasLayer
# UI.GD - User Interface Controller
# =================================
# Manages UI labels and buttons
# Updates score, moves, and level display based on Grid signals

# Cache references to UI nodes
@onready var score_label: Label = $ScoreLabel
@onready var moves_label: Label = $MovesLabel
@onready var level_label: Label = $LevelLabel
@onready var high_score_label: Label = $HighScoreLabel
@onready var max_level_label: Label = $MaxLevelLabel

func _ready() -> void:
	# Connect to PlayerStats singleton for high score and max level
	if PlayerStats:
		PlayerStats.high_score_changed.connect(_on_high_score_changed)
		PlayerStats.max_level_changed.connect(_on_max_level_changed)
		# Initialize displays
		high_score_label.text = "High Score: %d" % PlayerStats.high_score
		max_level_label.text = "Max Level: %d" % PlayerStats.max_level
	
	# Find the Grid node and connect its signals
	var current = get_tree().get_current_scene()
	if current == null:
		return
	var grid = current.get_node_or_null("Grid")
	if grid:
		# Connect grid signals to UI update functions
		grid.connect("score_changed", Callable(self, "_on_score_changed"))
		grid.connect("moves_changed", Callable(self, "_on_moves_changed"))
		grid.connect("level_changed", Callable(self, "_on_level_changed"))
		
		# Connect restart button to grid's reset function
		$RestartButton.pressed.connect(Callable(grid, "reset_game"))

func _on_score_changed(new_score):
	# Update score label when score changes
	score_label.text = "Score: %d" % new_score

func _on_moves_changed(remaining_moves):
	# Update moves label when moves_left changes
	moves_label.text = "Moves: %d" % remaining_moves

func _on_level_changed(new_level):
	# Update level label when level changes
	level_label.text = "Level: %d" % new_level

func _on_high_score_changed(new_high_score):
	# Update high score label when high score changes
	high_score_label.text = "High Score: %d" % new_high_score

func _on_max_level_changed(new_max_level):
	# Update max level label when max level changes
	max_level_label.text = "Max Level: %d" % new_max_level
