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
var gravity := 1200.0  # Adjusted for pixel perfect system (was 2000.0)
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Knife-specific properties
var is_knife := true
var rotation_speed := 720.0  # Degrees per second rotation
var has_hit_target := false
var target_hit := false
var last_collision_object: Node2D = null  # Track last collision to prevent duplicates

# Dual-sided landing mechanics
var blade_marker: Marker2D
var handle_marker: Marker2D
var is_handle_landing := false  # Track if handle side is facing down
var handle_bounce_count := 0
var max_handle_bounces := 2  # Handle can bounce up to 2 times
var handle_bounce_factor := 0.98  # How much velocity is retained after handle bounce (increased for dramatic bounces)
var min_handle_bounce_speed := 50.0  # Minimum speed for handle to bounce

# Clamp for bounce height
const MAX_BOUNCE_VZ := 600.0

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
const MAX_LAUNCH_HEIGHT := 384.0   # 8 cells (48 * 8) for pixel perfect system - knives fly lower than balls
const MIN_LAUNCH_HEIGHT := 144.0   # 3 cells (48 * 3) for pixel perfect system

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

# Call this to launch the knife
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
	# Calculate initial vertical velocity to achieve the desired maximum height
	# Using physics formula: z_max = vz_initial^2 / (2 * gravity)
	# So: vz_initial = sqrt(2 * gravity * height)
	vz = sqrt(2.0 * gravity * height)  # This will make the knife reach the exact height specified
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
	
	# Setup collision detection
	_setup_collision_detection()
	
	# Set initial rotation direction based on throw direction
	# Positive rotation_speed = clockwise, negative = counter-clockwise
	# When throwing right (positive X), rotate clockwise (positive)
	# When throwing left (negative X), rotate counter-clockwise (negative)
	if direction.x > 0:
		rotation_speed = 720.0  # Clockwise rotation for right throws
	else:
		rotation_speed = -720.0  # Counter-clockwise rotation for left throws
	
	update_visual_effects()
	
	# Store time percentage for sweet spot detection
	self.time_percentage = time_percentage

func _setup_collision_detection() -> void:
	"""Setup collision detection for the knife"""
	var area = $Area2D
	if area:
		# Connect to area signals for collision detection
		if not area.area_entered.is_connected(_on_area_entered):
			area.area_entered.connect(_on_area_entered)
		if not area.area_exited.is_connected(_on_area_exited):
			area.area_exited.connect(_on_area_exited)
		
		# Set collision layer to 1 so objects can detect it
		area.collision_layer = 1
		# Set collision mask to 1 so it can detect objects on layer 1
		area.collision_mask = 1
		
	else:
		print("✗ ERROR: Area2D not found on knife!")

func _disable_collision_detection() -> void:
	"""Disable collision detection when knife has landed"""
	var area = $Area2D
	if area:
		# Disable collision detection completely
		area.monitoring = false
		area.monitorable = false
		area.collision_layer = 0
		area.collision_mask = 0
	else:
		print("✗ ERROR: Area2D not found on knife!")

func _on_area_entered(area: Area2D) -> void:
	"""Handle collisions with objects when knife enters their collision area"""
	if landed_flag:
		return  # Don't handle collisions if knife has already landed
	
	var object = area.get_parent()
	if not object:
		return
	
	print("=== KNIFE COLLISION DETECTED ===")
	print("Knife position:", global_position)
	print("Knife height (z):", z)
	print("Collision object:", object.name if object else "Unknown")
	print("Object has _handle_ball_collision:", object.has_method("_handle_ball_collision") if object else false)
	print("Object has _handle_trunk_collision:", object.has_method("_handle_trunk_collision") if object else false)
	print("Object has take_damage:", object.has_method("take_damage") if object else false)
	print("=== END KNIFE COLLISION DEBUG ===")
	
	# Prevent duplicate collision handling for the same object
	if last_collision_object == object:
		return
	
	# Track this collision to prevent duplicates
	last_collision_object = object
	
	# Check if this is a tree collision
	if object.has_method("_handle_trunk_collision"):
		print("Handling tree collision with roof bounce system")
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is an NPC collision (GangMember)
	if object.has_method("_handle_ball_collision"):
		print("Handling NPC collision with roof bounce system")
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is a Shop collision
	if object.has_method("_handle_shop_collision"):
		print("Handling shop collision with roof bounce system")
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is an Oil Drum collision
	if object.has_method("_handle_collision"):
		print("Handling oil drum collision with roof bounce system")
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is a player collision
	if object.has_method("take_damage") and object.name == "Player":
		print("Handling player collision")
		_handle_player_collision(object)
		return

