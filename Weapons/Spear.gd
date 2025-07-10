extends Node2D

signal spear_landed(final_position: Vector2)
signal spear_hit_target(target: Node2D)
signal landed(final_tile: Vector2i)  # Add landed signal for compatibility with course

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle

# Audio
var spear_impact_sound: AudioStreamPlayer2D
var spear_whoosh_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 1200.0  # Adjusted for pixel perfect system
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Spear-specific properties
var is_spear := true
var has_hit_target := false
var target_hit := false
var last_collision_object: Node2D = null  # Track last collision to prevent duplicates

# Spear orientation system
var blade_marker: Marker2D
var handle_marker: Marker2D
var is_handle_landing := false  # Track if handle side is facing down
var handle_bounce_count := 0
var max_handle_bounces := 1  # Spear handle can bounce once
var handle_bounce_factor := 0.6  # How much velocity is retained after handle bounce
var min_handle_bounce_speed := 50.0  # Minimum speed for handle to bounce

# Clamp for bounce height
const MAX_BOUNCE_VZ := 400.0

# Bounce mechanics (spears stick like sticky shots - no bounces)
var bounce_count := 0
var max_bounces := 0  # Spears don't bounce - they stick
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
const MAX_LAUNCH_HEIGHT := 384.0   # 8 cells (48 * 8) for pixel perfect system
const MIN_LAUNCH_HEIGHT := 0.0   # Allow for ground-level throws

# Power constants (will be overridden by club_info from character stats)
var MAX_LAUNCH_POWER := 300.0  # Default max distance (will be set by club_info)
var MIN_LAUNCH_POWER := 200.0   # Default min distance (will be set by club_info)

# Progressive height resistance variables
var initial_height_percentage := 0.0
var height_resistance_factor := 1.0
var is_applying_height_resistance := false

# Launch parameters
var time_percentage: float = -1.0  # -1 means not set, use power percentage instead
var club_info: Dictionary = {}  # Will be set by the course script
var is_penalty_shot: bool = false  # True if red circle is below min distance

# Simple collision system variables
var current_ground_level: float = 0.0  # Current ground level (can be elevated by roofs)

# Spear-specific orientation tracking
var launch_direction: Vector2 = Vector2.ZERO
var initial_rotation: float = 0.0

# Call this to launch the spear
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Reset state for new throw
	has_hit_target = false
	target_hit = false
	landed_flag = false
	bounce_count = 0
	handle_bounce_count = 0
	is_handle_landing = false
	last_collision_object = null  # Reset collision tracking
	
	# Reset simple collision system for new throw
	current_ground_level = 0.0
	
	# Store launch direction for orientation calculations
	launch_direction = direction.normalized()
	
	# Calculate height percentage for sweet spot check
	var height_percentage = height / MAX_LAUNCH_HEIGHT  # Simplified calculation for 0.0 to MAX_LAUNCH_HEIGHT range
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	initial_height_percentage = height_percentage
	
	# Initialize height resistance
	height_resistance_factor = 1.0
	is_applying_height_resistance = height_percentage > HEIGHT_SWEET_SPOT_MAX
	
	if chosen_landing_spot != Vector2.ZERO:
		# Calculate the distance to the landing spot
		var spear_global_pos = global_position
		var distance_to_target = spear_global_pos.distance_to(chosen_landing_spot)
		
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
		
		# Use the direction passed in from LaunchManager (which is calculated from spear position to target)
		# The LaunchManager already calculates the correct direction, so we don't need to override it
		
		# Determine if this is a penalty throw (red circle below min distance)
		var min_distance = club_info.get("min_distance", 200.0)
		is_penalty_shot = distance_to_target < min_distance
		
		# Update the power variable to use the calculated value for physics
		power = final_power

	# Apply the resistance to the final velocity calculation
	velocity = direction.normalized() * power
	
	z = 0.0
	# Calculate velocity based on direction to target (like golf ball)
	velocity = direction.normalized() * power
	
	# Calculate initial vertical velocity to achieve the desired maximum height
	# Using physics formula: z_max = vz_initial^2 / (2 * gravity)
	# So: vz_initial = sqrt(2 * gravity * height)
	vz = sqrt(2.0 * gravity * height)  # This will make the spear reach the exact height specified
	landed_flag = false
	max_height = 0.0
	
	# Immediately launch the spear into the air by applying the first vertical update
	z += vz * 0.016  # Apply one frame of vertical movement (assuming 60 FPS)
	vz -= gravity * 0.016  # Apply one frame of gravity
	
	# Get references to sprite and shadow
	sprite = $SpearSprite
	shadow = $Shadow
	
	# Get references to blade and handle markers
	blade_marker = $SpearSprite/Blade
	handle_marker = $SpearSprite/Handle
	
	# Set base scale from sprite's current scale
	if sprite:
		base_scale = sprite.scale
	
	# Set initial shadow position (same as spear but on ground)
	if shadow:
		shadow.position = Vector2.ZERO
		shadow.z_index = -1
		shadow.modulate = Color(0, 0, 0, 0.3)  # Semi-transparent black
	
	# Setup collision detection
	_setup_collision_detection()
	
	# Set initial rotation based on vertical velocity (not direction)
	update_spear_rotation()
	
	update_visual_effects()
	
	# Store time percentage for sweet spot detection
	self.time_percentage = time_percentage

