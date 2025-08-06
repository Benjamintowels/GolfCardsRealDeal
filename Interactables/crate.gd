extends Node2D

# Crate destructible object with health system
# Similar to OilDrum but with crate-specific properties

# Health system variables
var max_health: int = 15
var current_health: int = 15
var is_destroyed: bool = false

# Damage calculation constants (same as other entities)
const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
const MAX_VELOCITY = 1200.0  # Maximum velocity for 88 damage

# Ball connection tracking
var connected_balls: Array = []
var ball_check_timer: Timer

# Collision areas
var collision_area: Area2D

# Health bar system
var health_bar: HealthBar
var health_bar_container: Control

func _ready():
	# Add to groups for smart optimization and attack detection
	add_to_group("interactables")
	add_to_group("collision_objects")
	add_to_group("destructible_objects")  # New group for attack detection
	add_to_group("boulders")  # Add to boulders group for ball collision detection
	
	# Set up collision areas
	_setup_collision_areas()
	
	# Create health bar
	_create_health_bar()
	
	# Update Y-sort on ready
	call_deferred("_update_ysort")
	
	# Connect to ball landed signal to reset health
	_connect_to_ball_landed_signals()
	
	# Set up timer to check for new balls
	_setup_ball_check_timer()

func _setup_collision_areas():
	"""Set up collision areas for the crate"""
	# Get collision area for ball detection
	collision_area = get_node_or_null("CrateArea2D")
	
	if collision_area:
		# Set collision layer to 1 so golf balls can detect it
		collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		collision_area.connect("area_entered", _on_area_entered)
		collision_area.connect("area_exited", _on_area_exited)
		print("✓ Crate CrateArea2D collision setup complete")
	else:
		print("✗ ERROR: Crate CrateArea2D not found!")
	
	# Setup HitBox for gun collision detection
	# NOTE: HitBoxes use collision layer 2 to avoid conflicts with golf balls (layer 1)
	# This prevents golf balls from colliding with HitBoxes while allowing weapons to detect them
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		# Add to hitboxes group for weapon system detection
		hitbox.add_to_group("hitboxes")
		print("✓ Crate Hitbox collision setup complete")
	else:
		print("✗ ERROR: Crate Hitbox not found!")

func _create_health_bar():
	"""Create and position the health bar for the crate"""
	# Create health bar container
	health_bar_container = Control.new()
	health_bar_container.name = "HealthBarContainer"
	health_bar_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	health_bar_container.position.y = -80  # Position above the crate
	health_bar_container.size.y = 20
	add_child(health_bar_container)
	
	# Create health bar
	var HealthBar = preload("res://HealthBar.tscn")
	health_bar = HealthBar.instantiate()
	health_bar_container.add_child(health_bar)
	health_bar.set_health(current_health, max_health)
	
	# Initially hide health bar (only show when damaged)
	health_bar_container.visible = false

func _connect_to_ball_landed_signals():
	"""Connect to ball landed signals to reset health when ball lands"""
	# Connect to Global ball landed signal
	if Global.has_signal("ball_landed"):
		Global.connect("ball_landed", _on_ball_landed)
	
	# Connect to course ball landed signal if available
	var course = get_node_or_null("/root/Course1")
	if course and course.has_signal("ball_landed"):
		course.connect("ball_landed", _on_ball_landed)

func _setup_ball_check_timer():
	"""Set up timer to check for new balls"""
	ball_check_timer = Timer.new()
	ball_check_timer.wait_time = 0.1
	ball_check_timer.connect("timeout", _check_for_new_balls)
	add_child(ball_check_timer)
	ball_check_timer.start()

func _check_for_new_balls():
	"""Check for new balls and connect to them"""
	var balls = get_tree().get_nodes_in_group("golf_balls")
	for ball in balls:
		if ball not in connected_balls:
			connected_balls.append(ball)
			if ball.has_signal("ball_landed"):
				ball.connect("ball_landed", _on_ball_landed)

