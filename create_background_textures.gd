extends Node

# Utility script to create basic background textures for testing
# Run this script to generate placeholder background textures

func _ready():
	print("Creating background textures...")
	create_background_textures()
	print("Background textures created!")

func create_background_textures():
	# Create Backgrounds directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("Backgrounds"):
		dir.make_dir("Backgrounds")
	
	# Create sky gradient
	create_sky_gradient()
	
	# Create mountain textures
	create_mountain_textures()
	
	# Create forest textures
	create_forest_textures()
	
	# Create desert textures
	create_desert_textures()
	
	# Create ocean textures
	create_ocean_textures()
	
	# Create Course1 specific textures
	create_course1_textures()

func create_sky_gradient():
	var image = Image.create(1024, 512, false, Image.FORMAT_RGBA8)
	
	# Create sky gradient (light blue to white)
	for y in range(512):
		var t = float(y) / 511.0
		var color = Color.LIGHT_BLUE.lerp(Color.WHITE, t)
		for x in range(1024):
			image.set_pixel(x, y, color)
	
	save_texture(image, "res://Backgrounds/sky_gradient.png")
	save_texture(image, "res://Backgrounds/forest_sky.png")
	save_texture(image, "res://Backgrounds/desert_sky.png")
	save_texture(image, "res://Backgrounds/ocean_sky.png")

func create_mountain_textures():
	# Distant mountains (light gray, very simple)
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Create simple mountain silhouette
	for x in range(1024):
		var height = 50 + sin(x * 0.01) * 30 + sin(x * 0.03) * 20
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.3
				image.set_pixel(x, y, Color(0.7, 0.7, 0.7, alpha))
	
	save_texture(image, "res://Backgrounds/distant_mountains.png")
	
	# Mid mountains (darker, more detailed)
	image.fill(Color.TRANSPARENT)
	for x in range(1024):
		var height = 80 + sin(x * 0.015) * 40 + sin(x * 0.05) * 30
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.5
				image.set_pixel(x, y, Color(0.5, 0.5, 0.5, alpha))
	
	save_texture(image, "res://Backgrounds/mid_mountains.png")
	
	# Near mountains (darkest, most detailed)
	image.fill(Color.TRANSPARENT)
	for x in range(1024):
		var height = 120 + sin(x * 0.02) * 50 + sin(x * 0.07) * 40
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.7
				image.set_pixel(x, y, Color(0.3, 0.3, 0.3, alpha))
	
	save_texture(image, "res://Backgrounds/near_mountains.png")

func create_forest_textures():
	# Distant trees (simple green shapes)
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for i in range(20):
		var x = i * 50 + randf() * 30
		var height = 60 + randf() * 40
		var width = 20 + randf() * 20
		
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height and abs(px - x) < width:
					var alpha = 0.4
					image.set_pixel(px, py, Color(0.2, 0.4, 0.2, alpha))
	
	save_texture(image, "res://Backgrounds/distant_trees.png")
	
	# Mid trees (more detailed)
	image.fill(Color.TRANSPARENT)
	for i in range(15):
		var x = i * 70 + randf() * 40
		var height = 80 + randf() * 50
		var width = 25 + randf() * 25
		
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height and abs(px - x) < width:
					var alpha = 0.6
					image.set_pixel(px, py, Color(0.1, 0.3, 0.1, alpha))
	
	save_texture(image, "res://Backgrounds/mid_trees.png")

func create_desert_textures():
	# Distant dunes (sandy brown)
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(1024):
		var height = 40 + sin(x * 0.008) * 30 + sin(x * 0.02) * 20
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.4
				image.set_pixel(x, y, Color(0.8, 0.7, 0.5, alpha))
	
	save_texture(image, "res://Backgrounds/distant_dunes.png")
	
	# Mid dunes (darker)
	image.fill(Color.TRANSPARENT)
	for x in range(1024):
		var height = 60 + sin(x * 0.012) * 40 + sin(x * 0.03) * 30
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.6
				image.set_pixel(x, y, Color(0.6, 0.5, 0.3, alpha))
	
	save_texture(image, "res://Backgrounds/mid_dunes.png")

