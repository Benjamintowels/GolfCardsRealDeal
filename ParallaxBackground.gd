extends Node2D
class_name ParallaxBackgroundSystem

# Parallax Background System
# Creates multiple background layers that move at different speeds when the camera moves
# This creates a depth effect and makes the world feel more dynamic
# REVERSED: First layer moves most, progressively less behind TreeLine1

signal background_updated

# Background layer data structure
class BackgroundLayer:
	var sprite: Sprite2D
	var parallax_factor: float  # How much this layer moves relative to camera (0.0 = static, 1.0 = full movement)
	var base_position: Vector2
	var texture_size: Vector2
	var repeat_horizontal: bool = true
	var repeat_vertical: bool = false
	var total_offset: Vector2 = Vector2.ZERO  # Track total accumulated offset
	var layer_index: int = 0  # Track layer order for reversed parallax
	
	func _init(sprite_node: Sprite2D, factor: float, repeat_h: bool = true, repeat_v: bool = false, index: int = 0):
		sprite = sprite_node
		parallax_factor = factor
		base_position = sprite.position
		texture_size = sprite.texture.get_size() if sprite.texture else Vector2.ZERO
		repeat_horizontal = repeat_h
		repeat_vertical = repeat_v
		total_offset = Vector2.ZERO
		layer_index = index

# Background layers array
var background_layers: Array[BackgroundLayer] = []

# Camera reference
var camera: Camera2D = null

# World grid reference (this is what we anchor to)
var world_grid_center: Vector2 = Vector2.ZERO

# Screen dimensions
var screen_size: Vector2 = Vector2.ZERO

# Performance optimization
var last_camera_position: Vector2 = Vector2.ZERO
var update_threshold: float = 1.0  # Only update if camera moves more than this (reduced for testing)

# Parallax configuration
var max_parallax_factor: float = 0.3  # Dramatically reduced from 1.0
var tree_line_index: int = -1  # Index of TreeLine1 layer (will be set when found)

func _ready():
	# Get camera reference
	camera = get_tree().get_first_node_in_group("camera")
	if not camera:
		# Try to find camera in the scene
		var cameras = get_tree().get_nodes_in_group("camera")
		if cameras.size() > 0:
			camera = cameras[0]
		else:
			# Look for any Camera2D in the scene
			var camera_nodes = get_tree().get_nodes_in_group("Camera2D")
			if camera_nodes.size() > 0:
				camera = camera_nodes[0]
	
	if not camera:
		print("⚠ ParallaxBackground: No camera found! Background will not move.")
		return
	
	# Get screen size
	screen_size = get_viewport().get_visible_rect().size
	
	# Set world grid center (this is what we anchor the backgrounds to)
	# Assuming the world grid is centered at (0,0) or we can calculate it
	world_grid_center = Vector2.ZERO  # This should be the center of your world grid
	
	# Store initial camera position
	last_camera_position = camera.global_position
	
	# Connect to camera movement (if signal exists)
	if camera.has_signal("position_changed"):
		camera.position_changed.connect(_on_camera_moved)
	else:
		# Use polling method instead
		print("✓ ParallaxBackground: Using polling method for camera movement")
	
	print("✓ ParallaxBackground initialized with camera: ", camera.name, " and world grid center: ", world_grid_center)

func _process(_delta):
	# Update screen size if viewport changes
	var current_screen_size = get_viewport().get_visible_rect().size
	if current_screen_size != screen_size:
		screen_size = current_screen_size
		update_all_layers()
	
	# Always check for camera movement (for testing)
	if camera:
		check_camera_movement()

