extends Node2D

# Import FlowerData for flower variations (similar to BushData)
const FlowerData = preload("res://Obstacles/FlowerData.gd")

# Flower collision and Y-sort system with FlowerData integration
# Uses velocity damping instead of bouncing for realistic flower behavior
# Flowers are treated as bushes for collision purposes

# FlowerData for this specific flower instance
var flower_data: FlowerData = null

func _ready():
	# Add to groups for collision detection and optimization
	# Add to bushes group so flowers work with existing bush collision detection
	add_to_group("flowers")
	add_to_group("bushes")  # This allows flowers to work with existing bush collision systems
	add_to_group("collision_objects")
	
	# Set up Area2D collision detection
	var area2d = get_node_or_null("FlowerArea2D")
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered and exited signals for collision detection
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
	
	# Flower data will be applied externally via set_flower_data()

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func set_flower_data(data: FlowerData):
	"""Set the FlowerData for this flower instance"""
	flower_data = data
	_apply_flower_data()

func _apply_flower_data():
	"""Apply the FlowerData properties to this flower instance"""
	if not flower_data:
		return
	
	# Update sprite texture
	var sprite = get_node_or_null("FlowerSprite")
	if sprite and flower_data.sprite_texture:
		sprite.texture = flower_data.sprite_texture
	
	# Update collision radius
	var area2d = get_node_or_null("FlowerArea2D")
	if area2d:
		var collision_shape = area2d.get_node_or_null("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = flower_data.get_collision_radius()
	
	# Update rustle sound
	var rustle_sound = get_node_or_null("LeavesRustle")
	if rustle_sound and flower_data.get_rustle_sound():
		rustle_sound.stream = flower_data.get_rustle_sound()

func _update_ysort():
	"""Update the Flower's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this flower.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	if flower_data:
		return flower_data.get_collision_radius()
	return 24.0  # Default flower collision radius (smaller than bushes)

func get_height() -> float:
	"""Get the height of this flower for collision detection"""
	if flower_data:
		return flower_data.get_height()
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the flower area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_flower_collision on the flower
		pass

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the flower area - reset ground level"""
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
	
	# Get flower height
	var flower_height = get_height()
	
	# Use roof bounce collision system
	_handle_roof_bounce_collision(projectile)

func _handle_flower_collision(projectile: Node2D) -> void:
	"""
	Handle collision with flower - uses velocity damping instead of bouncing.
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
	
	# Check if ball is high enough to pass over the flower (55 units - flowers are slightly taller than bushes)
	if projectile_height >= 55.0:
		print("=== BALL PASSING OVER FLOWER ===")
		print("Projectile:", projectile.name, "Height:", projectile_height)
		print("Ball is high enough to pass over flower (55+ units)")
		return  # No collision effects - ball passes over
	
	print("=== FLOWER COLLISION HANDLED ===")
	print("Projectile:", projectile.name, "Type:", projectile.get_class())
	print("Projectile height:", projectile_height)
	if flower_data:
		print("Flower Type:", flower_data.name)
	
	# Play rustle sound
	_play_flower_rustle()
	
	# Apply velocity damping to the projectile
	_handle_flower_velocity_damping(projectile)
	
	print("=== END FLOWER COLLISION ===")

# Also support bush collision method for compatibility with existing systems
func _handle_bush_collision(projectile: Node2D) -> void:
	"""
	Handle collision as if this is a bush - for compatibility with existing collision detection.
	Flowers can be treated as bushes for collision purposes.
	"""
	_handle_flower_collision(projectile)

func _handle_flower_velocity_damping(projectile: Node2D) -> void:
	"""
	Apply velocity damping to projectiles that hit the flower.
	Flowers slow down projectiles instead of bouncing them.
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
		# Get damping factor from flower data or use default
		var damping_factor = 0.7  # Default: reduce velocity by 30% (slightly less than bushes)
		if flower_data:
			damping_factor = flower_data.get_velocity_damping_factor()
		
		var damped_velocity = projectile_velocity * damping_factor
		
		# Apply the damped velocity
		if projectile.has_method("set_velocity"):
			projectile.set_velocity(damped_velocity)
		elif "velocity" in projectile:
			projectile.velocity = damped_velocity
		
		print("Applied flower velocity damping:", projectile_velocity, "->", damped_velocity)
		if flower_data:
			print("Damping factor:", damping_factor, "from flower:", flower_data.name)

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
	
	# Get flower height
	var flower_height = get_height()
	
	# Check if projectile is above the flower
	if projectile_height > flower_height:
		# Projectile is above flower - set ground level to flower height
		if projectile.has_method("_set_ground_level"):
			projectile._set_ground_level(flower_height)
		elif "current_ground_level" in projectile:
			projectile.current_ground_level = flower_height
	else:
		# Projectile is below flower - apply velocity damping
		_handle_flower_velocity_damping(projectile)
		_play_flower_rustle()

func _play_flower_rustle() -> void:
	"""Play the flower rustle sound effect and flower shake animation"""
	var rustle_sound = get_node_or_null("LeavesRustle")
	if rustle_sound and rustle_sound.stream:
		# Add random pitch variation between 0.8 and 1.2 for variety
		rustle_sound.pitch_scale = randf_range(0.8, 1.2)
		rustle_sound.play()
		print("Flower rustle sound played")
		if flower_data:
			print("Sound from flower:", flower_data.name)
	
	# Play the flower shake animation
	var animation_player = get_node_or_null("FlowerSprite/AnimationPlayer")
	if animation_player:
		animation_player.play("flower_shake")
		print("Flower shake animation played")

func get_flower_data() -> FlowerData:
	"""Get the FlowerData for this flower instance"""
	return flower_data

func is_dense() -> bool:
	"""Check if this flower is dense (affects visibility)"""
	if flower_data:
		return flower_data.is_dense
	return false  # Default flowers are not dense (unlike bushes)

func get_wind_resistance() -> float:
	"""Get the wind resistance factor for this flower"""
	if flower_data:
		return flower_data.wind_resistance
	return 0.8  # Default wind resistance (less than bushes)
