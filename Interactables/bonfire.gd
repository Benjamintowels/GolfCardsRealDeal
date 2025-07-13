extends Node2D

# A rest site that you activate with fire and then you can rest there

@onready var bonfire_flame: Sprite2D = $BonfireFlame
@onready var bonfire_area: Area2D = $BonfireArea2D
@onready var top_height_marker: Marker2D = $TopHeight
@onready var ysort_point: Marker2D = $YsortPoint

# Flame animation properties
var flame_frames: Array[Texture2D] = []
var current_frame_index: int = 0
var animation_timer: float = 0.0
var animation_speed: float = 0.15  # Time between frame changes
var scale_variation: float = 0.1   # How much the flame scales
var base_scale: Vector2 = Vector2(1.0, 1.0)
var opacity_variation: float = 0.2 # How much opacity changes
var base_opacity: float = 1.0

# Height properties
var bonfire_height: float = 10.0  # Height from base to top

# Activation properties
var is_active: bool = false  # Whether the bonfire is lit
var cell_size: int = 48  # Tile size for grid calculations
var map_manager: Node = null  # Reference to map manager for tile checking

# Lighter dialog properties
var lighter_dialog: Control = null
var lighter_dialog_active: bool = false

func _ready():
	# Add to groups for Y-sorting and optimization
	add_to_group("visual_objects")
	add_to_group("ysort_objects")
	add_to_group("interactables")
	add_to_group("obstacles")  # Add to obstacles group for movement blocking
	
	setup_flame_animation()
	setup_collision_detection()
	
	# Initialize Y-sorting
	_update_ysort()
	
	# Find map manager for tile checking
	_find_map_manager()
	
	# Start inactive
	set_bonfire_active(false)
	
	# Add to obstacle map to block movement
	_add_to_obstacle_map()

func _find_map_manager():
	"""Find the map manager in the scene"""
	var course = get_tree().current_scene
	if course and course.has_node("MapManager"):
		map_manager = course.get_node("MapManager")

func _add_to_obstacle_map():
	"""Add bonfire to obstacle map to block movement"""
	var course = get_tree().current_scene
	if course and "obstacle_map" in course:
		var grid_pos = get_grid_position()
		course.obstacle_map[grid_pos] = self
		print("Bonfire: Added to obstacle map at position", grid_pos)

func blocks() -> bool:
	"""Return true to block movement on this tile"""
	return true

func setup_flame_animation():
	# Load flame textures
	flame_frames = [
		preload("res://Interactables/BonfireFlame1.png"),
		preload("res://Interactables/BonfireFlame2.png"),
		preload("res://Interactables/BonfireFlame3.png")
	]
	
	# Set initial frame
	if flame_frames.size() > 0:
		bonfire_flame.texture = flame_frames[0]
		bonfire_flame.visible = false  # Start hidden (inactive)

func setup_collision_detection():
	# Connect collision signals - use area_entered for Area2D collision detection
	bonfire_area.area_entered.connect(_on_area_entered)
	bonfire_area.area_exited.connect(_on_area_exited)

func _process(delta):
	if is_active:
		animate_flame(delta)
	
	# Check for fire tiles nearby
	_check_for_nearby_fire()
	
	# Check for player meditation when bonfire is active
	if is_active:
		_check_for_player_meditation()
	else:
		# Debug: Check if bonfire should be active but isn't
		if map_manager and _check_for_nearby_fire_debug():
			print("Bonfire: Should be active due to nearby fire but isn't!")

func animate_flame(delta):
	animation_timer += delta
	
	# Change frame
	if animation_timer >= animation_speed:
		animation_timer = 0.0
		current_frame_index = (current_frame_index + 1) % flame_frames.size()
		bonfire_flame.texture = flame_frames[current_frame_index]
	
	# Animate scale and opacity
	var time_factor = sin(Time.get_ticks_msec() * 0.003) * 0.5 + 0.5  # 0 to 1 oscillation
	var scale_factor = 1.0 + (time_factor * scale_variation)
	var opacity_factor = base_opacity - (time_factor * opacity_variation)
	
	bonfire_flame.scale = base_scale * scale_factor
	bonfire_flame.modulate = Color(1.0, 0.8, 0.6, opacity_factor)  # Orange-red-yellow tint

func _check_for_nearby_fire():
	"""Check if any adjacent tiles or the bonfire's own tile are on fire"""
	if is_active or not map_manager:
		return
	
	# Get bonfire's tile position
	var bonfire_tile = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
	
	# Check if bonfire's own tile is on fire
	if _is_tile_on_fire(bonfire_tile):
		set_bonfire_active(true)
		return
	
	# Check adjacent tiles (8-directional)
	var adjacent_positions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in adjacent_positions:
		var check_tile = bonfire_tile + direction
		if _is_tile_on_fire(check_tile):
			set_bonfire_active(true)
			return