func _setup_collision_detection():
	"""Set up collision detection for the spear"""
	# Connect area signals for collision detection
	var area = $Shadow/Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)

func _disable_collision_detection():
	"""Disable collision detection after landing"""
	var area = $Shadow/Area2D
	if area:
		area.monitoring = false
		area.monitorable = false

func _on_body_entered(body: Node2D):
	"""Handle collision with bodies (NPCs, players, etc.)"""
	if landed_flag or not is_instance_valid(body):
		return
	
	# Check if we've already hit this object
	if body == last_collision_object:
		return
	last_collision_object = body
	
	# Check if it's an NPC
	if body.is_in_group("npcs") or body.has_method("take_damage"):
		_handle_npc_stick(body)
		return
	
	# Check if it's the player
	if body.is_in_group("players") or body.has_method("take_damage"):
		_handle_player_collision(body)
		return
	
	# Check if it's an obstacle
	if body.is_in_group("obstacles") or body.has_method("_play_trunk_thunk_sound") or body.has_method("_play_oil_drum_sound"):
		_handle_obstacle_collision(body)
		return

func _on_area_entered(area: Area2D):
	"""Handle collision with areas"""
	if landed_flag or not is_instance_valid(area):
		return
	
	# Check if we've already hit this object
	if area == last_collision_object:
		return
	last_collision_object = area
	
	# Check if it's an obstacle area
	var parent = area.get_parent()
	if parent and (parent.is_in_group("obstacles") or parent.has_method("_play_trunk_thunk_sound") or parent.has_method("_play_oil_drum_sound")):
		_handle_obstacle_collision(parent)
		return

func _handle_obstacle_collision(obstacle: Node2D):
	"""Handle collision with obstacles"""
	# Use enhanced height collision detection
	if Global.is_object_above_obstacle(self, obstacle):
		# Spear is above obstacle entirely - let it pass through
		return
	else:
		# Spear is within or below obstacle height - handle collision
		
		# Determine which side is facing the obstacle
		determine_landing_side()
		
		# Handle collision based on which side hits the obstacle
		if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
			# Handle side hit obstacle - bounce off
			_handle_obstacle_bounce(obstacle)
		else:
			# Blade side hit obstacle or handle side exhausted bounces - stick in obstacle
			_handle_obstacle_stick(obstacle)

