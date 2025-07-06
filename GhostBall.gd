extends Node2D

signal ghost_ball_landed(landing_position: Vector2)

var cell_size: int = 48
var map_manager: Node = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var club_info: Dictionary = {}
var is_putting: bool = false  # Flag for putter-only rolling mechanics

var velocity := Vector2.ZERO
var gravity := 1200.0  # Adjusted for pixel perfect system (was 2000.0)
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Ghost ball specific properties
var is_ghost := true
var opacity := 0.6  # Increased from 0.3 to make it more visible
var launch_interval := 2.0  # Launch every 2 seconds
var launch_timer := 0.0
var power_percentage := 0.5  # Reduced from 0.75 to 0.5 to prevent going off-screen

# Store original position for relaunching
var original_position: Vector2 = Vector2.ZERO

# Bounce and roll mechanics (simplified for ghost)
var bounce_count := 0
var min_bounces := 2
var max_bounces := 2
var bounce_factor := 0.7
var roll_friction := 0.98
var min_roll_speed := 25.0
var is_rolling := false

# Visual effects
var sprite: Sprite2D
var shadow: Sprite2D
var base_scale := Vector2.ONE

# Height constants (matching LaunchManager)
const MAX_LAUNCH_HEIGHT := 480.0   # 10 cells (48 * 10) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 144.0   # 3 cells (48 * 3) for pixel perfect system
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0

# Simple collision system variables
var current_ground_level: float = 0.0  # Current ground level (can be elevated by roofs)

func _ready():
	# Set up the ghost ball visual
	sprite = $Sprite2D
	shadow = $Shadow
	
	# Make the ball transparent
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, opacity)  # Blue tint for ghost ball
		# No scaling needed since sprites are properly sized
		base_scale = Vector2.ONE  # No scaling needed
		sprite.scale = base_scale
	if shadow:
		shadow.modulate = Color(0, 0, 0, opacity * 0.3)
		shadow.scale = base_scale
	
	# Connect to Area2D's area_entered signal for collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
		print("✓ Ghost ball Area2D collision detection connected")
	else:
		print("✗ ERROR: Ghost ball Area2D not found!")
	
	# Store the original position for relaunching
	original_position = position
	
	# Start the launch timer
	launch_timer = 0.0
	
	# Launch immediately if we have a landing spot
	if chosen_landing_spot != Vector2.ZERO:
		launch_ghost_ball()
	else:
		launch_ghost_ball()  # Launch anyway with default direction
	
	print("Ghost ball ready at position:", position)
	print("=== END GHOST BALL _READY ===")

