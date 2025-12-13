extends Resource
class_name Match3BoardConfig

@export var rules: Array = []

func default_if_empty() -> void:
	if rules.is_empty():
		rules = [Match3Rule.new()]

class Match3Rule:
	var shape: String = "Horizontal"
	var min_size: int = 3
	var strict_size: bool = false
	var priority: int = 0
	var piece_to_spawn: StringName = "line" # e.g., "line", "bomb"

	func _init(_shape: String = "Horizontal", _min_size: int = 3, _strict: bool = false, _priority: int = 0, _spawn: StringName = "") -> void:
		shape = _shape
		min_size = _min_size
		strict_size = _strict
		priority = _priority
		piece_to_spawn = _spawn