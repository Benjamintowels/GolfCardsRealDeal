extends Node2D

signal ghost_ball_landed(landing_position: Vector2)

var cell_size: int = 48
var map_manager: Node = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var club_info: Dictionary = {}

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
var trail: Line2D

# Height and power constants (matching GolfBall.gd)
const MAX_LAUNCH_HEIGHT := 2000.0
const MIN_LAUNCH_HEIGHT := 400.0
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
	
	# Create trail for visibility
	trail = Line2D.new()
	trail.width = 6  # Increased from 3 to 6 for better visibility
	trail.default_color = Color(0.5, 0.8, 1.0, 0.6)  # Increased alpha from 0.4 to 0.6
	trail.z_index = 0
	add_child(trail)
	
	# Launch immediately if we have a landing spot
	if chosen_landing_spot != Vector2.ZERO:
		launch_ghost_ball()
	else:
		launch_ghost_ball()  # Launch anyway with default direction
	
	print("Ghost ball ready at position:", position)
	print("=== END GHOST BALL _READY ===")

func _process(delta):
	print("Ghost ball _process called - delta:", delta, "z:", z, "vz:", vz)  # Track z and vz values
	
	# Debug: Check if ball is near any trees
	var ball_grid_x = int(floor(position.x / cell_size))
	var ball_grid_y = int(floor(position.y / cell_size))
	print("Ghost ball grid position:", ball_grid_x, ",", ball_grid_y)
	
	# Check if ball is in the area where trees should be
	if ball_grid_x >= 16 and ball_grid_x <= 18 and ball_grid_y >= 10 and ball_grid_y <= 12:
		print("*** GHOST BALL IN TREE AREA! Grid:", ball_grid_x, ",", ball_grid_y, "Position:", position, "Global:", global_position)
	
	if landed_flag:
		print("Ghost ball landed, not processing")
		return
	
	# Update launch timer
	launch_timer += delta
	if launch_timer >= launch_interval:
		launch_timer = 0.0
		print("Ghost ball timer triggered - launching")
		launch_ghost_ball()
	
	# Update position
	var old_position = position
	position += velocity * delta
	
	# Update Y-sorting based on new position
	update_y_sort()
	
	# Debug: Show movement
	if velocity.length() > 0:
		print("Ghost ball physics - Old pos:", old_position, "New pos:", position, "Velocity:", velocity, "Delta:", delta)
	else:
		print("Ghost ball has zero velocity - Position:", position)
	
	# Debug: Show position every 0.5 seconds
	if int(launch_timer * 2) % 2 == 0 and velocity.length() > 0:
		print("Ghost ball moving - Position:", position, "Velocity:", velocity, "Z:", z, "VZ:", vz)
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Ball is in the air
		z += vz * delta
		vz -= gravity * delta
		is_rolling = false
		
		print("Ghost ball in air - Z:", z, "VZ:", vz, "Position:", position)
		
		# Check if ball has landed
		if z <= 0.0:
			z = 0.0
			print("Ghost ball landed from air")
			# Check for water hazard on any bounce
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y) if map_manager else ""
			print("Ghost ball landed on tile type:", tile_type, "at grid pos:", tile_x, ",", tile_y)
			if tile_type == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit water, stopping")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit sand, stopping")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			
			# Calculate bounce based on bounce count
			var landing_speed = abs(vz)
			
			# Determine if we should bounce or start rolling
			if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
				# Bounce!
				bounce_count += 1
				print("Ghost ball bouncing - Bounce count:", bounce_count)
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
				print("Ghost ball bounce - New vz:", vz, "New velocity:", velocity)
			else:
				# Start rolling
				vz = 0.0
				is_rolling = true
				print("Ghost ball starting to roll")
	
	elif vz > 0.0:
		# Ball is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		is_rolling = false
		
		# Check if ball has landed again
		if z <= 0.0:
			z = 0.0
			
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
			print("Ghost ball on ground - tile type:", tile_type, "at grid pos:", tile_x, ",", tile_y, "velocity:", velocity)
			if tile_type == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit water on ground, stopping")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit sand on ground, stopping")
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
				print("Ghost ball out of bounds, stopping")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
		
		# If we have negative vz but we're on the ground, check if we should bounce
		if vz < 0.0 and not is_rolling:
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
				# Start rolling only after minimum bounces are complete
				vz = 0.0
				is_rolling = true
		
		if is_rolling:
			# Ball is rolling on the ground
			vz = 0.0
			# Check for water hazard while rolling
			var tile_x_roll = int(floor(position.x / cell_size))
			var tile_y_roll = int(floor(position.y / cell_size))
			var tile_type_roll = map_manager.get_tile_type(tile_x_roll, tile_y_roll) if map_manager else ""
			print("Ghost ball rolling - tile type:", tile_type_roll, "at grid pos:", tile_x_roll, ",", tile_y_roll, "velocity:", velocity)
			if tile_type_roll == "W":
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit water while rolling, stopping")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
			elif tile_type_roll == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				print("Ghost ball hit sand while rolling, stopping")
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
				print("Ghost ball stopped rolling due to low speed")
				ghost_ball_landed.emit(position)
				# Reset and relaunch instead of destroying
				launch_timer = launch_interval  # Trigger immediate relaunch
				landed_flag = false  # Reset so _process continues
				return
	
	# Update visual effects
	update_visual_effects()
	
	# Update Y-sorting after visual effects to ensure z_index is maintained
	update_y_sort()
	
	# Update trail
	if trail and velocity.length() > 0:
		# Use the ball's global position for the trail (which includes height offset)
		var ball_global_pos = global_position
		# Convert global position to trail's local coordinates
		var trail_local_pos = trail.to_local(ball_global_pos)
		trail.add_point(trail_local_pos)
		# Keep only last 20 points to prevent trail from getting too long
		if trail.get_point_count() > 20:
			trail.remove_point(0)