func _is_tile_on_fire(tile_pos: Vector2i) -> bool:
	"""Check if a tile is currently on fire"""
	# Check for existing fire tiles in the scene
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile) and fire_tile.has_method("is_fire_active"):
			if fire_tile.get_tile_position() == tile_pos and fire_tile.is_fire_active():
				return true
	return false

func _check_for_nearby_fire_debug() -> bool:
	"""Debug version of fire check that returns true if any nearby tiles are on fire"""
	# Get bonfire's tile position
	var bonfire_tile = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
	
	# Check if bonfire's own tile is on fire
	if _is_tile_on_fire(bonfire_tile):
		return true
	
	# Check adjacent tiles (8-directional)
	var adjacent_positions = [
		Vector2i(0, -1),  # Up
		Vector2i(1, 0),   # Right
		Vector2i(0, 1),   # Down
		Vector2i(-1, 0),  # Left
		Vector2i(1, -1),  # Up-right
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(-1, -1)  # Up-left
	]
	
	for direction in adjacent_positions:
		var check_tile = bonfire_tile + direction
		if _is_tile_on_fire(check_tile):
			return true
	
	return false

func set_bonfire_active(active: bool):
	"""Set the bonfire's active state"""
	if is_active == active:
		return  # No change
	
	is_active = active
	
	if active:
		# Activate bonfire
		bonfire_flame.visible = true
		
		# Play activation sound
		var bonfire_sound = get_node_or_null("BonfireOn")
		if bonfire_sound and bonfire_sound.stream:
			bonfire_sound.play()
	else:
		# Deactivate bonfire
		bonfire_flame.visible = false

func _on_area_entered(area: Area2D):
	print("Bonfire: Area entered bonfire area:", area.name if area else "null")
	
	# Get the parent of the area (the actual object)
	var object = area.get_parent()
	if not object:
		print("Bonfire: No parent object found for area")
		return
	
	print("Bonfire: Object name:", object.name if object else "null")
	print("Bonfire: Object has get_ball_height:", object.has_method("get_ball_height") if object else "N/A")
	print("Bonfire: Object has get_ball_velocity:", object.has_method("get_ball_velocity") if object else "N/A")
	
	if object.has_method("get_ball_height") and object.has_method("get_ball_velocity"):
		print("Bonfire: Handling ball collision")
		handle_ball_collision(object)
	elif object.name == "Player" or (object.has_method("get_grid_position") and object.has_method("take_damage")):
		print("Bonfire: Handling player collision")
		handle_player_entered(object)
	else:
		print("Bonfire: Unknown object type entered")

func _on_area_exited(area: Area2D):
	# Handle any cleanup when ball leaves bonfire area
	pass

func handle_ball_collision(ball: Node2D):
	var ball_height = ball.get_ball_height()
	var ball_velocity = ball.get_ball_velocity()
	var ball_position = ball.global_position
	
	# Check if ball is in air (above ground level)
	if ball_height > 0:
		# Ball in air - check height against bonfire
		if ball_height < bonfire_height:
			# Ball hits bonfire wall - reflect
			reflect_ball_off_wall(ball, ball_velocity)
		else:
			# Ball passes over bonfire
			ball_passes_over(ball, ball_velocity)
	else:
		# Ball is rolling on ground
		reflect_ball_off_wall(ball, ball_velocity)

func handle_player_entered(player: Node2D):
	"""Handle when player enters bonfire area"""
	print("Bonfire: Player entered bonfire area")
	print("Bonfire: Player name:", player.name if player else "null")
	print("Bonfire: Bonfire is_active:", is_active)
	
	if is_active:
		print("Bonfire: Bonfire is already active, no dialog needed")
		return  # Already active, no need for lighter dialog
	
	print("Bonfire: Checking if player has lighter...")
	# Check if player has lighter equipped
	if _player_has_lighter():
		print("Bonfire: Player has lighter! Showing dialog...")
		show_lighter_dialog()
	else:
		print("Bonfire: Player does not have lighter equipped")

func _player_has_lighter() -> bool:
	"""Check if the player has a Lighter equipped"""
	print("Bonfire: Checking for equipment manager...")
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		print("Bonfire: Equipment manager found:", equipment_manager.name)
		if equipment_manager.has_method("has_lighter"):
			var has_lighter = equipment_manager.has_lighter()
			print("Bonfire: Equipment manager has_lighter() returned:", has_lighter)
			return has_lighter
		else:
			print("Bonfire: Equipment manager does not have has_lighter() method")
	else:
		print("Bonfire: Equipment manager not found in current scene")
	return false