func add_background_layer(sprite: Sprite2D, parallax_factor: float, repeat_horizontal: bool = true, repeat_vertical: bool = false, custom_base_position: Vector2 = Vector2.ZERO) -> void:
	"""
	Add a new background layer
	
	Parameters:
	- sprite: The Sprite2D node to use as background
	- parallax_factor: How much this layer moves (0.0 = static, 1.0 = full camera movement)
	- repeat_horizontal: Whether to repeat the texture horizontally
	- repeat_vertical: Whether to repeat the texture vertically
	- custom_base_position: Custom base position (if Vector2.ZERO, uses sprite's current position)
	"""
	if not sprite or not sprite.texture:
		print("⚠ ParallaxBackground: Cannot add layer - sprite or texture is null")
		return
	
	# Add sprite as child if it's not already a child
	if sprite.get_parent() != self:
		add_child(sprite)
	
	# Create background layer with current index
	var layer_index = background_layers.size()
	var layer = BackgroundLayer.new(sprite, parallax_factor, repeat_horizontal, repeat_vertical, layer_index)
	
	# Override base position if custom position is provided
	if custom_base_position != Vector2.ZERO:
		layer.base_position = custom_base_position
		print("✓ Using custom base position for ", sprite.name, ": ", custom_base_position)
	
	background_layers.append(layer)
	
	# Check if this is TreeLine1 to set the reference point
	if sprite.name.contains("TreeLine1") or sprite.name.contains("tree_line_1"):
		tree_line_index = layer_index
		print("✓ Found TreeLine1 at index: ", tree_line_index)
	
	# Set initial position
	update_layer_position(layer)
	
	print("✓ Added background layer: ", sprite.name, " with parallax factor: ", parallax_factor, " at index: ", layer_index)

func remove_background_layer(sprite: Sprite2D) -> void:
	"""Remove a background layer by its sprite"""
	for i in range(background_layers.size()):
		if background_layers[i].sprite == sprite:
			# Remove from scene tree
			if sprite.get_parent() == self:
				remove_child(sprite)
				sprite.queue_free()
			
			background_layers.remove_at(i)
			
			# Update layer indices and tree_line_index
			update_layer_indices()
			
			print("✓ Removed background layer: ", sprite.name)
			return

func update_layer_indices() -> void:
	"""Update layer indices after removal and recalculate tree_line_index"""
	for i in range(background_layers.size()):
		background_layers[i].layer_index = i
		
		# Recalculate tree_line_index
		if background_layers[i].sprite.name.contains("TreeLine1") or background_layers[i].sprite.name.contains("tree_line_1"):
			tree_line_index = i
			print("✓ Updated TreeLine1 index to: ", tree_line_index)

func clear_all_layers() -> void:
	"""Remove all background layers"""
	# Remove all sprites from the scene tree
	for layer in background_layers:
		if layer.sprite and layer.sprite.get_parent() == self:
			remove_child(layer.sprite)
			layer.sprite.queue_free()
	
	background_layers.clear()
	tree_line_index = -1
	print("✓ Cleared all background layers")

func update_all_layers() -> void:
	"""Update all background layer positions"""
	for layer in background_layers:
		update_layer_position(layer)
	background_updated.emit()

func update_all_layers_with_movement(previous_camera_position: Vector2) -> void:
	"""Update all background layer positions with explicit camera movement"""
	for layer in background_layers:
		update_layer_position_with_movement(layer, previous_camera_position)
	background_updated.emit()

func calculate_reversed_parallax_factor(layer: BackgroundLayer) -> float:
	"""
	Calculate the reversed parallax factor based on layer position
	- First layer (index 0) moves the most (max_parallax_factor)
	- Progressively less movement behind TreeLine1
	- TreeLine1 and beyond have minimal to no movement
	- Custom parallax factors override the calculation
	"""
	# Check if this layer has a custom parallax factor that should override the calculation
	if layer.parallax_factor > 0.0 and layer.parallax_factor != 0.0:
		# Use the custom parallax factor, but scale it to the max_parallax_factor range
		var custom_factor = layer.parallax_factor * max_parallax_factor / 10.0  # Scale from 0-10 range to 0-max_parallax_factor
		print("✓ Using custom parallax factor for ", layer.sprite.name, ": ", layer.parallax_factor, " -> ", custom_factor)
		return custom_factor
	
	# Otherwise use the reversed calculation
	if tree_line_index == -1:
		# If no TreeLine1 found, use simple reversed order
		var total_layers = background_layers.size()
		if total_layers <= 1:
			return 0.0
		
		# First layer moves most, last layer moves least
		var reversed_factor = max_parallax_factor * (1.0 - float(layer.layer_index) / float(total_layers - 1))
		return max(0.0, reversed_factor)
	else:
		# TreeLine1 is the reference point
		if layer.layer_index <= tree_line_index:
			# Before and including TreeLine1: first layer moves most, TreeLine1 moves least
			var factor = max_parallax_factor * (1.0 - float(layer.layer_index) / float(tree_line_index))
			return max(0.0, factor)
		else:
			# After TreeLine1: minimal movement, progressively less
			var layers_after_tree = background_layers.size() - tree_line_index - 1
			if layers_after_tree <= 0:
				return 0.0
			
			var relative_index = layer.layer_index - tree_line_index - 1
			var factor = max_parallax_factor * 0.1 * (1.0 - float(relative_index) / float(layers_after_tree))
			return max(0.0, factor)