func _on_area_exited(area: Area2D) -> void:
	"""Handle when knife exits an object's collision area"""
	# Area exit handling if needed
	pass

func _handle_tree_collision(tree: Node2D) -> void:
	"""Handle collision with a tree"""
	# Use standardized height for tree collision detection
	var tree_height = Global.get_object_height_from_marker(tree)
	
	if Global.is_object_above_height(z, tree_height):
		# Knife is above the tree entirely - let it pass through
		return
	else:
		# Knife is within or below tree height - handle collision
		
		# Determine which side is facing the tree
		determine_landing_side()
		
		# Handle collision based on which side hits the tree
		if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
			# Handle side hit tree - bounce off
			_handle_tree_bounce(tree)
		else:
			# Blade side hit tree or handle side exhausted bounces - stick in tree
			_handle_tree_stick(tree)

func _handle_tree_bounce(tree: Node2D) -> void:
	"""Handle bouncing off a tree (handle side collision)"""
	handle_bounce_count += 1
	
	# Calculate bounce velocity (similar to ground bounce but with tree reflection)
	var tree_center = tree.global_position
	var knife_pos = global_position
	
	# Calculate the direction from tree center to knife
	var to_knife_direction = (knife_pos - tree_center).normalized()
	
	# Reflect the velocity across the tree center
	var reflected_velocity = velocity - 2 * velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= handle_bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * handle_bounce_factor * 6.0, 0, MAX_BOUNCE_VZ)  # Dramatic bounce height, clamped
	
	# Reverse rotation direction and reduce speed after bounce
	rotation_speed = -rotation_speed * 0.7
	
	# Play tree thunk sound
	var thunk = tree.get_node_or_null("TrunkThunk")
	if thunk:
		thunk.play()

func _handle_tree_stick(tree: Node2D) -> void:
	"""Handle sticking in a tree (blade side collision)"""
	# Stop the knife
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	rotation_speed = 0.0
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play knife impact sound
	var knife_impact = get_node_or_null("KnifeImpact")
	if knife_impact:
		knife_impact.play()
	
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
	
	# Disable collision detection since knife has landed
	_disable_collision_detection()

func _handle_npc_collision(npc: Node2D) -> void:
	"""Handle collision with an NPC (GangMember)"""
	# Use standardized height for NPC collision detection
	var npc_height = Global.get_object_height_from_marker(npc)
	if npc.has_method("get_height"):
		npc_height = npc.get_height()
	
	# Check if knife is above NPC entirely
	if Global.is_object_above_height(z, npc_height):
		# Knife is above NPC entirely - let it pass through
		return
	else:
		# Knife is within or below NPC height - handle collision
		
		# Determine which side is facing the NPC
		determine_landing_side()
		
		# Handle collision based on which side hits the NPC
		if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
			# Handle side hit NPC - bounce off
			_handle_npc_bounce(npc)
		else:
			# Blade side hit NPC or handle side exhausted bounces - stick in NPC
			_handle_npc_stick(npc)

func _handle_npc_bounce(npc: Node2D) -> void:
	"""Handle bouncing off an NPC (handle side collision)"""
	handle_bounce_count += 1
	
	# Calculate bounce velocity (similar to ground bounce but with NPC reflection)
	var npc_center = npc.global_position
	var knife_pos = global_position
	
	# Calculate the direction from NPC center to knife
	var to_knife_direction = (knife_pos - npc_center).normalized()
	
	# Reflect the velocity across the NPC center
	var reflected_velocity = velocity - 2 * velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= handle_bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * handle_bounce_factor * 6.0, 0, MAX_BOUNCE_VZ)  # Dramatic bounce height, clamped
	
	# Reverse rotation direction and reduce speed after bounce
	rotation_speed = -rotation_speed * 0.7
	
	# Play collision sound
	_play_collision_sound()