func _process(delta):
	# Debug: Check if ball is near any trees
	var ball_grid_x = int(floor(position.x / cell_size))
	var ball_grid_y = int(floor(position.y / cell_size))
	
	# Check if ball is in the area where trees should be
	# if ball_grid_x >= 16 and ball_grid_x <= 18 and ball_grid_y >= 10 and ball_grid_y <= 12:
	# 	print("*** GHOST BALL IN TREE AREA! Grid:", ball_grid_x, ",", ball_grid_y, "Position:", position, "Global:", global_position)
	
	if landed_flag:
		return
	

	
	# Update launch timer
	launch_timer += delta
	if launch_timer >= launch_interval:
		launch_timer = 0.0
		launch_ghost_ball()
	
	# Update position
	var old_position = position
	position += velocity * delta
	
	# Update Y-sorting based on new position
	update_y_sort()
	
	# OPTIMIZED: Ball handles its own tree collision detection
	# Only check for tree collisions when ball is in the air (during launch mode)
	if z > 0.0:
		check_nearby_tree_collisions()
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Ball is in the air
		z += vz * delta
		vz -= gravity * delta
		is_rolling = false
		
		# Check if ball has landed (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Play roof bounce sound if landing on elevated ground
			if current_ground_level > 0.0:
				_play_roof_bounce_sound("")
			# Check for water hazard on any bounce
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y) if map_manager else ""
			if tile_type == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			
			# For putters, go directly to rolling (no bounces)
			if is_putting:
				vz = 0.0
				is_rolling = true
			else:
				# Calculate bounce based on bounce count
				var landing_speed = abs(vz)
				
				# Determine if we should bounce or start rolling
				if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
					# Bounce!
					bounce_count += 1
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						# Calculate bounce height using physics formula for 144.0 height
						bounce_height = sqrt(2.0 * gravity * 144.0)  # First bounce height (3 cells for pixel perfect system)
					else:
						# Calculate the height percentage for this bounce
						var bounce_height_percentage = pow(bounce_factor, bounce_count - 1)
						bounce_height = sqrt(2.0 * gravity * 144.0 * bounce_height_percentage)  # 3 cells for pixel perfect system
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
				else:
					# Start rolling
					vz = 0.0
					is_rolling = true
	
	elif vz > 0.0:
		# Ball is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		is_rolling = false
		
		# Check if ball has landed again (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Play roof bounce sound if landing on elevated ground
			if current_ground_level > 0.0:
				_play_roof_bounce_sound("")
			
			# For putters, go directly to rolling (no bounces)
			if is_putting:
				vz = 0.0
				is_rolling = true
			else:
				# Calculate bounce based on bounce count
				var landing_speed = abs(vz)
				
				# Determine if we should bounce or start rolling
				if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
					# Bounce!
					bounce_count += 1
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						bounce_height = 144.0  # First bounce height (3 cells for pixel perfect system)
					else:
						bounce_height = 144.0 * pow(bounce_factor, bounce_count - 1)  # 3 cells for pixel perfect system
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
				else:
					# Start rolling
					vz = 0.0
					is_rolling = true
	
	else:
		# Ball is on the ground (z = current_ground_level, vz <= 0)
		z = current_ground_level

		# Check for water hazard when ball is on the ground
		if map_manager != null:
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y)
			if tile_type == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return

		# Check for out of bounds when ball is on the ground
		if map_manager != null:
			var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
			if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
		
		# If we have negative vz but we're on the ground, check if we should bounce
		if vz < 0.0 and not is_rolling and z <= current_ground_level:
			# For putters, go directly to rolling (no bounces)
			if is_putting:
				vz = 0.0
				is_rolling = true
			else:
				# Check if we should bounce or start rolling
				var landing_speed = abs(vz)
				
				# Only bounce if we haven't reached max bounces AND we haven't completed minimum bounces
				if bounce_count < max_bounces and bounce_count < min_bounces:
					# Bounce!
					bounce_count += 1
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						bounce_height = 144.0  # First bounce height (3 cells for pixel perfect system)
					else:
						bounce_height = 144.0 * pow(bounce_factor, bounce_count - 1)  # 3 cells for pixel perfect system
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
				else:
					# Start rolling
					vz = 0.0
					is_rolling = true
		
		if is_rolling:
			# Ball is rolling on the ground
			vz = 0.0
			# Check for water hazard while rolling
			var tile_x_roll = int(floor(position.x / cell_size))
			var tile_y_roll = int(floor(position.y / cell_size))
			var tile_type_roll = map_manager.get_tile_type(tile_x_roll, tile_y_roll) if map_manager else ""
			if tile_type_roll == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type_roll == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			
			# Apply friction (simplified for ghost ball)
			velocity *= 0.98
			
			# Check if ball should stop rolling
			if velocity.length() < min_roll_speed:
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
	
	# Update visual effects
	update_visual_effects()
	
	# Update Y-sorting after visual effects to ensure z_index is maintained
	update_y_sort()

