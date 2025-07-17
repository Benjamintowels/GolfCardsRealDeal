extends BaseObstacle

# Pylon for generator puzzle system
# Used on GeneratorSwitch puzzle holes. 2 are placed on the same grid or same row and a ForceField is placed between them

var connected_field: Node2D = null
var is_active: bool = true

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("pylons")
	
	# Set up Area2D collision detection
	var area2d = get_node_or_null("Area2D")
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
	"""Update the Pylon's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func connect_to_field(field: Node2D):
	"""Connect this pylon to a force field"""
	connected_field = field

func deactivate_pylon():
	"""Deactivate the pylon when generator is powered down"""
	is_active = false
	
	# Hide the pylon sprite or change its appearance
	var sprite = get_node_or_null("PylonSprite")
	if sprite:
		# You could change the sprite to a deactivated version here
		sprite.modulate = Color(0.5, 0.5, 0.5)  # Dim the sprite
	
	# Disable collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.collision_layer = 0
		area2d.collision_mask = 0

func get_collision_radius() -> float:
	"""
	Get the collision radius for this pylon.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 30.0  # Pylon collision radius

func get_height() -> float:
	"""Get the height of this pylon for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the pylon area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_roof_bounce_collision on the pylon
		pass

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the pylon area - reset ground level"""
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
	if not projectile or not is_active:
		return
	
	# Use roof bounce collision system
	_handle_roof_bounce_collision(projectile)

func _handle_pylon_collision(projectile: Node2D) -> void:
	"""
	Handle collision with pylon - uses the roof bounce system for height-based collision detection.
	"""
	_handle_roof_bounce_collision(projectile)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""
	Enhanced collision handler with wall reflect detection from below.
	If projectile height < pylon height, reflect.
	If projectile height > pylon height, check for wall reflect from below.
	"""
	if not projectile or not is_active:
		return
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get pylon height
	var pylon_height = get_height()
	
	# Check if projectile is above the pylon
	if projectile_height > pylon_height:
		# Check for wall reflect collision from below (ball Z-index higher than pylon)
		_check_wall_reflect_from_below(projectile)
		
		# Set ground level to pylon height
		if projectile.has_method("set_ground_level"):
			projectile.set_ground_level(pylon_height)
	else:
		# Projectile is below pylon height - reflect off pylon
		_reflect_off_pylon(projectile)

func _reflect_off_pylon(projectile: Node2D) -> void:
	"""
	Reflect the projectile off the pylon surface.
	"""
	if not projectile or not is_active:
		return
	
	# Get projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	# Calculate reflection direction (away from pylon center)
	var pylon_center = global_position
	var projectile_pos = projectile.global_position
	var to_projectile_direction = (projectile_pos - pylon_center).normalized()
	
	# Reflect velocity across the pylon surface
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
	var collision_sound = get_node_or_null("CollideSound")
	if collision_sound and collision_sound.stream:
		collision_sound.play()

func _check_wall_reflect_from_below(projectile: Node2D) -> void:
	"""
	Check if the projectile is hitting the pylon from below (higher Z-index).
	If so, play collision sound.
	"""
	if not projectile or not is_active:
		return
	
	# Get projectile Z-index
	var projectile_z_index = 0
	if projectile.has_method("get_z_index"):
		projectile_z_index = projectile.get_z_index()
	elif "z_index" in projectile:
		projectile_z_index = projectile.z_index
	
	# Get pylon Z-index
	var pylon_z_index = z_index
	
	# Check if projectile has higher Z-index (hitting from below)
	if projectile_z_index > pylon_z_index:
		# Play collision sound
		var collision_sound = get_node_or_null("CollideSound")
		if collision_sound and collision_sound.stream:
			collision_sound.play()