func _handle_npc_stick(npc: Node2D) -> void:
	"""Handle sticking in an NPC (blade side collision)"""
	# Stop the knife
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	rotation_speed = 0.0
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play knife impact sound
	var knife_impact = get_node_or_null("KnifeImpact")
	if knife_impact:
		knife_impact.play()
	
	# Deal damage to the NPC
	if npc.has_method("take_damage"):
		# Calculate base damage based on knife velocity
		var base_damage = _calculate_knife_damage(velocity.length())
		
		# Check for headshot if the NPC supports it
		var final_damage = base_damage
		var is_headshot = false
		if npc.has_method("_is_headshot"):
			is_headshot = npc._is_headshot(z)
			if is_headshot:
				# Apply headshot multiplier (assuming 1.5x like GangMember)
				final_damage = int(base_damage * 1.5)
				print("KNIFE HEADSHOT! Height:", z, "Base damage:", base_damage, "Final damage:", final_damage)
			else:
				print("Knife body shot. Height:", z, "Damage:", final_damage)
		
		npc.take_damage(final_damage, is_headshot)
	
	# Attach knife sprite to NPC if it's a GangMember
	if npc.has_method("attach_knife_sprite") and sprite:
		npc.attach_knife_sprite(sprite, global_position, sprite.rotation)
		
		# Hide the original knife sprite since it's now attached to the NPC
		sprite.visible = false
		if shadow:
			shadow.visible = false
	
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

func _handle_player_collision(player: Node2D) -> void:
	"""Handle collision with the player"""
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(self, player):
		# Knife is above player entirely - let it pass through
		return
	else:
		# Knife is within or below player height - handle collision
		
		# Determine which side is facing the player
		determine_landing_side()
		
		# Handle collision based on which side hits the player
		if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
			# Handle side hit player - bounce off
			_handle_player_bounce(player)
		else:
			# Blade side hit player or handle side exhausted bounces - stick in player
			_handle_player_stick(player)

func _handle_player_bounce(player: Node2D) -> void:
	"""Handle bouncing off the player (handle side collision)"""
	handle_bounce_count += 1
	
	# Calculate bounce velocity (similar to ground bounce but with player reflection)
	var player_center = player.global_position
	var knife_pos = global_position
	
	# Calculate the direction from player center to knife
	var to_knife_direction = (knife_pos - player_center).normalized()
	
	# Reflect the velocity across the player center
	var reflected_velocity = velocity - 2 * velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= handle_bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * handle_bounce_factor * 6.0, 0, MAX_BOUNCE_VZ)  # Dramatic bounce height, clamped
	
	# Reverse rotation direction and reduce speed after bounce
	rotation_speed = -rotation_speed * 0.7
	
	# Play collision sound
	_play_collision_sound()

func _handle_player_stick(player: Node2D) -> void:
	"""Handle sticking in the player (blade side collision)"""
	# Stop the knife
	vz = 0.0
	landed_flag = true
	velocity = Vector2.ZERO
	rotation_speed = 0.0
	
	# Keep the final rotation for visual effect
	# Don't reset rotation to 0 - let it stay at the final landing rotation
	
	# Play knife impact sound
	var knife_impact = get_node_or_null("KnifeImpact")
	if knife_impact:
		knife_impact.play()
	
	# Deal damage to the player
	if player.has_method("take_damage"):
		# Calculate base damage based on knife velocity
		var base_damage = _calculate_knife_damage(velocity.length())
		
		# Check for headshot if the player supports it
		var final_damage = base_damage
		var is_headshot = false
		if player.has_method("_is_headshot"):
			is_headshot = player._is_headshot(z)
			if is_headshot:
				# Apply headshot multiplier (assuming 1.5x like GangMember)
				final_damage = int(base_damage * 1.5)
				print("KNIFE HEADSHOT ON PLAYER! Height:", z, "Base damage:", base_damage, "Final damage:", final_damage)
			else:
				print("Knife body shot on player. Height:", z, "Damage:", final_damage)
		
		player.take_damage(final_damage, is_headshot)
	
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
	
	# Disable collision detection since knife has landed
	_disable_collision_detection()