func _on_ball_landed():
	"""Reset health when ball lands"""
	if not is_destroyed:
		current_health = max_health
		if health_bar:
			health_bar.set_health(current_health, max_health)
		health_bar_container.visible = false

func take_damage(amount: int) -> void:
	"""Take damage and handle destruction"""
	
	# Play thunk sound when taking damage
	_play_crate_sound()
	
	# Calculate new health
	var new_health = current_health - amount
	
	# Apply damage
	current_health = max(0, new_health)
	
	# Update health bar
	if health_bar:
		health_bar.set_health(current_health, max_health)
		health_bar_container.visible = true
	
	# Check if we should be destroyed
	if current_health <= 0:
		# Crate is destroyed
		is_destroyed = true
		_destroy_crate()
	else:
		# Just take damage normally
		_flash_damage()

func _flash_damage():
	"""Flash the crate when taking damage"""
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		# Create a simple flash effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _destroy_crate():
	"""Destroy the crate and trigger explosion"""
	print("=== CRATE DESTROYED ===")
	
	# Hide the sprite and collision
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.visible = false
	
	# Disable collision areas
	if collision_area:
		collision_area.collision_layer = 0
		collision_area.collision_mask = 0
		collision_area.monitoring = false
		collision_area.monitorable = false
	
	var hitbox = get_node_or_null("Hitbox")
	if hitbox:
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0
		hitbox.monitoring = false
		hitbox.monitorable = false
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Play break sound
	_play_break_sound()
	
	# Trigger explosion
	_trigger_explosion()
	
	# Place reward
	_place_reward()

func _trigger_explosion():
	"""Trigger the crate explosion effect"""
	var explosion = get_node_or_null("CrateExplosion")
	if explosion:
		explosion.visible = true
		if explosion.has_method("trigger_explosion"):
			explosion.trigger_explosion()
		else:
			# Fallback: just make it visible
			explosion.visible = true

func _place_reward():
	"""Place a random reward on the crate's tile"""
	# This will be handled by the CrateExplosion script
	# The explosion script will place the reward at the crate's position
	pass

func _play_crate_sound():
	"""Play the crate thunk sound - called by reflection system only"""
	# Check cooldown to prevent duplicate sounds
	var current_time = Time.get_ticks_msec() / 1000.0
	if has_meta("last_thunk_time") and get_meta("last_thunk_time") + 0.1 > current_time:
		return  # Still in cooldown
	
	var thunk = get_node_or_null("Thunk")
	if thunk:
		thunk.play()
		set_meta("last_thunk_time", current_time)

func _play_break_sound():
	"""Play the crate break sound when destroyed"""
	var break_sound = get_node_or_null("BoxBreak")
	if break_sound:
		break_sound.play()

