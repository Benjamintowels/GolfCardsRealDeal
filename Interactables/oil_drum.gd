extends Node2D

# Oil drum interactable object
# This will work with the roof system and Y-sort system

# Health system variables
var max_health: int = 50
var current_health: int = 50
var is_tipped_over: bool = false

# Damage calculation constants (same as other entities)
const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
const MAX_VELOCITY = 1200.0  # Maximum velocity for 88 damage

# Ball connection tracking
var connected_balls: Array = []
var ball_check_timer: Timer

func _ready():
	# Add to groups for smart optimization
	add_to_group("interactables")
	add_to_group("collision_objects")
	
	# Set up collision layers for the main Area2D node
	var main_area = get_node_or_null("Area2D")
	if main_area:
		# Connect to area_entered and area_exited signals for collision detection
		main_area.connect("area_entered", _on_area_entered)
		main_area.connect("area_exited", _on_area_exited)
		# Set collision layer to 1 so golf balls can detect it
		main_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		main_area.collision_mask = 1
		print("✓ Oil drum Area2D setup complete for collision detection")
	else:
		print("✗ ERROR: Oil drum Area2D not found!")
	
	# Update Y-sort on ready
	call_deferred("_update_ysort")
	
	# Connect to ball landed signal to reset health
	_connect_to_ball_landed_signals()
	
	# Set up timer to check for new balls
	_setup_ball_check_timer()

func _setup_ball_check_timer():
	"""Set up a timer to periodically check for new balls and connect to them"""
	ball_check_timer = Timer.new()
	ball_check_timer.wait_time = 1.0  # Check every second
	ball_check_timer.timeout.connect(_check_for_new_balls)
	add_child(ball_check_timer)
	ball_check_timer.start()

func _check_for_new_balls():
	"""Check for new balls and connect to their landed signals"""
	var golf_balls = get_tree().get_nodes_in_group("balls")
	var knives = get_tree().get_nodes_in_group("knives")
	
	# Check golf balls
	for ball in golf_balls:
		if ball.has_signal("landed") and ball not in connected_balls:
			# Disconnect first to avoid duplicate connections
			if ball.is_connected("landed", _on_ball_landed):
				ball.disconnect("landed", _on_ball_landed)
			ball.connect("landed", _on_ball_landed)
			connected_balls.append(ball)
			print("✓ Connected to new golf ball landed signal")
	
	# Check throwing knives
	for knife in knives:
		if knife.has_signal("landed") and knife not in connected_balls:
			# Disconnect first to avoid duplicate connections
			if knife.is_connected("landed", _on_ball_landed):
				knife.disconnect("landed", _on_ball_landed)
			knife.connect("landed", _on_ball_landed)
			connected_balls.append(knife)
			print("✓ Connected to new throwing knife landed signal")
	
	# Clean up invalid references
	connected_balls = connected_balls.filter(func(ball): return is_instance_valid(ball))

func connect_to_new_ball(ball: Node2D):
	"""Connect to a specific new ball's landed signal"""
	if ball.has_signal("landed") and ball not in connected_balls:
		# Disconnect first to avoid duplicate connections
		if ball.is_connected("landed", _on_ball_landed):
			ball.disconnect("landed", _on_ball_landed)
		ball.connect("landed", _on_ball_landed)
		connected_balls.append(ball)
		print("✓ Connected to new ball landed signal:", ball.name)

func _connect_to_ball_landed_signals():
	"""Connect to ball landed signals to reset oil drum health"""
	# Connect to any existing golf balls in the scene
	var golf_balls = get_tree().get_nodes_in_group("balls")
	for ball in golf_balls:
		if ball.has_signal("landed"):
			# Disconnect first to avoid duplicate connections
			if ball.is_connected("landed", _on_ball_landed):
				ball.disconnect("landed", _on_ball_landed)
			ball.connect("landed", _on_ball_landed)
			print("✓ Connected to existing golf ball landed signal")
	
	# Also connect to any throwing knives in the scene
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if knife.has_signal("landed"):
			# Disconnect first to avoid duplicate connections
			if knife.is_connected("landed", _on_ball_landed):
				knife.disconnect("landed", _on_ball_landed)
			knife.connect("landed", _on_ball_landed)
			print("✓ Connected to existing throwing knife landed signal")

