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
			vz = 0.0
			
			# Handle bounce or landing
			if bounce_count < max_bounces and velocity.length() > min_bounce_speed:
				# Bounce
				bounce_count += 1
				vz = velocity.length() * bounce_factor * 0.5  # Reduced bounce height
				velocity *= bounce_factor
				
				# Reduce rotation speed after bounce
				rotation_speed *= 0.7
			else:
				# Land
				# Remove lines like:
				# print("=== KNIFE LANDING ===")
				# print("Knife landed at position:", global_position)
				# print("Final z:", z)
				# print("Final vz:", vz)
				# print("=== END KNIFE LANDING ===")
				
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				# Stop rotation and stick in ground
				if sprite:
					sprite.rotation_degrees = 0.0
				
				# Emit landed signals
				emit_signal("knife_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(global_position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					# Remove lines like:
					# print("Warning: MapManager missing or missing world_to_map method")
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
	
	# Update visual effects
	update_visual_effects()
	

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