func _handle_obstacle_bounce(obstacle: Node2D):
	"""Handle bouncing off an obstacle (handle side collision)"""
	handle_bounce_count += 1
	
	# Calculate bounce velocity (similar to ground bounce but with obstacle reflection)
	var obstacle_center = obstacle.global_position
	var spear_pos = global_position
	
	# Calculate the direction from obstacle center to spear
	var to_spear_direction = (spear_pos - obstacle_center).normalized()
	
	# Reflect the velocity across the obstacle center
	var reflected_velocity = velocity - 2 * velocity.dot(to_spear_direction) * to_spear_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= handle_bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * handle_bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
	
	# Play collision sound
	_play_collision_sound()

func _handle_obstacle_stick(obstacle: Node2D):
	"""Handle sticking in an obstacle (blade side collision)"""
	# Stop the spear
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play spear impact sound
	var spear_impact = get_node_or_null("KnifeImpact")
	if spear_impact:
		spear_impact.play()
	
	# Emit landed signals
	emit_signal("spear_landed", global_position)
	
	# Emit landed signal for course compatibility (convert position to tile)
	if map_manager and map_manager.has_method("world_to_map"):
		var final_tile = map_manager.world_to_map(global_position)
		emit_signal("landed", final_tile)
	else:
		# Fallback if no map manager or no world_to_map method
		emit_signal("landed", Vector2i.ZERO)
	
	# Check for target hits
	check_target_hits()

func _handle_npc_stick(npc: Node2D):
	"""Handle sticking in an NPC (blade side collision)"""
	# Stop the spear
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play spear impact sound
	var spear_impact = get_node_or_null("KnifeImpact")
	if spear_impact:
		spear_impact.play()
	
	# Deal damage to the NPC
	if npc.has_method("take_damage"):
		# Calculate base damage based on spear velocity
		var base_damage = _calculate_spear_damage(velocity.length())
		
		# Check for headshot if the NPC supports it
		var final_damage = base_damage
		var is_headshot = false
		if npc.has_method("_is_headshot"):
			is_headshot = npc._is_headshot(z)
			if is_headshot:
				# Apply headshot multiplier (assuming 1.5x like GangMember)
				final_damage = int(base_damage * 1.5)
		
		npc.take_damage(final_damage, is_headshot)
	
	# Attach spear sprite to NPC if it's a GangMember
	if npc.has_method("attach_knife_sprite") and sprite:
		npc.attach_knife_sprite(sprite, global_position, sprite.rotation)
		
		# Hide the original spear sprite since it's now attached to the NPC
		sprite.visible = false
		if shadow:
			shadow.visible = false
	
	# Emit landed signals
	emit_signal("spear_landed", global_position)
	
	# Emit landed signal for course compatibility (convert position to tile)
	if map_manager and map_manager.has_method("world_to_map"):
		var final_tile = map_manager.world_to_map(global_position)
		emit_signal("landed", final_tile)
	else:
		# Fallback if no map manager or no world_to_map method
		emit_signal("landed", Vector2i.ZERO)
	
	# Check for target hits
	check_target_hits()

func _handle_player_collision(player: Node2D):
	"""Handle collision with the player"""
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(self, player):
		# Spear is above player entirely - let it pass through
		return
	else:
		# Spear is within or below player height - handle collision
		
		# Determine which side is facing the player
		determine_landing_side()
		
		# Handle collision based on which side hits the player
		if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
			# Handle side hit player - bounce off
			_handle_player_bounce(player)
		else:
			# Blade side hit player or handle side exhausted bounces - stick in player
			_handle_player_stick(player)

func _handle_player_bounce(player: Node2D):
	"""Handle bouncing off the player (handle side collision)"""
	handle_bounce_count += 1
	
	# Calculate bounce velocity (similar to ground bounce but with player reflection)
	var player_center = player.global_position
	var spear_pos = global_position
	
	# Calculate the direction from player center to spear
	var to_spear_direction = (spear_pos - player_center).normalized()
	
	# Reflect the velocity across the player center
	var reflected_velocity = velocity - 2 * velocity.dot(to_spear_direction) * to_spear_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= handle_bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * handle_bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
	
	# Play collision sound
	_play_collision_sound()