func launch_ghost_ball():
	"""Launch the ghost ball at 75% power"""
	# Reset ball state
	landed_flag = false
	bounce_count = 0
	is_rolling = false
	
	# Reset simple collision system for new shot
	current_ground_level = 0.0
	
	# Reset to original position
	position = original_position
	
	# Calculate direction to landing spot or use default direction
	var direction: Vector2
	if chosen_landing_spot != Vector2.ZERO:
		direction = (chosen_landing_spot - global_position).normalized()
	
	else:
		# Default direction (forward) if no landing spot set
		direction = Vector2(1, 0)  # Launch to the right
	
	
	# Calculate power using the EXACT same logic as the real ball
	var power = 0.0
	var height = 0.0
	
	if chosen_landing_spot != Vector2.ZERO:
		# Calculate the distance to the landing spot
		var ball_global_pos = global_position
		var distance_to_target = ball_global_pos.distance_to(chosen_landing_spot)
		
		# Use 75% power percentage for ghost ball (sweet spot)
		var power_percentage = 0.75
		
		# Use the EXACT same power calculation as the real ball
		# Calculate base power needed for the distance (same as course_1.gd)
		var reference_distance = 1200.0  # Driver's max distance as reference
		var distance_factor = distance_to_target / reference_distance
		var ball_physics_factor = 0.8 + (distance_factor * 0.4)
		var base_power_per_distance = 0.6 + (distance_factor * 0.2)
		var base_power_for_target = distance_to_target * base_power_per_distance * ball_physics_factor
		
		# Apply club-specific power scaling (same as course_1.gd)
		var club_efficiency = 1.0
		if club_info.has("max_distance"):
			var club_max = club_info["max_distance"]
			var efficiency_factor = 1200.0 / club_max
			club_efficiency = sqrt(efficiency_factor)
			club_efficiency = clamp(club_efficiency, 0.7, 1.5)
		
		var power_for_target = base_power_for_target * club_efficiency
		
		# For sweet spot shots (75%), use the calculated power needed for the target distance
		power = power_for_target
		
		# Calculate height based on putting mode
		if is_putting:
			# For putters, set height to 0 (no arc, just rolling)
			height = 0.0
			print("Ghost ball: Putter mode - height set to 0")
		else:
			# Calculate height at 50% (sweet spot height) - use same constants as LaunchManager
			var height_percentage = 0.5  # 50% height (sweet spot)
			height = MIN_LAUNCH_HEIGHT + (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT) * height_percentage
		
	else:
		# Default values if no landing spot
		var max_power = club_info.get("max_distance", 1200.0)
		power = max_power * power_percentage
		
		# Set height based on putting mode
		if is_putting:
			height = 0.0
		else:
			height = MIN_LAUNCH_HEIGHT + (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT) * 0.5  # 50% height with same constants as LaunchManager
	
	# Set initial velocity and ensure ball starts in the air
	velocity = direction * power
	# Calculate initial vertical velocity to achieve the desired maximum height
	# Using physics formula: z_max = vz_initial^2 / (2 * gravity)
	# So: vz_initial = sqrt(2 * gravity * height)
	vz = sqrt(2.0 * gravity * height)  # This will make the ball reach the exact height specified
	
	# For putters, start on the ground (z = 0)
	# For other clubs, start slightly above ground
	if is_putting:
		z = 0.0
	else:
		z = 0.1  # Start slightly above ground to ensure it's in the air

func update_visual_effects():
	if not sprite:
		return
	
	# Ghost ball has its own physics-based height system
	# Apply height-based positioning directly to the sprite
	sprite.position.y = -z  # Move sprite up based on height (negative because Y increases downward)
	
	# Apply ghost ball specific visual effects
	sprite.modulate = Color(0.5, 0.8, 1.0, opacity)  # Blue tint for ghost ball
	sprite.scale = base_scale  # Use base scale without height scaling
	
	# Update shadow effects
	if shadow:
		# Keep shadow at ground level
		shadow.position = Vector2.ZERO
		shadow.scale = base_scale
		
		# Shadow opacity changes with height (more transparent when higher)
		var shadow_alpha = 0.3 - (z / 500.0)  # Opacity change per 500 units for pixel perfect system
		shadow_alpha = clamp(shadow_alpha, 0.05, 0.3)
		shadow.modulate = Color(0, 0, 0, shadow_alpha * opacity)
	
	# Add rolling-specific effects
	if is_rolling:
		# Slightly smaller when rolling
		sprite.scale *= 0.9
		if shadow:
			shadow.scale *= 1.1
			shadow.modulate = Color(0, 0, 0, 0.4 * opacity)  # More opaque when rolling

func set_landing_spot(spot: Vector2):
	"""Set the target landing spot for the ghost ball"""
	chosen_landing_spot = spot

func set_club_info(club_data: Dictionary):
	"""Set the club information for power calculations"""
	club_info = club_data

func set_putting_mode(putting: bool):
	"""Set the putting mode for the ghost ball"""
	is_putting = putting
	print("Ghost ball putting mode set to:", is_putting)

func reset_ball():
	"""Reset the ghost ball to its starting position"""
	velocity = Vector2.ZERO
	vz = 0.0
	z = 0.0
	landed_flag = false
	bounce_count = 0
	is_rolling = false
	launch_timer = 0.0
	
	# Reset to original position
	position = original_position
	
	# Reset visual effects
	if sprite:
		sprite.position.y = 0
		sprite.scale = base_scale
	if shadow:
		shadow.scale = base_scale
		shadow.modulate = Color(0, 0, 0, opacity * 0.3)

