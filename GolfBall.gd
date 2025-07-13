extends Node2D

# Import ElementData for element system
const ElementData = preload("res://Elements/ElementData.gd")

signal landed(final_tile: Vector2i)
signal out_of_bounds()  # New signal for out of bounds
signal sand_landing()  # New signal for sand landing

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle
var shot_start_position: Vector2 = Vector2.ZERO  # Position where the shot was taken from

# Audio
var ball_land_sound: AudioStreamPlayer2D
var ball_stop_sound: AudioStreamPlayer2D
var land_on_green_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 720.0  # Increased gravity for more satisfying ball trajectories
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Bounce and roll mechanics
var bounce_count := 0
var min_bounces := 2  # Every ball bounces at least twice
var max_bounces := 2  # Maximum bounces before rolling
var initial_height := 0.0  # Store the initial launch height
var first_bounce_height := 0.0  # Height of the first bounce
var bounce_factor := 0.7 # How much velocity is retained after each bounce (increased from 0.6)
var roll_friction := 0.98 # Reduced friction when rolling on ground (was 0.96)
var min_roll_speed := 25.0 # Reduced minimum speed before stopping (was 50.0)
var is_rolling := false

# Tile-based bounce reduction system
var bounce_reduction_applied := false  # Track if bounce reduction has been applied
var bounce_reduction_values = {
	"Base": 1,  # Base grass - lose 1 bounce
	"R": 2,     # Rough - lose 2 bounces
	"F": 0,     # Fairway - no bounce reduction
	"G": 0,     # Green - no bounce reduction
	"S": 0,     # Sand - no bounce reduction (handled separately)
	"W": 0,     # Water - no bounce reduction (handled separately)
	"T": 0,     # Tee - no bounce reduction
	"Tee": 0,   # Tee - no bounce reduction
	"P": 0,     # Pin - no bounce reduction
	"O": 0,     # Obstacle - no bounce reduction
	"Scorched": 1  # Scorched earth - lose 1 bounce (same as base grass)
}

# Height-based rolling mechanics
var initial_launch_height := 0.0  # Store the original launch height for roll calculations
var roll_distance_multiplier := 1.0  # Multiplier for roll distance based on height
var target_roll_distance := 0.0  # Target distance the ball should roll
var roll_start_position := Vector2.ZERO  # Position where rolling started
var dynamic_roll_friction := 0.98  # Friction that will be adjusted based on power

# Ball-specific roll properties
var ball_roll_factor := 0.70  # Reduced friction - ball loses 70% speed per second (was 0.90)
var ball_roll_boost := 1.0  # Removed the boost multiplier

# Tile-based friction system - FIXED: Lower values = more friction (ball stops faster)
var tile_friction_values = {
	"Base": 1.99,  # Base grass - high friction (was 0.80)
	"F": 0.80,  # Fairway - high friction (was 0.70)
	"G": 0.30,  # Green - moderate friction (was 0.60)
	"R": 2.98,  # Rough - very high friction (was 0.40)
	"S": 0.15,  # Sand - extremely high friction (was 0.20)
	"W": 0.08,  # Water - maximum friction (was 0.10)
	"T": 0.60,  # Tee - high friction (was 0.80)
	"Tee": 0.60,  # Tee - high friction (was 0.80)
	"P": 0.40,  # Pin - same as green (was 0.60)
	"O": 0.15,  # Obstacle - maximum friction (was 0.20)
	"Scorched": 1.99,  # Scorched earth - same high friction as base grass
	"Ice": 0.3  # Ice - low friction (ball slides easily)
}
var current_tile_friction := 0.60  # Default friction (was 0.80)

# Visual effects
var sprite: Sprite2D
var shadow: Sprite2D
var base_scale := Vector2.ONE
var max_height := 0.0
var shadow_base_scale := Vector2.ONE # Store the shadow's original scale from the scene

# Height sweet spot constants (matching LaunchManager.gd)
const HEIGHT_SWEET_SPOT_MIN := 0.3 # 30% of max height
const HEIGHT_SWEET_SPOT_MAX := 0.5 # 50% of max height
const MAX_LAUNCH_HEIGHT := 360.0   # Slightly above tree height (331px) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 0.0   # Allow for ground-level shots (was 144.0)

# Power constants (matching course_1.gd)
const MAX_LAUNCH_POWER := 1200.0
const MIN_LAUNCH_POWER := 300.0

# Progressive height resistance variables
var initial_height_percentage := 0.0
var height_resistance_factor := 1.0
var is_applying_height_resistance := false

# Add at the top with other variables
var spin: float = 0.0
var spin_progress: float = 0.0
var original_launch_direction: Vector2 = Vector2.ZERO  # Track original direction for spin limits
var spin_strength_category: int = 0  # 0=green, 1=yellow, 2=red - for scaling spin effect
var time_percentage: float = -1.0  # -1 means not set, use power percentage instead

# StickyShot effect variables
var sticky_shot_active: bool = false  # Track if StickyShot effect is active
var bouncey_shot_active: bool = false  # Track if Bouncey effect is active
var explosive_shot_active: bool = false  # Track if Explosive effect is active

# Element system variables
var current_element: ElementData = null  # Current element applied to the ball
var element_sprite: Sprite2D = null  # Reference to the Element sprite node

# Elemental club effect variables
var fire_club_active: bool = false  # Fire Club special effects
var ice_club_active: bool = false  # Ice Club special effects

# Fire spreading system variables
var last_fire_tile: Vector2i = Vector2i.ZERO  # Track the last tile that caught fire
var fire_tiles_created: Array[Vector2i] = []  # Track all fire tiles created by this ball

# Ice spreading system
var last_ice_tile: Vector2i = Vector2i.ZERO  # Track the last tile that froze
var ice_tiles_created: Array[Vector2i] = []  # Track all ice tiles created by this ball

# Ball landing highlight system
var final_landing_tile: Vector2i = Vector2i.ZERO  # Track the final tile where ball stopped
var landing_highlight: ColorRect = null  # Visual highlight for the final landing tile
var has_emitted_landed_signal: bool = false  # Track if we've already emitted the landed signal

# Progressive overcharge system variables
var club_info: Dictionary = {}  # Will be set by the course script
var is_penalty_shot: bool = false  # True if red circle is below min distance
var is_putting: bool = false  # Flag for putter-only rolling mechanics

# Special handling for putters - start rolling immediately
var putt_start_time := 0.0  # Record when putt started

# Simple collision system variables
var current_ground_level: float = 0.0  # Current ground level (can be elevated by roofs)

# Wall collision system variables
var last_wall_collision_time: float = 0.0  # Time of last wall collision
var wall_collision_cooldown: float = 0.1  # Cooldown between wall collisions (seconds)

# Rolling collision delay system
var rolling_collision_delay_distance: float = 100.0  # Distance ball must roll before player collision activates
var rolling_start_position: Vector2 = Vector2.ZERO  # Position where rolling started
var rolling_collision_enabled: bool = true  # Whether rolling collisions are enabled

# Enhanced collision prevention system
var last_player_collision_time: float = 0.0  # Time of last player collision
var player_collision_cooldown: float = 0.5  # Cooldown between player collisions (seconds)
var player_collision_count: int = 0  # Number of consecutive player collisions
var max_player_collisions: int = 3  # Maximum consecutive player collisions before forcing escape

# BallHop system variables (for Wand equipment)
var ballhop_cooldown: float = 0.0
var ballhop_cooldown_duration: float = 1.0  # 1 second cooldown
var ballhop_force: float = 350.0  # Vertical force applied by BallHop (reduced for less intense effect)