func show_lighter_dialog():
	"""Show dialog asking if player wants to light the bonfire"""
	if lighter_dialog_active:
		return  # Already showing dialog
	
	lighter_dialog_active = true
	
	# Create dialog
	lighter_dialog = Control.new()
	lighter_dialog.name = "LighterDialog"
	lighter_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lighter_dialog.z_index = 1000
	lighter_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	lighter_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(400, 200)
	main_container.position = Vector2(-200, -100)
	main_container.z_index = 1000
	lighter_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = -1
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Light Bonfire?"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.ORANGE)
	title.position = Vector2(150, 20)
	title.size = Vector2(100, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "You have a Lighter equipped.\nWould you like to light this bonfire?"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(50, 60)
	message.size = Vector2(300, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	main_container.add_child(message)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 140)
	button_container.size = Vector2(200, 40)
	main_container.add_child(button_container)
	
	# Yes button
	var yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_lighter_yes)
	button_container.add_child(yes_button)
	
	# No button
	var no_button = Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(_on_lighter_no)
	button_container.add_child(no_button)
	
	# Add to UI layer
	var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(lighter_dialog)
	else:
		get_tree().current_scene.add_child(lighter_dialog)

func _on_lighter_yes():
	"""Player chose to light the bonfire"""
	set_bonfire_active(true)
	_close_lighter_dialog()

func _on_lighter_no():
	"""Player chose not to light the bonfire"""
	_close_lighter_dialog()

func _close_lighter_dialog():
	"""Close the lighter dialog"""
	if lighter_dialog and is_instance_valid(lighter_dialog):
		lighter_dialog.queue_free()
		lighter_dialog = null
	lighter_dialog_active = false

func reflect_ball_off_wall(ball: Node2D, velocity: Vector2):
	# Simple wall reflection - reverse horizontal velocity
	var reflected_velocity = Vector2(-velocity.x * 0.8, velocity.y)  # Reduce speed slightly
	ball.set_ball_velocity(reflected_velocity)

func ball_passes_over(ball: Node2D, velocity: Vector2):
	# Ball passes over bonfire - no collision, just continue
	# Could add visual effects here
	pass

# Getter methods for external access
func get_bonfire_height() -> float:
	return bonfire_height

func get_top_height_position() -> Vector2:
	return top_height_marker.global_position

func get_ysort_position() -> Vector2:
	return ysort_point.global_position

func get_y_sort_point() -> float:
	"""Get the Y-sort reference point for the bonfire"""
	# Use the YsortPoint marker for consistent Y-sorting
	if ysort_point:
		return ysort_point.global_position.y
	else:
		# Fallback to global position if no YsortPoint marker
		return global_position.y

func get_grid_position() -> Vector2i:
	"""Get the grid position of the bonfire"""
	return Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))

func is_bonfire_active() -> bool:
	"""Check if the bonfire is currently active"""
	return is_active

func _check_for_player_meditation():
	"""Check if player is adjacent to this bonfire and trigger meditation"""
	# Find the player - try multiple methods
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		# Try searching recursively through the scene tree
		player = _find_player_recursive(get_tree().current_scene)
	
	if not player or not player.has_method("get_grid_position"):
		return
	
	# Get player's grid position
	var player_grid_pos = player.get_grid_position()
	var bonfire_grid_pos = get_grid_position()
	
	# Check if player is adjacent (within 1 tile)
	var distance = abs(player_grid_pos.x - bonfire_grid_pos.x) + abs(player_grid_pos.y - bonfire_grid_pos.y)
	if distance <= 1 and distance > 0:  # Adjacent but not on the same tile
		# Check if player is not already meditating
		if player.has_method("is_currently_meditating") and not player.is_currently_meditating():
			# Check if player is not moving
			if player.has_method("is_currently_moving") and not player.is_currently_moving():
				# Trigger meditation
				if player.has_method("start_meditation"):
					player.start_meditation()
					print("✓ Player meditation triggered by adjacent bonfire at distance", distance)
					print("✓ Player position:", player_grid_pos, "Bonfire position:", bonfire_grid_pos)
	else:
		# Debug: Print distance when not adjacent
		if player.has_method("is_currently_meditating") and not player.is_currently_meditating():
			var distance_debug = abs(player_grid_pos.x - bonfire_grid_pos.x) + abs(player_grid_pos.y - bonfire_grid_pos.y)
			if distance_debug <= 3:  # Only print for nearby positions to avoid spam
				print("Bonfire: Player distance:", distance_debug, "Player pos:", player_grid_pos, "Bonfire pos:", bonfire_grid_pos)

func _find_player_recursive(node: Node) -> Node2D:
	"""Recursively search for a Player node in the scene tree"""
	if node.name == "Player":
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	
	return null

func _update_ysort():
	"""Update the Bonfire's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
