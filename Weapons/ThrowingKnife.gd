extends Node2D

signal knife_landed(final_position: Vector2)
signal knife_hit_target(target: Node2D)
signal landed(final_tile: Vector2i)  # Add landed signal for compatibility with course

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle

# Audio
var knife_impact_sound: AudioStreamPlayer2D
var knife_whoosh_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 2000.0
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Knife-specific properties
var is_knife := true
var rotation_speed := 720.0  # Degrees per second rotation
var has_hit_target := false
var target_hit := false

# Dual-sided landing mechanics
var blade_marker: Marker2D
var handle_marker: Marker2D
var is_handle_landing := false  # Track if handle side is facing down
var handle_bounce_count := 0
var max_handle_bounces := 2  # Handle can bounce up to 2 times
var handle_bounce_factor := 0.98  # How much velocity is retained after handle bounce (increased for dramatic bounces)
var min_handle_bounce_speed := 50.0  # Minimum speed for handle to bounce

# Bounce mechanics (knives stick like sticky shots - no bounces)
var bounce_count := 0
var max_bounces := 0  # Knives don't bounce - they stick
var bounce_factor := 0.0  # No bounce
var min_bounce_speed := 0.0

# Visual effects
var sprite: Sprite2D
var shadow: Sprite2D
var base_scale := Vector2.ONE
var max_height := 0.0

# Height sweet spot constants (matching LaunchManager.gd)
const HEIGHT_SWEET_SPOT_MIN := 0.3 # 30% of max height
const HEIGHT_SWEET_SPOT_MAX := 0.5 # 50% of max height
const MAX_LAUNCH_HEIGHT := 2000.0
const MIN_LAUNCH_HEIGHT := 500.0

# Power constants (using Hybrid club stats)
const MAX_LAUNCH_POWER := 1050.0  # Hybrid max distance
const MIN_LAUNCH_POWER := 200.0   # Hybrid min distance

# Progressive height resistance variables
var initial_height_percentage := 0.0
var height_resistance_factor := 1.0
var is_applying_height_resistance := false

# Launch parameters
var time_percentage: float = -1.0  # -1 means not set, use power percentage instead
var club_info: Dictionary = {}  # Will be set by the course script
var is_penalty_shot: bool = false  # True if red circle is below min distance