# Call this to launch the ball
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Store the shot start position for distance calculations
	shot_start_position = global_position
	
	# Reset landing highlight and signal flag for new shot
	remove_landing_highlight()
	has_emitted_landed_signal = false
	final_landing_tile = Vector2i.ZERO
	
	# Calculate height percentage for sweet spot check
	var height_percentage = height / MAX_LAUNCH_HEIGHT  # Simplified calculation for 0.0 to MAX_LAUNCH_HEIGHT range
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	initial_height_percentage = height_percentage
	
	# Initialize height resistance
	height_resistance_factor = 1.0
	is_applying_height_resistance = height_percentage > HEIGHT_SWEET_SPOT_MAX
	
	# For sweet spot check, we need to use the same scaling that the power meter uses
	# The power meter shows 0-100% based on the scaled range, so we should check against that
	var power_scale_factor = 1.0
	var scaled_power = power  # Default to original power
	var adjusted_scaled_max_power = MAX_LAUNCH_POWER  # Default to original max
	
	if chosen_landing_spot != Vector2.ZERO:
		# Calculate the distance to the landing spot
		var ball_global_pos = global_position
		var distance_to_target = ball_global_pos.distance_to(chosen_landing_spot)
		
		# Use the power directly as passed from the course
		scaled_power = power
		
		# For putters, don't apply distance-based power scaling
		if is_putting:
			scaled_power = power  # Use full power for putters
			# Putter detected - using full power
		
		# Calculate power percentage based on the scaled range (what the player sees on the meter)
		# Use the same calculation as the power meter in course_1.gd
		# The power meter uses the adjusted scaled max power (500.0 in this case)
		adjusted_scaled_max_power = max(scaled_power, MIN_LAUNCH_POWER + 200.0)  # Same logic as course_1.gd
		var power_percentage = (power - MIN_LAUNCH_POWER) / (adjusted_scaled_max_power - MIN_LAUNCH_POWER)
		power_percentage = clamp(power_percentage, 0.0, 1.0)
		
		# Simplified: For sweet spot detection, use the original power range
		var original_power_percentage = (power - MIN_LAUNCH_POWER) / (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER)
		original_power_percentage = clamp(original_power_percentage, 0.0, 1.0)
		# Determine if this is a sweet spot shot based on time percentage or power percentage
		var is_sweet_spot_shot = false
		var power_in_sweet_spot = false
		if time_percentage >= 0.0:
			# Use time percentage for sweet spot detection (new system)
			power_in_sweet_spot = time_percentage >= 0.65 and time_percentage <= 0.75
		else:
			# Fallback to original power percentage (old system)
			power_in_sweet_spot = original_power_percentage >= 0.65 and original_power_percentage <= 0.75
		
		# Only power sweet spot determines red circle targeting
		if power_in_sweet_spot:
			is_sweet_spot_shot = true
		
		# Use red circle targeting for ALL shots when a landing spot is chosen (not just sweet spot shots)
		# Calculate the direction to the landing spot using global positions
		var direction_to_target = (chosen_landing_spot - ball_global_pos).normalized()
		
		# Use the direction to the target instead of the mouse direction
		direction = direction_to_target
		
		# Determine if this is a penalty shot (red circle below min distance)
		var min_distance = club_info.get("min_distance", 300.0)
		is_penalty_shot = distance_to_target < min_distance
		
		# Calculate the final landing distance based on shot type and charge
		var final_landing_distance = distance_to_target
		
		# For normal shots, use the original scaled power system
		# For penalty shots, calculate power based on final landing distance
		var final_power = scaled_power  # Default to original scaled power
		
		var effective_power_percentage = time_percentage if time_percentage >= 0.0 else original_power_percentage
		
		if is_penalty_shot:
			# Calculate power needed for penalty shot landing distance
			var power_needed = final_landing_distance * 2.0  # Rough conversion factor
			power_needed = clamp(power_needed, MIN_LAUNCH_POWER, MAX_LAUNCH_POWER)
			final_power = power_needed
		else:
			# Use the power passed from the course directly
			final_power = power  # Use the power that was passed to the ball
			# Shot - using passed power
		
		# The course now properly calculates club-specific power, so no additional scaling needed
		# The power passed from the course already accounts for club efficiency
		
		# Update the power variable to use the calculated value for physics
		power = final_power
	else:
		pass  # No landing spot chosen - using normal power/height system
	
	# Apply the resistance to the final velocity calculation
	velocity = direction.normalized() * power
	# Store the original launch direction for spin limits
	original_launch_direction = direction.normalized()
	
	# Ball launch debug info removed for performance
	# Apply minimal initial spin - most of the spin effect will come from progressive in-air influence
	if spin != 0.0:
		var perp = Vector2(-direction.y, direction.x)
		# Apply only a small fraction of spin at launch (10% of total spin)
		var initial_spin = spin * 0.1
		velocity += perp.normalized() * initial_spin
	z = 0.0
	# Calculate initial vertical velocity to achieve the desired maximum height
	# Using physics formula: z_max = vz_initial^2 / (2 * gravity)
	# So: vz_initial = sqrt(2 * gravity * height)
	vz = sqrt(2.0 * gravity * height)  # This will make the ball reach the exact height specified
	landed_flag = false
	max_height = 0.0
	
	# Reset bounce and roll variables
	bounce_count = 0
	is_rolling = false
	
	# Reset simple collision system for new shot
	current_ground_level = 0.0
	
	# Reset wall collision system for new shot
	last_wall_collision_time = 0.0
	
	# Reset rolling collision delay system for new shot
	rolling_collision_enabled = true
	rolling_start_position = Vector2.ZERO
	
	# Reset enhanced collision prevention system for new shot
	last_player_collision_time = 0.0
	player_collision_count = 0
	
	# Special handling for putters - start rolling immediately
	if is_putting:
		is_rolling = true
		roll_start_position = position
		putt_start_time = Time.get_ticks_msec()  # Record when putt started in milliseconds
		rolling_start_position = position  # Record position for collision delay
		rolling_collision_enabled = false  # Disable collisions until ball moves away
	
	# Store initial height and calculate first bounce height
	initial_height = height
	initial_launch_height = height  # Store for roll calculations
	# Calculate bounce height using the same physics formula
	# For 60% of initial height, we need 60% of the initial velocity
	first_bounce_height = sqrt(2.0 * gravity * height * 0.6)  # First bounce is 60% of initial height
	
	# Apply Bouncey effect to increase bounce height if active
	if bouncey_shot_active:
		first_bounce_height = sqrt(2.0 * gravity * height * 1.2)  # Bouncey effect: Increased bounce height to 120% of initial height
		# Bouncey effect: Increased bounce height
	
	# Calculate roll distance based on height (higher shots roll less, lower shots roll more)
	var height_percentage_for_roll = height / MAX_LAUNCH_HEIGHT  # Simplified calculation for 0.0 to MAX_LAUNCH_HEIGHT range
	height_percentage_for_roll = clamp(height_percentage_for_roll, 0.0, 1.0)
	
	# Calculate power percentage for roll distance
	var power_percentage_for_roll = (power - MIN_LAUNCH_POWER) / (MAX_LAUNCH_POWER - MIN_LAUNCH_POWER)
	power_percentage_for_roll = clamp(power_percentage_for_roll, 0.0, 1.0)
	
	# New roll distance curve based on angle specifications
	var height_multiplier = 1.0
	
	# Treat height as angle: 0% = 0°, 50% = 45°, 100% = 90°
	# Specifications: 90°=10%, 65°=50%, 45°=100%, 20°=200%
	var angle_percentage = height_percentage_for_roll
	
	if angle_percentage <= 0.22:  # 0° to 20° (0% to 22% height)
		# Linear increase from 1.0 to 2.0 (100% to 200% roll distance)
		height_multiplier = 1.0 + (angle_percentage / 0.22) * 1.0
	elif angle_percentage <= 0.5:  # 20° to 45° (22% to 50% height)
		# Linear decrease from 2.0 to 1.0 (200% to 100% roll distance)
		var drop_factor = (angle_percentage - 0.22) / (0.5 - 0.22)
		height_multiplier = 2.0 - (drop_factor * 1.0)
	elif angle_percentage <= 0.72:  # 45° to 65° (50% to 72% height)
		# Linear decrease from 1.0 to 0.5 (100% to 50% roll distance)
		var drop_factor = (angle_percentage - 0.5) / (0.72 - 0.5)
		height_multiplier = 1.0 - (drop_factor * 0.5)
	else:  # 65° to 90° (72% to 100% height)
		# Linear decrease from 0.5 to 0.1 (50% to 10% roll distance)
		var drop_factor = (angle_percentage - 0.72) / (1.0 - 0.72)
		height_multiplier = 0.5 - (drop_factor * 0.4)
	
	# Power also affects roll distance: higher power = more roll distance
	var power_multiplier = 1.0 + (power_percentage_for_roll * 3.0)  # 1.0 to 4.0 range (much more dramatic)
	
	# Calculate dynamic friction based on power (higher power = less friction for longer rolls)
	dynamic_roll_friction = 0.99 - (power_percentage_for_roll * 0.08)  # 0.99 to 0.91 range
	
	target_roll_distance = 300.0 * height_multiplier * power_multiplier  # Increased base roll distance from 200 to 300 pixels
	
	# Get references to sprite and shadow
	sprite = $Sprite2D
	shadow = $Shadow
	element_sprite = $Element
	
	# Set initial shadow position (same as ball but on ground)
	if shadow:
		shadow.position = Vector2.ZERO
		shadow.z_index = -1
		shadow.modulate = Color(0, 0, 0, 0.3)  # Semi-transparent black
		
	
	update_visual_effects()
	
	# Store spin
	self.spin = spin
	self.spin_strength_category = spin_strength_category
	spin_progress = 0.0
	
	# Debug output removed for cleaner code
	
	# Reset bounce reduction system for new shot
	bounce_reduction_applied = false
	min_bounces = 2  # Reset to default
	max_bounces = 2  # Reset to default
	
	# Apply Bouncey effect if active
	if bouncey_shot_active:
		min_bounces = 4  # Double the minimum bounces
		max_bounces = 4  # Double the maximum bounces
		# Bouncey effect: Doubling bounces

	fire_trail_timer = 0.0