func update_layer_position(layer: BackgroundLayer) -> void:
	"""Update the position of a specific background layer"""
	if not layer or not layer.sprite or not camera:
		return
	
	# Calculate camera movement relative to world grid
	var camera_movement = camera.global_position - last_camera_position
	
	# Calculate the reversed parallax factor for this layer
	var effective_parallax_factor = calculate_reversed_parallax_factor(layer)
	
	# Only apply parallax to X movement, keep Y fixed
	var world_relative_offset = Vector2(camera_movement.x * effective_parallax_factor, 0.0)
	
	# Accumulate the total offset (only X component)
	layer.total_offset += world_relative_offset
	
	# First layer (index 0) is tethered to world grid - it moves with camera
	# Other layers move relative to the world grid
	if layer.layer_index == 0:
		# First layer moves with camera (tethered to world grid)
		layer.sprite.position = layer.base_position + layer.total_offset
	else:
		# Other layers move relative to world grid (reversed parallax)
		layer.sprite.position = layer.base_position - layer.total_offset
	
	# Handle texture repeating
	if layer.repeat_horizontal or layer.repeat_vertical:
		handle_texture_repeating(layer)

func update_layer_position_with_movement(layer: BackgroundLayer, previous_camera_position: Vector2) -> void:
	"""Update the position of a specific background layer with explicit camera movement"""
	if not layer or not layer.sprite or not camera:
		return
	
	# Calculate camera movement relative to world grid using the provided previous position
	var camera_movement = camera.global_position - previous_camera_position
	
	# Calculate the reversed parallax factor for this layer
	var effective_parallax_factor = calculate_reversed_parallax_factor(layer)
	
	# Only apply parallax to X movement, keep Y fixed
	var world_relative_offset = Vector2(camera_movement.x * effective_parallax_factor, 0.0)
	
	# Accumulate the total offset (only X component)
	layer.total_offset += world_relative_offset
	
	# First layer (index 0) is tethered to world grid - it moves with camera
	# Other layers move relative to the world grid
	if layer.layer_index == 0:
		# First layer moves with camera (tethered to world grid)
		layer.sprite.position = layer.base_position + layer.total_offset
	else:
		# Other layers move relative to world grid (reversed parallax)
		layer.sprite.position = layer.base_position - layer.total_offset
	
	# Handle texture repeating
	if layer.repeat_horizontal or layer.repeat_vertical:
		handle_texture_repeating(layer)

func handle_texture_repeating(layer: BackgroundLayer) -> void:
	"""Handle texture repeating for seamless backgrounds"""
	if not layer.sprite or not layer.sprite.texture:
		return
	
	var texture_size = layer.texture_size
	var camera_pos = camera.global_position
	
	# Horizontal repeating - only adjust scale, don't override position
	if layer.repeat_horizontal and texture_size.x > 0:
		var screen_width = screen_size.x
		var texture_width = texture_size.x * layer.sprite.scale.x
		
		# If the texture is smaller than screen, scale it up to cover
		if texture_width < screen_width:
			var scale_factor = screen_width / texture_width
			layer.sprite.scale.x *= scale_factor
	
	# Vertical repeating - only adjust scale, don't override position
	if layer.repeat_vertical and texture_size.y > 0:
		var screen_height = screen_size.y
		var texture_height = texture_size.y * layer.sprite.scale.y
		
		# If the texture is smaller than screen, scale it up to cover
		if texture_height < screen_height:
			var scale_factor = screen_height / texture_height
			layer.sprite.scale.y *= scale_factor

func check_camera_movement() -> void:
	"""Check if camera has moved and update layers if needed"""
	if not camera:
		return
	
	# Check if camera moved enough to warrant an update
	var camera_movement = camera.global_position.distance_to(last_camera_position)
	if camera_movement < update_threshold:
		return
	
	# Store the previous camera position for calculating movement
	var previous_camera_position = last_camera_position
	
	# Update last camera position AFTER updating layers
	last_camera_position = camera.global_position
	
	# Update all layers with the correct movement calculation
	update_all_layers_with_movement(previous_camera_position)