func update_y_sort() -> void:
	"""Update the ball's z_index using the simple global Y-sort system"""
	# Use the global Y-sort system
	Global.update_ball_y_sort(self)

func get_ground_position() -> Vector2:
	"""Return the ball's position on the ground (ignoring height) for Y-sorting"""
	# The ball's position is already the ground position
	# The height (z) is only used for visual effects (sprite.position.y = -z)
	return global_position

func get_velocity() -> Vector2:
	"""Return the ball's current velocity for collision handling"""
	return velocity

func set_velocity(new_velocity: Vector2) -> void:
	"""Set the ball's velocity for collision handling"""
	velocity = new_velocity

func get_height() -> float:
	"""Return the ball's current height for collision handling"""
	return z 

func check_nearby_tree_collisions() -> void:
	"""OPTIMIZED: Ball checks for nearby tree collisions during flight"""
	# Only check for leaves rustling sound (trunk collisions handled by Area2D)
	# This is much more efficient than trees checking all balls every frame
	
	var trees = get_tree().get_nodes_in_group("trees")
	if trees.is_empty():
		return
	
	# Get ball's ground position (shadow position)
	var ball_ground_pos = global_position
	if has_method("get_ground_position"):
		ball_ground_pos = get_ground_position()
	
	# Check only nearby trees (spatial optimization)
	var nearby_trees = []
	for tree in trees:
		if is_instance_valid(tree):
			var distance_to_tree = ball_ground_pos.distance_to(tree.global_position)
			if distance_to_tree <= 150.0:  # Only check trees within 150 pixels
				nearby_trees.append(tree)
	
	# Process leaves rustling for nearby trees
	for tree in nearby_trees:
		var tree_center = tree.global_position
		var distance_to_trunk = ball_ground_pos.distance_to(tree_center)
		var trunk_radius = 120.0
		
		# Only check if ball is within the trunk radius
		if distance_to_trunk <= trunk_radius:
			# Check if ball is at the right height to pass through leaves
			var ball_height = z
			var tree_height = Global.get_object_height_from_marker(tree)  # Use actual tree height from marker
			var min_leaves_height = 60.0
			
			if ball_height > min_leaves_height and ball_height < tree_height:
				# Check if we haven't played the sound recently for this ball-tree combination
				var current_time = Time.get_ticks_msec() / 1000.0
				var tree_id = tree.get_instance_id()
				var sound_key = "last_leaves_rustle_time_%d" % tree_id
				
				if not has_meta(sound_key) or get_meta(sound_key) + 0.5 < current_time:
					var rustle = tree.get_node_or_null("LeavesRustle")
					if rustle:
						rustle.play()
						print("✓ LeavesRustle sound played - ball passing through leaves near trunk")
						# Mark when we last played the sound for this ball-tree combination
						set_meta(sound_key, current_time)

func _on_area_entered(area):
	# Check if this is a Pin collision
	if area.get_parent() and area.get_parent().name == "Pin":
		# Pin collision detected - the pin will handle hole completion
		pass
	# Check if this is an NPC collision (GangMember)
	elif area.get_parent() and area.get_parent().has_method("_handle_ball_collision"):
		# NPC collision detected - let the NPC handle the collision
		# The NPC will check ball height and apply appropriate effects
		area.get_parent()._handle_ball_collision(self)
	# Check if this is a Player collision
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		# Player collision detected - handle player damage
		_handle_player_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit player
		notify_course_of_collision()
	# Check if this is a Tree collision
	elif area.get_parent() and area.get_parent().has_method("_handle_trunk_collision"):
		# Tree collision detected - use new roof bounce system
		_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit tree
		notify_course_of_collision()
	# Check if this is a Shop collision
	elif area.get_parent() and area.get_parent().has_method("_handle_shop_collision"):
		# Shop collision detected - use new roof bounce system
		_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit shop
		notify_course_of_collision()
	# Check if this is an Oil Drum collision
	elif area.get_parent() and area.get_parent().has_method("_handle_collision"):
		# Oil drum collision detected - use new roof bounce system
		_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit oil drum
		notify_course_of_collision()

func _on_area_exited(area):
	# Area exit handling if needed
	pass

func _handle_player_collision(player: Node2D) -> void:
	"""Handle collision with player - ghost balls don't deal damage"""
	# Ghost balls don't deal damage to players
	pass

func notify_course_of_collision() -> void:
	"""Notify the course that the ghost ball has collided with something"""
	# Ghost balls don't need to notify the course of collisions
	pass 