func _calculate_knife_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on knife velocity magnitude"""
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

func _play_collision_sound() -> void:
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

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			return current_node
		current_node = current_node.get_parent()
	return null

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
	
	# OPTIMIZED: Knife handles its own object collision detection during flight
	# Only check for object collisions when knife is in the air (during flight)
	# DISABLED: Proximity collision detection to debug Area2D collision issues
	# if z > 0.0:
	# 	check_nearby_object_collisions()
	
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
		
		# Check for landing (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Determine which side is facing down
			determine_landing_side()
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed - bounce like a golf ball
				handle_bounce_count += 1
				vz = clamp(velocity.length() * handle_bounce_factor * 6.0, 0, MAX_BOUNCE_VZ)  # Dramatic bounce height, clamped
				velocity *= handle_bounce_factor
				
				# Reduce rotation speed after bounce (keep same direction)
				rotation_speed *= 0.7
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play knife impact sound for blade landing
				var knife_impact = get_node_or_null("KnifeImpact")
				if knife_impact:
					knife_impact.play()
				
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
				
				# Disable collision detection since knife has landed
				_disable_collision_detection()
	
	elif vz > 0.0:
		# Knife is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Rotate the knife while in flight
		if sprite:
			sprite.rotation_degrees += rotation_speed * delta
		
		# Check if knife has landed again (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Determine which side is facing down
			determine_landing_side()
			
			# Handle bounce or landing based on which side is down
			if is_handle_landing and handle_bounce_count < max_handle_bounces and velocity.length() > min_handle_bounce_speed:
				# Handle side landed - bounce like a golf ball
				handle_bounce_count += 1
				vz = clamp(velocity.length() * handle_bounce_factor * 6.0, 0, MAX_BOUNCE_VZ)  # Dramatic bounce height, clamped
				velocity *= handle_bounce_factor
				
				# Reduce rotation speed after bounce (keep same direction)
				rotation_speed *= 0.7
				
				# Play golf ball bounce sound for handle landing
				var ball_land_sound = get_node_or_null("BallLand")
				if ball_land_sound:
					ball_land_sound.play()
			else:
				# Blade side landed or handle side exhausted bounces - stick in ground
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				# Keep the final rotation for visual effect
				# Don't reset rotation to 0 - let it stay at the final landing rotation
				
				# Play knife impact sound for blade landing
				var knife_impact = get_node_or_null("KnifeImpact")
				if knife_impact:
					knife_impact.play()
				
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
				
				# Disable collision detection since knife has landed
				_disable_collision_detection()
	
	# Update visual effects
	update_visual_effects()
	
	# Update Y-sorting after visual effects to ensure z_index is maintained
	update_y_sort()

func check_nearby_object_collisions() -> void:
	"""OPTIMIZED: Knife checks for nearby object collisions during flight"""
	# This is a backup collision detection system for objects that might be missed by Area2D
	# due to fast movement or timing issues
	
	# Skip proximity checks if we've already handled a collision this frame
	if last_collision_object != null:
		return
	
	# Check for nearby trees
	var trees = get_tree().get_nodes_in_group("trees")
	if not trees.is_empty():
		_check_nearby_tree_collisions(trees)
	
	# Check for nearby NPCs
	var entities = _find_course_script()
	if entities and entities.has_node("Entities"):
		var entities_manager = entities.get_node("Entities")
		if entities_manager and entities_manager.has_method("get_npcs"):
			var npcs = entities_manager.get_npcs()
			_check_nearby_npc_collisions(npcs)

func _check_nearby_tree_collisions(trees: Array) -> void:
	"""Check for collisions with nearby trees"""
	var knife_ground_pos = global_position
	
	for tree in trees:
		if not is_instance_valid(tree):
			continue
		
		var distance_to_tree = knife_ground_pos.distance_to(tree.global_position)
		if distance_to_tree <= 150.0:  # Only check trees within 150 pixels
			# Use standardized height for tree collision detection
			var tree_height = Global.get_object_height_from_marker(tree)
			
			# Only check for collision if knife is within tree height
			# If knife is above tree height, let it pass through
			if not Global.is_object_above_height(z, tree_height):
				# Knife is within tree height - check for collision
				var trunk_radius = 120.0
				if distance_to_tree <= trunk_radius:
					# Knife is within trunk radius - handle collision
					_handle_tree_collision(tree)
					return

func _check_nearby_npc_collisions(npcs: Array) -> void:
	"""Check for collisions with nearby NPCs"""
	var knife_ground_pos = global_position
	
	for npc in npcs:
		if not is_instance_valid(npc):
			continue
		
		var distance_to_npc = knife_ground_pos.distance_to(npc.global_position)
		if distance_to_npc <= 100.0:  # Only check NPCs within 100 pixels
			# Use standardized height for NPC collision detection
			var npc_height = Global.get_object_height_from_marker(npc)
			if npc.has_method("get_height"):
				npc_height = npc.get_height()
			
			# Only check for collision if knife is within NPC height
			# If knife is above NPC height, let it pass through
			if not Global.is_object_above_height(z, npc_height):
				# Knife is within NPC height - check for collision
				var npc_collision_radius = 50.0  # NPC collision radius
				if distance_to_npc <= npc_collision_radius:
					# Knife is within NPC collision radius - handle collision
					_handle_npc_collision(npc)
					return

func determine_landing_side():
	"""Determine which side of the knife is facing down when landing"""
	if not sprite or not blade_marker or not handle_marker:
		is_handle_landing = false
		return
	
	# Get the global positions of the blade and handle markers
	var blade_global_pos = blade_marker.global_position
	var handle_global_pos = handle_marker.global_position
	
	# Compare Y positions - the higher Y value is facing down toward the ground
	# Since the knife is rotating, we need to check which marker has the higher Y position
	if handle_global_pos.y > blade_global_pos.y:
		# Handle has higher Y - handle side is facing down
		is_handle_landing = true
	else:
		# Blade has higher Y - blade side is facing down
		is_handle_landing = false

func update_visual_effects():
	if not sprite or not shadow:
		return
	
	# Use standardized height visual effects
	Global.apply_standard_height_visual_effects(sprite, shadow, z, base_scale)

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

func set_velocity(new_velocity: Vector2) -> void:
	"""Set the velocity of the knife for collision handling"""
	velocity = new_velocity

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
	
	# Update power constants based on character-specific club data
	MAX_LAUNCH_POWER = info.get("max_distance", 300.0)
	MIN_LAUNCH_POWER = info.get("min_distance", 200.0)
	
	print("=== THROWING KNIFE CLUB INFO SET ===")
	print("Max distance:", MAX_LAUNCH_POWER)
	print("Min distance:", MIN_LAUNCH_POWER)
	print("Club info:", info)
	print("=== END THROWING KNIFE CLUB INFO ===")

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

# Simple collision system methods
func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < object height, reflect.
	If projectile height > object height, set ground to object height.
	"""
	print("=== SIMPLE COLLISION HANDLER (KNIFE) ===")
	print("Object:", object.name)
	print("Knife height:", z)
	
	var object_height = Global.get_object_height_from_marker(object)
	print("Object height:", object_height)
	
	# Check if knife is above the object
	if z > object_height:
		print("✓ Knife is above object - setting ground level")
		current_ground_level = object_height
	else:
		print("✗ Knife is below object height - reflecting")
		_reflect_off_object(object)