func _handle_player_stick(player: Node2D):
	"""Handle sticking in the player (blade side collision)"""
	# Stop the spear
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play spear impact sound
	var spear_impact = get_node_or_null("KnifeImpact")
	if spear_impact:
		spear_impact.play()
	
	# Deal damage to the player
	if player.has_method("take_damage"):
		# Calculate base damage based on spear velocity
		var base_damage = _calculate_spear_damage(velocity.length())
		
		# Check for headshot if the player supports it
		var final_damage = base_damage
		var is_headshot = false
		if player.has_method("_is_headshot"):
			is_headshot = player._is_headshot(z)
			if is_headshot:
				# Apply headshot multiplier (assuming 1.5x like GangMember)
				final_damage = int(base_damage * 1.5)
		
		player.take_damage(final_damage, is_headshot)
	
	# Emit landed signals
	emit_signal("spear_landed", global_position)
	
	# Emit landed signal for course compatibility (convert position to tile)
	if map_manager and map_manager.has_method("world_to_map"):
		var final_tile = map_manager.world_to_map(global_position)
		emit_signal("landed", final_tile)
	else:
		# Fallback if no map manager or no world_to_map method
		emit_signal("landed", Vector2i.ZERO)
	
	# Check for target hits
	check_target_hits()
	
	# Disable collision detection since spear has landed
	_disable_collision_detection()

