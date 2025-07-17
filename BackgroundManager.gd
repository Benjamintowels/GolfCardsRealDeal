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
				"z_index": -266,
				"scale": Vector2(100.0, 100.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": 2535  # Same Y position as mountains
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
				"custom_y_position": -1700  # Override Y position
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
	},
	"driving_range": {
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
				"custom_y_position": 2800  # Closer Y position for tighter spacing
			},
			{
				"name": "Horizon",
				"texture_path": "res://Backgrounds/horizon.png",
				"parallax_factor": 6.5,  # Same as mountains
				"z_index": -266,
				"scale": Vector2(100.0, 100.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": 1480  # Aligned with top of grid map (10 rows * 48 cell size)
			},
			{
				"name": "DistantHill",
				"texture_path": "res://Backgrounds/distant_hill.png",
				"parallax_factor": 5.5,  # In front of mountains
				"z_index": -220,
				"scale": Vector2(1.4, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -700  # Closer Y position for tighter spacing
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
				"custom_y_position": -600  # Closer Y position for tighter spacing
			},
			{
				"name": "Clouds",
				"texture_path": "res://Backgrounds/clouds.png",
				"parallax_factor": 9.0,  # EXTREME - very high hyperspeed parallax
				"z_index": -200,
				"scale": Vector2(1.3, 1.0),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -900  # Closer Y position for tighter spacing
			},
			{
				"name": "TreeLine3",
				"texture_path": "res://Backgrounds/tree_line_3.png",
				"parallax_factor": 2.5,  # EXTREME - medium-high hyperspeed parallax
				"z_index": -120,
				"scale": Vector2(1.1, 1.0),
				"repeat_horizontal": false,
				"repeat_vertical": false,
				"custom_y_position": -600  # Closer Y position for tighter spacing
			},
			{
				"name": "TreeLine2",
				"texture_path": "res://Backgrounds/tree_line_2.png",
				"parallax_factor": 1.5,  # EXTREME - medium hyperspeed parallax
				"z_index": -100,
				"scale": Vector2(0.9, 0.9),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -580  # Closer Y position for tighter spacing
			},
			{
				"name": "Foreground",
				"texture_path": "res://Backgrounds/foreground.png",
				"parallax_factor": 0.5,  # Between TreeLine2 and TreeLine1
				"z_index": -85,
				"scale": Vector2(1.8, 1.8),
				"repeat_horizontal": true,
				"repeat_vertical": false,
				"custom_y_position": -400  # Closer Y position for tighter spacing
			},
			{
				"name": "TreeLine1",
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
var use_existing_layers: bool = false
var existing_layers_node: Node2D = null

# Vertical parallax for Driving Range
var vertical_parallax_enabled: bool = false
var camera_reference: Camera2D = null
var driving_range_zoom_min: float = 0.6  # Zoom out limit
var driving_range_zoom_max: float = 3.0  # Zoom in limit
var vertical_parallax_layers: Array = []  # Store layer data for vertical parallax

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
	

func set_theme(theme_name: String) -> void:
	"""
	Set the background theme
	
	Parameters:
	- theme_name: Name of the theme to use (e.g., "golf_course", "forest", "desert", "ocean")
	"""
	
	# Clear existing background layers
	clear_current_theme()
	
	# Set new theme
	current_theme = theme_name
	var theme_data = background_themes[theme_name]
	
	# Check if we should use existing layers
	if use_existing_layers and existing_layers_node:
		setup_existing_layers(theme_data)
	else:
		# Create background layers
		create_theme_layers(theme_data)
	
	theme_changed.emit(theme_name)

func set_use_existing_layers(enabled: bool, layers_node: Node2D = null) -> void:
	"""
	Configure the background manager to use pre-existing layers from a scene
	
	Parameters:
	- enabled: Whether to use existing layers instead of creating them
	- layers_node: The Node2D containing the background sprite layers
	"""
	use_existing_layers = enabled
	existing_layers_node = layers_node
	print("BackgroundManager: Use existing layers set to ", enabled)

func setup_existing_layers(theme_data: Dictionary) -> void:
	"""Set up background layers using pre-existing sprites from the scene"""
	if not existing_layers_node:
		print("ERROR: No existing layers node provided!")
		return
	
	print("Setting up existing background layers...")
	
	# Clear any existing layers in parallax system
	parallax_system.clear_all_layers()
	
	# Get all sprite children from the existing layers node
	var sprites = []
	for child in existing_layers_node.get_children():
		if child is Sprite2D:
			sprites.append(child)
	
	print("Found ", sprites.size(), " existing sprite layers")
	
	# Match existing sprites with theme data
	for layer_data in theme_data.layers:
		var layer_name = layer_data.get("name", "")
		var matching_sprite = null
		
		# Find matching sprite by name
		for sprite in sprites:
			if sprite.name == layer_name:
				matching_sprite = sprite
				break
		
		if matching_sprite:
			print("Setting up existing layer: ", layer_name)
			
			# Preserve editor settings - only apply z_index and parallax effects
			matching_sprite.z_index = layer_data.get("z_index", -100)
			
			# Use the sprite's current position and scale from the editor
			var editor_position = matching_sprite.position
			var editor_scale = matching_sprite.scale
			
			print("  - Using editor position: ", editor_position)
			print("  - Using editor scale: ", editor_scale)
			
			# Add to parallax system using editor position as base
			parallax_system.add_background_layer(
				matching_sprite,
				layer_data.get("parallax_factor", 0.0),
				layer_data.get("repeat_horizontal", true),
				layer_data.get("repeat_vertical", false),
				editor_position  # Use editor position as base position
			)
		else:
			print("WARNING: No matching sprite found for layer: ", layer_name)
			# Create fallback layer if needed
			create_background_layer(layer_data)
	
	print("✓ Existing background layers setup complete")

func create_theme_layers(theme_data: Dictionary) -> void:
	"""Create all layers for a theme"""
	
	for layer_data in theme_data.layers:
		create_background_layer(layer_data)

func create_background_layer(layer_data: Dictionary) -> void:
	"""Create a single background layer"""
	# Load texture
	var texture_path = layer_data.get("texture_path", "")
	
	# Try to load the texture
	var texture = load(texture_path)
	if not texture:
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
	
	parallax_system.add_background_layer(
		sprite,
		layer_data.get("parallax_factor", 0.0),
		layer_data.get("repeat_horizontal", true),
		layer_data.get("repeat_vertical", false),
		custom_base_position
	)
	

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
	
	# Store camera reference for vertical parallax
	camera_reference = camera

func enable_vertical_parallax(enabled: bool) -> void:
	"""Enable or disable vertical parallax for Driving Range"""
	vertical_parallax_enabled = enabled
	print("BackgroundManager: Vertical parallax ", "enabled" if enabled else "disabled")
	
	if enabled:
		# Start the vertical parallax update process
		set_process(true)
	else:
		# Stop the vertical parallax update process
		set_process(false)

func cleanup_vertical_parallax() -> void:
	"""Clean up vertical parallax when leaving Driving Range"""
	enable_vertical_parallax(false)
	vertical_parallax_layers.clear()
	print("BackgroundManager: Vertical parallax cleaned up")

func _process(delta: float) -> void:
	"""Process vertical parallax updates"""
	if vertical_parallax_enabled and camera_reference and vertical_parallax_layers.size() > 0:
		update_vertical_parallax()

func update_vertical_parallax() -> void:
	"""Update vertical positions of background layers based on camera zoom"""
	if not camera_reference or not existing_layers_node:
		return
	
	var current_zoom = camera_reference.zoom.x  # Assuming uniform zoom
	var zoom_ratio = (current_zoom - driving_range_zoom_min) / (driving_range_zoom_max - driving_range_zoom_min)
	zoom_ratio = clamp(zoom_ratio, 0.0, 1.0)
	
	# Update each layer's vertical position
	for layer_data in vertical_parallax_layers:
		var sprite = layer_data.sprite
		var zoomed_out_y = layer_data.zoomed_out_y
		var zoomed_in_y = layer_data.zoomed_in_y
		var vertical_factor = layer_data.vertical_factor
		var anchor_to_grid = layer_data.anchor_to_grid
		
		if sprite:
			if anchor_to_grid:
				# For anchored layers (like TreeLine1), keep them at the grid top position
				sprite.position.y = 0  # Grid top is at Y=0
			else:
				# Calculate target Y position based on zoom
				var target_y = lerp(zoomed_out_y, zoomed_in_y, zoom_ratio)
				
				# Apply vertical parallax factor (layers closer to camera move more)
				var parallax_y = target_y + (target_y - zoomed_out_y) * vertical_factor * zoom_ratio
				
				# Update sprite Y position (preserve X position)
				sprite.position.y = parallax_y

func setup_driving_range_vertical_parallax() -> void:
	"""Set up vertical parallax specifically for Driving Range"""
	if not existing_layers_node:
		print("ERROR: No existing layers node for vertical parallax setup!")
		return
	
	print("Setting up Driving Range vertical parallax...")
	
	# Clear previous layer data
	vertical_parallax_layers.clear()
	
	# Calculate world map grid boundaries
	# Driving Range grid: 250x10 cells, cell_size = 48
	var grid_top_y = 0  # Top of the world map grid
	var grid_bottom_y = 10 * 48  # Bottom of the world map grid (480)
	
	# Get the zoomed in reference node
	var zoomed_in_reference = existing_layers_node.get_parent().get_node_or_null("BackgroundLayersZoomedIn")
	if not zoomed_in_reference:
		print("WARNING: BackgroundLayersZoomedIn not found! Using fallback positions.")
	
	# Define layer names to process
	var layer_names = ["Sky", "Mountains", "Horizon", "DistantHill", "City", "Hill", "Clouds", "TreeLine3", "TreeLine2", "Foreground", "TreeLine1"]
	
	# Find sprites and set up vertical parallax data
	for sprite_name in layer_names:
		# Find the sprite in the existing layers node (zoomed in position)
		var sprite = existing_layers_node.get_node_or_null(sprite_name)
		if not sprite:
			print("  - WARNING: Sprite not found for vertical parallax: ", sprite_name)
			continue
		
		# Get zoomed in position (current editor position)
		var zoomed_in_y = sprite.position.y
		
		# Get zoomed out position from reference node
		var zoomed_out_y = zoomed_in_y  # Fallback to current position
		var anchor_to_grid = false
		var vertical_factor = 0.0
		
		if zoomed_in_reference:
			var zoomed_out_sprite = zoomed_in_reference.get_node_or_null(sprite_name)
			if zoomed_out_sprite:
				zoomed_out_y = zoomed_out_sprite.position.y
				print("  - Found zoomed out position for ", sprite_name, ": ", zoomed_out_y)
			else:
				print("  - WARNING: Zoomed out sprite not found: ", sprite_name)
		
		# Special handling for TreeLine1 (anchor to grid)
		if sprite_name == "TreeLine1":
			anchor_to_grid = true
			vertical_factor = 0.0
			zoomed_in_y = grid_top_y  # Always anchor to grid top
		else:
			# Calculate vertical factor based on distance from TreeLine1
			var distance_from_tree = abs(zoomed_out_y - grid_top_y)
			vertical_factor = clamp(distance_from_tree / 2000.0, 0.0, 1.0)  # Normalize to 0-1 range
		
		# Create layer data
		var layer_data = {
			"sprite": sprite,
			"zoomed_out_y": zoomed_out_y,
			"zoomed_in_y": zoomed_in_y,
			"vertical_factor": vertical_factor,
			"anchor_to_grid": anchor_to_grid
		}
		
		vertical_parallax_layers.append(layer_data)
		print("  - Set up vertical parallax for ", sprite_name, ": ", zoomed_out_y, " -> ", zoomed_in_y, " (factor: ", vertical_factor, ", anchored: ", anchor_to_grid, ")")
	
	print("✓ Driving Range vertical parallax setup complete with ", vertical_parallax_layers.size(), " layers")

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

	
	
func adjust_layer_position(layer_name: String, new_position: Vector2) -> void:
	"""Manually adjust the position of a specific layer"""
	
	# Find the sprite by searching through children recursively
	var sprite = find_sprite_by_name(parallax_system, layer_name)
	if sprite:
		sprite.position = new_position
		
		# Also update the base_position in the parallax system's BackgroundLayer
		# This is crucial for preventing the layer from resetting to the old position
		if parallax_system.has_method("update_layer_base_position"):
			parallax_system.update_layer_base_position(layer_name, new_position)
		
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
	# Find all sprites recursively and adjust their positions
	var sprites = find_all_sprites(parallax_system)
	for sprite in sprites:
		sprite.position += offset

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
	
	# Find the sprite by searching through children recursively
	var sprite = find_sprite_by_name(parallax_system, layer_name)
	if sprite:
		sprite.scale = new_scale
		
func reset_layer_offsets() -> void:
	"""Reset all layer offsets (useful when camera is repositioned)"""
	if parallax_system and parallax_system.has_method("reset_layer_offsets"):
		parallax_system.reset_layer_offsets()

func reset_layer_offset(layer_name: String) -> void:
	"""Reset the offset for a specific layer"""
	if parallax_system and parallax_system.has_method("reset_layer_offset"):
		parallax_system.reset_layer_offset(layer_name)