func create_ocean_textures():
	# Ocean waves (blue with wave pattern)
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	
	for y in range(256):
		for x in range(1024):
			var wave = sin(x * 0.02 + y * 0.01) * 0.1
			var blue = 0.3 + wave + (y / 256.0) * 0.3
			blue = clamp(blue, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.1, 0.2, blue, 0.8))
	
	save_texture(image, "res://Backgrounds/ocean_waves.png")
	
	# Shore line (sandy beach)
	image.fill(Color.TRANSPARENT)
	for x in range(1024):
		var height = 30 + sin(x * 0.01) * 10
		for y in range(256):
			if y > 256 - height:
				var alpha = 0.7
				image.set_pixel(x, y, Color(0.9, 0.8, 0.6, alpha))
	
	save_texture(image, "res://Backgrounds/shore_line.png")

func create_course1_textures():
	# Create clouds texture
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Create cloud shapes
	for i in range(8):
		var x = i * 120 + randf() * 60
		var y = 50 + randf() * 100
		var size = 40 + randf() * 60
		
		# Create cloud blob
		for px in range(max(0, x - size), min(1024, x + size)):
			for py in range(max(0, y - size/2), min(256, y + size/2)):
				var dist = Vector2(px - x, py - y).length()
				if dist < size:
					var alpha = 0.6 * (1.0 - dist / size)
					image.set_pixel(px, py, Color(1.0, 1.0, 1.0, alpha))
	
	save_texture(image, "res://Backgrounds/clouds.png")
	
	# Create city skyline
	image.fill(Color.TRANSPARENT)
	for i in range(15):
		var x = i * 70 + randf() * 30
		var height = 80 + randf() * 120
		var width = 15 + randf() * 20
		
		# Create building
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height:
					var alpha = 0.7
					var color = Color(0.3, 0.3, 0.4, alpha)
					# Add some windows
					if (px - x) % 10 < 3 and (py - (256 - height)) % 15 < 5:
						color = Color(1.0, 1.0, 0.8, alpha)
					image.set_pixel(px, py, color)
	
	save_texture(image, "res://Backgrounds/city_skyline.png")
	
	# Create tree line textures (3 different layers)
	create_tree_line_textures()

func create_tree_line_textures():
	# TreeLine1 (closest, no parallax)
	var image = Image.create(1024, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for i in range(25):
		var x = i * 40 + randf() * 20
		var height = 100 + randf() * 60
		var width = 15 + randf() * 10
		
		# Create tree
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height:
					var alpha = 0.9
					image.set_pixel(px, py, Color(0.1, 0.3, 0.1, alpha))
	
	save_texture(image, "res://Backgrounds/tree_line_1.png")
	
	# TreeLine2 (medium distance, minimal parallax)
	image.fill(Color.TRANSPARENT)
	for i in range(20):
		var x = i * 50 + randf() * 25
		var height = 80 + randf() * 50
		var width = 12 + randf() * 8
		
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height:
					var alpha = 0.7
					image.set_pixel(px, py, Color(0.15, 0.35, 0.15, alpha))
	
	save_texture(image, "res://Backgrounds/tree_line_2.png")
	
	# TreeLine3 (farthest, more parallax)
	image.fill(Color.TRANSPARENT)
	for i in range(15):
		var x = i * 70 + randf() * 35
		var height = 60 + randf() * 40
		var width = 10 + randf() * 6
		
		for px in range(max(0, x - width), min(1024, x + width)):
			for py in range(256):
				if py > 256 - height:
					var alpha = 0.5
					image.set_pixel(px, py, Color(0.2, 0.4, 0.2, alpha))
	
	save_texture(image, "res://Backgrounds/tree_line_3.png")

func save_texture(image: Image, path: String):
	var error = image.save_png(path)
	if error == OK:
		print("✓ Created: ", path)
	else:
		print("✗ Failed to create: ", path, " (Error: ", error, ")") 