func _calculate_velocity_damage(velocity: float) -> int:
	"""Calculate damage based on velocity"""
	if velocity < MIN_VELOCITY:
		return 0
	elif velocity > MAX_VELOCITY:
		return 88
	else:
		# Linear interpolation between MIN_VELOCITY and MAX_VELOCITY
		var damage_ratio = (velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
		return int(damage_ratio * 87) + 1

func get_y_sort_point() -> float:
	"""
	Get the Y-sort reference point for the crate.
	Uses the base of the crate (ground level) for consistent Y-sorting.
	"""
	# The crate sprite is positioned at the center
	# The base is at the bottom of the sprite
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		# Get the actual height of the crate sprite
		var crate_height = sprite.texture.get_height() * sprite.scale.y
		# The base is at the bottom of the sprite, so add the height to the sprite's Y position
		return sprite.global_position.y + crate_height / 2
	else:
		# Fallback calculation based on sprite position
		return global_position.y + 16.0  # Approximate crate height

func _update_ysort():
	"""Update the Crate's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this crate.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 25.0  # Crate collision radius

func get_height() -> float:
	"""Get the height of this crate for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the crate area using proper height-based detection"""
	print("=== CRATE AREA ENTERED ===")
	print("Area:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "None")
	
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		print("✓ Handling throwing knife collision")
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_ball_collision on the crate
		print("✓ Ball collision detected - ball will handle collision")
		# The ball's collision system should call _handle_ball_collision on this crate

func _on_area_exited(area: Area2D):
	"""Handle area exit if needed"""
	pass

func _handle_area_collision(projectile: Node2D):
	"""Handle area collision with projectiles"""
	# Calculate damage based on projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	var damage = _calculate_velocity_damage(projectile_velocity.length())
	
	# Apply damage to crate
	take_damage(damage)

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball/knife collisions - check height to determine if ball/knife should pass through"""
	print("=== CRATE BALL COLLISION DETECTED ===")
	print("Ball:", ball.name)
	print("Ball class:", ball.get_class())
	
	# Get ball height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	# Get crate height
	var crate_height = Global.get_object_height_from_marker(self)
	
	print("Ball height:", ball_height)
	print("Crate height:", crate_height)
	
	# Simple height check: if ball is above crate height, let it pass through
	if ball_height > crate_height:
		# Ball/knife is above crate entirely - let it pass through
		print("Ball is above crate - passing through")
		return
	else:
		# Ball/knife is within or below crate height - handle collision
		print("Ball is within crate height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with crate
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)
	
	print("=== END CRATE BALL COLLISION ===")

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with crate"""
	
	# Play collision sound effect
	_play_crate_sound()
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with crate"""
	
	# Play collision sound effect
	_play_crate_sound()
	
	# Apply collision effect to the ball
	_apply_ball_collision_effect(ball)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection to knife"""
	# Get knife velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	# Calculate reflected velocity (simple reflection)
	var normal = (knife.global_position - global_position).normalized()
	var reflected_velocity = knife_velocity.bounce(normal)
	
	# Apply the reflected velocity to the knife
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity

func _apply_ball_collision_effect(ball: Node2D) -> void:
	"""Apply collision effect to ball"""
	# Get ball velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	# Calculate damage based on velocity
	var damage = _calculate_velocity_damage(ball_velocity.length())
	
	# Check if this damage will destroy the crate
	var will_destroy = damage >= current_health
	
	if will_destroy:
		# Calculate overkill damage (negative health value)
		var overkill_damage = damage - current_health
		
		# Apply damage to the crate (this will set health to negative)
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

func _calculate_circular_reflection(ball: Node2D, ball_velocity: Vector2) -> Vector2:
	"""Calculate circular reflection for ball collision"""
	# Get the direction from crate center to ball
	var to_ball = ball.global_position - global_position
	var normal = to_ball.normalized()
	
	# Reflect the velocity off the normal
	var reflected_velocity = ball_velocity.bounce(normal)
	
	# Apply some dampening to the reflected velocity
	reflected_velocity *= 0.8
	
	return reflected_velocity

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate velocity dampening when destroying the crate"""
	# Apply significant dampening when destroying the crate
	var dampening_factor = 0.3  # Reduce velocity to 30%
	return ball_velocity * dampening_factor

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""Handle collision with projectiles - called by roof bounce system"""
	# Calculate damage based on projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	var damage = _calculate_velocity_damage(projectile_velocity.length())
	
	# Apply damage to crate
	take_damage(damage)

func get_grid_position() -> Vector2i:
	"""Get the grid position of the crate"""
	if has_meta("grid_position"):
		return get_meta("grid_position")
	elif get("grid_position") != null:
		return get("grid_position")
	else:
		# Fallback: calculate grid position from world position
		var world_pos = global_position
		var cell_size = 48  # Default cell size
		# Since the crate is placed at cell center, we need to adjust for the offset
		var grid_x = floor((world_pos.x - cell_size / 2) / cell_size)
		var grid_y = floor((world_pos.y - cell_size / 2) / cell_size)
		return Vector2i(grid_x, grid_y)

func blocks() -> bool:
	"""Return true to block movement on this tile"""
	return true
