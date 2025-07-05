extends Node2D

# Oil drum interactable object
# This will work with the roof system and Y-sort system

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
	var ball = area.get_parent()
	
	print("=== OIL DRUM AREA ENTERED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	print("Oil drum position:", global_position)
	print("Distance to oil drum:", ball.global_position.distance_to(global_position) if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall" or ball.has_method("is_throwing_knife")):
		print("✓ Valid ball/knife detected:", ball.name)
		# Handle the collision
		_handle_collision(ball)
	else:
		print("✗ Invalid ball/knife or non-ball object:", ball.name if ball else "Unknown")
	
	print("=== END OIL DRUM AREA ENTERED ===")

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the oil drum area - reset ground level"""
	var projectile = area.get_parent()
	
	print("=== OIL DRUM AREA EXITED ===")
	print("Projectile:", projectile.name if projectile else "Unknown")
	
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0
				print("✓ Reset projectile ground level to 0.0")
	
	print("=== END OIL DRUM AREA EXITED ===")

func _handle_collision(ball: Node2D):
	"""Handle oil drum collisions - check height to determine if ball should pass through"""
	print("=== HANDLING OIL DRUM COLLISION ===")
	print("Ball/knife name:", ball.name)
	print("Ball/knife type:", ball.get_class())
	
	# Check if this is a throwing knife
	if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
		# Handle knife collision with oil drum
		print("Handling knife oil drum collision")
		_handle_knife_collision(ball)
		print("=== END OIL DRUM COLLISION (KNIFE) ===")
		return
	
	# Check if projectile has height information
	if not ball.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_handle_ball_collision(ball)
		return
	
	# Get projectile and oil drum heights
	var projectile_height = ball.get_height()
	var oil_drum_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Oil drum height:", oil_drum_height)
	
	# Apply the collision logic:
	# If projectile height > oil drum height: allow entry and set ground level
	# If projectile height < oil drum height: reflect
	if projectile_height > oil_drum_height:
		print("✓ Projectile is above oil drum - allowing entry and setting ground level")
		_allow_projectile_entry(ball, oil_drum_height)
	else:
		print("✗ Projectile is below oil drum height - reflecting")
		_handle_ball_collision(ball)

func _allow_projectile_entry(projectile: Node2D, oil_drum_height: float):
	"""Allow projectile to enter oil drum area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (OIL DRUM) ===")
	
	# Set the projectile's ground level to the oil drum height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(oil_drum_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = oil_drum_height
			print("✓ Set projectile ground level to oil drum height:", oil_drum_height)
	
	# The projectile will now land on the oil drum instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _handle_knife_collision(knife: Node2D):
	"""Handle knife collision with oil drum"""
	print("Handling knife oil drum collision")
	
	# Check if knife is above the oil drum - if so, let it pass through
	if knife.has_method("get_height"):
		var knife_height = knife.get_height()
		var oil_drum_height = Global.get_object_height_from_marker(self)
		
		print("Knife height:", knife_height)
		print("Oil drum height:", oil_drum_height)
		
		if knife_height > oil_drum_height:
			print("✓ Knife is above oil drum - letting it pass through")
			return  # Let the knife pass through without any collision handling
		else:
			print("✗ Knife is below oil drum height - handling collision")
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_shop_collision"):
		knife._handle_shop_collision(self)
	else:
		# Fallback: just reflect the knife
		_reflect_knife(knife)

func _reflect_knife(knife: Node2D):
	"""Special reflection for knife collisions with oil drum - creates pinball effect"""
	# Play oil drum thunk sound
	var thunk = get_node_or_null("OilDrumThunk")
	if thunk:
		thunk.play()
		print("✓ OilDrumThunk sound played")
	else:
		print("✗ OilDrumThunk sound not found!")
	
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Reflecting knife with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var oil_drum_center = global_position
	
	# Calculate the direction from oil drum center to knife
	var to_knife_direction = (knife_pos - oil_drum_center).normalized()
	
	# Simple reflection: reflect the velocity across the oil drum center
	# This creates a more predictable pinball effect
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

func _handle_ball_collision(ball: Node2D) -> void:
	"""
	Handle collision with golf ball.
	This will be called by the ball's collision detection system.
	"""
	print("Oil drum collision with ball!")
	
	# Play oil drum thunk sound
	var thunk = get_node_or_null("OilDrumThunk")
	if thunk:
		thunk.play()
		print("✓ OilDrumThunk sound played")
	else:
		print("✗ OilDrumThunk sound not found!")
	
	# Apply bounce effect to the ball
	if ball.has_method("set_velocity"):
		var current_velocity = ball.get_velocity()
		var bounce_velocity = current_velocity * 0.8  # 80% of original velocity
		ball.set_velocity(bounce_velocity)
