extends Node2D

# A rest site that you activate with fire and then you can rest there

@onready var bonfire_flame: Sprite2D = $BonfireFlame
@onready var bonfire_area: Area2D = $BonfireArea2D
@onready var detect_area: Area2D = $DetectArea2D
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

# Meditation trigger properties
var last_meditation_trigger_time: float = 0.0  # Prevent rapid meditation triggers
var meditation_cooldown: float = 2.0  # Minimum time between meditation triggers

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
	
	# Connect to player movement signal for meditation checking
	_connect_to_player_movement()

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

func _connect_to_player_movement():
	"""Connect to player movement signal for meditation checking"""
	# Wait a frame to ensure the player is created
	await get_tree().process_frame
	
	# Find the player and connect to their movement signal
	var player = get_tree().current_scene.get_node_or_null("Player")
	
	if player and player.has_signal("moved_to_tile"):
		player.moved_to_tile.connect(_on_player_moved)
		print("Bonfire: Connected to player movement signal")
	else:
		print("Bonfire: Could not connect to player movement signal")

func _on_player_moved(new_grid_pos: Vector2i):
	"""Called when the player moves to a new tile"""
	if is_active:
		print("Bonfire: Player moved to", new_grid_pos, ", checking for meditation...")
		_check_for_player_meditation()

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
	# Setup ball collision area (BonfireArea2D)
	print("=== BONFIRE COLLISION SETUP DEBUG ===")
	print("Bonfire: Setting up collision detection")
	print("Bonfire: bonfire_area found:", bonfire_area != null)
	print("Bonfire: detect_area found:", detect_area != null)
	
	# Configure BonfireArea2D for ball collisions
	if bonfire_area:
		# Set collision layer to 1 so golf balls can detect it
		bonfire_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		bonfire_area.collision_mask = 1
		# Make sure the area is monitoring and monitorable for ball collisions
		bonfire_area.monitoring = true
		bonfire_area.monitorable = true
		
		print("Bonfire: bonfire_area collision layer:", bonfire_area.collision_layer)
		print("Bonfire: bonfire_area collision mask:", bonfire_area.collision_mask)
		print("Bonfire: bonfire_area monitoring:", bonfire_area.monitoring)
		print("Bonfire: bonfire_area monitorable:", bonfire_area.monitorable)
		
		# Connect ball collision signals
		bonfire_area.area_entered.connect(_on_ball_area_entered)
		bonfire_area.area_exited.connect(_on_ball_area_exited)
	
	# Configure DetectArea2D for player detection
	if detect_area:
		# Set collision layer to 0 (we don't want other objects to detect the bonfire)
		detect_area.collision_layer = 0
		# Set collision mask to 3 to detect player (layer 1 + layer 2 = 3)
		detect_area.collision_mask = 3
		# Make sure the area is monitoring (detecting other areas)
		detect_area.monitoring = true
		# Make sure the area is monitorable (can be detected by other areas)
		detect_area.monitorable = false  # We don't want other objects to detect the bonfire
		
		print("Bonfire: detect_area collision layer:", detect_area.collision_layer)
		print("Bonfire: detect_area collision mask:", detect_area.collision_mask)
		print("Bonfire: detect_area monitoring:", detect_area.monitoring)
		print("Bonfire: detect_area monitorable:", detect_area.monitorable)
		
		# Connect player detection signals
		detect_area.area_entered.connect(_on_player_area_entered)
		detect_area.area_exited.connect(_on_player_area_exited)
		
		# Check collision shape
		var collision_shape = detect_area.get_node_or_null("CollisionShape2D")
		if collision_shape:
			print("Bonfire: Detect collision shape found:", collision_shape.name)
			if collision_shape.shape:
				print("Bonfire: Detect collision shape type:", collision_shape.shape.get_class())
				if collision_shape.shape is CircleShape2D:
					print("Bonfire: Detect circle radius:", collision_shape.shape.radius)
					print("Bonfire: Detect circle radius with scale:", collision_shape.shape.radius * collision_shape.scale.x)
				print("Bonfire: Detect collision shape scale:", collision_shape.scale)
		else:
			print("Bonfire: No detect collision shape found!")
	
	print("Bonfire: Collision signals connected")
	print("=== END BONFIRE COLLISION SETUP DEBUG ===")