func _calculate_spear_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on spear velocity magnitude"""
	# Define velocity ranges for damage scaling (similar to ball damage)
	const MIN_VELOCITY = 25.0  # Minimum velocity for 1 damage
	const MAX_VELOCITY = 1200.0  # Maximum velocity for 88 damage
	
	# Clamp velocity to our defined range
	var clamped_velocity = clamp(velocity_magnitude, MIN_VELOCITY, MAX_VELOCITY)
	
	# Calculate damage percentage (0.0 to 1.0)
	var damage_percentage = (clamped_velocity - MIN_VELOCITY) / (MAX_VELOCITY - MIN_VELOCITY)
	
	# Scale damage from 1 to 88
	var damage = 1 + (damage_percentage * 87)
	
	# Return as integer
	var final_damage = int(damage)
	
	return final_damage

func _play_collision_sound():
	"""Play a collision sound effect"""
	# Try to find an audio player in the course
	var course = _find_course_script()
	if course:
		var audio_players = course.get_tree().get_nodes_in_group("audio_players")
		if audio_players.size() > 0:
			var audio_player = audio_players[0]
			if audio_player.has_method("play"):
				audio_player.play()
				return
		
		# Try to find Push sound specifically
		var push_sound = course.get_node_or_null("Push")
		if push_sound and push_sound is AudioStreamPlayer2D:
			push_sound.play()
			return
	
	# Fallback: create a temporary audio player
	var temp_audio = AudioStreamPlayer2D.new()
	var sound_file = load("res://Sounds/Push.mp3")
	if sound_file:
		temp_audio.stream = sound_file
		temp_audio.volume_db = -10.0  # Slightly quieter
		add_child(temp_audio)
		temp_audio.play()
		# Remove the audio player after it finishes
		temp_audio.finished.connect(func(): temp_audio.queue_free())

func _find_course_script():
	"""Find the course script in the scene tree"""
	var current = get_parent()
	while current:
		if current.has_method("_on_ball_launched"):
			return current
		current = current.get_parent()
	return null

func determine_landing_side():
	"""Determine which side of the spear is facing down"""
	if not sprite:
		return
	
	# Get the current rotation of the spear
	var current_rotation = sprite.rotation
	
	# Normalize the rotation to 0-2PI range
	while current_rotation < 0:
		current_rotation += 2 * PI
	while current_rotation >= 2 * PI:
		current_rotation -= 2 * PI
	
	# The spear sprite is set up with the blade pointing down (rotation = PI)
	# We need to determine which side is facing down based on the current rotation
	# If the rotation is closer to PI (blade down), then blade is landing
	# If the rotation is closer to 0 or 2PI (handle down), then handle is landing
	
	var blade_down_rotation = PI
	var handle_down_rotation = 0.0
	
	var distance_to_blade_down = abs(current_rotation - blade_down_rotation)
	var distance_to_handle_down = min(abs(current_rotation - handle_down_rotation), abs(current_rotation - 2 * PI))
	
	is_handle_landing = distance_to_handle_down < distance_to_blade_down

func update_visual_effects():
	"""Update visual effects based on height and velocity"""
	if not sprite or not shadow:
		return
	
	# Update shadow position and scale based on height
	if shadow:
		# Shadow moves down as spear goes up
		shadow.position.y = -z * 0.5  # Shadow moves down at half the height
		
		# Shadow gets smaller and more transparent as spear goes higher
		var height_scale = 1.0 - (z / MAX_LAUNCH_HEIGHT) * 0.5  # Scale from 1.0 to 0.5
		height_scale = clamp(height_scale, 0.5, 1.0)
		shadow.scale = base_scale * height_scale
		
		var alpha = 0.3 - (z / MAX_LAUNCH_HEIGHT) * 0.2  # Alpha from 0.3 to 0.1
		alpha = clamp(alpha, 0.1, 0.3)
		shadow.modulate = Color(0, 0, 0, alpha)
	
	# Update sprite position based on height
	if sprite:
		sprite.position.y = -z  # Move sprite up as z increases
		
		# Update spear rotation based on vertical velocity
		update_spear_rotation()

func update_spear_rotation():
	"""Update spear rotation based on vertical velocity"""
	if not sprite:
		return
	
	# Calculate rotation based on vertical velocity
	# vz = 0 -> 90° (pointing up)
	# vz > 0 (upward) -> 0° (pointing right)
	# vz < 0 (downward) -> 180° (pointing left)
	
	# Normalize vertical velocity to rotation range
	var max_vz = sqrt(2.0 * gravity * MAX_LAUNCH_HEIGHT)  # Maximum possible upward velocity
	var normalized_vz = clamp(vz / max_vz, -1.0, 1.0)  # Clamp to -1 to 1 range
	
	# Convert to rotation (0° to 180°)
	# normalized_vz = 1 (max up) -> 0°
	# normalized_vz = 0 (no vertical) -> 90°
	# normalized_vz = -1 (max down) -> 180°
	var rotation_degrees = 90.0 - (normalized_vz * 90.0)
	var rotation_radians = deg_to_rad(rotation_degrees)
	
	# Apply the rotation
	sprite.rotation = rotation_radians
	initial_rotation = sprite.rotation

func _physics_process(delta: float):
	"""Main physics update for the spear"""
	if landed_flag:
		return
	
	# Update horizontal position
	position += velocity * delta
	print("Spear physics - position: ", position, " velocity: ", velocity, " z: ", z, " vz: ", vz)
	
	# Update Y-sort for proper layering
	update_y_sort()
	
	# Handle vertical movement and gravity
	if z > 0.0:
		# Spear is in the air
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Check for landing (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Determine which side is facing down
			determine_landing_side()
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed - bounce like a golf ball
				handle_bounce_count += 1
				vz = clamp(velocity.length() * handle_bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
				velocity *= handle_bounce_factor
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play appropriate sound based on which side landed
				if is_handle_landing:
					# Handle side landed - play handle land sound
					var handle_land = get_node_or_null("HandleLand")
					if handle_land:
						handle_land.play()
				else:
					# Blade side landed - play spear impact sound
					var spear_impact = get_node_or_null("KnifeImpact")
					if spear_impact:
						spear_impact.play()
				
				# Emit landed signals
				emit_signal("spear_landed", global_position)
				print("Spear landing - map_manager: ", map_manager, " global_position: ", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(position)
					print("Spear landed at tile: ", final_tile)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					print("Spear using fallback - no map_manager")
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
				
				# Disable collision detection since spear has landed
				_disable_collision_detection()
	
	elif vz > 0.0:
		# Spear is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Check if spear has landed again (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Determine which side is facing down
			determine_landing_side()
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed again - bounce
				handle_bounce_count += 1
				vz = clamp(velocity.length() * handle_bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
				velocity *= handle_bounce_factor
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play appropriate sound based on which side landed
				if is_handle_landing:
					# Handle side landed - play handle land sound
					var handle_land = get_node_or_null("HandleLand")
					if handle_land:
						handle_land.play()
				else:
					# Blade side landed - play spear impact sound
					var spear_impact = get_node_or_null("KnifeImpact")
					if spear_impact:
						spear_impact.play()
				
				# Emit landed signals
				emit_signal("spear_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
				
				# Disable collision detection since spear has landed
				_disable_collision_detection()
	
	# Update visual effects and rotation
	update_visual_effects()
	update_spear_rotation()

func update_y_sort():
	"""Update the spear's z_index using the same global Y-sort system as the golf ball"""
	# Use the global Y-sort system like the golf ball
	Global.update_ball_y_sort(self)