func set_element(element_data: ElementData) -> void:
	"""Set the current element for the ball"""
	current_element = element_data
	
	# Update the element sprite
	if element_sprite:
		if element_data and element_data.texture:
			element_sprite.texture = element_data.texture
			element_sprite.modulate = element_data.color
			element_sprite.visible = true
			# Element set
		else:
			element_sprite.visible = false
			# Element cleared

func clear_element() -> void:
	"""Clear the current element from the ball"""
	current_element = null
	if element_sprite:
		element_sprite.visible = false
		# Element cleared from ball

func get_element():
	"""Get the current element data from the ball"""
	return current_element

func is_in_flight() -> bool:
	"""Check if the ball is currently in flight (moving or rolling)"""
	# Ball is in flight if it's not landed and has velocity
	return not landed_flag and (velocity.length() > 0.1 or vz != 0.0 or z > current_ground_level)

func _process(delta):
	if landed_flag:
		return
	
	# Update BallHop cooldown
	if ballhop_cooldown > 0.0:
		ballhop_cooldown -= delta
	
	# Comprehensive water collision check for balls on the ground (including putters)
	if map_manager != null and not ice_club_active and z <= current_ground_level:
		var tile_x = int(floor(position.x / cell_size))
		var tile_y = int(floor(position.y / cell_size))
		var tile_type = map_manager.get_tile_type(tile_x, tile_y)
		if tile_type == "W":
			# Ball hit water tile - treat as out of bounds
			velocity = Vector2.ZERO
			vz = 0.0
			landed_flag = true
			remove_landing_highlight()  # Remove highlight if it exists
			reset_shot_effects()
			out_of_bounds.emit()
			return
	
	# Apply progressive height resistance during flight
	if is_applying_height_resistance and z > 0.0:
		# Use the initial height percentage that was set at launch
		# This ensures consistent resistance throughout the flight
		var current_height_percentage = initial_height_percentage
		
		# Apply progressive resistance when height exceeds sweet spot
		if current_height_percentage > HEIGHT_SWEET_SPOT_MAX:
			var excess_height = current_height_percentage - HEIGHT_SWEET_SPOT_MAX
			var resistance_factor = excess_height / (1.0 - HEIGHT_SWEET_SPOT_MAX)
			
			# Apply resistance as a gradual force (like air resistance)
			# Calculate resistance force based on velocity and height excess
			var resistance_force = velocity.length() * resistance_factor * 0.1 * delta  # Reduced from 0.5 to 0.1
			
			# Apply resistance in the opposite direction of horizontal velocity
			var horizontal_velocity = Vector2(velocity.x, 0)
			if horizontal_velocity.length() > 0:
				var resistance_direction = -horizontal_velocity.normalized()
				velocity += resistance_direction * resistance_force
	
	# Update position
	position += velocity * delta
	
	# Update Y-sorting based on new position
	update_y_sort()
	
	# Check for out-of-bounds collision at any height
	check_out_of_bounds_collision()
	
	# OPTIMIZED: Ball handles its own tree collision detection
	# Only check for tree collisions when ball is in the air (during launch mode)
	if z > 0.0:
		check_nearby_tree_collisions()
	# Bush collisions are now handled through proper Area2D collision detection
	# No need for distance-based checking
	
	# DEBUG: Check if there are any bushes in the scene
	if Time.get_ticks_msec() % 1000 < 16:  # Only check every ~1 second to avoid spam
		var bushes = get_tree().get_nodes_in_group("bushes")
		if bushes.size() > 0:
			print("DEBUG: Found", bushes.size(), "bushes in scene")
			for bush in bushes:
				var distance = global_position.distance_to(bush.global_position)
				if distance < 200:  # Only show nearby bushes
					print("  Bush at", bush.global_position, "distance:", distance)
		else:
			print("DEBUG: No bushes found in scene")
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Ball is in the air
		z += vz * delta
		vz -= gravity * delta
		
		if is_rolling:
			is_rolling = false
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Height tracking for visual effects
		
		# Apply progressive spin effect during in-air flight
		if spin != 0.0 and velocity.length() > 0.1:
			# Check if ball has already deflected more than 90 degrees from original direction
			var current_direction = velocity.normalized()
			var angle_to_original = abs(current_direction.angle_to(original_launch_direction))
			var max_deflection_angle = PI / 2.0  # 90 degrees in radians
			
			if angle_to_original < max_deflection_angle:
				spin_progress = clamp(spin_progress + delta * 0.7, 0.0, 1.0) # Lerp in over ~1.4s
				var lerp_spin = lerp(0.0, spin, spin_progress)
				var perp = Vector2(-velocity.y, velocity.x).normalized()
				
				# Progressive spin effect: starts weak, increases exponentially over time, caps at maximum
				# Much more dramatic exponential curve for stronger late-game spin
				var exponential_factor = pow(spin_progress, 0.05)  # Much steeper curve (0.05 instead of 0.15)
				var base_progressive_factor = clamp(exponential_factor * 15.0, 0.0, 50.0)  # Reduced max from 250.0 to 50.0
				
				# Scale progressive factor based on spin strength category
				var spin_scale_multiplier = 1.0
				match spin_strength_category:
					0:  # Green - low spin - greatly reduced effect
						spin_scale_multiplier = 0.1  # 10% of normal effect
					1:  # Yellow - medium spin - normal effect
						spin_scale_multiplier = 1.0  # 100% of normal effect
					2:  # Red - high spin - greatly increased effect
						spin_scale_multiplier = 3.0  # 300% of normal effect
				
				var progressive_factor = base_progressive_factor * spin_scale_multiplier
				var spin_force = perp * lerp_spin * 0.15 * progressive_factor * delta
				velocity += spin_force

		# Check if ball has landed (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			print("=== BALL LANDED ===")
			print("Landing speed:", abs(vz), "Horizontal speed:", velocity.length())
			print("Bounce count:", bounce_count, "Max bounces:", max_bounces, "Min bounces:", min_bounces)
			
			# Play roof bounce sound if landing on elevated ground
			if current_ground_level > 0.0:
				_play_roof_bounce_sound("")
			
			_check_fire_spreading()
			_check_ice_spreading()
			
			# Check for water hazard on any bounce
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y) if map_manager else ""
			if tile_type == "W":
				# Ice Club can pass through water tiles
				if ice_club_active:
					pass  # Ice Club effect: Ball passes through water tile
					# Continue normal physics - don't stop the ball
				else:
					velocity = Vector2.ZERO
					vz = 0.0
					landed_flag = true
					remove_landing_highlight()  # Remove highlight if it exists
					reset_shot_effects()
					out_of_bounds.emit()
					return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				sand_landing.emit()
				return
			
			# Check for bounce reduction on first landing
			check_bounce_reduction()
			
			# Calculate bounce based on bounce count and initial height
			var landing_speed = abs(vz)
			var horizontal_speed = velocity.length()
			
			# Determine if we should bounce or start rolling
			if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
				# Check for StickyShot effect
				if sticky_shot_active and not is_putting:
					# StickyShot effect: Skipping bounces for normal shot
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Natural physics-based bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					
					# Check for explosive shot effect on first bounce
					if explosive_shot_active and bounce_count == 1:
						_create_explosion_at_position()
						explosive_shot_active = false  # Clear the effect after explosion
					
					# Simple physics: reflect the vertical velocity with energy loss
					# The ball was falling with negative vz, so bounce it back up with positive vz
					# Apply bounce factor to reduce energy each bounce
					vz = abs(vz) * bounce_factor
					
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
				rolling_start_position = position  # Record position for collision delay
				rolling_collision_enabled = false  # Disable collisions until ball moves away
	
	elif vz > 0.0:
		# Ball is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		if is_rolling:
			is_rolling = false
		
		# Apply progressive spin effect during bounces (still in air)
		if spin != 0.0 and velocity.length() > 0.1:
			# Check if ball has already deflected more than 90 degrees from original direction
			var current_direction = velocity.normalized()
			var angle_to_original = abs(current_direction.angle_to(original_launch_direction))
			var max_deflection_angle = PI / 2.0  # 90 degrees in radians
			
			if angle_to_original < max_deflection_angle:
				spin_progress = clamp(spin_progress + delta * 0.7, 0.0, 1.0) # Lerp in over ~1.4s
				var lerp_spin = lerp(0.0, spin, spin_progress)
				var perp = Vector2(-velocity.y, velocity.x).normalized()
				
				# Progressive spin effect: starts weak, increases exponentially over time, caps at maximum
				# Much more dramatic exponential curve for stronger late-game spin
				var exponential_factor = pow(spin_progress, 0.05)  # Much steeper curve (0.05 instead of 0.15)
				var base_progressive_factor = clamp(exponential_factor * 15.0, 0.0, 50.0)  # Reduced max from 250.0 to 50.0
				
				# Scale progressive factor based on spin strength category
				var spin_scale_multiplier = 1.0
				match spin_strength_category:
					0:  # Green - low spin - greatly reduced effect
						spin_scale_multiplier = 0.1  # 10% of normal effect
					1:  # Yellow - medium spin - normal effect
						spin_scale_multiplier = 1.0  # 100% of normal effect
					2:  # Red - high spin - greatly increased effect
						spin_scale_multiplier = 3.0  # 300% of normal effect
				
				var progressive_factor = base_progressive_factor * spin_scale_multiplier
				var spin_force = perp * lerp_spin * 0.15 * progressive_factor * delta
				velocity += spin_force
		# Check if ball has landed again (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Play roof bounce sound if landing on elevated ground
			if current_ground_level > 0.0:
				_play_roof_bounce_sound("")
			
			# Calculate bounce based on bounce count and initial height
			var landing_speed = abs(vz)
			var horizontal_speed = velocity.length()
			
			# Determine if we should bounce or start rolling
			if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
				# Check for StickyShot effect
				if sticky_shot_active and not is_putting:
					# StickyShot effect: Skipping bounces for normal shot
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Natural physics-based bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					
					# Check for explosive shot effect on first bounce
					if explosive_shot_active and bounce_count == 1:
						_create_explosion_at_position()
						explosive_shot_active = false  # Clear the effect after explosion
					
					# Simple physics: reflect the vertical velocity with energy loss
					# The ball was falling with negative vz, so bounce it back up with positive vz
					# Apply bounce factor to reduce energy each bounce
					vz = abs(vz) * bounce_factor
					
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling only after minimum bounces are complete
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
	
	else:
		# Ball is on the ground (z = current_ground_level, vz <= 0)
		z = current_ground_level

		# Check for water hazard when ball is on the ground (before out of bounds)
		if map_manager != null:
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y)
			if tile_type == "W":
				# Ice Club can pass through water tiles
				if ice_club_active:
					pass  # Ice Club effect: Ball passes through water tile while rolling
					# Continue normal physics - don't stop the ball
				else:
					velocity = Vector2.ZERO
					vz = 0.0
					landed_flag = true
					remove_landing_highlight()  # Remove highlight if it exists
					reset_shot_effects()
					out_of_bounds.emit()
					return
			elif tile_type == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				sand_landing.emit()
				return

		# Check for out of bounds when ball is on the ground
		if map_manager != null:
			var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
			if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
				# Ball landed out of bounds
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				out_of_bounds.emit()
				return
		
		# If we have negative vz but we're on the ground, check if we should bounce
		if vz < 0.0 and not is_rolling and z <= current_ground_level:
			# Check if we should bounce or start rolling
			var landing_speed = abs(vz)
			var horizontal_speed = velocity.length()
			
			# Only bounce if we haven't reached max bounces AND we haven't completed minimum bounces
			if bounce_count < max_bounces and bounce_count < min_bounces:
				# Check for StickyShot effect
				if sticky_shot_active and not is_putting:
					# StickyShot effect: Skipping bounces for normal shot
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Natural physics-based bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					
					# Check for fire spreading on bounce
					print("=== BOUNCE FIRE SPREADING CHECK ===")
					print("Bounce count:", bounce_count, "Position:", position, "Tile:", Vector2i(floor(position.x / cell_size), floor(position.y / cell_size)))
					_check_fire_spreading()
					
					# Simple physics: reflect the vertical velocity with energy loss
					# The ball was falling with negative vz, so bounce it back up with positive vz
					# Apply bounce factor to reduce energy each bounce
					vz = abs(vz) * bounce_factor
					
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling only after minimum bounces are complete
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
				rolling_start_position = position  # Record position for collision delay
				rolling_collision_enabled = false  # Disable collisions until ball moves away
		
		if is_rolling:
			# Ball is rolling on the ground
			vz = 0.0
			
			# Check for fire spreading while rolling
			_check_fire_spreading()
			# Check for ice spreading while rolling
			_check_ice_spreading()
			
			# Check for water hazard while rolling
			var tile_x_roll = int(floor(position.x / cell_size))
			var tile_y_roll = int(floor(position.y / cell_size))
			var tile_type_roll = map_manager.get_tile_type(tile_x_roll, tile_y_roll) if map_manager else ""
			if tile_type_roll == "W":
				# Ice Club can pass through water tiles
				if ice_club_active:
					pass  # Ice Club effect: Ball passes through water tile while rolling
					# Continue normal physics - don't stop the ball
				else:
					velocity = Vector2.ZERO
					vz = 0.0
					landed_flag = true
					remove_landing_highlight()  # Remove highlight if it exists
					reset_shot_effects()
					out_of_bounds.emit()
					return
			elif tile_type_roll == "S":  # Sand trap
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				sand_landing.emit()
				return
			
			# Check rolling collision delay and enable collisions if ball has moved far enough
			_check_rolling_collision_delay()
			
			# Check for wall/shop collisions while rolling (pinball effect)
			check_rolling_wall_collisions()
			
			# Update friction based on current tile type
			update_tile_friction()
			
			# Track roll distance
			var current_roll_distance = position.distance_to(roll_start_position)
			
			# Apply friction based on tile type - MUCH MORE AGGRESSIVE
			var tile_friction = current_tile_friction
			var combined_friction = tile_friction * ball_roll_factor * ball_roll_boost
			
			# Special handling for putters - much higher friction
			if is_putting:
				# Check if we're in the first 1 second of the putt
				var current_time = Time.get_ticks_msec()
				var putt_duration = current_time - putt_start_time
				
				if putt_duration < 1000:  # 1000 milliseconds = 1 second
					# First 1 second: NO friction for natural roll
					combined_friction = 0.0  # No friction at all
				else:
					# After 1 second: increased putter friction
					combined_friction = combined_friction * 0.3  # Increased from 0.1 to 0.3 for more friction
			
			# StickyShot effect: Remove rolling for normal shots (but maintain for putting)
			if sticky_shot_active and not is_putting:
				# StickyShot effect: Stopping ball immediately (no rolling for normal shots)
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				
				# Calculate final landing tile
				if map_manager != null:
					final_landing_tile = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
					# Ball finally stopped on tile
					create_landing_highlight(final_landing_tile)
					
					# Emit landed signal with final tile position (only once)
					if not has_emitted_landed_signal:
						landed.emit(final_landing_tile)
						has_emitted_landed_signal = true
					
					# Only play ball stop sound if on fairway tile
					var tile_type = map_manager.get_tile_type(final_landing_tile.x, final_landing_tile.y)
					if tile_type == "F":
						if ball_stop_sound and ball_stop_sound.stream:
							ball_stop_sound.play()
					
					# Play clap sound if ball lands on green within 1000 pixels
					if tile_type == "G":
						var shot_distance = shot_start_position.distance_to(global_position)
						if shot_distance < 1000.0:
							if ball_stop_sound and ball_stop_sound.stream:
								ball_stop_sound.play()
						elif shot_distance > 1000.0:
							if land_on_green_sound and land_on_green_sound.stream:
								land_on_green_sound.play()
				
				# Reset shot effects when ball finally stops (for both map manager cases)
				reset_shot_effects()
				return
			
			# MUCH MORE AGGRESSIVE FRICTION: Lose a fixed percentage per frame
			# Higher friction values = more velocity reduction per frame
			var friction_per_frame = combined_friction * 0.02  # Reduced from 0.1 to 0.02 - ball loses much less velocity per frame
			velocity = velocity * (1.0 - friction_per_frame)
			
			# Check if ball should stop rolling
			if velocity.length() < min_roll_speed:
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				
				# Calculate final landing tile
				if map_manager != null:
					final_landing_tile = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
					# Ball finally stopped on tile
					create_landing_highlight(final_landing_tile)
					
					# Emit landed signal with final tile position (only once)
					if not has_emitted_landed_signal:
						landed.emit(final_landing_tile)
						has_emitted_landed_signal = true
					
					# Only play ball stop sound if on fairway tile
					var tile_type = map_manager.get_tile_type(final_landing_tile.x, final_landing_tile.y)
					if tile_type == "F":
						if ball_stop_sound and ball_stop_sound.stream:
							ball_stop_sound.play()
					
					# Play clap sound if ball lands on green within 1000 pixels
					if tile_type == "G":
						var shot_distance = shot_start_position.distance_to(global_position)
						if shot_distance < 1000.0:
							if ball_stop_sound and ball_stop_sound.stream:
								ball_stop_sound.play()
						elif shot_distance > 1000.0:
							if land_on_green_sound and land_on_green_sound.stream:
								land_on_green_sound.play()
				
				# Reset shot effects when ball finally stops (for both map manager cases)
				reset_shot_effects()
				return
	
	# Update visual effects
	update_visual_effects()

	# Fire element trail logic
	if current_element and current_element.name == "Fire" and (z > 0.0 or is_rolling):
		fire_trail_timer += delta
		if fire_trail_timer >= fire_trail_interval:
			fire_trail_timer = 0.0
			_spawn_fire_particle()
	else:
		fire_trail_timer = 0.0  # Reset if not in air, not fire, or rolling

