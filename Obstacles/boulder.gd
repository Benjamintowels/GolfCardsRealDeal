extends BaseObstacle

# Boulder collision and Y-sort system
# Uses the same roof bounce system as trees and other obstacles

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("boulders")
	
	# Set up Area2D collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		# Set collision layer to 1 so golf balls can detect it
		area2d.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		area2d.collision_mask = 1
		
		# Connect to area entered signal for collision detection
		area2d.connect("area_entered", _on_area_entered)

func _process(delta):
	# Update Y-sort for proper layering
	_update_ysort()

func _update_ysort():
	"""Update the Boulder's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this boulder.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 50.0  # Boulder collision radius

func get_height() -> float:
	"""Get the height of this boulder for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the boulder area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_roof_bounce_collision on the boulder
		pass

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
	
	# Get boulder height
	var boulder_height = get_height()
	
	# Use roof bounce collision system
	_handle_roof_bounce_collision(projectile)

func _handle_boulder_collision(projectile: Node2D) -> void:
	"""
	Handle collision with boulder - uses the roof bounce system for height-based collision detection.
	"""
	_handle_roof_bounce_collision(projectile)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < boulder height, reflect.
	If projectile height > boulder height, set ground to boulder height.
	"""
	if not projectile:
		return
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get boulder height
	var boulder_height = get_height()
	
	# Check if projectile is above the boulder
	if projectile_height > boulder_height:
		# Projectile is above boulder - set ground level to boulder height
		if projectile.has_method("set_ground_level"):
			projectile.set_ground_level(boulder_height)
	else:
		# Projectile is below boulder height - reflect off boulder
		_reflect_off_boulder(projectile)

func _reflect_off_boulder(projectile: Node2D) -> void:
	"""
	Reflect the projectile off the boulder surface.
	"""
	if not projectile:
		return
	
	# Get projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	# Calculate reflection direction (away from boulder center)
	var boulder_center = global_position
	var projectile_pos = projectile.global_position
	var to_projectile_direction = (projectile_pos - boulder_center).normalized()
	
	# Reflect velocity across the boulder surface
	var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile_direction) * to_projectile_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity
	
	# Play collision sound if available
	var collision_sound = get_node_or_null("CollisionSound")
	if collision_sound and collision_sound.stream:
		collision_sound.play()