func _process(delta):
	if is_active:
		animate_flame(delta)
	
	# Check for fire tiles nearby
	_check_for_nearby_fire()
	
	# Meditation is now checked event-based (when bonfire becomes active, player enters area, or player moves)
	# No more timer-based checking for better performance
	
	# Debug: Check if bonfire should be active but isn't
	if not is_active and map_manager and _check_for_nearby_fire_debug():
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
		
		# Reset meditation cooldown so first meditation can trigger immediately
		last_meditation_trigger_time = 0.0
		
		# Play activation sound
		var bonfire_sound = get_node_or_null("BonfireOn")
		if bonfire_sound and bonfire_sound.stream:
			bonfire_sound.play()
		
		# Check for meditation immediately when bonfire becomes active
		# Use deferred call to ensure this happens after the bonfire is fully activated
		print("Bonfire: Just became active, checking for adjacent player...")
		call_deferred("_check_for_player_meditation")
		
		# Also check if player is already in the area
		call_deferred("_check_for_player_in_area")
	else:
		# Deactivate bonfire
		bonfire_flame.visible = false

func _find_player_in_hierarchy(node: Node) -> Node:
	"""Find the Player node in the parent hierarchy"""
	var current = node
	while current:
		if current.name == "Player":
			return current
		current = current.get_parent()
	return null

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
		print("Bonfire: Bonfire is active, checking for meditation trigger")
		# Check if enough time has passed since last meditation trigger
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_meditation_trigger_time >= meditation_cooldown:
			print("Bonfire: Cooldown passed, checking meditation conditions...")
			# Check if player should start meditating
			if player.has_method("is_currently_meditating"):
				var is_meditating = player.is_currently_meditating()
				print("Bonfire: Player is_currently_meditating() returned:", is_meditating)
				if not is_meditating:
					# Allow meditation even while moving (removed movement check)
					if player.has_method("start_meditation"):
						print("Bonfire: All conditions met, starting meditation...")
						player.start_meditation()
						last_meditation_trigger_time = current_time
						print("✓ Player meditation triggered by entering active bonfire area")
					else:
						print("Bonfire: Player missing start_meditation() method")
				else:
					print("Bonfire: Player is already meditating")
			else:
				print("Bonfire: Player missing is_currently_meditating() method")
		else:
			print("Bonfire: Meditation trigger on cooldown (", meditation_cooldown - (current_time - last_meditation_trigger_time), "s remaining)")
		return
	
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

func _check_for_player_in_area():
	"""Check if the player is already in the bonfire's detect area when it becomes active"""
	if not is_active:
		return
		
	print("Bonfire: Checking if player is already in detect area...")
	
	# Use the DetectArea2D to check for overlapping areas
	if detect_area:
		# Get all overlapping areas
		var overlapping_areas = detect_area.get_overlapping_areas()
		print("Bonfire: Found", overlapping_areas.size(), "overlapping areas")
		
		for area in overlapping_areas:
			var object = area.get_parent()
			if not object:
				continue
			
			print("Bonfire: Checking overlapping object:", object.name)
			
			# Check if this is the Player (either directly or through parent hierarchy)
			var player_node = _find_player_in_hierarchy(object)
			if player_node:
				print("Bonfire: Player is already in detect area, triggering detection...")
				# Trigger the area entered logic
				handle_player_entered(player_node)
				return
		
		print("Bonfire: No player found in detect area")
	else:
		print("Bonfire: No detect area found for area check")

func _check_for_player_meditation():
	"""Check if player is in the bonfire's detect area and trigger meditation"""
	print("=== BONFIRE MEDITATION CHECK ===")
	
	# Check if enough time has passed since last meditation trigger
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_meditation_trigger_time < meditation_cooldown:
		print("Bonfire: Still on cooldown, skipping meditation check")
		return  # Still on cooldown
	
	print("Bonfire: Cooldown passed, checking for player in detect area...")
	
	# Use the DetectArea2D to check for overlapping areas
	if not detect_area:
		print("Bonfire: No detect area found!")
		return
	
	var overlapping_areas = detect_area.get_overlapping_areas()
	print("Bonfire: Found", overlapping_areas.size(), "overlapping areas")
	
	for area in overlapping_areas:
		var object = area.get_parent()
		if not object:
			continue
		
		# Check if this is the Player (either directly or through parent hierarchy)
		var player_node = _find_player_in_hierarchy(object)
		if player_node:
			print("Bonfire: Player found in detect area, checking meditation status...")
			# Check if player is not already meditating
			if player_node.has_method("is_currently_meditating"):
				var is_meditating = player_node.is_currently_meditating()
				print("Bonfire: Player meditation status:", is_meditating)
				
				if not is_meditating:
					print("Bonfire: Player not meditating, triggering meditation...")
					# Trigger meditation
					if player_node.has_method("start_meditation"):
						print("Bonfire: Calling player.start_meditation()...")
						player_node.start_meditation()
						last_meditation_trigger_time = current_time
						print("✓ Player meditation triggered by bonfire detect area")
					else:
						print("Bonfire: Player missing start_meditation method")
				else:
					print("Bonfire: Player is already meditating")
			else:
				print("Bonfire: Player missing is_currently_meditating method")
			return
	
	print("Bonfire: No player found in detect area")
	print("=== END BONFIRE MEDITATION CHECK ===")



