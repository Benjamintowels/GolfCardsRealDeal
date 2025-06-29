extends Node2D

signal landed(final_tile: Vector2i)
signal out_of_bounds()  # New signal for out of bounds
signal sand_landing()  # New signal for sand landing

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle

# Audio
var ball_land_sound: AudioStreamPlayer2D
var ball_stop_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 2000.0
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
	"O": 0      # Obstacle - no bounce reduction
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
	"O": 0.15   # Obstacle - maximum friction (was 0.20)
}
var current_tile_friction := 0.60  # Default friction (was 0.80)

# Visual effects
var sprite: Sprite2D
var shadow: Sprite2D
var base_scale := Vector2.ONE
var max_height := 0.0

# Height sweet spot constants (matching course_1.gd)
const HEIGHT_SWEET_SPOT_MIN := 0.4 # 40% of max height
const HEIGHT_SWEET_SPOT_MAX := 0.6 # 60% of max height
const MAX_LAUNCH_HEIGHT := 2000.0
const MIN_LAUNCH_HEIGHT := 400.0

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

# Call this to launch the ball
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Reset landing highlight and signal flag for new shot
	remove_landing_highlight()
	has_emitted_landed_signal = false
	final_landing_tile = Vector2i.ZERO
	
	# Calculate height percentage for sweet spot check
	var height_percentage = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
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
			print("Putter detected - using full power:", power)
		
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
			print("Shot - using passed power:", power, "target distance:", distance_to_target)
		
		# The course now properly calculates club-specific power, so no additional scaling needed
		# The power passed from the course already accounts for club efficiency
		
		# Update the power variable to use the calculated value for physics
		power = final_power
	else:
		print("No landing spot chosen - using normal power/height system")
	
	# Apply the resistance to the final velocity calculation
	velocity = direction.normalized() * power
	# Store the original launch direction for spin limits
	original_launch_direction = direction.normalized()
	# Apply minimal initial spin - most of the spin effect will come from progressive in-air influence
	if spin != 0.0:
		var perp = Vector2(-direction.y, direction.x)
		# Apply only a small fraction of spin at launch (10% of total spin)
		var initial_spin = spin * 0.1
		velocity += perp.normalized() * initial_spin
	z = 0.0
	vz = height  # Use the height parameter directly for vertical velocity
	landed_flag = false
	max_height = 0.0
	
	# Reset bounce and roll variables
	bounce_count = 0
	is_rolling = false
	
	# Special handling for putters - start rolling immediately
	if is_putting:
		is_rolling = true
		roll_start_position = position
		putt_start_time = Time.get_ticks_msec()  # Record when putt started in milliseconds
	
	# Store initial height and calculate first bounce height
	initial_height = height
	initial_launch_height = height  # Store for roll calculations
	first_bounce_height = height * 0.6  # First bounce is 60% of initial height (increased from 40%)
	
	# Apply Bouncey effect to increase bounce height if active
	if bouncey_shot_active:
		first_bounce_height = height * 1.2  # Bouncey effect: 120% of initial height for much higher bounces
		print("Bouncey effect: Increased bounce height to", first_bounce_height, "(120% of initial height)")
	
	# Calculate roll distance based on height (higher shots roll less, lower shots roll more)
	var height_percentage_for_roll = (height - MIN_LAUNCH_HEIGHT) / (MAX_LAUNCH_HEIGHT - MIN_LAUNCH_HEIGHT)
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
	
	print("=== BALL LAUNCH DEBUG ===")
	print("Ball is_putting flag:", is_putting)
	print("Club info:", club_info)
	print("Launch power:", power)
	print("Launch height:", height)
	print("Initial velocity length:", velocity.length())
	print("Velocity vector:", velocity)
	print("=== END BALL LAUNCH DEBUG ===")
	
	# Reset bounce reduction system for new shot
	bounce_reduction_applied = false
	min_bounces = 2  # Reset to default
	max_bounces = 2  # Reset to default
	
	# Apply Bouncey effect if active
	if bouncey_shot_active:
		min_bounces = 4  # Double the minimum bounces
		max_bounces = 4  # Double the maximum bounces
		print("Bouncey effect: Doubling bounces to", min_bounces, "minimum and", max_bounces, "maximum")
	
	print("=== NEW SHOT BOUNCE SETTINGS ===")
	print("Initial min_bounces:", min_bounces)
	print("Initial max_bounces:", max_bounces)
	print("Bouncey effect active:", bouncey_shot_active)
	print("=== END NEW SHOT BOUNCE SETTINGS ===")