func _on_ball_landed(final_tile: Vector2i):
	"""Reset oil drum health when ball lands"""
	if is_tipped_over:
		print("Oil drum health reset to", max_health, "after ball landed")
		current_health = max_health
		is_tipped_over = false
		_tip_upright()

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude"""
	# Clamp velocity to our defined range
	var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
	
	# Calculate damage percentage (0.0 to 1.0)
	var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	
	# Scale damage from 1 to 88
	var damage = 1 + (damage_percentage * 87)
	
	# Return as integer
	var final_damage = int(damage)
	
	print("=== OIL DRUM VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END OIL DRUM VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func take_damage(amount: int) -> void:
	"""Take damage and handle tipping over if health reaches 0"""
	current_health = max(0, current_health - amount)
	print("Oil drum took", amount, "damage. Current health:", current_health, "/", max_health)
	
	if current_health <= 0 and not is_tipped_over:
		print("Oil drum health reached 0 - tipping over!")
		is_tipped_over = true
		_tip_over()

func _tip_over():
	"""Tip the oil drum over - switch sprites and collision shapes"""
	print("=== TIPPING OIL DRUM OVER ===")
	
	# Hide upright sprite and show tipped over sprite
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite and tipped_sprite:
		upright_sprite.visible = false
		tipped_sprite.visible = true
		print("✓ Switched oil drum sprites")
	else:
		print("✗ ERROR: Oil drum sprites not found!")
	
	# Switch collision areas
	var upright_area = get_node_or_null("Area2D")
	var tipped_area = get_node_or_null("OilDrumTippedOver/Area2D")
	
	if upright_area and tipped_area:
		# Disconnect from upright area
		if upright_area.is_connected("area_entered", _on_area_entered):
			upright_area.disconnect("area_entered", _on_area_entered)
		if upright_area.is_connected("area_exited", _on_area_exited):
			upright_area.disconnect("area_exited", _on_area_exited)
		
		# Connect to tipped area
		tipped_area.connect("area_entered", _on_area_entered)
		tipped_area.connect("area_exited", _on_area_exited)
		tipped_area.collision_layer = 1
		tipped_area.collision_mask = 1
		
		# Disable upright area collision
		upright_area.collision_layer = 0
		upright_area.collision_mask = 0
		
		print("✓ Switched oil drum collision areas")
	else:
		print("✗ ERROR: Oil drum collision areas not found!")
	
	# Update Y-sort for the new position
	call_deferred("_update_ysort")
	
	print("=== OIL DRUM TIPPED OVER ===")

func _tip_upright():
	"""Tip the oil drum back upright - switch sprites and collision shapes back"""
	print("=== TIPPING OIL DRUM UPRIGHT ===")
	
	# Show upright sprite and hide tipped over sprite
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite and tipped_sprite:
		upright_sprite.visible = true
		tipped_sprite.visible = false
		print("✓ Switched oil drum sprites back to upright")
	else:
		print("✗ ERROR: Oil drum sprites not found!")
	
	# Switch collision areas back
	var upright_area = get_node_or_null("Area2D")
	var tipped_area = get_node_or_null("OilDrumTippedOver/Area2D")
	
	if upright_area and tipped_area:
		# Disconnect from tipped area
		if tipped_area.is_connected("area_entered", _on_area_entered):
			tipped_area.disconnect("area_entered", _on_area_entered)
		if tipped_area.is_connected("area_exited", _on_area_exited):
			tipped_area.disconnect("area_exited", _on_area_exited)
		
		# Connect back to upright area
		upright_area.connect("area_entered", _on_area_entered)
		upright_area.connect("area_exited", _on_area_exited)
		upright_area.collision_layer = 1
		upright_area.collision_mask = 1
		
		# Disable tipped area collision
		tipped_area.collision_layer = 0
		tipped_area.collision_mask = 0
		
		print("✓ Switched oil drum collision areas back to upright")
	else:
		print("✗ ERROR: Oil drum collision areas not found!")
	
	# Update Y-sort for the new position
	call_deferred("_update_ysort")
	
	print("=== OIL DRUM TIPPED UPRIGHT ===")

func get_y_sort_point() -> float:
	"""
	Get the Y-sort reference point for the oil drum.
	Uses the base of the oil drum (ground level) for consistent Y-sorting.
	"""
	# The oil drum sprite is positioned with negative Y offset
	# The base is at the bottom of the sprite
	var sprite = get_node_or_null("OilDrumUpright")
	if sprite:
		# Get the actual height of the oil drum sprite
		var drum_height = sprite.texture.get_height() * sprite.scale.y
		# The base is at the bottom of the sprite, so add the height to the sprite's Y position
		return sprite.global_position.y + drum_height
	else:
		# Fallback calculation based on sprite position
		return global_position.y + 30.0  # Approximate oil drum height

func _update_ysort():
	"""Update the Oil Drum's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")
	
	# Only print debug info once
	if not has_meta("ysort_update_printed"):
		print("Oil Drum Ysort updated - z_index:", z_index, " global_position:", global_position)
		set_meta("ysort_update_printed", true)