func update_visual_effects():
	if not sprite or not shadow:
		return

	# Use standardized height visual effects for the ball sprite (if needed)
	Global.apply_standard_height_visual_effects(sprite, shadow, z, base_scale)

	# Shadow scaling and opacity based on height
	var min_shadow_scale = 0.5  # Smallest shadow at max height (relative to base)
	var max_shadow_scale = 1.0  # Full size on ground (relative to base)
	var min_shadow_alpha = 0.1  # Most transparent at max height
	var max_shadow_alpha = 0.4  # Most opaque on ground

	var height_ratio = clamp(z / MAX_LAUNCH_HEIGHT, 0.0, 1.0)
	var shadow_scale = lerp(max_shadow_scale, min_shadow_scale, height_ratio)
	var shadow_alpha = lerp(max_shadow_alpha, min_shadow_alpha, height_ratio)

	shadow.scale = shadow_base_scale * shadow_scale
	shadow.modulate.a = shadow_alpha

	# Update element sprite position and effects
	if element_sprite and element_sprite.visible:
		# Position element sprite to match the ball sprite
		element_sprite.position = sprite.position
		element_sprite.scale = sprite.scale
		element_sprite.z_index = sprite.z_index + 1  # Element appears on top of ball
		# Add element-specific visual effects
		if current_element and current_element.name == "Fire":
			# Add fire flickering effect
			var flicker = sin(Time.get_ticks_msec() * 0.01) * 0.1 + 0.9
			element_sprite.modulate.a = flicker
		elif current_element and current_element.name == "Ice":
			# Add ice shimmering effect
			var shimmer = sin(Time.get_ticks_msec() * 0.005) * 0.05 + 0.95
			element_sprite.modulate.a = shimmer
			# Add a subtle blue tint that pulses
			var blue_tint = sin(Time.get_ticks_msec() * 0.003) * 0.1 + 0.9
			element_sprite.modulate.b = blue_tint

	# Add rolling-specific effects
	if is_rolling:
		# Slightly smaller when rolling
		sprite.scale *= 0.9
		if shadow:
			shadow.scale *= 1.1
			shadow.modulate = Color(0, 0, 0, 0.4)

	# Add explosive shot visual effects
	if explosive_shot_active and z > 0.0:
		# Red flashing tint when ball is in the air
		var flash_speed = 0.01  # Speed of the flash effect
		var flash_intensity = sin(Time.get_ticks_msec() * flash_speed) * 0.5 + 0.5
		var red_tint = Color(1.0, 0.3, 0.3, 1.0)  # Red tint
		var original_color = Color(1.0, 1.0, 1.0, 1.0)  # Original white
		sprite.modulate = original_color.lerp(red_tint, flash_intensity * 0.7)  # 70% intensity
	else:
		# Reset to normal color when not explosive or on ground
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	# Add rotation based on velocity
	var speed = velocity.length()
	if speed > 0:
		# Calculate rotation speed based on velocity magnitude
		# Faster speed = faster rotation
		var rotation_speed = speed * 0.01  # Adjust this multiplier to control rotation speed
		# Calculate rotation direction based on velocity direction
		# For a golf ball, we want it to rotate forward (like a real golf ball)
		var velocity_angle = velocity.angle()
		# Add rotation to the sprite (positive for clockwise rotation)
		sprite.rotation += rotation_speed
		# Optional: Add some visual feedback for very fast shots
		if speed > 200:
			# Add a slight wobble effect for high-speed shots
			var wobble = sin(sprite.rotation * 10) * 0.02
			sprite.rotation += wobble