func _process(delta):
	if landed_flag:
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
	
	# Update vertical physics (arc and bounce)
	if z > 0.0:
		# Ball is in the air
		z += vz * delta
		vz -= gravity * delta
		if is_rolling:
			is_rolling = false
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
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
					# StickyShot active and not putting - skip bounces and go straight to rolling
					print("StickyShot effect: Skipping bounces for normal shot")
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Normal bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						# First bounce: use calculated first bounce height
						bounce_height = first_bounce_height
					else:
						# Subsequent bounces: reduce by bounce factor each time
						bounce_height = first_bounce_height * pow(bounce_factor, bounce_count - 1)
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
	
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
		# Check if ball has landed again
		if z <= 0.0:
			z = 0.0
			
			# Calculate bounce based on bounce count and initial height
			var landing_speed = abs(vz)
			var horizontal_speed = velocity.length()
			
			# Determine if we should bounce or start rolling
			if bounce_count < max_bounces and (bounce_count < min_bounces or landing_speed > 50.0):
				# Check for StickyShot effect
				if sticky_shot_active and not is_putting:
					# StickyShot active and not putting - skip bounces and go straight to rolling
					print("StickyShot effect: Skipping bounces for normal shot")
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Normal bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						# First bounce: use calculated first bounce height
						bounce_height = first_bounce_height
					else:
						# Subsequent bounces: reduce by bounce factor each time
						bounce_height = first_bounce_height * pow(bounce_factor, bounce_count - 1)
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling only after minimum bounces are complete
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
	
	else:
		# Ball is on the ground (z = 0, vz <= 0)
		z = 0.0

		# Check for water hazard when ball is on the ground (before out of bounds)
		if map_manager != null:
			var tile_x = int(floor(position.x / cell_size))
			var tile_y = int(floor(position.y / cell_size))
			var tile_type = map_manager.get_tile_type(tile_x, tile_y)
			if tile_type == "W":
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
				print("Ball landed out of bounds at:", tile_pos)
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				remove_landing_highlight()  # Remove highlight if it exists
				reset_shot_effects()
				out_of_bounds.emit()
				return
		
		# If we have negative vz but we're on the ground, check if we should bounce
		if vz < 0.0 and not is_rolling:
			# Check if we should bounce or start rolling
			var landing_speed = abs(vz)
			var horizontal_speed = velocity.length()
			
			# Only bounce if we haven't reached max bounces AND we haven't completed minimum bounces
			if bounce_count < max_bounces and bounce_count < min_bounces:
				# Check for StickyShot effect
				if sticky_shot_active and not is_putting:
					# StickyShot active and not putting - skip bounces and go straight to rolling
					print("StickyShot effect: Skipping bounces for normal shot")
					vz = 0.0
					is_rolling = true
					roll_start_position = position  # Record where rolling started
				else:
					# Normal bounce logic
					bounce_count += 1
					# Play ball landing sound on every bounce
					if ball_land_sound and ball_land_sound.stream:
						ball_land_sound.play()
					# Calculate bounce height based on bounce count
					var bounce_height = 0.0
					if bounce_count == 1:
						# First bounce: use calculated first bounce height
						bounce_height = first_bounce_height
					else:
						# Subsequent bounces: reduce by bounce factor each time
						bounce_height = first_bounce_height * pow(bounce_factor, bounce_count - 1)
					# Set vertical velocity for the bounce
					vz = bounce_height
					# Reduce horizontal velocity slightly on bounce
					velocity *= 0.98
			else:
				# Start rolling only after minimum bounces are complete
				vz = 0.0
				is_rolling = true
				roll_start_position = position  # Record where rolling started
		
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
				# StickyShot active and not putting - stop the ball immediately
				print("StickyShot effect: Stopping ball immediately (no rolling for normal shots)")
				velocity = Vector2.ZERO
				vz = 0.0
				landed_flag = true
				
				# Calculate final landing tile
				if map_manager != null:
					final_landing_tile = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
					print("Ball finally stopped on tile:", final_landing_tile)
					
					# Create landing highlight for the final tile
					create_landing_highlight(final_landing_tile)
					
					# Only play ball stop sound if on fairway tile
					var tile_type = map_manager.get_tile_type(final_landing_tile.x, final_landing_tile.y)
					if tile_type == "F":
						if ball_stop_sound and ball_stop_sound.stream:
							ball_stop_sound.play()
					
					# Emit landed signal with final tile position (only once)
					if not has_emitted_landed_signal:
						has_emitted_landed_signal = true
						print("Ball landed on final tile:", final_landing_tile)
						# Reset shot effects after the ball has landed
						reset_shot_effects()
						landed.emit(final_landing_tile)
				else:
					print("Map manager is null, can't determine final tile")
					# Reset shot effects even if map manager is null
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
					print("Ball finally stopped on tile:", final_landing_tile)
					
					# Create landing highlight for the final tile
					create_landing_highlight(final_landing_tile)
					
					# Only play ball stop sound if on fairway tile
					var tile_type = map_manager.get_tile_type(final_landing_tile.x, final_landing_tile.y)
					if tile_type == "F":
						if ball_stop_sound and ball_stop_sound.stream:
							ball_stop_sound.play()
					
					# Emit landed signal with final tile position (only once)
					if not has_emitted_landed_signal:
						has_emitted_landed_signal = true
						print("Ball landed on final tile:", final_landing_tile)
						# Reset shot effects after the ball has landed
						reset_shot_effects()
						landed.emit(final_landing_tile)
				else:
					print("Map manager is null, can't determine final tile")
					# Reset shot effects even if map manager is null
					reset_shot_effects()
				return
	
	# Update visual effects
	update_visual_effects()