func _on_camera_moved() -> void:
	"""Called when camera position changes (signal method)"""
	check_camera_movement()

func set_camera_reference(new_camera: Camera2D) -> void:
	"""Set a new camera reference"""
	if camera and camera.has_signal("position_changed"):
		camera.position_changed.disconnect(_on_camera_moved)
	
	camera = new_camera
	if camera:
		last_camera_position = camera.global_position
		# Reset all layer X offsets when camera changes (preserve Y positions)
		reset_layer_offsets()
		if camera.has_signal("position_changed"):
			camera.position_changed.connect(_on_camera_moved)
			print("✓ ParallaxBackground: Camera reference updated to: ", camera.name, " (using signals)")
		else:
			print("✓ ParallaxBackground: Camera reference updated to: ", camera.name, " (using polling)")

func set_world_grid_center(new_center: Vector2) -> void:
	"""Set the world grid center for parallax calculations"""
	world_grid_center = new_center
	print("✓ ParallaxBackground: World grid center set to: ", world_grid_center)

func get_layer_count() -> int:
	"""Get the number of background layers"""
	return background_layers.size()

func get_layer_info() -> Array:
	"""Get information about all layers for debugging"""
	var info = []
	for i in range(background_layers.size()):
		var layer = background_layers[i]
		var effective_factor = calculate_reversed_parallax_factor(layer)
		info.append({
			"index": i,
			"name": layer.sprite.name if layer.sprite else "Unknown",
			"original_parallax_factor": layer.parallax_factor,
			"effective_parallax_factor": effective_factor,
			"position": layer.sprite.position if layer.sprite else Vector2.ZERO,
			"texture_size": layer.texture_size,
			"is_tree_line": (i == tree_line_index)
		})
	return info

func update_layer_base_position(layer_name: String, new_base_position: Vector2) -> void:
	"""Update the base position of a specific layer"""
	for layer in background_layers:
		if layer.sprite and layer.sprite.name == layer_name:
			# Preserve custom Y positions for specific layers
			var preserve_y = false
			if layer_name in ["Clouds", "Mountains", "DistantHill", "City", "Hill", "TreeLine2", "TreeLine3", "Foreground"]:
				preserve_y = true
				print("⚠ Preserving custom Y position for ", layer_name, " (not updating to: ", new_base_position, ")")
			
			if preserve_y:
				# Only update X position, preserve Y
				layer.base_position.x = new_base_position.x
				print("✓ Updated X base position for ", layer_name, " to: ", layer.base_position)
			else:
				# Update both X and Y
				layer.base_position = new_base_position
				print("✓ Updated base position for ", layer_name, " to: ", new_base_position)
			return
	print("⚠ Layer not found for base position update: ", layer_name)

func reset_layer_offsets() -> void:
	"""Reset all layer offsets (useful when camera is repositioned)"""
	for layer in background_layers:
		# Reset X offset to base position
		layer.total_offset.x = 0.0
		layer.sprite.position.x = layer.base_position.x
		# Ensure Y position matches the configured base position
		layer.sprite.position.y = layer.base_position.y
	print("✓ Reset all layer X offsets and restored Y positions to base")

func reset_layer_offset(layer_name: String) -> void:
	"""Reset the offset for a specific layer"""
	for layer in background_layers:
		if layer.sprite and layer.sprite.name == layer_name:
			# Reset X offset to base position
			layer.total_offset.x = 0.0
			layer.sprite.position.x = layer.base_position.x
			# Ensure Y position matches the configured base position
			layer.sprite.position.y = layer.base_position.y
			print("✓ Reset X offset and restored Y position to base for ", layer_name)
			return
	print("⚠ Layer not found for offset reset: ", layer_name)

func set_max_parallax_factor(new_factor: float) -> void:
	"""Set the maximum parallax factor (dramatically reduced effect)"""
	max_parallax_factor = clamp(new_factor, 0.0, 1.0)
	print("✓ Set max parallax factor to: ", max_parallax_factor)

func get_parallax_debug_info() -> Dictionary:
	"""Get detailed debug information about the parallax system"""
	return {
		"total_layers": background_layers.size(),
		"tree_line_index": tree_line_index,
		"max_parallax_factor": max_parallax_factor,
		"camera_position": camera.global_position if camera else Vector2.ZERO,
		"world_grid_center": world_grid_center,
		"layers": get_layer_info()
	} 