func get_collision_radius() -> float:
	"""
	Get the collision radius for this oil drum.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 50.0  # Oil drum collision radius

func _on_area_entered(area: Area2D):
	"""Handle collisions with the oil drum area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		# Play oil drum thunk sound for ALL collisions (both wall and roof bounce)
		_play_oil_drum_sound()
		
		# Use the simple roof bounce system for all projectiles
		if projectile.has_method("_handle_roof_bounce_collision"):
			projectile._handle_roof_bounce_collision(self)

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the oil drum area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0





func _on_tree_entered():
	"""Called when the oil drum enters the scene tree - connect to any new balls"""
	# Connect to ball landed signals when entering the scene
	call_deferred("_connect_to_ball_landed_signals")

func _on_tree_exited():
	"""Called when the oil drum exits the scene tree - disconnect signals"""
	# Stop the ball check timer
	if ball_check_timer and is_instance_valid(ball_check_timer):
		ball_check_timer.stop()
		ball_check_timer.queue_free()
	
	# Disconnect from all ball landed signals when leaving the scene
	for ball in connected_balls:
		if is_instance_valid(ball) and ball.has_signal("landed") and ball.is_connected("landed", _on_ball_landed):
			ball.disconnect("landed", _on_ball_landed)
	
	# Clear the connected balls array
	connected_balls.clear()

func get_is_tipped_over() -> bool:
	"""Get whether the oil drum is currently tipped over"""
	return is_tipped_over

func get_grid_position() -> Vector2i:
	"""Get the grid position of the oil drum"""
	if has_meta("grid_position"):
		return get_meta("grid_position")
	elif get("grid_position") != null:
		return get("grid_position")
	else:
		# Fallback: calculate grid position from world position
		var world_pos = global_position
		var cell_size = 48  # Default cell size
		# Since the oil drum is placed at cell center, we need to adjust for the offset
		var grid_x = floor((world_pos.x - cell_size / 2) / cell_size)
		var grid_y = floor((world_pos.y - cell_size / 2) / cell_size)
		return Vector2i(grid_x, grid_y)

func _play_oil_drum_sound() -> void:
	"""Play the oil drum thunk sound - called by reflection system"""
	# Check cooldown to prevent duplicate sounds
	var current_time = Time.get_ticks_msec() / 1000.0
	if has_meta("last_thunk_time") and get_meta("last_thunk_time") + 0.1 > current_time:
		return  # Still in cooldown
	
	var thunk = get_node_or_null("OilDrumThunk")
	if thunk:
		thunk.play()
		set_meta("last_thunk_time", current_time)
		print("✓ OilDrumThunk sound played for collision")
	else:
		print("✗ OilDrumThunk sound not found")

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""Handle collision with projectiles - called by roof bounce system"""
	# Calculate damage based on projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	var damage = _calculate_velocity_damage(projectile_velocity.length())
	
	# Apply damage to oil drum
	take_damage(damage)
	
	# Note: Sound is now played in _on_area_entered for all collisions