func update_tile_friction() -> void:
	if map_manager == null:
		# Map manager is null!
		return
		
	# Calculate which tile the ball is currently on
	var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if ball is out of bounds
	if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
		# Ball is out of bounds
		return
	
	# Get the tile type at this position
	var tile_type = map_manager.get_tile_type(tile_pos.x, tile_pos.y)
	
	# Update friction based on tile type
	if tile_friction_values.has(tile_type):
		current_tile_friction = tile_friction_values[tile_type]
	else:
		current_tile_friction = 0.60  # Default friction
	
	# Apply Fire Club special effect: Reduced friction on grass/rough tiles
	if fire_club_active and (tile_type == "R" or tile_type == "F"):
		# Fire Club effect: Reduced friction on grass/rough tiles
		current_tile_friction = min(current_tile_friction + 0.2, 0.95)  # Reduce friction by 0.2, cap at 0.95

func check_bounce_reduction() -> void:
	"""Check if the ball should have its bounces reduced based on the tile it landed on"""
	if bounce_reduction_applied or map_manager == null:
		return
		
	# Calculate which tile the ball is currently on
	var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if ball is out of bounds
	if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
		return
	
	# Get the tile type at this position
	var tile_type = map_manager.get_tile_type(tile_pos.x, tile_pos.y)
	
	# Check if this tile type reduces bounces
	if bounce_reduction_values.has(tile_type):
		var reduction = bounce_reduction_values[tile_type]
		if reduction > 0:
			# Apply bounce reduction
			min_bounces = max(0, min_bounces - reduction)
			max_bounces = max(0, max_bounces - reduction)
			bounce_reduction_applied = true

func _ready():
	# Get references to audio players
	ball_land_sound = get_node_or_null("BallLand")
	ball_stop_sound = get_node_or_null("BallStop")
	land_on_green_sound = get_node_or_null("LandOnGreen")
	
	# Get references to sprite and shadow
	sprite = get_node_or_null("Sprite2D")
	shadow = get_node_or_null("Shadow")
	element_sprite = get_node_or_null("Element")
	
	# Store the shadow's base scale from the scene
	if shadow:
		shadow_base_scale = shadow.scale
	
	# Initialize element sprite
	if element_sprite:
		element_sprite.visible = false  # Start hidden
	
	# Connect to area_entered signal for collision detection
	var area2d = get_node_or_null("Area2D")
	if area2d:
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
	
	# Add to groups for easy detection by NPCs
	add_to_group("golf_balls")
	add_to_group("balls")

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
	# Check if this is a Pin collision
	if area.get_parent() and area.get_parent().name == "Pin":
		# Pin collision detected - the pin will handle hole completion
		pass
	# Check if this is an NPC collision (GangMember)
	elif area.get_parent() and area.get_parent().has_method("_handle_ball_collision"):
		# Check if this is a vision area collision - ignore those
		if area.name == "VisionArea2D":
			print("GolfBall: Ignoring vision area collision with ", area.get_parent().name)
			return  # Ignore vision area collisions
		
		# Only handle collisions with body areas, not vision areas
		if area.name != "BodyArea2D":
			print("GolfBall: Ignoring non-body area collision with ", area.name, " on ", area.get_parent().name)
			return  # Ignore non-body area collisions
		
		# NPC collision detected - let the NPC handle the collision
		# The NPC will check ball height and apply appropriate effects
		# GolfBall: NPC collision detected
		print("GolfBall: Processing body area collision with ", area.get_parent().name)
		area.get_parent()._handle_ball_collision(self)
	# Check if this is a Player collision
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		# Player collision detected - check if collision should be allowed
		if not _should_allow_player_collision():
			return  # Skip this collision based on various conditions
		
		# Update collision tracking
		player_collision_count += 1
		last_player_collision_time = Time.get_ticks_msec() / 1000.0
		
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
	# Check if this is a StoneWall collision
	elif area.get_parent() and area.get_parent().has_method("_handle_wall_area_collision"):
		# StoneWall collision detected - use new roof bounce system
		_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit stone wall
		notify_course_of_collision()
	# Check if this is an Oil Drum collision
	elif area.get_parent() and (area.get_parent().name.contains("Oil") or area.get_parent().name.contains("oil") or area.get_parent().name.contains("OilDrum")):
		# Oil drum collision detected - use the oil drum's ball collision system
		if area.get_parent().has_method("_handle_ball_collision"):
			area.get_parent()._handle_ball_collision(self)
		else:
			# Fallback to roof bounce system
			_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit oil drum
		notify_course_of_collision()
	# Check if this is a Boulder collision
	elif area.get_parent() and area.get_parent().has_method("_handle_boulder_collision"):
		# Boulder collision detected - use roof bounce system
		_handle_roof_bounce_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit boulder
		notify_course_of_collision()
	# Check if this is a Bush collision
	elif area.get_parent() and area.get_parent().has_method("_handle_bush_collision"):
		print("=== GOLFBALL BUSH COLLISION DETECTED ===")
		print("Area parent:", area.get_parent().name)
		print("Area parent type:", area.get_parent().get_class())
		# Bush collision detected - use bush velocity damping system
		_handle_bush_collision(area.get_parent())
		# Notify course to re-enable player collision since ball hit bush
		notify_course_of_collision()
		print("=== END GOLFBALL BUSH COLLISION ===")