# Simple collision system methods
func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < object height, reflect.
	If projectile height > object height, set ground to object height.
	"""
	print("=== SIMPLE COLLISION HANDLER (GHOST) ===")
	print("Object:", object.name)
	print("Ghost ball height:", z)
	
	var object_height = Global.get_object_height_from_marker(object)
	print("Object height:", object_height)
	
	# Check if ball is above the object
	if z > object_height:
		print("✓ Ghost ball is above object - setting ground level")
		current_ground_level = object_height
	else:
		print("✗ Ghost ball is below object height - reflecting")
		_reflect_off_object(object)

func _reflect_off_object(object: Node2D) -> void:
	"""
	Simple reflection off an object when ball is below object height.
	"""
	print("=== REFLECTING OFF OBJECT (GHOST) ===")
	
	# Get the ball's current velocity
	var ball_velocity = velocity
	
	print("Reflecting ghost ball with velocity:", ball_velocity)
	
	# Play collision sound if available
	if object.has_method("_play_trunk_thunk_sound"):
		object._play_trunk_thunk_sound()
	elif object.has_method("_play_oil_drum_sound"):
		object._play_oil_drum_sound()
	
	var ball_pos = global_position
	var object_center = object.global_position
	
	# Calculate the direction from object center to ball
	var to_ball_direction = (ball_pos - object_center).normalized()
	
	# Simple reflection: reflect the velocity across the object center
	var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected ghost ball velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the ball
	velocity = reflected_velocity

func _set_ground_level(height: float) -> void:
	"""
	Set the ground level to a specific height (used by Area2D collision system).
	"""
	print("=== SETTING GROUND LEVEL (GHOST) ===")
	print("Setting ground level to:", height)
	current_ground_level = height
	print("Ground level set to:", current_ground_level)

func _reset_ground_level() -> void:
	"""
	Reset the ground level to normal (0.0) when exiting Area2D collision.
	"""
	print("=== RESETTING GROUND LEVEL (GHOST) ===")
	print("Resetting ground level from:", current_ground_level, "to 0.0")
	current_ground_level = 0.0
	print("Ground level reset to:", current_ground_level)

func _play_roof_bounce_sound(object_type: String) -> void:
	"""
	Play the appropriate sound when landing on elevated ground (roof bounce).
	This is called when the ghost ball actually lands on the elevated surface.
	"""
	print("=== PLAYING ROOF BOUNCE SOUND (GHOST) ===")
	print("Current ground level:", current_ground_level)
	
	# Find the object that set this ground level and play its sound
	var objects = get_tree().get_nodes_in_group("collision_objects")
	print("Found", objects.size(), "collision objects")
	
	for obj in objects:
		if not obj.has_method("get_collision_radius"):
			continue
			
		var distance = global_position.distance_to(obj.global_position)
		var collision_radius = obj.get_collision_radius()
		
		print("Checking object:", obj.name, "distance:", distance, "radius:", collision_radius)
		
		# Check if we're within the collision radius of this object
		if distance <= collision_radius:
			# Check if this object's height matches our current ground level
			var obj_height = Global.get_object_height_from_marker(obj)
			print("Object height:", obj_height, "ground level:", current_ground_level)
			
			if abs(obj_height - current_ground_level) < 1.0:  # Small tolerance for floating point
				# Play the appropriate sound based on object type
				if obj.name.contains("Shop") or obj.name.contains("shop"):
					var thunk = obj.get_node_or_null("TrunkThunk")
					if thunk:
						thunk.play()
						print("✓ TrunkThunk sound played for shop roof bounce (ghost)")
				elif obj.name.contains("Tree") or obj.name.contains("tree"):
					var thunk = obj.get_node_or_null("TrunkThunk")
					if thunk:
						thunk.play()
						print("✓ TrunkThunk sound played for tree roof bounce (ghost)")
				elif obj.name.contains("Oil") or obj.name.contains("oil") or obj.name.contains("OilDrum"):
					var thunk = obj.get_node_or_null("OilDrumThunk")
					if thunk:
						thunk.play()
						print("✓ OilDrumThunk sound played for oil drum roof bounce (ghost)")
					else:
						print("✗ OilDrumThunk sound not found for oil drum roof bounce (ghost)")
				elif obj.name.contains("GangMember") or obj.name.contains("gang") or obj.name.contains("Gang"):
					obj._play_collision_sound()
				break 
