extends AudioStreamPlayer
# MUSICPLAYER.GD - Background Music Manager
# =========================================
# Handles looping background music

func _ready() -> void:
	finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	# Restart the music when it finishes to create a loop
	play()