func update_visual_effects():
	if not sprite:
		return
	
	# Scale the ball based on height (bigger when higher)
	var height_scale = 1.0 + (z / 500.0)  # Scale factor based on height
	
	# Add slight scaling effect when rolling
	if is_rolling:
		height_scale *= 0.9  # Slightly smaller when rolling
	
	sprite.scale = base_scale * height_scale
	
	# Move the ball up based on height
	sprite.position.y = -z  # Negative because we want to move up
	
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
	
	# Update shadow size and opacity based on height
	if shadow:
		var shadow_scale = 1.0 - (z / 800.0)  # Shadow gets smaller when ball is higher
		shadow_scale = clamp(shadow_scale, 0.1, 0.8)  # Reduced max from 1.0 to 0.8 - shadow is smaller at max
		
		# Shadow is more prominent when rolling
		if is_rolling:
			shadow_scale *= 1.1  # Reduced from 1.2 to 1.1 - less dramatic increase when rolling
			shadow_scale = clamp(shadow_scale, 0.1, 1.0)  # Reduced max from 1.5 to 1.0
		
		shadow.scale = base_scale * shadow_scale
		
		# Shadow opacity also changes with height
		var shadow_alpha = 0.3 - (z / 1000.0)  # Less opaque when ball is higher
		shadow_alpha = clamp(shadow_alpha, 0.05, 0.3)  # Keep some visibility
		
		# Shadow is more opaque when rolling
		if is_rolling:
			shadow_alpha = 0.4
		
		shadow.modulate = Color(0, 0, 0, shadow_alpha)

func update_tile_friction() -> void:
	if map_manager == null:
		print("Map manager is null!")
		return
		
	# Calculate which tile the ball is currently on
	var tile_pos = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
	
	# Check if ball is out of bounds
	if tile_pos.x < 0 or tile_pos.y < 0 or tile_pos.x >= map_manager.grid_width or tile_pos.y >= map_manager.grid_height:
		print("Ball is out of bounds at:", tile_pos)
		return
	
	# Get the tile type at this position
	var tile_type = map_manager.get_tile_type(tile_pos.x, tile_pos.y)
	
	# Update friction based on tile type
	if tile_friction_values.has(tile_type):
		current_tile_friction = tile_friction_values[tile_type]
	else:
		current_tile_friction = 0.60  # Default friction
		print("Unknown tile type:", tile_type, "at position:", tile_pos, "using default friction")

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
	
	# Get references to sprite and shadow
	sprite = get_node_or_null("Sprite2D")
	shadow = get_node_or_null("Shadow")
	
	# Debug collision setup
	var area2d = get_node_or_null("Area2D")
	if area2d:
		print("GolfBall _ready - Area2D found, collision_layer:", area2d.collision_layer, "collision_mask:", area2d.collision_mask)
		print("GolfBall Area2D - monitoring:", area2d.monitoring, "monitorable:", area2d.monitorable)
		# Connect to area_entered signal for debugging
		area2d.connect("area_entered", _on_area_entered)
		area2d.connect("area_exited", _on_area_exited)
	else:
		print("GolfBall _ready - ERROR: Area2D not found!")
	
	print("GolfBall _ready called at position:", global_position)
	print("GolfBall is_ghost property:", "is_ghost" in self, "value:", get("is_ghost") if "is_ghost" in self else "N/A")