func _on_area_exited(area):
	# Area exit handling if needed
	pass

func _handle_player_collision(player: Node2D) -> void:
	"""Handle collision with player - deal damage based on ball velocity"""
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if "is_ghost" in self:
		is_ghost_ball = get("is_ghost")
	elif name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		return
	
	# Calculate damage based on ball velocity
	var ball_speed = velocity.length()
	var damage = 0
	
	# Simple damage calculation based on speed
	if ball_speed > 800:
		damage = 25  # High speed = high damage
	elif ball_speed > 400:
		damage = 15  # Medium speed = medium damage
	elif ball_speed > 100:
		damage = 5   # Low speed = low damage
	else:
		damage = 1   # Very low speed = minimal damage
	
	# Apply damage to player
	if player.has_method("take_damage"):
		player.take_damage(damage)
	
	# Reflect the ball away from the player
	var ball_pos = global_position
	var player_center = player.global_position
	
	# Calculate the direction from player center to ball
	var to_ball_direction = (ball_pos - player_center).normalized()
	
	# Simple reflection: reflect the velocity across the player center
	var reflected_velocity = velocity - 2 * velocity.dot(to_ball_direction) * to_ball_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the ball
	velocity = reflected_velocity

func reset_shot_effects() -> void:
	"""Reset all shot modification effects after the ball has landed"""
	sticky_shot_active = false
	bouncey_shot_active = false
	clear_element()  # Clear any element effects
	
	# Reset elemental club effects
	fire_club_active = false
	ice_club_active = false
	
	# Reset fire spreading system
	last_fire_tile = Vector2i.ZERO
	fire_tiles_created.clear()
	
	# Reset ice spreading system
	last_ice_tile = Vector2i.ZERO
	ice_tiles_created.clear()

func notify_course_of_collision() -> void:
	"""Notify the course that the ball has collided with something, so it can re-enable player collision"""
	# Find the course script and notify it
	var course_script = get_parent().get_parent()  # camera_container -> course_1
	if course_script and course_script.has_method("_on_ball_collision_detected"):
		course_script._on_ball_collision_detected()

func create_landing_highlight(tile_pos: Vector2i) -> void:
	"""Create a bright highlight effect for the final landing tile"""
	# Remove any existing highlight
	if landing_highlight and landing_highlight.is_inside_tree():
		landing_highlight.queue_free()
		landing_highlight = null
	
	# Create new highlight
	landing_highlight = ColorRect.new()
	landing_highlight.name = "LandingHighlight"
	landing_highlight.size = Vector2(cell_size, cell_size)
	landing_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Ignore mouse input
	
	# Position relative to the course scene (world coordinates), not camera
	var course_script = get_parent().get_parent()  # camera_container -> course_1
	
	# Try to add to CameraContainer first (which contains the GridContainer)
	if course_script and course_script.has_node("CameraContainer"):
		var camera_container = course_script.get_node("CameraContainer")
		
		# Position relative to the camera container (which contains the grid)
		landing_highlight.position = Vector2(tile_pos.x * cell_size, tile_pos.y * cell_size)
		landing_highlight.z_index = -3  # Keep in highlight tiles range
		landing_highlight.color = Color(1.0, 1.0, 0.0, 0.6)  # Bright yellow with 60% opacity
		
		# Add a pulsing animation effect
		var tween = create_tween()
		tween.set_loops()  # Loop forever
		tween.tween_property(landing_highlight, "color:a", 0.3, 0.8)  # Fade to 30% opacity
		tween.tween_property(landing_highlight, "color:a", 0.6, 0.8)  # Fade back to 60% opacity
		
		# Add the highlight to the camera container so it moves with the world
		camera_container.add_child(landing_highlight)
	else:
		landing_highlight.queue_free()

func remove_landing_highlight() -> void:
	"""Remove the landing highlight effect"""
	if landing_highlight and landing_highlight.is_inside_tree():
		landing_highlight.queue_free()
		landing_highlight = null

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
						# LeavesRustle sound played - ball passing through leaves near trunk
						# Mark when we last played the sound for this ball-tree combination
						set_meta(sound_key, current_time)

func check_nearby_bush_collisions() -> void:
	"""Ball checks for nearby bush collisions during flight (distance-based, like tree leaves)"""
	# REMOVED: Distance-based bush collision detection
	# Bush collisions are now handled through proper Area2D collision detection
	# The bush's Area2D will automatically trigger when the ball enters/exits
	pass

