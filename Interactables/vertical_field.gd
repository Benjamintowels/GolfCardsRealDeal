extends BaseObstacle

# VerticalField for generator puzzle system
# Spans between two Pylons on the same column and handles projectile collisions

var pylon1: Node2D = null
var pylon2: Node2D = null
var is_active: bool = true

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("force_fields")
	
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
	"""Update the VerticalField's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func setup_field(pylon1_ref: Node2D, pylon2_ref: Node2D):
	"""Setup the field between two pylons"""
	pylon1 = pylon1_ref
	pylon2 = pylon2_ref
	
	# The field position is already set correctly in build_map.gd
	# We just need to scale and configure the field based on pylon positions
	if pylon1 and pylon2:
		# Calculate the height of the field based on pylon positions
		var field_height = abs(pylon2.global_position.y - pylon1.global_position.y)
		
		# Scale the field sprite to match the distance between pylons
		var sprite = get_node_or_null("FieldSprite")
		if sprite:
			sprite.scale.y = field_height / sprite.texture.get_height() if sprite.texture else 1.0
		
		# Update collision shape to match the field size
		var collision_shape = get_node_or_null("Area2D/CollisionShape2D")
		if collision_shape and collision_shape.shape:
			if collision_shape.shape is RectangleShape2D:
				collision_shape.shape.size.y = field_height
			elif collision_shape.shape is CircleShape2D:
				collision_shape.shape.radius = field_height / 2.0

func deactivate_field():
	"""Deactivate the force field when generator is powered down"""
	print("=== DEACTIVATING VERTICAL FIELD ===")
	print("Field name:", name)
	print("Field was active:", is_active)
	
	is_active = false
	
	# Hide the field sprite with fade effect
	var sprite = get_node_or_null("FieldSprite")
	if sprite:
		# Create a tween for fade out effect
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)  # Fade out over 0.5 seconds
		tween.tween_callback(func(): sprite.visible = false)  # Hide after fade
		print("Field sprite fading out")
	
	# Disable collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.collision_layer = 0
		area2d.collision_mask = 0
		print("Field collision detection disabled")
	
	print("=== VERTICAL FIELD DEACTIVATED ===")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this vertical field.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 25.0  # Smaller collision radius for fields

func get_height() -> float:
	"""Get the height of this vertical field for collision detection"""
	var height = Global.get_object_height_from_marker(self)
	print("Vertical field height from marker:", height)
	return height

func _on_area_entered(area: Area2D):
	"""Handle collisions with the vertical field area using proper height-based detection"""
	var projectile = area.get_parent()
	
	# Only handle Area2D collisions for projectiles that don't have their own collision detection
	# Balls (GolfBall, GhostBall) will handle their own collisions through the ball's collision system
	if projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)
	else:
		# For balls, let them handle their own collision through their collision system
		# The ball will call _handle_roof_bounce_collision on the vertical field
		pass

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the vertical field area - reset ground level"""
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

func _handle_vertical_field_collision(projectile: Node2D) -> void:
	"""
	Handle collision with vertical field - uses the roof bounce system for height-based collision detection.
	"""
	_handle_roof_bounce_collision(projectile)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""
	Enhanced collision handler with wall reflect detection from below.
	If projectile height < field height, reflect.
	If projectile height > field height, check for wall reflect from below.
	"""
	print("=== VERTICAL FIELD _handle_roof_bounce_collision CALLED ===")
	print("Projectile:", projectile.name if projectile else "null")
	print("Field active:", is_active)
	print("Field name:", name)
	
	if not projectile or not is_active:
		return
	
	# Play force field bounce sound for any collision
	_play_force_field_bounce_sound()
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get field height
	var field_height = get_height()
	
	print("Projectile height:", projectile_height)
	print("Field height:", field_height)
	
	# Check if projectile is above the field
	if projectile_height > field_height:
		print("Projectile is ABOVE field - setting ground level")
		# Check for wall reflect collision from below (ball Z-index higher than field)
		_check_wall_reflect_from_below(projectile)
		
		# Set ground level to field height
		if projectile.has_method("set_ground_level"):
			projectile.set_ground_level(field_height)
	else:
		print("Projectile is BELOW field - reflecting off field")
		# Projectile is below field height - reflect off field
		_reflect_off_field(projectile)

func _reflect_off_field(projectile: Node2D) -> void:
	"""
	Reflect the projectile off the field surface.
	"""
	print("=== REFLECTING OFF VERTICAL FIELD ===")
	print("Projectile:", projectile.name if projectile else "null")
	print("Field active:", is_active)
	
	if not projectile or not is_active:
		return
	
	# Get projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	# Calculate reflection direction (horizontal reflection for vertical field)
	var reflected_velocity = Vector2(-projectile_velocity.x, projectile_velocity.y)
	
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
	
	# Sound already played at the start of collision

func _check_wall_reflect_from_below(projectile: Node2D) -> void:
	"""
	Check if the projectile is hitting the field from below (higher Z-index).
	If so, play force field bounce sound.
	"""
	if not projectile or not is_active:
		return
	
	# Get projectile Z-index
	var projectile_z_index = 0
	if projectile.has_method("get_z_index"):
		projectile_z_index = projectile.get_z_index()
	elif "z_index" in projectile:
		projectile_z_index = projectile.z_index
	
	# Get field Z-index
	var field_z_index = z_index
	
	# Check if projectile has higher Z-index (hitting from below)
	if projectile_z_index > field_z_index:
		# Sound already played at the start of collision
		pass

func _play_force_field_bounce_sound():
	"""Play the force field bounce sound"""
	print("=== PLAYING FORCE FIELD BOUNCE SOUND ===")
	var bounce_sound = get_node_or_null("ForceFieldBounce")
	if bounce_sound and bounce_sound.stream:
		bounce_sound.play()
		print("Force field bounce sound played successfully")
	else:
		print("Force field bounce sound not found or no stream")
