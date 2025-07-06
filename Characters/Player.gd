extends CharacterBody2D

signal player_clicked
signal moved_to_tile(new_grid_pos: Vector2i)

var grid_pos: Vector2i
var movement_range: int = 1
var base_mobility: int = 0
var valid_movement_tiles: Array = []
var is_movement_mode: bool = false
var selected_card = null
var obstacle_map = {}
var grid_size: Vector2i
var cell_size: int = 48

# Highlight effect variables
var character_sprite: Sprite2D = null
var highlight_tween: Tween = null

# Ball collision and health properties
var base_collision_area: Area2D
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true

# Ball collision delay system
var collision_delay_distance: float = 100.0  # Distance ball must travel before player collision activates
var ball_launch_position: Vector2 = Vector2.ZERO  # Store where ball was launched from

# Mouse facing system
var game_phase: String = "move"  # Will be updated by parent
var is_charging: bool = false  # Will be updated by parent
var is_charging_height: bool = false  # Will be updated by parent
var camera: Camera2D = null  # Will be set by parent
var is_in_launch_mode: bool = false  # Track if we're in launch mode (ball flying)

# Performance optimization - Y-sort only when moving
# No camera tracking needed since camera panning doesn't affect Y-sort in 2.5D

func _ready():
	# Look for the character sprite (it's added as a direct child by the course script)
	for child in get_children():
		if child is Sprite2D:
			character_sprite = child
			print("[Player.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
			break
		elif child is Node2D:
			# Also check Node2D children in case the structure changes
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					character_sprite = grandchild
					print("[Player.gd] Found character sprite for highlight:", character_sprite, "Initial modulate:", character_sprite.modulate)
					break
	
	# Setup ball collision area
	_setup_ball_collision()
	
	# Connect to character scene's Area2D for collision detection
	_connect_character_collision()
	
	print("[Player.gd] Player ready with health:", current_health, "/", max_health)
	
	# Debug visual height
	var char_sprite = get_character_sprite()
	if char_sprite:
		Global.debug_visual_height(char_sprite, "Player")

func _connect_character_collision() -> void:
	"""Connect to the character scene's Area2D for collision detection"""
	var character_area = _find_character_area2d()
	if character_area:
		# Disconnect any existing connections to avoid duplicates
		if character_area.area_entered.is_connected(_on_character_area_entered):
			character_area.area_entered.disconnect(_on_character_area_entered)
		
		# Connect to the character's Area2D
		character_area.area_entered.connect(_on_character_area_entered)
		print("✓ Connected to character Area2D for collision detection")
	else:
		print("⚠ No character Area2D found for collision detection")

func get_character_sprite() -> Sprite2D:
	# First check direct children
	for child in get_children():
		if child is Sprite2D:
			return child
		elif child is Node2D:
			# Also check Node2D children in case the structure changes
			for grandchild in child.get_children():
				if grandchild is Sprite2D:
					return grandchild
	return null

func show_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] show_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 0, 0.6), 0.3)

func hide_highlight():
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] hide_highlight: No character sprite for highlight!")
		return
	if highlight_tween:
		highlight_tween.kill()
	highlight_tween = create_tween()
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.3)

func force_reset_highlight():
	var sprite = get_character_sprite()
	if sprite:
		sprite.modulate = Color(1, 1, 1, 1)
		if highlight_tween:
			highlight_tween.kill()
	else:
		print("[Player.gd] force_reset_highlight: No character sprite to reset!")

func flash_damage():
	"""Flash the player red to indicate damage taken"""
	var sprite = get_character_sprite()
	if not sprite:
		print("[Player.gd] flash_damage: No character sprite for damage flash!")
		return
	
	if highlight_tween:
		highlight_tween.kill()
	
	highlight_tween = create_tween()
	# Flash red for 0.3 seconds, then return to normal
	highlight_tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	highlight_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("player_clicked")

func setup(grid_size_: Vector2i, cell_size_: int, base_mobility_: int, obstacle_map_: Dictionary):
	grid_size = grid_size_
	cell_size = cell_size_
	base_mobility = base_mobility_
	obstacle_map = obstacle_map_
	
	# Create highlight sprite after setup is complete
	print("Setup complete, deferring highlight sprite creation...")
	call_deferred("create_highlight_sprite")

func set_grid_position(pos: Vector2i, ysort_objects: Array = [], shop_grid_pos: Vector2i = Vector2i.ZERO):
	grid_pos = pos
	self.position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	# OPTIMIZED: Always update Y-sort when player moves
	# Camera panning doesn't change Y-sort relationships in 2.5D perspective
	update_z_index_for_ysort(ysort_objects, shop_grid_pos)

