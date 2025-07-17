extends BaseObstacle

# GeneratorSwitch collision and Y-sort system
# Uses the same roof bounce system as boulders and other obstacles

var is_powered_down: bool = false
var connected_pylons: Array[Node2D] = []
var connected_fields: Array[Node2D] = []

func _ready():
	# Add to groups for collision detection and optimization
	add_to_group("collision_objects")
	add_to_group("generator_switches")
	
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
	"""Update the GeneratorSwitch's z_index for proper Y-sorting"""
	# Force update the Ysort using the global system
	Global.update_object_y_sort(self, "objects")

func get_collision_radius() -> float:
	"""
	Get the collision radius for this generator switch.
	Used by the roof bounce system to determine when ball has exited collision area.
	"""
	return 50.0  # Same collision radius as boulder

func get_height() -> float:
	"""Get the height of this generator switch for collision detection"""
	return Global.get_object_height_from_marker(self)

func _on_area_entered(area: Area2D):
	"""Handle collisions with the generator switch area"""
	var projectile = area.get_parent()
	
	# Check if this is a golf ball or ghost ball
	if projectile and (projectile.has_method("get_velocity") or "velocity" in projectile):
		# Check if ball is hitting the bottom half of the generator switch
		var ball_pos = projectile.global_position
		var switch_pos = global_position
		
		# If ball is below the center of the switch, it's hitting the bottom half
		if ball_pos.y > switch_pos.y:
			print("=== GENERATOR SWITCH BOTTOM HALF HIT ===")
			print("Ball position:", ball_pos)
			print("Switch position:", switch_pos)
			
			# Play switch sound first
			var switch_sound = get_node_or_null("Switch")
			if switch_sound and switch_sound.stream:
				switch_sound.play()
				print("Switch sound played")
			
			# Then play collide sound
			var collision_sound = get_node_or_null("CollideSound")
			if collision_sound and collision_sound.stream:
				collision_sound.play()
				print("Collision sound played")
			
			# Set the generator switch as powered down
			is_powered_down = true
			print("Generator switch powered down")
			
			# Play powered down sound
			_play_powered_down_sound()
			
			# Deactivate all connected pylons and fields
			_deactivate_puzzle_system()
		else:
			# Ball is hitting the top half - just reflect normally
			print("=== GENERATOR SWITCH TOP HALF HIT ===")
			_reflect_off_generator_switch(projectile)
	
	# Handle throwing knives and other projectiles
	elif projectile and projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the generator switch area - reset ground level"""
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
	
	# Get generator switch height
	var switch_height = get_height()
	
	# Use roof bounce collision system
	_handle_roof_bounce_collision(projectile)

func _handle_generator_switch_collision(projectile: Node2D) -> void:
	"""
	Handle collision with generator switch - uses the roof bounce system for height-based collision detection.
	"""
	_handle_roof_bounce_collision(projectile)

func _handle_roof_bounce_collision(projectile: Node2D) -> void:
	"""
	Enhanced collision handler with wall reflect detection from below.
	If projectile height < generator switch height, reflect.
	If projectile height > generator switch height, check for wall reflect from below.
	"""
	if not projectile:
		return
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "z" in projectile:
		projectile_height = projectile.z
	
	# Get generator switch height
	var switch_height = get_height()
	
	# Check if projectile is above the generator switch
	if projectile_height > switch_height:
		# Set ground level to generator switch height
		if projectile.has_method("set_ground_level"):
			projectile.set_ground_level(switch_height)
	else:
		# Projectile is below generator switch height - reflect off generator switch
		_reflect_off_generator_switch(projectile)

func _reflect_off_generator_switch(projectile: Node2D) -> void:
	"""
	Reflect the projectile off the generator switch surface.
	"""
	if not projectile:
		return
	
	# Get projectile velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	# Calculate reflection direction (away from generator switch center)
	var switch_center = global_position
	var projectile_pos = projectile.global_position
	var to_projectile_direction = (projectile_pos - switch_center).normalized()
	
	# Reflect velocity across the generator switch surface
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

# Removed _check_wall_reflect_from_below method - using simpler bottom-half collision detection instead

func _play_powered_down_sound():
	"""Play the powered down sound when generator is deactivated"""
	var powered_down_sound = get_node_or_null("PoweredDown")
	if powered_down_sound and powered_down_sound.stream:
		powered_down_sound.play()

func connect_to_pylons(pylons: Array[Node2D]):
	"""Connect this generator switch to pylons"""
	connected_pylons = pylons

func connect_to_fields(fields: Array[Node2D]):
	"""Connect this generator switch to force fields"""
	connected_fields = fields

func _deactivate_puzzle_system():
	"""Deactivate all connected pylons and fields when generator is powered down"""
	print("=== DEACTIVATING GENERATOR PUZZLE SYSTEM ===")
	print("Connected pylons:", connected_pylons.size())
	print("Connected fields:", connected_fields.size())
	
	# Deactivate all connected pylons
	for pylon in connected_pylons:
		if pylon and is_instance_valid(pylon) and pylon.has_method("deactivate_pylon"):
			print("Deactivating pylon:", pylon.name)
			pylon.deactivate_pylon()
	
	# Deactivate all connected fields
	for field in connected_fields:
		if field and is_instance_valid(field) and field.has_method("deactivate_field"):
			print("Deactivating field:", field.name)
			field.deactivate_field()
	
	print("=== GENERATOR PUZZLE SYSTEM DEACTIVATED ===")
