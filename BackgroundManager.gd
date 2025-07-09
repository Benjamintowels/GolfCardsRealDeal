extends Node
class_name BackgroundManager

# Background Manager
# Handles different background themes and automatically sets up parallax layers
# This makes it easy to switch between different background styles

signal theme_changed(theme_name: String)

# Background theme definitions
var background_themes = {
	"golf_course": {
		"layers": [
			{
				"name": "Sky",
				"texture_path": "res://Backgrounds/sky_gradient.png",
				"parallax_factor": 0.0,  # Static sky
				"z_index": -200,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "DistantMountains",
				"texture_path": "res://Backgrounds/distant_mountains.png",
				"parallax_factor": 0.1,  # Very slow movement
				"z_index": -150,
				"scale": Vector2(1.5, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "MidMountains",
				"texture_path": "res://Backgrounds/mid_mountains.png",
				"parallax_factor": 0.3,  # Slow movement
				"z_index": -120,
				"scale": Vector2(1.2, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "NearMountains",
				"texture_path": "res://Backgrounds/near_mountains.png",
				"parallax_factor": 0.5,  # Medium movement
				"z_index": -100,
				"scale": Vector2(1.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			}
		]
	},
	"forest": {
		"layers": [
			{
				"name": "Sky",
				"texture_path": "res://Backgrounds/forest_sky.png",
				"parallax_factor": 0.0,
				"z_index": -200,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "DistantTrees",
				"texture_path": "res://Backgrounds/distant_trees.png",
				"parallax_factor": 0.15,
				"z_index": -150,
				"scale": Vector2(1.5, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "MidTrees",
				"texture_path": "res://Backgrounds/mid_trees.png",
				"parallax_factor": 0.4,
				"z_index": -120,
				"scale": Vector2(1.2, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			}
		]
	},
	"desert": {
		"layers": [
			{
				"name": "Sky",
				"texture_path": "res://Backgrounds/desert_sky.png",
				"parallax_factor": 0.0,
				"z_index": -200,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "DistantDunes",
				"texture_path": "res://Backgrounds/distant_dunes.png",
				"parallax_factor": 0.2,
				"z_index": -150,
				"scale": Vector2(1.5, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "MidDunes",
				"texture_path": "res://Backgrounds/mid_dunes.png",
				"parallax_factor": 0.5,
				"z_index": -120,
				"scale": Vector2(1.2, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			}
		]
	},
	"ocean": {
		"layers": [
			{
				"name": "Sky",
				"texture_path": "res://Backgrounds/ocean_sky.png",
				"parallax_factor": 0.0,
				"z_index": -200,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "Ocean",
				"texture_path": "res://Backgrounds/ocean_waves.png",
				"parallax_factor": 0.3,
				"z_index": -150,
				"scale": Vector2(1.5, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "Shore",
				"texture_path": "res://Backgrounds/shore_line.png",
				"parallax_factor": 0.6,
				"z_index": -100,
				"scale": Vector2(1.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			}
		]
	},
	"course1": {
		"layers": [
			{
				"name": "Sky",
				"texture_path": "res://Backgrounds/sky_gradient.png",
				"parallax_factor": 8.0,  # EXTREME - hyperspeed movement (furthest away)
				"z_index": -300,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "Mountains",
				"texture_path": "res://Backgrounds/distant_mountains.png",
				"parallax_factor": 6.5,  # EXTREME - hyperspeed parallax
				"z_index": -250,
				"scale": Vector2(1.5, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1500  # Override Y position
			},
			{
				"name": "Horizon",
				"texture_path": "res://Backgrounds/horizon.png",
				"parallax_factor": 6.5,  # Same as mountains
				"z_index": -245,
				"scale": Vector2(2.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1500  # Same Y position as mountains
			},
			{
				"name": "DistantHill",
				"texture_path": "res://Backgrounds/distant_hill.png",
				"parallax_factor": 5.5,  # In front of mountains
				"z_index": -220,
				"scale": Vector2(1.4, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1400  # Override Y position
			},
			{
				"name": "Hill",
				"texture_path": "res://Backgrounds/hill.png",
				"parallax_factor": 5.2,  # In front of distant hill
				"z_index": -190,
				"scale": Vector2(0.9, 0.3),
				"repeat_horizontal": true,
				"repeat_vertical": false
			},
			{
				"name": "City",
				"texture_path": "res://Backgrounds/city_skyline.png",
				"parallax_factor": 5.0,  # Between hill layers
				"z_index": -210,
				"scale": Vector2(1.2, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1390  # Override Y position
			},
			{
				"name": "Clouds",
				"texture_path": "res://Backgrounds/clouds.png",
				"parallax_factor": 9.0,  # EXTREME - very high hyperspeed parallax
				"z_index": -200,
				"scale": Vector2(1.3, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1600  # Override Y position
			},
			{
				"name": "TreeLine3",
				"texture_path": "res://Backgrounds/tree_line_3.png",
				"parallax_factor": 2.5,  # EXTREME - medium-high hyperspeed parallax
				"z_index": -120,
				"scale": Vector2(1.1, 1.0),
				"repeat_horizontal": false,
				"repeat_vertical": false,
				"custom_y_position": -1029  # Override Y position
			},
			{
				"name": "TreeLine2",
				"texture_path": "res://Backgrounds/tree_line_2.png",
				"parallax_factor": 1.5,  # EXTREME - medium hyperspeed parallax
				"z_index": -100,
				"scale": Vector2(0.9, 0.9),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -1010  # Override Y position
			},
			{
				"name": "Foreground",
				"texture_path": "res://Backgrounds/foreground.png",
				"parallax_factor": 0.5,  # Between TreeLine2 and TreeLine1
				"z_index": -85,
				"scale": Vector2(1.8, 1.8),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -720  # Override Y position
			},
			{
				"name": "TreeLine",
				"texture_path": "res://Backgrounds/tree_line_1.png",
				"parallax_factor": 0.0,  # No parallax (static) - TreeLine1 stays fixed
				"z_index": -80,
				"scale": Vector2(1.0, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false
			}
		]
	}
}

# Current theme
var current_theme: String = ""
var parallax_system: Node2D = null
var background_container: Node2D = null

func _ready():
	# Create background container
	background_container = Node2D.new()
	background_container.name = "BackgroundContainer"
	background_container.z_index = -300  # Behind everything
	add_child(background_container)
	
	# Create parallax system
	var parallax_scene = preload("res://ParallaxBackground.tscn")
	parallax_system = parallax_scene.instantiate()
	background_container.add_child(parallax_system)
	
	print("✓ BackgroundManager initialized")

func set_theme(theme_name: String) -> void:
	"""
	Set the background theme
	
	Parameters:
	- theme_name: Name of the theme to use (e.g., "golf_course", "forest", "desert", "ocean")
	"""
	if not background_themes.has(theme_name):
		print("⚠ BackgroundManager: Theme '", theme_name, "' not found!")
		return
	
	if current_theme == theme_name:
		print("✓ BackgroundManager: Theme '", theme_name, "' is already active")
		return
	
	# Clear existing background layers
	clear_current_theme()
	
	# Set new theme
	current_theme = theme_name
	var theme_data = background_themes[theme_name]
	
	# Create background layers
	create_theme_layers(theme_data)
	
	print("✓ BackgroundManager: Switched to theme '", theme_name, "'")
	theme_changed.emit(theme_name)

func create_theme_layers(theme_data: Dictionary) -> void:
	"""Create all layers for a theme"""
	if not theme_data.has("layers"):
		print("⚠ BackgroundManager: Theme data missing 'layers' key")
		return
	
	for layer_data in theme_data.layers:
		create_background_layer(layer_data)

func create_background_layer(layer_data: Dictionary) -> void:
	"""Create a single background layer"""
	# Load texture
	var texture_path = layer_data.get("texture_path", "")
	if texture_path.is_empty():
		print("⚠ BackgroundManager: Layer missing texture_path")
		return
	
	# Try to load the texture
	var texture = load(texture_path)
	if not texture:
		print("⚠ BackgroundManager: Could not load texture: ", texture_path)
		# Create a fallback colored rectangle
		texture = create_fallback_texture(layer_data.get("name", "Unknown"))
	
	# Create sprite
	var sprite = Sprite2D.new()
	sprite.name = layer_data.get("name", "BackgroundLayer")
	sprite.texture = texture
	sprite.z_index = layer_data.get("z_index", -100)
	sprite.scale = layer_data.get("scale", Vector2.ONE)
	
	# Position sprite in world coordinates (not screen-relative)
	# The background should be positioned relative to the world grid, not the screen
	var screen_size = get_viewport().get_visible_rect().size
	
	# Calculate world-relative position
	# The world grid is centered at (0,0), so we position backgrounds relative to that
	var grid_width = 50 * 48  # grid_size.x * cell_size (from course_1.gd)
	var grid_height = 50 * 48  # grid_size.y * cell_size
	
	# Position backgrounds - use custom Y position if specified, otherwise use default
	var y_position = layer_data.get("custom_y_position", -grid_height / 2)
	sprite.position = Vector2(0, y_position)  # X=0, Y=custom or default
	
	# Add to parallax system with custom base position if specified
	var custom_base_position = Vector2.ZERO
	if layer_data.has("custom_y_position"):
		custom_base_position = Vector2(0, layer_data.get("custom_y_position"))
		print("✓ Using custom Y position for ", sprite.name, ": ", custom_base_position.y)
	else:
		print("⚠ No custom Y position for ", sprite.name, " - using default")
	
	parallax_system.add_background_layer(
		sprite,
		layer_data.get("parallax_factor", 0.0),
		layer_data.get("repeat_horizontal", true),
		layer_data.get("repeat_vertical", false),
		custom_base_position
	)
	
	print("✓ Created background layer: ", sprite.name, " at position: ", sprite.position, " with z_index: ", sprite.z_index)
	print("  - Texture size: ", texture.get_size() if texture else "None")
	print("  - Scale: ", sprite.scale)
	print("  - Screen size: ", screen_size)

func create_fallback_texture(layer_name: String) -> Texture2D:
	"""Create a fallback texture when the real texture can't be loaded"""
	var image = Image.create(512, 256, false, Image.FORMAT_RGBA8)
	
	# Create a simple gradient based on layer name
	var color1 = Color.WHITE
	var color2 = Color.LIGHT_BLUE
	
	if "mountain" in layer_name.to_lower():
		color1 = Color.LIGHT_GRAY
		color2 = Color.DARK_GRAY
	elif "tree" in layer_name.to_lower():
		color1 = Color.DARK_GREEN
		color2 = Color.FOREST_GREEN
	elif "desert" in layer_name.to_lower() or "dune" in layer_name.to_lower():
		color1 = Color.SANDY_BROWN
		color2 = Color.DARK_GOLDENROD
	elif "ocean" in layer_name.to_lower():
		color1 = Color.LIGHT_BLUE
		color2 = Color.DARK_BLUE
	elif "sky" in layer_name.to_lower():
		color1 = Color.LIGHT_BLUE
		color2 = Color.WHITE
	
	# Create gradient
	for y in range(256):
		var t = float(y) / 255.0
		var color = color1.lerp(color2, t)
		for x in range(512):
			image.set_pixel(x, y, color)
	
	var texture = ImageTexture.create_from_image(image)
	return texture

func clear_current_theme() -> void:
	"""Clear all current background layers"""
	if parallax_system:
		parallax_system.clear_all_layers()
	current_theme = ""

func get_current_theme() -> String:
	"""Get the name of the current theme"""
	return current_theme

func get_available_themes() -> Array:
	"""Get list of available theme names"""
	return background_themes.keys()

func set_camera_reference(camera: Camera2D) -> void:
	"""Set camera reference for the parallax system"""
	if parallax_system:
		parallax_system.set_camera_reference(camera)

func set_world_grid_center(world_center: Vector2) -> void:
	"""Set the world grid center for parallax calculations"""
	if parallax_system:
		# We need to access the world_grid_center property
		# Since it's a private property, we'll need to add a setter method to ParallaxBackground
		parallax_system.set_world_grid_center(world_center)

func get_parallax_system() -> Node2D:
	"""Get the parallax system instance"""
	return parallax_system

func get_background_info() -> Dictionary:
	"""Get information about the current background setup"""
	var info = {
		"current_theme": current_theme,
		"available_themes": get_available_themes(),
		"layer_count": 0,
		"layers": []
	}
	
	if parallax_system:
		info.layer_count = parallax_system.get_layer_count()
		info.layers = parallax_system.get_layer_info()
	
	return info

func debug_background_layers() -> void:
	"""Debug function to print information about all background layers"""
	print("=== BACKGROUND LAYERS DEBUG ===")
	if not parallax_system:
		print("No parallax system found!")
		return
	
	var layers = parallax_system.get_layer_info()
	print("Total layers: ", layers.size())
	
	for layer_info in layers:
		print("Layer: ", layer_info.name)
		print("  - Position: ", layer_info.position)
		print("  - Original parallax factor: ", layer_info.original_parallax_factor)
		print("  - Effective parallax factor: ", layer_info.effective_parallax_factor)
		print("  - Texture size: ", layer_info.texture_size)
		print("  - Layer index: ", layer_info.index)
		print("  - Is TreeLine: ", layer_info.is_tree_line)
		print("---")
	
	# Also show actual sprites found
	print("=== ACTUAL SPRITES FOUND ===")
	var sprites = find_all_sprites(parallax_system)
	print("Found ", sprites.size(), " sprites:")
	for sprite in sprites:
		print("  - ", sprite.name, " at position: ", sprite.position, " scale: ", sprite.scale, " visible: ", sprite.visible)
	print("=== END DEBUG ===")

func adjust_layer_position(layer_name: String, new_position: Vector2) -> void:
	"""Manually adjust the position of a specific layer"""
	if not parallax_system:
		print("No parallax system found!")
		return
	
	# Find the sprite by searching through children recursively
	var sprite = find_sprite_by_name(parallax_system, layer_name)
	if sprite:
		sprite.position = new_position
		
		# Also update the base_position in the parallax system's BackgroundLayer
		# This is crucial for preventing the layer from resetting to the old position
		if parallax_system.has_method("update_layer_base_position"):
			parallax_system.update_layer_base_position(layer_name, new_position)
		
		print("✓ Adjusted ", layer_name, " to position: ", new_position)
	else:
		print("⚠ Layer not found: ", layer_name)

func find_sprite_by_name(node: Node, name: String) -> Sprite2D:
	"""Recursively find a sprite by name"""
	for child in node.get_children():
		if child is Sprite2D and child.name == name:
			return child
		elif child is Node2D:
			var result = find_sprite_by_name(child, name)
			if result:
				return result
	return null

func adjust_all_layers_position(offset: Vector2) -> void:
	"""Adjust all layers by a specific offset"""
	if not parallax_system:
		print("No parallax system found!")
		return
	
	# Find all sprites recursively and adjust their positions
	var sprites = find_all_sprites(parallax_system)
	for sprite in sprites:
		sprite.position += offset
		print("✓ Adjusted ", sprite.name, " by offset: ", offset, " (new pos: ", sprite.position, ")")

func find_all_sprites(node: Node) -> Array:
	"""Recursively find all sprites"""
	var sprites = []
	for child in node.get_children():
		if child is Sprite2D:
			sprites.append(child)
		elif child is Node2D:
			sprites.append_array(find_all_sprites(child))
	return sprites

func set_layer_scale(layer_name: String, new_scale: Vector2) -> void:
	"""Manually adjust the scale of a specific layer"""
	if not parallax_system:
		print("No parallax system found!")
		return
	
	# Find the sprite by searching through children recursively
	var sprite = find_sprite_by_name(parallax_system, layer_name)
	if sprite:
		sprite.scale = new_scale
		print("✓ Set ", layer_name, " scale to: ", new_scale)
	else:
		print("⚠ Layer not found: ", layer_name)

func reset_layer_offsets() -> void:
	"""Reset all layer offsets (useful when camera is repositioned)"""
	if parallax_system and parallax_system.has_method("reset_layer_offsets"):
		parallax_system.reset_layer_offsets()
		print("✓ Reset all layer offsets via BackgroundManager")
	else:
		print("⚠ Cannot reset layer offsets - parallax system not available")

func reset_layer_offset(layer_name: String) -> void:
	"""Reset the offset for a specific layer"""
	if parallax_system and parallax_system.has_method("reset_layer_offset"):
		parallax_system.reset_layer_offset(layer_name)
	else:
		print("⚠ Cannot reset layer offset - parallax system not available") 
