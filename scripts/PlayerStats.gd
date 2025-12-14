extends Node
# PLAYERSTATS.GD - Persistent Player Statistics
# ==============================================
# Tracks and saves high score and max level reached
# Uses ConfigFile to persist data between game sessions

const SAVE_PATH = "user://player_stats.cfg"

var high_score: int = 0
var max_level: int = 1

signal high_score_changed(new_high_score)
signal max_level_changed(new_max_level)

func _ready() -> void:
	load_stats()

func load_stats() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	if err == OK:
		high_score = config.get_value("player", "high_score", 0)
		max_level = config.get_value("player", "max_level", 1)
		print("Loaded stats - High Score: %d, Max Level: %d" % [high_score, max_level])
	else:
		print("No save file found. Starting with default stats.")
		high_score = 0
		max_level = 1

func save_stats() -> void:
	var config = ConfigFile.new()
	config.set_value("player", "high_score", high_score)
	config.set_value("player", "max_level", max_level)
	config.save(SAVE_PATH)
	print("Stats saved - High Score: %d, Max Level: %d" % [high_score, max_level])

func update_high_score(new_score: int) -> bool:
	if new_score > high_score:
		high_score = new_score
		save_stats()
		high_score_changed.emit(high_score)
		return true
	return false

func update_max_level(new_level: int) -> bool:
	if new_level > max_level:
		max_level = new_level
		save_stats()
		max_level_changed.emit(max_level)
		return true
	return false

func reset_stats() -> void:
	high_score = 0
	max_level = 1
	save_stats()
	high_score_changed.emit(high_score)
	max_level_changed.emit(max_level)
