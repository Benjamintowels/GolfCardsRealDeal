extends Node2D

# Import BushData for bush variations
const BushData = preload("res://Obstacles/BushData.gd")

# Bush collision and Y-sort system with BushData integration
# Uses velocity damping instead of bouncing for realistic bush behavior

# BushData for this specific bush instance
var bush_data: BushData = null

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
	
	# Bush data will be applied externally via set_bush_data()

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func set_bush_data(data: BushData):
	"""Set the BushData for this bush instance"""
	bush_data = data
	_apply_bush_data()

func _apply_bush_data():
	"""Apply the BushData properties to this bush instance"""
	if not bush_data:
		return
	
	# Update sprite texture
	var sprite = get_node_or_null("BushSprite")
	if sprite and bush_data.sprite_texture:
		sprite.texture = bush_data.sprite_texture
	
	# Update collision radius
	var area2d = get_node_or_null("BushArea2D")
	if area2d:
		var collision_shape = area2d.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = bush_data.get_collision_radius()
	
	# Update leaves rustle sound
	var leaves_sound = get_node_or_null("LeavesRustle")
	if leaves_sound and bush_data.get_leaves_rustle_sound():
		leaves_sound.stream = bush_data.get_leaves_rustle_sound()

func _update_ysort():
	"""Update the Bush's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this bush.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	if bush_data:
		return bush_data.get_collision_radius()
	return 38.0  # Default bush collision radius

func get_height() -> float:
	"""Get the height of this bush for collision detection"""
	if bush_data:
		return bush_data.get_height()
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
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Check if ball is high enough to pass over the bush (47 units)
	if projectile_height >= 47.0:
		print("=== BALL PASSING OVER BUSH ===")
		print("Projectile:", projectile.name, "Height:", projectile_height)
		print("Ball is high enough to pass over bush (47+ units)")
		return  # No collision effects - ball passes over
	
	print("=== BUSH COLLISION HANDLED ===")
	print("Projectile:", projectile.name, "Type:", projectile.get_class())
	print("Projectile height:", projectile_height)
	if bush_data:
		print("Bush Type:", bush_data.name)
	
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
		# Get damping factor from bush data or use default
		var damping_factor = 0.6  # Default: reduce velocity by 40%
		if bush_data:
			damping_factor = bush_data.get_velocity_damping_factor()
		
		var damped_velocity = projectile_velocity * damping_factor
		
		# Apply the damped velocity
		if projectile.has_method("set_velocity"):
			projectile.set_velocity(damped_velocity)
		elif "velocity" in projectile:
			projectile.velocity = damped_velocity
		
		print("Applied bush velocity damping:", projectile_velocity, "->", damped_velocity)
		if bush_data:
			print("Damping factor:", damping_factor, "from bush:", bush_data.name)

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
		if bush_data:
			print("Sound from bush:", bush_data.name)

func get_bush_data() -> BushData:
	"""Get the BushData for this bush instance"""
	return bush_data

func is_dense() -> bool:
	"""Check if this bush is dense (affects visibility)"""
	if bush_data:
		return bush_data.is_dense
	return true  # Default to dense

func get_wind_resistance() -> float:
	"""Get the wind resistance factor for this bush"""
	if bush_data:
		return bush_data.wind_resistance
	return 1.0  # Default wind resistance