func launch_ghost_ball():
	"""Launch the ghost ball at 75% power"""
	print("=== LAUNCHING GHOST BALL ===")
	
	# Reset ball state
	landed_flag = false
	bounce_count = 0
	is_rolling = false
	
	# Reset to original position
	position = original_position
	
	# Clear the trail
	if trail:
		trail.clear_points()
	
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
		var power_needed_for_target = distance_to_target * 0.8  # Same conversion factor as real ball
		power_needed_for_target = clamp(power_needed_for_target, 300.0, 1200.0)  # Same min/max as real ball
		
		# For sweet spot shots (75%), use the calculated power needed for the target distance
		power = power_needed_for_target
		
		# Calculate height at 50% (sweet spot height) - use same range as real ball
		var height_percentage = 0.5  # 50% height (sweet spot)
		height = 400.0 + (2000.0 - 400.0) * height_percentage  # Same range as real ball: 400-2000
		
	else:
		# Default values if no landing spot
		var max_power = club_info.get("max_distance", 1200.0)
		power = max_power * power_percentage
		height = 400.0 + (2000.0 - 400.0) * 0.5  # 50% height with same range as real ball
	
	# Set initial velocity and ensure ball starts in the air
	velocity = direction * power
	vz = height
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
	
	# Clear trail
	if trail:
		trail.clear_points()
	
	# Reset visual effects
	if sprite:
		sprite.position.y = 0
		sprite.scale = base_scale
	if shadow:
		shadow.scale = base_scale
		shadow.modulate = Color(0, 0, 0, opacity * 0.3) 

func update_y_sort() -> void:
	"""Update the ball's z_index based on its position relative to Y-sorted objects"""
	# Get the ball's grid position
	var ball_global_pos = global_position
	var ball_grid_pos = Vector2i(floor(ball_global_pos.x / cell_size), floor(ball_global_pos.y / cell_size))
	
	# Find the ball's sprite to update its z_index
	var ball_sprite = $Sprite2D
	if not ball_sprite:
		print("Ghost ball update_y_sort: No sprite found")
		return
	
	# Get the course script to access ysort_objects
	var course_script = get_parent().get_parent()  # camera_container -> course_1
	if not course_script or not course_script.has_method("update_ball_y_sort"):
		print("Ghost ball update_y_sort: Course script not found or missing method")
		return
	
	# Call the course script's Y-sort function
	course_script.update_ball_y_sort(self)
	
	print("Ghost ball update_y_sort: Ball sprite z_index after:", ball_sprite.z_index)
	
	# Check shadow z_index too
	var ball_shadow = $Shadow
	if ball_shadow:
		ball_shadow.z_index = ball_sprite.z_index - 1
		print("Ghost ball update_y_sort: Shadow z_index:", ball_shadow.z_index)

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
