tool
extends EditorScript

func _run() -> void:
	var colors = [
		Color8(244, 67, 54),
		Color8(33, 150, 243),
		Color8(76, 175, 80),
		Color8(255, 193, 7),
		Color8(156, 39, 176),
		Color8(0, 188, 212)
	]
	var size = 64
	for i in range(colors.size()):
		var img = Image.new()
		img.create(size, size, false, Image.FORMAT_RGBA8)
		img.lock()
		var col = colors[i]
		for y in range(size):
			for x in range(size):
				img.set_pixel(x, y, col)
		# draw a lighter circle in the middle
		var cx = size / 2
		var cy = size / 2
		var radius = int(size * 0.32)
		for y in range(size):
			for x in range(size):
				var dx = x - cx
				var dy = y - cy
				if dx * dx + dy * dy <= radius * radius:
					var base = img.get_pixel(x, y)
					var lit = base.linear_interpolate(Color(1,1,1,1), 0.22)
					img.set_pixel(x, y, lit)
		img.unlock()
		var path = "res://assets/tile_%d.png".format(i)
		var err = img.save_png(path)
		print("Saved: ", path, " -> ", err)
	print("Tile PNG generation complete.")