func update_y_sort() -> void:
	"""Update the ball's z_index based on its position relative to Y-sorted objects"""
	# Get the ball's grid position
	var ball_global_pos = global_position
	var ball_grid_pos = Vector2i(floor(ball_global_pos.x / cell_size), floor(ball_global_pos.y / cell_size))
	
	# Find the ball's sprite to update its z_index
	var ball_sprite = $Sprite2D
	if not ball_sprite:
		return
	
	# Get the course script to access ysort_objects
	var course_script = get_parent().get_parent()  # camera_container -> course_1
	if not course_script or not course_script.has_method("update_ball_y_sort"):
		return
	
	# Call the course script's Y-sort function
	course_script.update_ball_y_sort(self)

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
	print("GolfBall _on_area_entered - Area entered:", area)
	print("Area parent:", area.get_parent())
	print("Area parent name:", area.get_parent().name if area.get_parent() else "No parent")
	print("Ball position:", global_position, "Ball height:", z)
	print("Area position:", area.global_position)
	
	# Check if this is a Pin collision
	if area.get_parent() and area.get_parent().name == "Pin":
		print("*** PIN COLLISION DETECTED! ***")
		print("Ball height at collision:", z)
		if z <= 0.0:
			print("*** BALL SHOULD TRIGGER HOLE COMPLETION! ***")
			# Add a simple debug print to confirm the collision is working
			print("PIN COLLISION: Ball at ground level - hole completion should trigger")

func _on_area_exited(area):
	print("GolfBall _on_area_exited - Area exited:", area)
	print("Area parent:", area.get_parent())
	print("Area parent name:", area.get_parent().name if area.get_parent() else "No parent")

func reset_shot_effects() -> void:
	"""Reset all shot modification effects after the ball has landed"""
	sticky_shot_active = false
	bouncey_shot_active = false
	print("Shot effects reset: sticky_shot_active =", sticky_shot_active, "bouncey_shot_active =", bouncey_shot_active)

func create_landing_highlight(tile_pos: Vector2i) -> void:
	"""Create a bright highlight effect for the final landing tile"""
	print("=== CREATING LANDING HIGHLIGHT DEBUG ===")
	print("Tile position:", tile_pos)
	print("Cell size:", cell_size)
	
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
	print("Course script found:", course_script != null)
	
	if course_script:
		print("Course script children:")
		for child in course_script.get_children():
			print("  -", child.name, "Type:", child.get_class())
	
	# Try to add to CameraContainer first (which contains the GridContainer)
	if course_script and course_script.has_node("CameraContainer"):
		var camera_container = course_script.get_node("CameraContainer")
		print("CameraContainer found:", camera_container != null)
		print("CameraContainer position:", camera_container.position)
		print("CameraContainer size:", camera_container.size)
		
		# Position relative to the camera container (which contains the grid)
		landing_highlight.position = Vector2(tile_pos.x * cell_size, tile_pos.y * cell_size)
		landing_highlight.z_index = -3  # Keep in highlight tiles range
		landing_highlight.color = Color(1.0, 1.0, 0.0, 0.6)  # Bright yellow with 60% opacity
		
		print("Highlight position:", landing_highlight.position)
		print("Highlight size:", landing_highlight.size)
		print("Highlight color:", landing_highlight.color)
		print("Highlight z_index:", landing_highlight.z_index)
		
		# Add a pulsing animation effect
		var tween = create_tween()
		tween.set_loops()  # Loop forever
		tween.tween_property(landing_highlight, "color:a", 0.3, 0.8)  # Fade to 30% opacity
		tween.tween_property(landing_highlight, "color:a", 0.6, 0.8)  # Fade back to 60% opacity
		
		# Add the highlight to the camera container so it moves with the world
		camera_container.add_child(landing_highlight)
		print("Highlight added to CameraContainer")
		print("CameraContainer children count:", camera_container.get_child_count())
		print("Created landing highlight at tile:", tile_pos, "world position:", landing_highlight.position)
	else:
		print("ERROR: Could not find CameraContainer to add landing highlight")
		if course_script:
			print("Available nodes in course script:")
			for child in course_script.get_children():
				print("  -", child.name)
		landing_highlight.queue_free()
		landing_highlight = null
	
	print("=== END LANDING HIGHLIGHT DEBUG ===")

func remove_landing_highlight() -> void:
	"""Remove the landing highlight effect"""
	if landing_highlight and landing_highlight.is_inside_tree():
		landing_highlight.queue_free()
		landing_highlight = null
		print("Removed landing highlight")