func check_target_hits():
	# Check if spear hit any targets (enemies, etc.)
	var area = $Shadow/Area2D
	if area:
		var overlapping_bodies = area.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.has_method("take_damage") or body.has_method("hit"):
				# Spear hit a target
				if not has_hit_target:
					has_hit_target = true
					target_hit = true
					emit_signal("spear_hit_target", body)
					
					# Play impact sound
					var spear_impact = get_node_or_null("KnifeImpact")
					if spear_impact:
						spear_impact.play()
						
func is_in_flight() -> bool:
	"""Check if the spear is currently in flight"""
	return not landed_flag and (z > 0.0 or velocity.length() > 0.1)

func get_velocity() -> Vector2:
	"""Get the current velocity of the spear"""
	return velocity

func set_velocity(new_velocity: Vector2) -> void:
	"""Set the velocity of the spear for collision handling"""
	velocity = new_velocity

func get_ground_position() -> Vector2:
	"""Return the spear's position on the ground (ignoring height) for Y-sorting"""
	# The spear's position is already the ground position
	# The height (z) is only used for visual effects (sprite.position.y = -z)
	return global_position

func get_height() -> float:
	"""Return the spear's current height for Y-sorting and collision handling"""
	return z

# Method to set club info (called by LaunchManager)
func set_club_info(info: Dictionary):
	club_info = info
	
	# Update power constants based on character-specific club data
	MAX_LAUNCH_POWER = info.get("max_distance", 300.0)
	MIN_LAUNCH_POWER = info.get("min_distance", 200.0)

# Method to set time percentage (called by LaunchManager)
func set_time_percentage(percentage: float):
	time_percentage = percentage

# Method to get final power (called by course)
func get_final_power() -> float:
	"""Get the final power used for this throw"""
	return velocity.length() if velocity.length() > 0 else 0.0

# Method to check if this is a spear (called by course)
func is_spear_weapon() -> bool:
	"""Check if this is a spear weapon"""
	return true

# Simple collision system methods
func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < object height, reflect.
	If projectile height > object height, set ground to object height.
	"""
	var object_height = Global.get_object_height_from_marker(object)
	
	# Check if spear is above the object
	if z > object_height:
		current_ground_level = object_height
	else:
		_reflect_off_object(object)

func _reflect_off_object(object: Node2D) -> void:
	"""
	Simple reflection off an object when spear is below object height.
	"""
	# Get the spear's current velocity
	var spear_velocity = velocity
	
	# Play collision sound if available
	if object.has_method("_play_trunk_thunk_sound"):
		object._play_trunk_thunk_sound()
	elif object.has_method("_play_oil_drum_sound"):
		object._play_oil_drum_sound()
	
	var spear_pos = global_position
	var object_center = object.global_position
	
	# Calculate the direction from object center to spear
	var to_spear_direction = (spear_pos - object_center).normalized()
	
	# Simple reflection: reflect the velocity across the object center
	var reflected_velocity = spear_velocity - 2 * spear_velocity.dot(to_spear_direction) * to_spear_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the spear
	velocity = reflected_velocity 