# Call this to launch the knife
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Reset state for new throw
	has_hit_target = false
	target_hit = false
	landed_flag = false
	bounce_count = 0
	handle_bounce_count = 0
	is_handle_landing = false
	
	# Calculate height percentage for sweet spot check
	var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	initial_height_percentage = height_percentage
	
	# Initialize height resistance
	height_resistance_factor = 1.0
	is_applying_height_resistance = height_percentage > HEIGHT_SWEET_SPOT_MAX
	
	if chosen_landing_spot != Vector2.ZERO:
		# Calculate the distance to the landing spot
		var knife_global_pos = global_position
		var distance_to_target = knife_global_pos.distance_to(chosen_landing_spot)
		
		# Use the power directly as passed from the course
		var final_power = power
		
		# Calculate power percentage based on the scaled range
		var adjusted_scaled_max_power = max(power, MIN_LAUNCH_POWER + 200.0)
		var power_percentage = (power - MIN_LAUNCH_POWER) / (adjusted_scaled_max_power - MIN_LAUNCH_POWER)
		power_percentage = clamp(power_percentage, 0.0, 1.0)
		
		# Simplified: For sweet spot detection, use the original power range
		var original_power_percentage = (power - MIN_LAUNCH_POWER) / (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER)
		original_power_percentage = clamp(original_power_percentage, 0.0, 1.0)
		
		# Determine if this is a sweet spot throw
		var power_in_sweet_spot = false
		if time_percentage >= 0.0:
			# Use time percentage for sweet spot detection (new system)
			power_in_sweet_spot = time_percentage >= 0.65 and time_percentage <= 0.75
		else:
			# Fallback to original power percentage (old system)
			power_in_sweet_spot = original_power_percentage >= 0.65 and original_power_percentage <= 0.75
		
		# Use the direction passed in from LaunchManager (which is calculated from knife position to target)
		# The LaunchManager already calculates the correct direction, so we don't need to override it
		
		# Determine if this is a penalty throw (red circle below min distance)
		var min_distance = club_info.get("min_distance", 200.0)
		is_penalty_shot = distance_to_target < min_distance
		
		# Update the power variable to use the calculated value for physics
		power = final_power

	# Apply the resistance to the final velocity calculation
	velocity = direction.normalized() * power
	
	# Remove lines like:
	# print("=== KNIFE LAUNCH DEBUG ===")
	# print("Knife position:", global_position)
	# print("Launch direction:", direction)
	# print("Power:", power)
	# print("Final velocity:", velocity)
	# print("Height:", height)
	# print("=== END KNIFE LAUNCH DEBUG ===")
	
	z = 0.0
	vz = height  # Use the height parameter directly for vertical velocity
	landed_flag = false
	max_height = 0.0
	
	# Immediately launch the knife into the air by applying the first vertical update
	z += vz * 0.016  # Apply one frame of vertical movement (assuming 60 FPS)
	vz -= gravity * 0.016  # Apply one frame of gravity
	
	# Remove lines like:
	# print("=== KNIFE PHYSICS SETUP ===")
	# print("Initial z:", z)
	# print("Initial vz:", vz)
	# print("Height parameter:", height)
	# print("=== END KNIFE PHYSICS SETUP ===")
	
	# Get references to sprite and shadow
	sprite = $ThrowingKnife
	shadow = $Shadow
	
	# Get references to blade and handle markers
	blade_marker = $ThrowingKnife/Blade
	handle_marker = $ThrowingKnife/Handle
	
	# Set base scale from sprite's current scale
	if sprite:
		base_scale = sprite.scale
		# Remove lines like:
		# print("Set base_scale to:", base_scale)
	
	# Set initial shadow position (same as knife but on ground)
	if shadow:
		shadow.position = Vector2.ZERO
		shadow.z_index = -1
		shadow.modulate = Color(0, 0, 0, 0.3)  # Semi-transparent black
	
	update_visual_effects()
	
	# Store time percentage for sweet spot detection
	self.time_percentage = time_percentage