func update_z_index_for_ysort(ysort_objects: Array, shop_grid_pos: Vector2i = Vector2i.ZERO) -> void:
	"""Update player Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")
	
	# Special case: If player is on shop entrance tile, ensure they appear on top of the shop
	if shop_grid_pos != Vector2i.ZERO and grid_pos == shop_grid_pos:
		# Force player to appear above shop by setting a higher z_index
		# The shop typically has z_index around 1000-1100, so we'll set player to 1200+
		var current_z = z_index
		var shop_entrance_z = 1200  # Higher than typical shop z_index
		if current_z < shop_entrance_z:
			z_index = shop_entrance_z
			print("✓ Player z_index boosted to", z_index, "for shop entrance")

func start_movement_mode(card, movement_range_: int):
	selected_card = card
	movement_range = movement_range_
	is_movement_mode = true
	calculate_valid_movement_tiles()

func end_movement_mode():
	is_movement_mode = false
	selected_card = null
	valid_movement_tiles.clear()

func calculate_valid_movement_tiles():
	
	valid_movement_tiles.clear()
	var equipment_mobility = get_equipment_mobility_bonus()
	var total_range = movement_range + base_mobility + equipment_mobility
	
	
	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)
			if calculate_grid_distance(grid_pos, pos) <= total_range and pos != grid_pos:
				if obstacle_map.has(pos):
					var obstacle = obstacle_map[pos]
					if obstacle.has_method("blocks") and obstacle.blocks():
						continue
				valid_movement_tiles.append(pos)
	
	

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func can_move_to(pos: Vector2i) -> bool:
	return is_movement_mode and pos in valid_movement_tiles

func move_to_grid(pos: Vector2i):
	
	if can_move_to(pos):
		set_grid_position(pos)
		emit_signal("moved_to_tile", pos)
		print("Signal emitted, ending movement mode")
		end_movement_mode()
		print("Movement mode ended")
	else:
		print("Movement is invalid - cannot move to this position")
	print("=== END PLAYER.GD MOVE_TO_GRID DEBUG ===")

func _process(delta):
	# OPTIMIZED: Only update Y-sort when Player moves
	# Camera panning doesn't change Y-sort relationships in 2.5D perspective
	# No need to update Y-sort every frame or when camera moves
	
	# Handle mouse facing system
	_update_mouse_facing()

func _update_mouse_facing() -> void:
	"""Update player sprite to face the mouse direction when appropriate"""
	var sprite = get_character_sprite()
	if not sprite:
		return
	
	# Only face mouse when it's player's turn and not in launch charge mode or ball flying mode
	var should_face_mouse = (
		game_phase == "move" or 
		game_phase == "aiming" or 
		game_phase == "draw_cards" or
		game_phase == "ball_tile_choice"
	) and not is_charging and not is_charging_height and not is_in_launch_mode
	
	if not should_face_mouse:
		return
	
	# Get mouse position in world space
	if not camera:
		return
	
	var mouse_world_pos = camera.get_global_mouse_position()
	var player_world_pos = global_position
	
	# Calculate direction from player to mouse
	var direction = mouse_world_pos - player_world_pos
	
	# Only update if mouse is not too close to player (to prevent jittering)
	if direction.length() < 10.0:
		return
	
	# Determine if mouse is to the left or right of player
	var mouse_is_left = direction.x < 0
	
	# Flip the sprite horizontally based on mouse position
	# Assuming the default sprite faces right, so we flip when mouse is on the left
	sprite.flip_h = mouse_is_left

# Ball collision methods
func _setup_ball_collision() -> void:
	"""Setup the base collision area for ball detection"""
	# Collision is now handled by the character scene's Area2D
	# No need to create additional collision areas
	print("✓ Player collision handled by character scene Area2D")

func _on_character_area_entered(area: Area2D) -> void:
	"""Handle collisions with the character's collision area"""
	var ball = area.get_parent()
	print("=== PLAYER CHARACTER COLLISION DETECTED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	
	# Check if this is a ghost ball and ignore it completely
	if ball and ball.name == "GhostBall":
		print("Ghost ball detected - ignoring collision completely")
		return
	
	if ball and (ball.name == "GolfBall" or ball.has_method("is_throwing_knife")):
		print("Valid ball/knife detected:", ball.name)
		# Handle the collision
		_handle_ball_collision(ball)
	else:
		print("Invalid ball/knife or non-ball object:", ball.name if ball else "Unknown")
	print("=== END PLAYER CHARACTER COLLISION ===")

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball/knife collisions - check height and delay to determine if ball/knife should cause damage"""
	print("Handling ball/knife collision - checking ball/knife height and delay")
	
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if ball.has_method("is_ghost"):
		is_ghost_ball = ball.is_ghost
	elif "is_ghost" in ball:
		is_ghost_ball = ball.is_ghost
	elif ball.name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		print("Ghost ball detected - no damage dealt, just reflection")
		# Ghost balls only reflect, no damage
		_apply_ball_reflection(ball)
		return
	
	# Check if this is a throwing knife
	if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
		# Handle knife collision with player
		_handle_knife_collision(ball)
		return
	
	# Handle regular ball collision
	_handle_regular_ball_collision(ball)

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with player"""
	print("Handling knife collision with player")
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(knife, self):
		# Knife is above player entirely - let it pass through
		print("Knife is above player entirely - passing through")
		return
	
	# Check collision delay - knife must travel minimum distance from launch position
	var knife_distance_from_launch = knife.global_position.distance_to(ball_launch_position)
	if knife_distance_from_launch < collision_delay_distance:
		print("Knife too close to launch position (", knife_distance_from_launch, "<", collision_delay_distance, ") - no damage")
		_apply_knife_reflection(knife)
		return
	
	# Knife is within player height and past delay - handle collision
	print("Knife is within player height and past delay - handling collision")
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_player_collision"):
		knife._handle_player_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with player"""
	print("Handling regular ball collision with player")
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball is above player entirely - let it pass through
		print("Ball is above player entirely - passing through")
		return
	
	# Check collision delay - ball must travel minimum distance from launch position
	var ball_distance_from_launch = ball.global_position.distance_to(ball_launch_position)
	if ball_distance_from_launch < collision_delay_distance:
		print("Ball too close to launch position (", ball_distance_from_launch, "<", collision_delay_distance, ") - no damage")
		_apply_ball_reflection(ball)
		return
	
	# Ball is within player height and past delay - handle collision
	print("Ball is within player height and past delay - handling collision")
	
	# Calculate damage based on ball velocity
	var damage = _calculate_velocity_damage(ball.get_velocity().length())
	print("Ball collision damage calculated:", damage)
	
	# Apply damage to the player
	take_damage(damage)
	
	# Apply ball reflection
	_apply_ball_reflection(ball)

func _apply_ball_reflection(ball: Node2D) -> void:
	"""Apply reflection effect to the ball"""
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	var ball_pos = ball.global_position
	var player_center = global_position
	
	# Calculate the direction from player center to ball
	var to_ball_direction = (ball_pos - player_center).normalized()
	
	# Simple reflection: reflect the velocity across the player center
	var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the ball
	if ball.has_method("set_velocity"):
		ball.set_velocity(reflected_velocity)
	elif "velocity" in ball:
		ball.velocity = reflected_velocity

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude (1-10 range)"""
	# Define velocity ranges for damage scaling
	const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
	const MAX_VELOCITY = 1200.0  # Maximum velocity for 10 damage
	
	# Clamp velocity to our defined range
	var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
	
	# Calculate damage percentage (0.0 to 1.0)
	var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	
	# Scale damage from 1 to 10
	var damage = 1 + (damage_percentage * 9)
	
	# Return as integer
	var final_damage = int(damage)
	
	# Debug output
	print("=== PLAYER VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END PLAYER VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func take_damage(amount: int) -> void:
	"""Take damage and handle death if health reaches 0"""
	if not is_alive:
		print("Player is already dead, ignoring damage")
		return
	
	current_health = max(0, current_health - amount)
	print("Player took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Flash red to indicate damage
	flash_damage()
	
	if current_health <= 0:
		print("Player health reached 0 - GAME OVER!")
		# You can add game over logic here
		is_alive = false
	else:
		print("Player survived with", current_health, "health")

func set_ball_launch_position(launch_pos: Vector2) -> void:
	"""Set the ball launch position for collision delay calculation"""
	ball_launch_position = launch_pos
	print("Ball launch position set to:", launch_pos)

# Returns the Y-sorting reference point (base of character's feet)
func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

# Mouse facing system methods
func set_game_phase(phase: String) -> void:
	"""Set the current game phase for mouse facing logic"""
	game_phase = phase

func set_launch_state(charging: bool, charging_height: bool) -> void:
	"""Set the launch charging state for mouse facing logic"""
	is_charging = charging
	is_charging_height = charging_height

func set_camera_reference(camera_ref: Camera2D) -> void:
	"""Set the camera reference for mouse position calculation"""
	camera = camera_ref

func disable_collision_shape() -> void:
	"""Disable the player's collision shape during launch mode"""
	# Find the character's Area2D and disable it
	var character_area = _find_character_area2d()
	if character_area:
		character_area.monitoring = false
		character_area.monitorable = false

func enable_collision_shape() -> void:
	"""Enable the player's collision shape after ball lands"""
	# Find the character's Area2D and enable it
	var character_area = _find_character_area2d()
	if character_area:
		character_area.monitoring = true
		character_area.monitorable = true

func _find_character_area2d() -> Area2D:
	"""Find the Area2D in the character scene"""
	for child in get_children():
		if child is Area2D:
			return child
		elif child is Node2D:
			# Check Node2D children
			for grandchild in child.get_children():
				if grandchild is Area2D:
					return grandchild
	return null

func set_launch_mode(launch_mode: bool) -> void:
	"""Set the launch mode state for mouse facing logic"""
	is_in_launch_mode = launch_mode

func get_equipment_mobility_bonus() -> int:
	"""Get the mobility bonus from equipped equipment"""
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		return equipment_manager.get_mobility_bonus()
	return 0

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection effect to a knife (fallback method)"""
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Applying knife reflection with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var player_center = global_position
	
	# Calculate the direction from player center to knife
	var to_knife_direction = (knife_pos - player_center).normalized()
	
	# Simple reflection: reflect the velocity across the player center
	var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected knife velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the knife
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity
