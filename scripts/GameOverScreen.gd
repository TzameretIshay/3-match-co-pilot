extends CanvasLayer

signal restart_requested
signal next_level_requested

@export var is_victory: bool = false
@export var final_score: int = 0
@export var goal_score: int = 1000
@export var moves_used: int = 0
@export var moves_total: int = 30

func _ready() -> void:
	add_to_group("game_over_screen")
	update_display()

func update_display() -> void:
	var score_percent = int((float(final_score) / float(goal_score)) * 100)
	
	if is_victory:
		$Panel/VBox/TitleLabel.text = "VICTORY!"
		$Panel/VBox/TitleLabel.add_theme_color_override("font_color", Color.GREEN)
		$Panel/VBox/MessageLabel.text = "Congratulations! You reached the goal!"
		$Panel/VBox/NextButton.visible = true
		$Panel/VBox/StatsLabel.text = "Score: %d / %d (%d%%\n" % [final_score, goal_score, score_percent]
		$Panel/VBox/StatsLabel.text += "Moves used: %d / %d" % [moves_used, moves_total]
	else:
		$Panel/VBox/TitleLabel.text = "GAME OVER"
		$Panel/VBox/TitleLabel.add_theme_color_override("font_color", Color.RED)
		$Panel/VBox/MessageLabel.text = "You ran out of moves!"
		$Panel/VBox/NextButton.visible = false
		$Panel/VBox/StatsLabel.text = "Score: %d / %d (%d%%)\n" % [final_score, goal_score, score_percent]
		$Panel/VBox/StatsLabel.text += "Moves used: %d / %d" % [moves_used, moves_total]

func _on_RestartButton_pressed() -> void:
	restart_requested.emit()
	queue_free()

func _on_NextButton_pressed() -> void:
	next_level_requested.emit()
	queue_free()