func _reflect_off_object(object: Node2D) -> void:
	"""
	Simple reflection off an object when knife is below object height.
	"""
	print("=== REFLECTING OFF OBJECT (KNIFE) ===")
	
	# Get the knife's current velocity
	var knife_velocity = velocity
	
	print("Reflecting knife with velocity:", knife_velocity)
	
	# Play collision sound if available
	if object.has_method("_play_trunk_thunk_sound"):
		object._play_trunk_thunk_sound()
	elif object.has_method("_play_oil_drum_sound"):
		object._play_oil_drum_sound()
	
	var knife_pos = global_position
	var object_center = object.global_position
	
	# Calculate the direction from object center to knife
	var to_knife_direction = (knife_pos - object_center).normalized()
	
	# Simple reflection: reflect the velocity across the object center
	var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected knife velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the knife
	velocity = reflected_velocity

func _set_ground_level(height: float) -> void:
	"""
	Set the ground level to a specific height (used by Area2D collision system).
	"""
	print("=== SETTING GROUND LEVEL (KNIFE) ===")
	print("Setting ground level to:", height)
	current_ground_level = height
	print("Ground level set to:", current_ground_level)

func _reset_ground_level() -> void:
	"""
	Reset the ground level to normal (0.0) when exiting Area2D collision.
	"""
	print("=== RESETTING GROUND LEVEL (KNIFE) ===")
	print("Resetting ground level from:", current_ground_level, "to 0.0")
	current_ground_level = 0.0
	print("Ground level reset to:", current_ground_level) 