func _update_ysort():
	"""Update the Bonfire's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func debug_bonfire_detection():
	"""Debug function to test bonfire detection - can be called from console"""
	print("=== BONFIRE DEBUG DETECTION ===")
	print("Bonfire position:", global_position)
	print("Bonfire grid position:", get_grid_position())
	print("Bonfire is_active:", is_active)
	
	# Find player
	var player = get_tree().current_scene.get_node_or_null("Player")
	
	if player:
		print("Player found:", player.name)
		print("Player position:", player.global_position)
		print("Player grid position:", player.get_grid_position())
		
		var distance = player.get_grid_position().distance_to(get_grid_position())
		print("Distance to player:", distance)
		print("Should detect player:", distance <= 1.5)
		
		if is_active:
			print("Bonfire is active, checking meditation...")
			_check_for_player_meditation()
	else:
		print("No player found!")
	
	print("=== END BONFIRE DEBUG ===")

func test_activate_bonfire():
	"""Test function to manually activate the bonfire - can be called from console"""
	print("=== TESTING BONFIRE ACTIVATION ===")
	set_bonfire_active(true)
	print("Bonfire activated for testing")
	print("=== END TEST ACTIVATION ===")

func _on_ball_area_entered(area: Area2D):
	print("=== BONFIRE BALL AREA ENTERED DEBUG ===")
	print("Bonfire: Ball area entered bonfire area:", area.name if area else "null")
	print("Bonfire: Area parent name:", area.get_parent().name if area and area.get_parent() else "null")
	
	# Get the parent of the area (the actual object)
	var object = area.get_parent()
	if not object:
		print("Bonfire: No parent object found for area")
		return
	
	print("Bonfire: Object name:", object.name if object else "null")
	print("Bonfire: Object has get_ball_height:", object.has_method("get_ball_height") if object else "N/A")
	print("Bonfire: Object has get_ball_velocity:", object.has_method("get_ball_velocity") if object else "N/A")
	
	# Check if this is a ball collision
	if object.has_method("get_ball_height") and object.has_method("get_ball_velocity"):
		print("Bonfire: Handling ball collision")
		handle_ball_collision(object)
		return
	
	print("Bonfire: Unknown object type entered ball area (ignoring non-ball entities)")
	print("=== END BONFIRE BALL AREA ENTERED DEBUG ===")

func _on_ball_area_exited(area: Area2D):
	# Handle any cleanup when ball leaves bonfire area
	pass

func _on_player_area_entered(area: Area2D):
	print("=== BONFIRE PLAYER AREA ENTERED DEBUG ===")
	print("Bonfire: Player area entered detect area:", area.name if area else "null")
	print("Bonfire: Area parent name:", area.get_parent().name if area and area.get_parent() else "null")
	
	# Get the parent of the area (the actual object)
	var object = area.get_parent()
	if not object:
		print("Bonfire: No parent object found for area")
		return
	
	print("Bonfire: Object name:", object.name if object else "null")
	print("Bonfire: Object is Player:", object.name == "Player")
	
	# Check if this is the Player (either directly or through parent hierarchy)
	var player_node = _find_player_in_hierarchy(object)
	if player_node:
		print("Bonfire: Found Player in hierarchy:", player_node.name)
		print("Bonfire: Handling player detection")
		handle_player_entered(player_node)
		return
	
	print("Bonfire: Unknown object type entered player area (ignoring non-player entities)")
	print("=== END BONFIRE PLAYER AREA ENTERED DEBUG ===")

func _on_player_area_exited(area: Area2D):
	# Handle any cleanup when player leaves bonfire area
	pass