func _process(delta):
	if landed_flag:
		return
	
	# Debug: Track knife state every few frames
	if Engine.get_process_frames() % 30 == 0:  # Every 30 frames (about twice per second at 60 FPS)
		print("KNIFE STATE: z=", z, " vz=", vz, " velocity=", velocity, " landed_flag=", landed_flag, " handle_bounces=", handle_bounce_count)
	
	# Apply progressive height resistance during flight
	if is_applying_height_resistance and z > 0.0:
		var current_height_percentage = initial_height_percentage
		
		if current_height_percentage > HEIGHT_SWEET_SPOT_MAX:
			var excess_height = current_height_percentage - HEIGHT_SWEET_SPOT_MAX
			var resistance_factor = excess_height / (1.0 - HEIGHT_SWEET_SPOT_MAX)
			
			# Apply resistance as a gradual force
			var resistance_force = velocity.length() * resistance_factor * 0.1 * delta
			
			# Apply resistance in the opposite direction of horizontal velocity
			var horizontal_velocity = Vector2(velocity.x, 0)
			if horizontal_velocity.length() > 0:
				var resistance_direction = -horizontal_velocity.normalized()
				velocity += resistance_direction * resistance_force
	
	# Update position
	position += velocity * delta
	
	# Update Y-sorting based on new position
	update_y_sort()
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Knife is in the air
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Rotate the knife while in flight
		if sprite:
			sprite.rotation_degrees += rotation_speed * delta
		
		# Check for landing
		if z <= 0.0:
			z = 0.0
			
			# Determine which side is facing down
			determine_landing_side()
			
			print("=== KNIFE LANDING CONDITIONS ===")
			print("Is handle landing: ", is_handle_landing)
			print("Handle bounce count: ", handle_bounce_count)
			print("Max handle bounces: ", max_handle_bounces)
			print("Velocity length: ", velocity.length())
			print("Min handle bounce speed: ", min_handle_bounce_speed)
			print("Should bounce: ", (is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed))
			print("=== END LANDING CONDITIONS ===")
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed - bounce like a golf ball
				handle_bounce_count += 1
				vz = velocity.length() * handle_bounce_factor * 6.0  # Much more dramatic bounce height - increased from 1.5 to 6.0
				velocity *= handle_bounce_factor
				
				# Reduce rotation speed after bounce
				rotation_speed *= 0.7
				
				print("HANDLE BOUNCE: Bounce count now ", handle_bounce_count, ", vz set to ", vz)
				print("HANDLE BOUNCE: New velocity ", velocity, " (length: ", velocity.length(), ")")
				print("HANDLE BOUNCE: New rotation speed ", rotation_speed)
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
					print("HANDLE BOUNCE: Played ball land sound")
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				print("KNIFE STICKING: Final landing at ", global_position)
				print("KNIFE STICKING: Set landed_flag to true, velocity to zero")
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play knife impact sound for blade landing
				var knife_impact = get_node_or_null("KnifeImpact")
				if knife_impact:
					knife_impact.play()
					print("KNIFE STICKING: Played knife impact sound")
				
				# Emit landed signals
				emit_signal("knife_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(global_position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
	
	elif vz > 0.0:
		# Knife is bouncing up from ground (z = 0, vz > 0)
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Rotate the knife while in flight
		if sprite:
			sprite.rotation_degrees += rotation_speed * delta
		
		print("KNIFE BOUNCING: z=", z, " vz=", vz, " velocity=", velocity)
		
		# Check if knife has landed again
		if z <= 0.0:
			z = 0.0
			
			# Determine which side is facing down
			determine_landing_side()
			
			print("=== KNIFE SECOND LANDING CONDITIONS ===")
			print("Is handle landing: ", is_handle_landing)
			print("Handle bounce count: ", handle_bounce_count)
			print("Max handle bounces: ", max_handle_bounces)
			print("Velocity length: ", velocity.length())
			print("Min handle bounce speed: ", min_handle_bounce_speed)
			print("Should bounce: ", (is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed))
			print("=== END SECOND LANDING CONDITIONS ===")
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed - bounce like a golf ball
				handle_bounce_count += 1
				vz = velocity.length() * handle_bounce_factor * 6.0  # Much more dramatic bounce height - increased from 1.5 to 6.0
				velocity *= handle_bounce_factor
				
				# Reduce rotation speed after bounce
				rotation_speed *= 0.7
				
				print("HANDLE SECOND BOUNCE: Bounce count now ", handle_bounce_count, ", vz set to ", vz)
				print("HANDLE SECOND BOUNCE: New velocity ", velocity, " (length: ", velocity.length(), ")")
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
					print("HANDLE SECOND BOUNCE: Played ball land sound")
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				print("KNIFE STICKING AFTER BOUNCE: Final landing at ", global_position)
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play knife impact sound for blade landing
				var knife_impact = get_node_or_null("KnifeImpact")
				if knife_impact:
					knife_impact.play()
					print("KNIFE STICKING AFTER BOUNCE: Played knife impact sound")
				
				# Emit landed signals
				emit_signal("knife_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(global_position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
	
	# Update visual effects
	update_visual_effects()

func determine_landing_side():
	"""Determine which side of the knife is facing down when landing"""
	if not sprite or not blade_marker or not handle_marker:
		is_handle_landing = false
		print("Warning: Missing sprite or markers")
		return
	
	# Get the global positions of the blade and handle markers
	var blade_global_pos = blade_marker.global_position
	var handle_global_pos = handle_marker.global_position
	
	print("=== KNIFE LANDING SIDE DETECTION ===")
	print("Sprite rotation (degrees): ", sprite.rotation_degrees)
	print("Blade marker global Y: ", blade_global_pos.y)
	print("Handle marker global Y: ", handle_global_pos.y)
	print("Blade marker local pos: ", blade_marker.position)
	print("Handle marker local pos: ", handle_marker.position)
	
	# Compare Y positions - the higher Y value is facing down toward the ground
	# Since the knife is rotating, we need to check which marker has the higher Y position
	if handle_global_pos.y > blade_global_pos.y:
		# Handle has higher Y - handle side is facing down
		is_handle_landing = true
		print("RESULT: Handle side is facing down (Y: ", handle_global_pos.y, " > ", blade_global_pos.y, ")")
	else:
		# Blade has higher Y - blade side is facing down
		is_handle_landing = false
		print("RESULT: Blade side is facing down (Y: ", blade_global_pos.y, " > ", handle_global_pos.y, ")")
	print("=== END LANDING SIDE DETECTION ===")

func update_visual_effects():
	if not sprite or not shadow:
		return
	
	# Scale the knife based on height (bigger when higher) - adjusted for knife height range
	var height_scale = 1.0 + (z / 1500.0)  # More conservative scaling for knife's higher z values
	
	sprite.scale = base_scale * height_scale
	
	# Move the knife up based on height - scaled down to keep it on screen
	sprite.position.y = -(z / 3.0)  # Scale down vertical movement to keep knife visible
	
	# Update shadow size and opacity based on height - like golf ball
	# Keep shadow at ground level (Vector2.ZERO) - never move it up with the knife
	shadow.position = Vector2.ZERO
	
	var shadow_scale = 1.0 - (z / 2000.0)  # Shadow gets smaller when knife is higher - adjusted for knife height
	shadow_scale = clamp(shadow_scale, 0.1, 0.8)  # Shadow is smaller at max height
	
	shadow.scale = Vector2(0.21, 0.125) * shadow_scale
	
	# Shadow opacity also changes with height
	var shadow_alpha = 0.3 - (z / 2000.0)  # Less opaque when knife is higher - adjusted for knife height
	shadow_alpha = clamp(shadow_alpha, 0.05, 0.3)  # Keep some visibility
	
	shadow.modulate = Color(0, 0, 0, shadow_alpha)
	
	# Ensure shadow is always behind the knife sprite
	shadow.z_index = sprite.z_index - 1
	# Keep shadow visible even if knife is behind objects
	if shadow.z_index <= -5:
		shadow.z_index = 1

func update_y_sort():
	"""Update the knife's z_index using the same global Y-sort system as the golf ball"""
	# Use the global Y-sort system like the golf ball
	Global.update_ball_y_sort(self)

func check_target_hits():
	# Check if knife hit any targets (enemies, etc.)
	var area = $Area2D
	if area:
		var overlapping_bodies = area.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.has_method("take_damage") or body.has_method("hit"):
				# Knife hit a target
				if not has_hit_target:
					has_hit_target = true
					target_hit = true
					emit_signal("knife_hit_target", body)
					
					# Play impact sound
					var knife_impact = get_node_or_null("KnifeImpact")
					if knife_impact:
						knife_impact.play()
						
func is_in_flight() -> bool:
	"""Check if the knife is currently in flight"""
	return not landed_flag and (z > 0.0 or velocity.length() > 0.1)

func get_velocity() -> Vector2:
	"""Get the current velocity of the knife"""
	return velocity

func get_ground_position() -> Vector2:
	"""Return the knife's position on the ground (ignoring height) for Y-sorting"""
	# The knife's position is already the ground position
	# The height (z) is only used for visual effects (sprite.position.y = -z)
	return global_position

func get_height() -> float:
	"""Return the knife's current height for Y-sorting and collision handling"""
	return z

# Method to set club info (called by LaunchManager)
func set_club_info(info: Dictionary):
	club_info = info

# Method to set time percentage (called by LaunchManager)
func set_time_percentage(percentage: float):
	time_percentage = percentage

# Method to get final power (called by course)
func get_final_power() -> float:
	"""Get the final power used for this throw"""
	return velocity.length() if velocity.length() > 0 else 0.0

# Method to check if this is a knife (called by course)
func is_throwing_knife() -> bool:
	"""Check if this is a throwing knife"""
	return true 