# Simple collision system methods
func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < object height, reflect.
	If projectile height > object height, set ground to object height.
	"""
	# Simple collision handler - debug info removed for performance
	var object_height = Global.get_object_height_from_marker(object)
	
	# Check if ball is above the object
	if z > object_height:
		current_ground_level = object_height
	else:
		_reflect_off_object(object)

func _handle_bush_collision(bush: Node2D) -> void:
	"""
	Handle collision with bush - uses velocity damping instead of bouncing.
	"""
	if not bush or not bush.has_method("_handle_bush_collision"):
		return
	
	# Let the bush handle the collision (velocity damping and sound)
	bush._handle_bush_collision(self)

func _reflect_off_object(object: Node2D) -> void:
	"""
	Simple reflection off an object when ball is below object height.
	"""
	# Reflecting off object - debug info removed for performance
	var ball_velocity = velocity
	
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
	
	# Apply the reflected velocity to the ball
	velocity = reflected_velocity

func _set_ground_level(height: float) -> void:
	"""
	Set the ground level to a specific height (used by Area2D collision system).
	"""
	# Setting ground level - debug info removed for performance
	current_ground_level = height

func _reset_ground_level() -> void:
	"""
	Reset the ground level to normal (0.0) when exiting Area2D collision.
	"""
	# Resetting ground level - debug info removed for performance
	current_ground_level = 0.0

func _play_roof_bounce_sound(object_type: String) -> void:
	"""
	Play the appropriate sound when landing on elevated ground (roof bounce).
	This is called when the ball actually lands on the elevated surface.
	"""
	# Playing roof bounce sound - debug info removed for performance
	var current_ground_level_debug = current_ground_level
	
	# Find the object that set this ground level and play its sound
	var objects = get_tree().get_nodes_in_group("collision_objects")
	# Found collision objects - debug info removed for performance
	
	for obj in objects:
		if not obj.has_method("get_collision_radius"):
			continue
			
		var distance = global_position.distance_to(obj.global_position)
		var collision_radius = obj.get_collision_radius()
		
		# Checking collision objects - debug info removed for performance
		if distance <= collision_radius:
			# Object height and ground level - debug info removed for performance
			var obj_height = Global.get_object_height_from_marker(obj)
			if abs(obj_height - current_ground_level) < 1.0:  # Small tolerance for floating point
				# Play the appropriate sound based on object type
				if obj.name.contains("Shop") or obj.name.contains("shop"):
					var thunk = obj.get_node_or_null("TrunkThunk")
					if thunk:
						thunk.play()
						# TrunkThunk sound played for shop roof bounce
				elif obj.name.contains("Tree") or obj.name.contains("tree"):
					var thunk = obj.get_node_or_null("TrunkThunk")
					if thunk:
						thunk.play()
						# TrunkThunk sound played for tree roof bounce
				elif obj.name.contains("Oil") or obj.name.contains("oil") or obj.name.contains("OilDrum"):
					# Don't play oil drum sound on roof bounce - only on actual collision
					# The oil drum sound should only play when there's a direct collision/reflection
					pass
				elif obj.name.contains("GangMember") or obj.name.contains("gang") or obj.name.contains("Gang"):
					obj._play_collision_sound()
				elif obj.name.contains("Police") or obj.name.contains("police"):
					obj._play_collision_sound()
				break

func check_out_of_bounds_collision() -> void:
	"""
	Check if the ball has collided with an out-of-bounds tile at any height.
	Grid boundaries are reflected, water tiles cause out-of-bounds.
	"""
	if map_manager == null:
		return
		
	# Calculate which tile the ball is currently on
	var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if ball is out of bounds (grid boundaries)
	if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
		# Ball hit out-of-bounds tile
		_reflect_from_out_of_bounds(tile_pos)
		return
	
	# Only check for water collisions when the ball is actually on the ground
	# This prevents balls from bouncing off water tiles when they're high in the air
	if z <= current_ground_level:
		var tile_type = map_manager.get_tile_type(tile_pos.x, tile_pos.y)
		if tile_type == "W":  # Water is out-of-bounds
			# Ice Club can pass through water tiles
			if ice_club_active:
				pass  # Ice Club effect: Ball passes through water tile
				# Continue normal physics - don't stop the ball
			else:
				# Ball hit water tile - treat as out of bounds (don't reflect)
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				out_of_bounds.emit()
				return

func _reflect_from_out_of_bounds(tile_pos: Vector2i) -> void:
	"""
	Reflect the ball back into bounds when it hits an out-of-bounds tile.
	"""
	# Reflecting from out of bounds - debug info removed for performance
	var ball_velocity = velocity
	# Reflected velocity - debug info removed for performance
	
	# Determine which boundary was hit and calculate proper reflection
	var reflected_velocity = Vector2.ZERO
	
	# Check if ball is outside grid boundaries
	if tile_pos.x < 0:
		# Hit left boundary - reflect horizontally
		reflected_velocity = Vector2(abs(ball_velocity.x), ball_velocity.y)
		# Move ball back into bounds
		position.x = 0.0
	elif tile_pos.x >= map_manager.grid_width:
		# Hit right boundary - reflect horizontally
		reflected_velocity = Vector2(-abs(ball_velocity.x), ball_velocity.y)
		# Move ball back into bounds
		position.x = (map_manager.grid_width - 1) * cell_size
	elif tile_pos.y < 0:
		# Hit top boundary - reflect vertically
		reflected_velocity = Vector2(ball_velocity.x, abs(ball_velocity.y))
		# Move ball back into bounds
		position.y = 0.0
	elif tile_pos.y >= map_manager.grid_height:
		# Hit bottom boundary - reflect vertically
		reflected_velocity = Vector2(ball_velocity.x, -abs(ball_velocity.y))
		# Move ball back into bounds
		position.y = (map_manager.grid_height - 1) * cell_size
	else:
		# This should never be reached for water tiles since we handle them separately
		# This is a fallback for any other out-of-bounds tiles
		var tile_center = Vector2(tile_pos.x * cell_size + cell_size / 2, tile_pos.y * cell_size + cell_size / 2)
		var to_ball_direction = (global_position - tile_center).normalized()
		reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		# Move ball slightly away from the tile
		position += to_ball_direction * cell_size * 0.5
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the ball
	velocity = reflected_velocity
	
	# Play collision sound if available
	if ball_land_sound and ball_land_sound.stream:
		ball_land_sound.play()

func _check_rolling_collision_delay() -> void:
	"""
	Check if the ball has rolled far enough to enable player collisions.
	This prevents balls from getting stuck inside the player's Area2D when they start rolling.
	"""
	if rolling_collision_enabled:
		return  # Already enabled
	
	# Calculate distance from rolling start position
	var distance_from_start = position.distance_to(rolling_start_position)
	
	# Enable collisions if ball has moved far enough
	if distance_from_start >= rolling_collision_delay_distance:
		rolling_collision_enabled = true

func _should_allow_player_collision() -> bool:
	"""
	Check if player collision should be allowed based on various conditions.
	This prevents infinite collision loops and stuck balls.
	"""
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	
	# Check collision cooldown
	if current_time - last_player_collision_time < player_collision_cooldown:
		return false
	
	# Check if we've hit the player too many times consecutively
	if player_collision_count >= max_player_collisions:
		_force_escape_from_player()
		return false
	
	# Check rolling collision delay for rolling balls
	if is_rolling and not rolling_collision_enabled:
		return false
	
	return true

func _force_escape_from_player() -> void:
	"""
	Force the ball to escape from the player area when stuck in collision loop.
	"""
	print("=== FORCING BALL ESCAPE FROM PLAYER ===")
	
	# Find the player to calculate escape direction
	var player = null
	var players = get_tree().get_nodes_in_group("rectangular_obstacles")
	for p in players:
		if p.has_method("take_damage"):  # This identifies the player
			player = p
			break
	
	if player:
		var player_pos = player.global_position
		var ball_pos = global_position
		
		# Calculate direction away from player
		var escape_direction = (ball_pos - player_pos).normalized()
		if escape_direction.length() < 0.1:  # If ball is exactly on player, use random direction
			escape_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		
		# Apply strong escape velocity
		var escape_velocity = escape_direction * 200.0  # Strong escape force
		velocity = escape_velocity
		
		# Reset collision count and cooldown
		player_collision_count = 0
		last_player_collision_time = Time.get_ticks_msec() / 1000.0
		
		print("✓ Ball forced to escape with velocity:", escape_velocity)
	else:
		print("✗ Could not find player for escape calculation")

func check_rolling_wall_collisions() -> void:
	"""
	Check for wall/shop/player collisions while rolling (pinball effect).
	"""
	# Check cooldown to prevent multiple bounces
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	if current_time - last_wall_collision_time < wall_collision_cooldown:
		return  # Still in cooldown
	
	# Get all rectangular obstacle objects in the scene (includes shops, stone walls, and players)
	var rectangular_obstacles = get_tree().get_nodes_in_group("rectangular_obstacles")
	
	for obstacle in rectangular_obstacles:
		# Check if ball is within obstacle collision area
		var ball_pos = global_position
		var obstacle_pos = obstacle.global_position
		var distance = ball_pos.distance_to(obstacle_pos)
		
		# Use obstacle's collision radius
		var collision_radius = 150.0  # Default obstacle collision radius
		if obstacle.has_method("get_collision_radius"):
			collision_radius = obstacle.get_collision_radius()
		
		# If ball is within obstacle collision area, bounce it off
		if distance <= collision_radius:
			# Check if this is a player collision
			if obstacle.has_method("handle_ball_collision"):
				# This is a player - check if collision should be allowed
				if not _should_allow_player_collision():
					continue  # Skip this collision based on various conditions
				
				# Update collision tracking
				player_collision_count += 1
				last_player_collision_time = Time.get_ticks_msec() / 1000.0
				
				# This is a player - handle player collision
				obstacle.handle_ball_collision(self)
				# Update collision time
				last_wall_collision_time = current_time
				break  # Only handle one collision per frame
			else:
				# This is a regular obstacle (wall/shop) - pinball bounce!
				# Update collision time
				last_wall_collision_time = current_time
				
				# Calculate bounce direction (away from obstacle center)
				var bounce_direction = (ball_pos - obstacle_pos).normalized()
				
				# Reflect velocity across the bounce direction
				var reflected_velocity = velocity - 2 * velocity.dot(bounce_direction) * bounce_direction
				
				# Reduce speed slightly to prevent infinite bouncing
				reflected_velocity *= 0.8
				
				# Add a small amount of randomness to prevent infinite loops
				var random_angle = randf_range(-0.1, 0.1)
				reflected_velocity = reflected_velocity.rotated(random_angle)
				
				# Apply the reflected velocity
				velocity = reflected_velocity
				
				# Play collision sound if available
				if ball_land_sound and ball_land_sound.stream:
					ball_land_sound.play()
				
				# Ball bounced off rectangular obstacle - debug info removed for performance
				break  # Only handle one collision per frame

func _check_fire_spreading() -> void:
	"""Check if the fire ball should spread fire to the current tile"""

	if not current_element or current_element.name != "Fire":
		return  # Not a fire ball
	
	if map_manager == null:
		return  # No map manager
	
	# Get current tile position
	var current_tile = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if this tile is already on fire or has been scorched
	var is_already_affected = _is_tile_on_fire_or_scorched(current_tile)
	if is_already_affected:
		return  # Tile already affected by fire
	
	# Check if this is a grass tile that can catch fire
	var tile_type = map_manager.get_tile_type(current_tile.x, current_tile.y)
	if not _is_grass_tile(tile_type):
		return  # Not a grass tile
	
	# Check if we've already created a fire tile on this position
	var already_created = current_tile in fire_tiles_created
	if already_created:
		return  # Already created fire on this tile
	
	# Create fire tile
	_create_fire_tile(current_tile)

func _is_tile_on_fire_or_scorched(tile_pos: Vector2i) -> bool:
	"""Check if a tile is currently on fire or has been scorched"""
	# Check for existing fire tiles in the scene
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if fire_tile.get_tile_position() == tile_pos:
			return true
	return false

func _is_grass_tile(tile_type: String) -> bool:
	"""Check if a tile type is considered grass (can catch fire)"""
	return tile_type in ["F", "R", "Base", "G"]  # Fairway, Rough, Base grass, Green (excludes Scorched)

func _create_fire_tile(tile_pos: Vector2i) -> void:
	"""Create a fire tile at the specified position"""
	var fire_tile_scene = preload("res://Particles/FireTile.tscn")
	var fire_tile = fire_tile_scene.instantiate()
	
	# Set the tile position
	fire_tile.set_tile_position(tile_pos)
	
	# Find the camera container to add the fire tile to (so it moves with the world)
	var camera_container = get_parent()  # The ball should be a child of the camera container
	
	# Position the fire tile at the tile center (relative to camera container)
	var tile_center = Vector2(tile_pos.x * cell_size + cell_size / 2, tile_pos.y * cell_size + cell_size / 2)
	fire_tile.position = tile_center
	
	# Add to fire tiles group for easy management
	fire_tile.add_to_group("fire_tiles")
	
	# Connect to completion signal
	fire_tile.fire_tile_completed.connect(_on_fire_tile_completed)
	
	# Add to camera container so it moves with the world
	camera_container.add_child(fire_tile)
	
	# Track this fire tile
	fire_tiles_created.append(tile_pos)
	last_fire_tile = tile_pos

func _on_fire_tile_completed(tile_pos: Vector2i) -> void:
	"""Handle when a fire tile transitions to scorched earth"""
	# The fire tile will handle its own visual transition
	# We just need to notify the map manager that this tile is now scorched
	if map_manager and map_manager.has_method("set_tile_scorched"):
		map_manager.set_tile_scorched(tile_pos.x, tile_pos.y)

func _check_ice_spreading() -> void:
	"""Check if the ice ball should spread ice to the current tile"""

	if not current_element or current_element.name != "Ice":
		return  # Not an ice ball
	
	if map_manager == null:
		return  # No map manager
	
	# Get current tile position
	var current_tile = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if this tile is already iced or frozen
	var is_already_affected = _is_tile_iced_or_frozen(current_tile)
	if is_already_affected:
		return  # Tile already affected by ice
	
	# Check if this is a tile that can be iced (water, sand, grass)
	var tile_type = map_manager.get_tile_type(current_tile.x, current_tile.y)
	if not _is_iceable_tile(tile_type):
		return  # Not an iceable tile
	
	# Check if we've already created an ice tile on this position
	var already_created = current_tile in ice_tiles_created
	if already_created:
		return  # Already created ice on this tile
	
	# Create ice tile
	_create_ice_tile(current_tile)

func _is_tile_iced_or_frozen(tile_pos: Vector2i) -> bool:
	"""Check if a tile is currently iced or frozen"""
	# Check for existing ice tiles in the scene
	var ice_tiles = get_tree().get_nodes_in_group("ice_tiles")
	for ice_tile in ice_tiles:
		if ice_tile.get_tile_position() == tile_pos:
			return true
	return false

func _is_iceable_tile(tile_type: String) -> bool:
	"""Check if a tile type can be iced (water, sand, grass)"""
	return tile_type in ["W", "S", "F", "R", "Base", "G"]  # Water, Sand, Fairway, Rough, Base grass, Green

func _create_ice_tile(tile_pos: Vector2i) -> void:
	"""Create an ice tile at the specified position"""
	var ice_tile_scene = preload("res://Particles/IceTile.tscn")
	var ice_tile = ice_tile_scene.instantiate()
	
	# Set the tile position
	ice_tile.set_tile_position(tile_pos)
	
	# Find the camera container to add the ice tile to (so it moves with the world)
	var camera_container = get_parent()  # The ball should be a child of the camera container
	
	# Position the ice tile at the tile center (relative to camera container)
	var tile_center = Vector2(tile_pos.x * cell_size + cell_size / 2, tile_pos.y * cell_size + cell_size / 2)
	ice_tile.position = tile_center
	
	# Add to ice tiles group for easy management
	ice_tile.add_to_group("ice_tiles")
	
	# Connect to completion signal
	ice_tile.ice_tile_completed.connect(_on_ice_tile_completed)
	
	# Add to camera container so it moves with the world
	camera_container.add_child(ice_tile)
	
	# Track this ice tile
	ice_tiles_created.append(tile_pos)
	last_ice_tile = tile_pos

func _on_ice_tile_completed(tile_pos: Vector2i) -> void:
	"""Handle when an ice tile transitions to frozen state"""
	# The ice tile will handle its own visual transition
	# We just need to notify the map manager that this tile is now frozen
	if map_manager and map_manager.has_method("set_tile_iced"):
		map_manager.set_tile_iced(tile_pos.x, tile_pos.y)

func _spawn_fire_particle():
	var fire_particle_scene = preload("res://Particles/FireParticle.tscn")
	var fire_particle = fire_particle_scene.instantiate()
	# Spawn at the ball's visual sprite position (including height offset)
	if sprite:
		fire_particle.global_position = global_position + Vector2(0, sprite.position.y)
	else:
		fire_particle.global_position = global_position
	# If the ball is rolling, set drop_speed to 0 so the particle does not fall
	if is_rolling:
		fire_particle.drop_speed = 0.0
	get_tree().current_scene.add_child(fire_particle)

var fire_trail_timer := 0.0
var fire_trail_interval := 0.15  # How often to drop a fire particle (seconds)

func _create_explosion_at_position() -> void:
	"""Create an explosion at the ball's current position"""
	print("Creating explosion at position:", global_position)
	
	# Load the explosion scene
	var explosion_scene = preload("res://Particles/Explosion.tscn")
	var explosion = explosion_scene.instantiate()
	
	# Posi=== FIRE SPREADING CHECK ===tion the explosion at the ball's position
	explosion.global_position = global_position
	
	# Add the explosion to the scene
	get_tree().current_scene.add_child(explosion)
	
	print("Explosion created successfully")

