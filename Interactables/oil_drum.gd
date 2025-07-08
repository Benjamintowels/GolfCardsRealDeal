extends Node2D

# Oil drum interactable object
# This will work with the roof system and Y-sort system

# Import Explosion class for fire element explosions
const Explosion = preload("res://Particles/Explosion.gd")

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

# Collision areas for different states
var upright_collision_area: Area2D
var tipped_collision_area: Area2D

func _ready():
	# Add to groups for smart optimization
	add_to_group("interactables")
	add_to_group("collision_objects")
	
	# Initialize sprites - upright visible, tipped over hidden
	_initialize_sprites()
	
	# Set up collision areas for both states
	_setup_collision_areas()
	
	# Update Y-sort on ready
	call_deferred("_update_ysort")
	
	# Connect to ball landed signal to reset health
	_connect_to_ball_landed_signals()
	
	# Set up timer to check for new balls
	_setup_ball_check_timer()

func _initialize_sprites():
	"""Initialize the oil drum sprites - upright visible, tipped over hidden"""
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite and tipped_sprite:
		upright_sprite.visible = true
		tipped_sprite.visible = false
	else:
		print("✗ ERROR: Oil drum sprites not found!")

func _setup_collision_areas():
	"""Set up collision areas for both upright and tipped over states"""
	# Get collision areas
	upright_collision_area = get_node_or_null("Area2D")
	tipped_collision_area = get_node_or_null("OilDrumTippedOver/Area2D")
	
	if upright_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		upright_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		upright_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		upright_collision_area.connect("area_entered", _on_area_entered)
		upright_collision_area.connect("area_exited", _on_area_exited)
	else:
		print("✗ ERROR: Oil drum upright Area2D not found!")
	
	if tipped_collision_area:
		# Initially disable tipped collision area (only active when tipped over)
		tipped_collision_area.collision_layer = 0
		tipped_collision_area.collision_mask = 0
		tipped_collision_area.monitoring = false
		tipped_collision_area.monitorable = false
	else:
		print("✗ ERROR: Oil drum tipped Area2D not found!")
	
	# Setup HitBox for gun collision detection
	# NOTE: HitBoxes use collision layer 2 to avoid conflicts with golf balls (layer 1)
	# This prevents golf balls from colliding with HitBoxes while allowing weapons to detect them
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		# Add to hitboxes group for weapon system detection
		hitbox.add_to_group("hitboxes")
	else:
		print("✗ ERROR: Oil drum HitBox not found!")

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
	
	# Check throwing knives
	for knife in knives:
		if knife.has_signal("landed") and knife not in connected_balls:
			# Disconnect first to avoid duplicate connections
			if knife.is_connected("landed", _on_ball_landed):
				knife.disconnect("landed", _on_ball_landed)
			knife.connect("landed", _on_ball_landed)
			connected_balls.append(knife)
	
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
	
	# Also connect to any throwing knives in the scene
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if knife.has_signal("landed"):
			# Disconnect first to avoid duplicate connections
			if knife.is_connected("landed", _on_ball_landed):
				knife.disconnect("landed", _on_ball_landed)
			knife.connect("landed", _on_ball_landed)

func _on_ball_landed(final_tile: Vector2i):
	"""Reset oil drum health when ball lands"""
	if is_tipped_over:
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
	
	return final_damage

func take_damage(amount: int) -> void:
	"""Take damage and handle tipping over if health reaches 0, or explode if overkilled"""
	current_health = max(0, current_health - amount)
	
	# Check if this damage would overkill the oil drum
	# Overkill = damage - current_health (how much damage exceeds current health)
	var overkill_damage = amount - current_health
	
	# Overkill threshold: need at least 50 overkill damage to trigger explosion
	if overkill_damage >= 50:
		# Create a temporary ball node to pass to the explosion function
		var temp_ball = Node2D.new()
		temp_ball.name = "OverkillExplosionBall"
		
		# Add the ball to the scene temporarily
		get_parent().add_child(temp_ball)
		temp_ball.global_position = global_position
		
		# Trigger the explosion using the existing fire element logic
		_explode_oil_drum(temp_ball)
		
		# Remove the temporary ball
		temp_ball.queue_free()
	elif current_health <= 0 and not is_tipped_over:
		is_tipped_over = true
		_tip_over()

