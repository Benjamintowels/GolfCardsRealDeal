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
var height: float = 150.0  # Player height (ball needs 69.0 to pass over)
var base_collision_area: Area2D
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true

# Ball collision delay system
var collision_delay_distance: float = 100.0  # Distance ball must travel before player collision activates
var ball_launch_position: Vector2 = Vector2.ZERO  # Store where ball was launched from

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
	
	print("[Player.gd] Player ready with height:", height, "and health:", current_health, "/", max_health)

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

func set_grid_position(pos: Vector2i, ysort_objects: Array = []):
	grid_pos = pos
	self.position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	if ysort_objects.size() > 0:
		update_z_index_for_ysort(ysort_objects)

func update_z_index_for_ysort(ysort_objects: Array) -> void:
	"""Update player Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

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
	var total_range = movement_range + base_mobility
	
	
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
	# Update Y-sort every frame to stay in sync with camera movement
	update_z_index_for_ysort([])

# Ball collision methods
func _setup_ball_collision() -> void:
	"""Setup the base collision area for ball detection"""
	# Create base collision area
	base_collision_area = Area2D.new()
	base_collision_area.name = "BaseCollisionArea"
	add_child(base_collision_area)
	
	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 12.0  # Slightly larger than player collision
	collision_shape.shape = shape
	collision_shape.position = Vector2(0, 25)  # Offset from player center to base
	base_collision_area.add_child(collision_shape)
	
	# Set collision layer to 1 so golf balls can detect it
	base_collision_area.collision_layer = 1
	# Set collision mask to 1 so it can detect golf balls on layer 1
	base_collision_area.collision_mask = 1
	# Connect to area_entered signal for collision detection
	base_collision_area.connect("area_entered", _on_base_area_entered)
	print("✓ Player base collision area setup complete")

func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collisions with the base collision area"""
	var ball = area.get_parent()
	print("=== PLAYER BASE COLLISION DETECTED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
		print("Valid ball detected:", ball.name)
		# Handle the collision
		_handle_ball_collision(ball)
	else:
		print("Invalid ball or non-ball object:", ball.name if ball else "Unknown")
	print("=== END PLAYER BASE COLLISION ===")

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball collisions - check height and delay to determine if ball should cause damage"""
	print("Handling ball collision - checking ball height and delay")
	
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
	
	# Get ball height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	print("Ball height:", ball_height, "Player height:", height)
	
	# Check if ball is above player entirely
	if ball_height > height:
		# Ball is above player entirely - let it pass through
		print("Ball is above player entirely (height:", ball_height, "> player height:", height, ") - passing through")
		return
	
	# Check collision delay - ball must travel minimum distance from launch position
	var ball_distance_from_launch = ball.global_position.distance_to(ball_launch_position)
	if ball_distance_from_launch < collision_delay_distance:
		print("Ball too close to launch position (", ball_distance_from_launch, "<", collision_delay_distance, ") - no damage")
		_apply_ball_reflection(ball)
		return
	
	# Ball is within player height and past delay distance - handle collision
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