func ballhop():
	"""Apply BallHop effect - makes the ball bounce"""
	print("GolfBall: BallHop called - cooldown:", ballhop_cooldown, "landed_flag:", landed_flag, "is_rolling:", is_rolling)
	
	if ballhop_cooldown > 0.0:
		print("GolfBall: BallHop failed - still on cooldown")
		return false  # Still on cooldown
	
	# Check if ball has already landed and stopped
	if landed_flag:
		print("GolfBall: BallHop failed - ball has already landed and stopped")
		return false  # Ball has already landed and stopped
	
	# Apply bounce effect - give the ball upward velocity
	vz = ballhop_force
	
	# Set cooldown
	ballhop_cooldown = ballhop_cooldown_duration
	
	# Reset rolling state if ball was rolling
	if is_rolling:
		is_rolling = false
		print("GolfBall: BallHop reset rolling state")
	
	# Play BallHop sound effect
	var ballhop_sound = get_node_or_null("BallHop")
	if ballhop_sound and ballhop_sound.stream:
		ballhop_sound.play()
		print("GolfBall: Playing BallHop sound effect")
	
	print("GolfBall: BallHop applied successfully!")
	print("  - New vz:", vz)
	print("  - Ballhop force:", ballhop_force)
	print("  - Cooldown set to:", ballhop_cooldown)
	print("  - Ball position:", global_position, "z:", z)
	return true

func is_currently_punching() -> bool:
	"""Check if currently performing a PunchB animation"""
	return false  # GolfBall doesn't have punching animations

# NPC Ball Push System helper methods
func set_rolling_state(rolling: bool) -> void:
	"""Set the rolling state of the ball (for NPC push system)"""
	is_rolling = rolling
	if rolling:
		# Reset rolling start position when re-enabling rolling
		roll_start_position = position
		rolling_start_position = position
		rolling_collision_enabled = false  # Disable collisions until ball moves away
		print("Ball rolling state enabled by NPC push")

func set_landed_flag(landed: bool) -> void:
	"""Set the landed flag of the ball (for NPC push system)"""
	landed_flag = landed
	if not landed:
		# Reset bounce count when re-enabling flight
		bounce_count = 0
		# Clear landing highlight system so ball can create new highlight when it stops again
		remove_landing_highlight()
		has_emitted_landed_signal = false
		final_landing_tile = Vector2i.ZERO
		print("Ball landed flag reset by NPC push")