func _tip_over():
	"""Tip the oil drum over - switch sprites and collision shapes"""
	
	# Hide upright sprite and show tipped over sprite
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite and tipped_sprite:
		upright_sprite.visible = false
		tipped_sprite.visible = true
	
	# Switch collision areas
	if upright_collision_area and tipped_collision_area:
		# Disable upright area
		upright_collision_area.collision_layer = 0
		upright_collision_area.collision_mask = 0
		upright_collision_area.monitoring = false
		
		# Enable tipped area
		tipped_collision_area.collision_layer = 1
		tipped_collision_area.collision_mask = 1
		tipped_collision_area.monitoring = true
		tipped_collision_area.monitorable = true
		
		# Connect to tipped area signals
		if not tipped_collision_area.is_connected("area_entered", _on_area_entered):
			tipped_collision_area.connect("area_entered", _on_area_entered)
		if not tipped_collision_area.is_connected("area_exited", _on_area_exited):
			tipped_collision_area.connect("area_exited", _on_area_exited)
		
	# Update Y-sort for the new position
	call_deferred("_update_ysort")

func _tip_upright():
	"""Tip the oil drum back upright - switch sprites and collision shapes back"""
	
	# Show upright sprite and hide tipped over sprite
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite and tipped_sprite:
		upright_sprite.visible = true
		tipped_sprite.visible = false
	
	# Switch collision areas back
	if upright_collision_area and tipped_collision_area:
		# Enable upright area
		upright_collision_area.collision_layer = 1
		upright_collision_area.collision_mask = 1
		upright_collision_area.monitoring = true
		upright_collision_area.monitorable = true
		
		# Disable tipped area
		tipped_collision_area.collision_layer = 0
		tipped_collision_area.collision_mask = 0
		tipped_collision_area.monitoring = false
		tipped_collision_area.monitorable = false
		
		# Disconnect from tipped area signals
		if tipped_collision_area.is_connected("area_entered", _on_area_entered):
			tipped_collision_area.disconnect("area_entered", _on_area_entered)
		if tipped_collision_area.is_connected("area_exited", _on_area_exited):
			tipped_collision_area.disconnect("area_exited", _on_area_exited)
		
	# Update Y-sort for the new position
	call_deferred("_update_ysort")

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

func get_collision_radius() -> float:
	"""
	Get the collision radius for this oil drum.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 50.0  # Oil drum collision radius

func get_height() -> float:
	"""Get the height of this oil drum for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the oil drum area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_ball_collision on the oil drum
		pass

