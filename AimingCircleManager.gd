extends Node2D
class_name AimingCircleManager

# Aiming circle properties
var aiming_circle: Control
var circle_visual: TextureRect
var distance_label: Label
var is_visible: bool = false

# Distance validation
var max_distance: float = 100.0
var player_position: Vector2 = Vector2.ZERO
var current_distance: float = 0.0
var validated_position: Vector2 = Vector2.ZERO

# Default reticle texture
var default_reticle_texture: Texture2D

func _ready():
	# Load default reticle texture
	default_reticle_texture = preload("res://UI/TargetCircle.png")

func create_aiming_circle(position: Vector2, max_distance_param: int = 100) -> void:
	"""Create the aiming circle at the specified position"""
	# Store the max distance
	max_distance = float(max_distance_param)
	
	# Remove existing circle if it exists
	if aiming_circle:
		aiming_circle.queue_free()
	
	# Create new aiming circle
	aiming_circle = Control.new()
	aiming_circle.name = "AimingCircle"
	# Center the circle properly based on texture size
	var texture_size = Vector2(50, 50)  # Default size
	if default_reticle_texture:
		texture_size = default_reticle_texture.get_size()
	aiming_circle.position = position - (texture_size / 2)
	aiming_circle.z_index = 100
	add_child(aiming_circle)
	
	# Create circle visual with TextureRect
	circle_visual = TextureRect.new()
	circle_visual.name = "CircleVisual"
	circle_visual.texture = default_reticle_texture
	# Set size to match the texture size
	if default_reticle_texture:
		circle_visual.size = default_reticle_texture.get_size()
	else:
		circle_visual.size = Vector2(50, 50)  # Fallback size
	circle_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(circle_visual)
	
	# Add distance label
	distance_label = Label.new()
	distance_label.name = "DistanceLabel"
	distance_label.text = str(int(max_distance)) + "px"
	distance_label.add_theme_font_size_override("font_size", 12)
	distance_label.add_theme_color_override("font_color", Color.WHITE)
	distance_label.position = Vector2(0, 55)
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aiming_circle.add_child(distance_label)
	
	# Initially hide the circle
	aiming_circle.visible = false
	is_visible = false

func show_aiming_circle() -> void:
	"""Show the aiming circle"""
	if aiming_circle:
		aiming_circle.visible = true
		is_visible = true

func hide_aiming_circle() -> void:
	"""Hide the aiming circle"""
	if aiming_circle:
		aiming_circle.visible = false
		is_visible = false

func set_player_position(pos: Vector2) -> void:
	"""Set the player position for distance calculations"""
	player_position = pos

func set_max_distance(distance: int) -> void:
	"""Set the maximum distance for the aiming circle"""
	max_distance = float(distance)
	if distance_label:
		distance_label.text = str(distance) + "px"
	print("AimingCircleManager: Updated max distance to", distance)

func update_aiming_circle_position(global_position: Vector2, local_position: Vector2) -> void:
	"""Update the aiming circle position with distance validation"""
	if aiming_circle:
		# Calculate distance from player using global position
		current_distance = player_position.distance_to(global_position)
		
		# Constrain the aiming circle to stay within max distance from player
		var constrained_global_position = global_position
		if current_distance > max_distance:
			# Calculate direction from player to mouse
			var direction = (global_position - player_position).normalized()
			# Constrain to max distance boundary
			constrained_global_position = player_position + (direction * max_distance)
			current_distance = max_distance
		
		# Store the validated position (global)
		validated_position = constrained_global_position
		
		# Always recalculate local position from constrained global position to handle camera movement
		var camera = get_parent()  # Assuming aiming circle is child of camera
		var constrained_local_position = local_position
		if camera and camera.has_method("to_local"):
			constrained_local_position = camera.to_local(constrained_global_position)
		
		# Get the actual texture size to center properly
		var texture_size = Vector2(50, 50)  # Default size
		if circle_visual and circle_visual.texture:
			texture_size = circle_visual.texture.get_size()
		
		# Center the circle on the local position
		aiming_circle.position = constrained_local_position - (texture_size / 2)
		
		# Update distance label
		update_distance_label(int(current_distance))
		
		# Change color based on distance - green for good distance, red for too far
		var sweet_spot_min = max_distance * 0.6  # 60% of max distance
		var sweet_spot_max = max_distance * 0.85  # 85% of max distance
		
		if current_distance >= max_distance * 0.9:  # 90% or more of max distance
			if circle_visual:
				circle_visual.modulate = Color.RED
			if distance_label:
				distance_label.add_theme_color_override("font_color", Color.RED)
		elif current_distance >= sweet_spot_min and current_distance <= sweet_spot_max:  # Sweet spot
			if circle_visual:
				circle_visual.modulate = Color.GREEN
			if distance_label:
				distance_label.add_theme_color_override("font_color", Color.GREEN)
		else:  # Too close or in between
			if circle_visual:
				circle_visual.modulate = Color.WHITE
			if distance_label:
				distance_label.add_theme_color_override("font_color", Color.WHITE)

func update_aiming_circle_rotation(rotation: float) -> void:
	"""Update the aiming circle rotation"""
	if aiming_circle:
		aiming_circle.rotation = rotation

func update_distance_label(distance: int) -> void:
	"""Update the distance label text"""
	if distance_label:
		distance_label.text = str(distance) + "px"

func get_current_position() -> Vector2:
	"""Get the current validated position of the aiming circle in global coordinates"""
	return validated_position

func set_reticle_texture(texture: Texture2D) -> void:
	"""Set the reticle texture for the aiming circle"""
	if circle_visual:
		circle_visual.texture = texture

func get_aiming_circle() -> Control:
	"""Get the aiming circle node"""
	return aiming_circle

func is_aiming_circle_visible() -> bool:
	"""Check if the aiming circle is visible"""
	return is_visible

func destroy_aiming_circle() -> void:
	"""Destroy the aiming circle"""
	if aiming_circle:
		aiming_circle.queue_free()
		aiming_circle = null
		circle_visual = null
		distance_label = null
		is_visible = false 