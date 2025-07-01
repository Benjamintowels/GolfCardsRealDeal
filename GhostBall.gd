extends Node2D

signal ghost_ball_landed(landing_position: Vector2)

var cell_size: int = 48
var map_manager: Node = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var club_info: Dictionary = {}
var is_putting: bool = false  # Flag for putter-only rolling mechanics

var velocity := Vector2.ZERO
var gravity := 2000.0
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

# Height and power constants (matching GolfBall.gd)
const MAX_LAUNCH_HEIGHT := 8000.0
const MIN_LAUNCH_HEIGHT := 1000.0
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0

func _ready():
	# Set up the ghost ball visual
	sprite = $Sprite2D
	shadow = $Shadow
	
	# Debug collision setup
	var area2d = get_node_or_null("Area2D")
	if area2d:
		print("GhostBall _ready - Area2D found, collision_layer:", area2d.collision_layer, "collision_mask:", area2d.collision_mask)
		print("GhostBall Area2D monitoring:", area2d.monitoring, "monitorable:", area2d.monitorable)
		# Connect to area_entered signal for debugging
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
	else:
		print("GhostBall _ready - ERROR: Area2D not found!")
	
	print("GhostBall _ready called at position:", position)
	
	# Make the ball transparent
	if sprite:
		sprite.modulate = Color(0.5, 0.8, 1.0, opacity)  # Blue tint for ghost ball
		# Set a smaller base scale to make it more subtle
		base_scale = Vector2(0.4, 0.4)  # Reduced from 0.5 to 0.4
		sprite.scale = base_scale
	if shadow:
		shadow.modulate = Color(0, 0, 0, opacity * 0.3)
		shadow.scale = base_scale
	
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
	if ball_grid_x >= 16 and ball_grid_x <= 18 and ball_grid_y >= 10 and ball_grid_y <= 12:
		print("*** GHOST BALL IN TREE AREA! Grid:", ball_grid_x, ",", ball_grid_y, "Position:", position, "Global:", global_position)
	
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
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Ball is in the air
		z += vz * delta
		vz -= gravity * delta
		is_rolling = false
		
		# Check if ball has landed
		if z <= 0.0:
			z = 0.0
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
						bounce_height = 400.0  # First bounce height
					else:
						bounce_height = 400.0 * pow(bounce_factor, bounce_count - 1)
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
		
		# Check if ball has landed again
		if z <= 0.0:
			z = 0.0
			
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
						bounce_height = 400.0  # First bounce height
					else:
						bounce_height = 400.0 * pow(bounce_factor, bounce_count - 1)
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
				else:
					# Start rolling
					vz = 0.0
					is_rolling = true
	
	else:
		# Ball is on the ground (z = 0, vz <= 0)
		z = 0.0

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
		if vz < 0.0 and not is_rolling:
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
						bounce_height = 400.0  # First bounce height
					else:
						bounce_height = 400.0 * pow(bounce_factor, bounce_count - 1)
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
	print("=== LAUNCHING GHOST BALL ===")
	print("Ghost ball putting mode:", is_putting)
	
	# Reset ball state
	landed_flag = false
	bounce_count = 0
	is_rolling = false
	
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
			# Calculate height at 50% (sweet spot height) - use same range as real ball
			var height_percentage = 0.5  # 50% height (sweet spot)
			height = 400.0 + (2000.0 - 400.0) * height_percentage  # Same range as real ball: 400-2000
		
	else:
		# Default values if no landing spot
		var max_power = club_info.get("max_distance", 1200.0)
		power = max_power * power_percentage
		
		# Set height based on putting mode
		if is_putting:
			height = 0.0
		else:
			height = 400.0 + (2000.0 - 400.0) * 0.5  # 50% height with same range as real ball
	
	# Set initial velocity and ensure ball starts in the air
	velocity = direction * power
	vz = height
	
	# For putters, start on the ground (z = 0)
	# For other clubs, start slightly above ground
	if is_putting:
		z = 0.0
	else:
		z = 0.1  # Start slightly above ground to ensure it's in the air

func update_visual_effects():
	if not sprite:
		return
	
	# Scale the ball based on height (bigger when higher) - but keep it reasonable
	var height_scale = 1.0 + (z / 1000.0)  # Reduced scale factor to prevent oversized ball
	height_scale = clamp(height_scale, 0.8, 1.5)  # Clamp to reasonable range
	
	# Add slight scaling effect when rolling
	if is_rolling:
		height_scale *= 0.9  # Slightly smaller when rolling
	
	sprite.scale = base_scale * height_scale
	
	# Move the ball up based on height
	sprite.position.y = -z  # Negative because we want to move up
	
	# Update shadow size and opacity based on height
	if shadow:
		var shadow_scale = 1.0 - (z / 800.0)  # Shadow gets smaller when ball is higher
		shadow_scale = clamp(shadow_scale, 0.1, 0.8)  # Reduced max from 1.0 to 0.8
		
		# Shadow is more prominent when rolling
		if is_rolling:
			shadow_scale *= 1.1  # Reduced from 1.2 to 1.1
			shadow_scale = clamp(shadow_scale, 0.1, 1.0)  # Reduced max from 1.5 to 1.0
		
		shadow.scale = base_scale * shadow_scale
		
		# Shadow opacity also changes with height
		var shadow_alpha = 0.3 - (z / 1000.0)  # Less opaque when ball is higher
		shadow_alpha = clamp(shadow_alpha, 0.05, 0.3)  # Keep some visibility
		
		# Shadow is more opaque when rolling
		if is_rolling:
			shadow_alpha = 0.4
		
		shadow.modulate = Color(0, 0, 0, shadow_alpha * opacity)

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

func _on_area_entered(area):
	print("Ghost ball collision detected with area:", area.name, "Parent:", area.get_parent().name if area.get_parent() else "No parent")
	print("Ghost ball position:", global_position, "Height:", z)
	print("Area position:", area.global_position)

func _on_area_exited(area):
	print("Ghost ball collision exited with area:", area.name, "Parent:", area.get_parent().name if area.get_parent() else "No parent") 
