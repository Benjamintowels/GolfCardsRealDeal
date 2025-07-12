extends Node2D

# Bush collision and Y-sort system
# Uses velocity damping instead of bouncing for realistic bush behavior

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("bushes")
	add_to_group("collision_objects")
	
	# Set up Area2D collision detection
	var area2d = get_node_or_null("BushArea2D")
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered and exited signals for collision detection
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func _update_ysort():
	"""Update the Bush's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this bush.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 38.0  # Bush collision radius (matches CircleShape2D radius)

func get_height() -> float:
	"""Get the height of this bush for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the bush area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_bush_collision on the bush
		pass

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the bush area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D) -> void:
	"""
	Handle collision with throwing knives and other projectiles.
	Uses the roof bounce system for height-based collision detection.
	"""
	if not projectile:
		return
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get bush height
	var bush_height = get_height()
	
	# Use roof bounce collision system
	_handle_roof_bounce_collision(projectile)

func _handle_bush_collision(projectile: Node2D) -> void:
	"""
	Handle collision with bush - uses velocity damping instead of bouncing.
	This is the main method called by golf balls and other projectiles.
	"""
	if not projectile:
		return
	
	print("=== BUSH COLLISION HANDLED ===")
	print("Projectile:", projectile.name, "Type:", projectile.get_class())
	
	# Play leaves rustle sound
	_play_leaves_rustle()
	
	# Apply velocity damping to the projectile
	_handle_bush_velocity_damping(projectile)
	
	print("=== END BUSH COLLISION ===")

func _handle_bush_velocity_damping(projectile: Node2D) -> void:
	"""
	Apply velocity damping to projectiles that hit the bush.
	Bushes slow down projectiles instead of bouncing them.
	"""
	if not projectile:
		return
	
	# Get projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	if projectile_velocity.length() > 0:
		# Apply damping factor (bushes slow down projectiles)
		var damping_factor = 0.6  # Reduce velocity by 40%
		var damped_velocity = projectile_velocity * damping_factor
		
		# Apply the damped velocity
		if projectile.has_method("set_velocity"):
			projectile.set_velocity(damped_velocity)
		elif "velocity" in projectile:
			projectile.velocity = damped_velocity
		
		print("Applied bush velocity damping:", projectile_velocity, "->", damped_velocity)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""
	Handle collision using the roof bounce system for height-based collision detection.
	"""
	if not projectile:
		return
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get bush height
	var bush_height = get_height()
	
	# Check if projectile is above the bush
	if projectile_height > bush_height:
		# Projectile is above bush - set ground level to bush height
		if projectile.has_method("_set_ground_level"):
			projectile._set_ground_level(bush_height)
		elif "current_ground_level" in projectile:
			projectile.current_ground_level = bush_height
	else:
		# Projectile is below bush - apply velocity damping
		_handle_bush_velocity_damping(projectile)
		_play_leaves_rustle()

func _play_leaves_rustle() -> void:
	"""Play the leaves rustle sound effect"""
	var leaves_sound = get_node_or_null("LeavesRustle")
	if leaves_sound and leaves_sound.stream:
		leaves_sound.play()
		print("Leaves rustle sound played")