func _handle_area_collision(projectile: Node2D):
	"""Handle oil drum area collisions using proper Area2D detection"""
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		_reflect_projectile(projectile)
		return
	
	# Get projectile and oil drum heights
	var projectile_height = projectile.get_height()
	var oil_drum_height = Global.get_object_height_from_marker(self)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, oil_drum_height)
		return
	
	# Apply the collision logic:
	# If projectile height > oil drum height: allow entry and set ground level
	# If projectile height < oil drum height: reflect
	if projectile_height > oil_drum_height:
		_allow_projectile_entry(projectile, oil_drum_height)
	else:
		_reflect_projectile(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, oil_drum_height: float):
	"""Handle knife collision with oil drum area"""
	
	if knife_height > oil_drum_height:
		_allow_projectile_entry(knife, oil_drum_height)
	else:
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, oil_drum_height: float):
	"""Allow projectile to enter oil drum area and set ground level"""
	
	# Set the projectile's ground level to the oil drum height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(oil_drum_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = oil_drum_height
	
	# The projectile will now land on the oil drum instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the oil drum using proper circular collision detection"""
	
	# Play oil drum thunk sound for reflection (not for roof bounce)
	_play_oil_drum_sound()
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	# Use proper circular reflection
	var reflected_velocity = _calculate_circular_reflection(projectile, projectile_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

func _calculate_circular_reflection(projectile: Node2D, projectile_velocity: Vector2) -> Vector2:
	"""Calculate proper circular reflection for the oil drum"""
	var projectile_pos = projectile.global_position
	var oil_drum_pos = global_position
	
	# Get the oil drum's collision shape to determine the circle bounds
	var area2d = get_node_or_null("Area2D")
	var collision_shape = area2d.get_node_or_null("CollisionShape2D") if area2d else null
	
	if not collision_shape or not collision_shape.shape is CircleShape2D:
		return -projectile_velocity * 0.8  # Simple fallback
	
	# Get the circle's radius and position
	var circle_radius = collision_shape.shape.radius
	var circle_scale = collision_shape.scale
	var circle_offset = collision_shape.position
	
	# Calculate the actual circle radius (accounting for scale)
	var actual_radius = circle_radius * circle_scale.x  # Use X scale for uniform scaling
	
	# Calculate the circle's world center
	var circle_center = oil_drum_pos + circle_offset
	
	# Calculate the direction from circle center to projectile
	var to_projectile = projectile_pos - circle_center
	var distance_to_center = to_projectile.length()
	
	# If projectile is inside the circle, push it out first
	if distance_to_center < actual_radius:
		var push_direction = to_projectile.normalized()
		projectile.global_position = circle_center + push_direction * (actual_radius + 1.0)
	
	# Recalculate direction after potential push
	to_projectile = projectile.global_position - circle_center
	var normal_direction = to_projectile.normalized()
	
	# Calculate reflection using the circle's normal at the collision point
	# The normal is the direction from circle center to the collision point
	var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(normal_direction) * normal_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	return reflected_velocity

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
	"""Play the oil drum thunk sound - called by reflection system only"""
	# Check cooldown to prevent duplicate sounds
	var current_time = Time.get_ticks_msec() / 1000.0
	if has_meta("last_thunk_time") and get_meta("last_thunk_time") + 0.1 > current_time:
		return  # Still in cooldown
	
	var thunk = get_node_or_null("OilDrumThunk")
	if thunk:
		thunk.play()
		set_meta("last_thunk_time", current_time)

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
	
	# Note: Sound is now played in _reflect_projectile for actual collisions only

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball/knife collisions - check height to determine if ball/knife should pass through"""
	
	# Get ball height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	# Get oil drum height
	var oil_drum_height = Global.get_object_height_from_marker(self)
	
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above oil drum entirely - let it pass through
		return
	else:
		# Ball/knife is within or below oil drum height - handle collision
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with oil drum
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)
		

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with oil drum"""
	
	# Play collision sound effect
	_play_oil_drum_sound()
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with oil drum"""
	
	# Play collision sound effect
	_play_oil_drum_sound()
	
	# Apply collision effect to the ball
	_apply_ball_collision_effect(ball)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection effect to a knife using proper circular reflection"""
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	# Use proper circular reflection
	var reflected_velocity = _calculate_circular_reflection(knife, knife_velocity)
	
	# Apply the reflected velocity to the knife
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity

func _apply_ball_collision_effect(ball: Node2D) -> void:
	"""Apply collision effect to the ball (bounce, damage, etc.)"""
	
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if ball.has_method("is_ghost"):
		is_ghost_ball = ball.is_ghost
	elif "is_ghost" in ball:
		is_ghost_ball = ball.is_ghost
	elif ball.name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		# Ghost balls only reflect, no damage
		var ball_velocity = Vector2.ZERO
		if ball.has_method("get_velocity"):
			ball_velocity = ball.get_velocity()
		elif "velocity" in ball:
			ball_velocity = ball.velocity
		
		# Use proper circular reflection
		var reflected_velocity = _calculate_circular_reflection(ball, ball_velocity)
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity
		return
	
	# Check if this is a fire element ball - if so, explode the oil drum
	if _is_fire_element_ball(ball):
		_explode_oil_drum(ball)
		return
	
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	# Calculate damage based on ball velocity
	var damage = _calculate_velocity_damage(ball_velocity.length())
	
	# Check if this damage will tip over the oil drum
	var will_tip = damage >= current_health
	
	if will_tip:
		# Calculate overkill damage (negative health value)
		var overkill_damage = damage - current_health
		
		# Apply damage to the oil drum (this will set health to negative)
		take_damage(damage)
		
		# Apply velocity dampening based on overkill damage
		var dampened_velocity = _calculate_kill_dampening(ball_velocity, overkill_damage)
		
		# Apply the dampened velocity to the ball (no reflection)
		if ball.has_method("set_velocity"):
			ball.set_velocity(dampened_velocity)
		elif "velocity" in ball:
			ball.velocity = dampened_velocity
	else:
		# Normal collision - apply damage and reflect
		# Use proper circular reflection
		var reflected_velocity = _calculate_circular_reflection(ball, ball_velocity)
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate velocity dampening when ball tips over an oil drum"""
	# Define dampening ranges
	const MIN_OVERKILL = 1  # Minimum overkill for maximum dampening
	const MAX_OVERKILL = 60  # Maximum overkill for minimum dampening
	
	# Clamp overkill damage to our defined range
	var clamped_overkill = clamp(overkill_damage, MIN_OVERKILL, MAX_OVERKILL)
	
	# Calculate dampening factor (0.0 = no dampening, 1.0 = maximum dampening)
	# Higher overkill = less dampening (ball keeps more speed)
	var dampening_percentage = 1.0 - ((clamped_overkill - MIN_OVERKILL) / (MAX_OVERKILL - MIN_OVERKILL))
	
	# Apply dampening factor to velocity
	# Maximum dampening reduces velocity to 20% of original
	# Minimum dampening reduces velocity to 80% of original
	var dampening_factor = 0.2 + (dampening_percentage * 0.6)  # 0.2 to 0.8 range
	var dampened_velocity = ball_velocity * dampening_factor
	
	return dampened_velocity

func _is_fire_element_ball(ball: Node2D) -> bool:
	"""Check if the ball has a fire element"""
	
	if not ball.has_method("get_element"):
		return false
	
	var element = ball.get_element()
	if element:
		if element.name == "Fire":
			return true
		else:
			return false
	else:
		return false

func _explode_oil_drum(ball: Node2D) -> void:
	"""Explode the oil drum when hit by a fire element ball"""
	
	# Hide the oil drum sprites
	var upright_sprite = get_node_or_null("OilDrumUpright")
	var tipped_sprite = get_node_or_null("OilDrumTippedOver")
	
	if upright_sprite:
		upright_sprite.visible = false
	if tipped_sprite:
		tipped_sprite.visible = false
	
	# Disable collision areas
	if upright_collision_area:
		upright_collision_area.collision_layer = 0
		upright_collision_area.collision_mask = 0
		upright_collision_area.monitoring = false
		upright_collision_area.monitorable = false
	if tipped_collision_area:
		tipped_collision_area.collision_layer = 0
		tipped_collision_area.collision_mask = 0
		tipped_collision_area.monitoring = false
		tipped_collision_area.monitorable = false
	
	# Create explosion effect at the oil drum's position
	var explosion = Explosion.create_explosion_at_position(global_position, get_parent())
	
	if explosion:
		# Launch the golf ball with boosted velocity away from the explosion
		_launch_ball_from_explosion(ball)
		
		# Set the oil drum to be destroyed (it will be removed when the explosion completes)
		# We'll use a timer to remove the oil drum after the explosion animation
		var destroy_timer = Timer.new()
		destroy_timer.wait_time = 3.0  # Wait longer for explosion to complete (increased from 2.0)
		destroy_timer.one_shot = true
		destroy_timer.timeout.connect(_on_explosion_complete)
		add_child(destroy_timer)
		destroy_timer.start()

func _on_explosion_complete() -> void:
	"""Called when the explosion animation is complete - remove the oil drum"""
	queue_free()

func _launch_ball_from_explosion(ball: Node2D) -> void:
	"""Launch the golf ball with boosted velocity away from the explosion"""
	
	# Get the ball's current position and velocity
	var ball_pos = ball.global_position
	var oil_drum_pos = global_position
	
	# Calculate direction from explosion center to ball
	var direction_from_explosion = (ball_pos - oil_drum_pos).normalized()
	
	# Get the ball's current velocity
	var current_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		current_velocity = ball.get_velocity()
	elif "velocity" in ball:
		current_velocity = ball.velocity
	
	# Calculate explosion force based on distance from explosion center
	var distance_from_explosion = ball_pos.distance_to(oil_drum_pos)
	var explosion_force = 400.0  # Reduced base explosion force (was 800.0)
	
	# Reduce force based on distance (closer = more force)
	var distance_factor = clamp(1.0 - (distance_from_explosion / 200.0), 0.3, 1.0)
	explosion_force *= distance_factor
	
	# Add some randomness to the direction for more realistic explosion
	var random_angle = randf_range(-0.2, 0.2)  # Reduced random angle (was ±0.3)
	var randomized_direction = direction_from_explosion.rotated(random_angle)
	
	# Calculate new velocity: current velocity + explosion force in direction away from explosion
	var explosion_velocity = randomized_direction * explosion_force
	var new_velocity = current_velocity + explosion_velocity
	
	# Add much stronger upward component for more dramatic vertical effect
	var upward_force = 800.0 * distance_factor  # Increased upward force (was 400.0)
	new_velocity.y -= upward_force  # Negative Y is up in Godot
	
	# Cap the maximum velocity to prevent the ball from going too fast
	# Allow higher vertical velocity while limiting horizontal velocity
	var max_horizontal_velocity = 600.0  # Reduced horizontal cap (was 1200.0 total)
	var max_vertical_velocity = 1000.0   # Higher vertical cap for dramatic effect
	
	# Clamp horizontal velocity separately
	var horizontal_velocity = Vector2(new_velocity.x, 0)
	if horizontal_velocity.length() > max_horizontal_velocity:
		horizontal_velocity = horizontal_velocity.normalized() * max_horizontal_velocity
		new_velocity.x = horizontal_velocity.x
	
	# Clamp vertical velocity separately
	if abs(new_velocity.y) > max_vertical_velocity:
		new_velocity.y = -max_vertical_velocity if new_velocity.y < 0 else max_vertical_velocity
	
	# Apply the new velocity to the ball
	if ball.has_method("set_velocity"):
		ball.set_velocity(new_velocity)
	elif "velocity" in ball:
		ball.velocity = new_velocity
	
	# If the ball has a height system, give it some upward momentum
	if ball.has_method("get_height") and ball.has_method("set_velocity"):
		# Set a positive vertical velocity to make the ball go up
		var current_z = ball.get_height()
		if current_z <= 0.0:  # Only if ball is on the ground
			# Add upward velocity component
			var upward_velocity = -300.0  # Negative Y is up
			new_velocity.y = upward_velocity
			
			# Re-apply the updated velocity
			if ball.has_method("set_velocity"):
				ball.set_velocity(new_velocity)
