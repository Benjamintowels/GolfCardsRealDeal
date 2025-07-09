extends Node2D

signal grenade_landed(final_position: Vector2)
signal grenade_exploded(explosion_position: Vector2)
signal landed(final_tile: Vector2i)  # Add landed signal for compatibility with course
signal out_of_bounds()  # Signal for out of bounds
signal sand_landing()  # Signal for sand landing

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle

# Audio
var grenade_impact_sound: AudioStreamPlayer2D
var grenade_whoosh_sound: AudioStreamPlayer2D
var explosion_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 1200.0  # Adjusted for pixel perfect system
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false
var exploded_flag := false

# Grenade-specific properties
var is_grenade := true
var rotation_speed := 360.0  # Degrees per second rotation (slower than knife)
var has_hit_target := false
var target_hit := false
var last_collision_object: Node2D = null  # Track last collision to prevent duplicates

# Bounce mechanics (grenades bounce multiple times before stopping)
var bounce_count := 0
var max_bounces := 3  # Grenades can bounce up to 3 times
var bounce_factor := 0.6  # How much velocity is retained after bounce
var min_bounce_speed := 30.0  # Minimum speed for grenade to bounce

# Clamp for bounce height
const MAX_BOUNCE_VZ := 400.0

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
var MAX_LAUNCH_POWER := 400.0  # Default max distance (will be set by club_info)
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

# Explosion properties
var explosion_radius := 150.0  # Radius of explosion damage
var explosion_damage := 300  # Damage dealt by explosion

# Tile handling properties
var water_plunk_sound: AudioStreamPlayer2D

func _ready():
	"""Initialize the grenade when it's added to the scene"""
	add_to_group("grenades")
	add_to_group("collision_objects")
	
	# Get audio references
	water_plunk_sound = get_node_or_null("WaterPlunk")

# Call this to launch the grenade
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Reset state for new throw
	has_hit_target = false
	target_hit = false
	landed_flag = false
	exploded_flag = false
	bounce_count = 0
	last_collision_object = null  # Reset collision tracking
	
	# Reset simple collision system for new throw
	current_ground_level = 0.0
	
	# Calculate height percentage for sweet spot check
	var height_percentage = height / MAX_LAUNCH_HEIGHT  # Simplified calculation for 0.0 to MAX_LAUNCH_HEIGHT range
	height_percentage = clamp(height_percentage, 0.0, 1.0)
	initial_height_percentage = height_percentage
	
	# Initialize height resistance
	height_resistance_factor = 1.0
	is_applying_height_resistance = height_percentage > HEIGHT_SWEET_SPOT_MAX
	
	# Set initial velocity based on direction and power
	velocity = direction * power
	
	# Calculate initial vertical velocity for the specified height
	# Using physics formula: z_max = vz_initial^2 / (2 * gravity)
	# So: vz_initial = sqrt(2 * gravity * height)
	vz = sqrt(2.0 * gravity * height)  # This will make the grenade reach the exact height specified
	landed_flag = false
	max_height = 0.0
	
	# Immediately launch the grenade into the air by applying the first vertical update
	z += vz * 0.016  # Apply one frame of vertical movement (assuming 60 FPS)
	vz -= gravity * 0.016  # Apply one frame of gravity
	
	# Get references to sprite and shadow
	sprite = $GrenadeSprite
	shadow = $Shadow
	
	# Get reference to YSortPoint for proper Y-sorting
	var ysort_point = $YSortPoint
	
	# Set base scale from sprite's current scale
	if sprite:
		base_scale = sprite.scale
	
	# Set initial shadow position (same as grenade but on ground)
	if shadow:
		shadow.position = Vector2.ZERO
		shadow.z_index = -1
		# Shadow modulate is already set in the scene
	
	# Setup collision detection
	_setup_collision_detection()
	
	# Set initial rotation direction based on throw direction
	# Positive rotation_speed = clockwise, negative = counter-clockwise
	# When throwing right (positive X), rotate clockwise (positive)
	# When throwing left (negative X), rotate counter-clockwise (negative)
	if direction.x > 0:
		rotation_speed = 360.0  # Clockwise rotation for right throws
	else:
		rotation_speed = -360.0  # Counter-clockwise rotation for left throws
	
	update_visual_effects()
	
	# Store time percentage for sweet spot detection
	self.time_percentage = time_percentage

func _setup_collision_detection() -> void:
	"""Set up collision detection for the grenade"""
	# The Area2D is now attached to the Shadow node
	var shadow = get_node_or_null("Shadow")
	if shadow:
		var area = shadow.get_node_or_null("Area2D")
		if area:
			# Connect signals
			area.area_entered.connect(_on_area_entered)
			area.area_exited.connect(_on_area_exited)

func _disable_collision_detection() -> void:
	"""Disable collision detection after grenade has landed"""
	var shadow = get_node_or_null("Shadow")
	if shadow:
		var area = shadow.get_node_or_null("Area2D")
		if area:
			area.monitoring = false
			area.monitorable = false

func _on_area_entered(area: Area2D) -> void:
	"""Handle collisions with objects when grenade enters their collision area"""
	if landed_flag or exploded_flag:
		return  # Don't handle collisions if grenade has already landed or exploded
	
	var object = area.get_parent()
	if not object:
		return
	
	# Prevent duplicate collision handling for the same object
	if last_collision_object == object:
		return
	
	# Track this collision to prevent duplicates
	last_collision_object = object
	
	# Check if this is a tree collision
	if object.has_method("_handle_trunk_collision"):
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is an NPC collision (GangMember)
	if object.has_method("_handle_ball_collision"):
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is a Shop collision
	if object.has_method("_handle_shop_collision"):
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is a Boulder collision
	if object.has_method("_handle_boulder_collision"):
		_handle_roof_bounce_collision(object)
		return
	
	# Check if this is a player collision
	if object.has_method("take_damage") and object.name == "Player":
		_handle_player_collision(object)
		return

func _on_area_exited(area: Area2D) -> void:
	"""Handle when grenade exits an object's collision area"""
	# Area exit handling if needed
	pass

func _handle_player_collision(player: Node2D) -> void:
	"""Handle collision with the player"""
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(self, player):
		# Grenade is above player entirely - let it pass through
		return
	else:
		# Grenade is within or below player height - handle collision
		
		# Bounce off player
		_handle_player_bounce(player)

func _handle_player_bounce(player: Node2D) -> void:
	"""Handle bouncing off the player"""
	# Calculate bounce velocity (similar to ground bounce but with player reflection)
	var player_center = player.global_position
	var grenade_pos = global_position
	
	# Calculate the direction from player center to grenade
	var to_grenade_direction = (grenade_pos - player_center).normalized()
	
	# Reflect the velocity across the player center
	var reflected_velocity = velocity - 2 * velocity.dot(to_grenade_direction) * to_grenade_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity
	velocity = reflected_velocity
	
	# Set vertical velocity for bounce
	vz = clamp(velocity.length() * bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
	
	# Reverse rotation direction and reduce speed after bounce
	rotation_speed = -rotation_speed * 0.8
	
	# Play collision sound
	_play_collision_sound()

func _play_collision_sound() -> void:
	"""Play collision sound effect"""
	var collision_sound = get_node_or_null("GrenadeImpact")
	if collision_sound:
		collision_sound.play()

func update_visual_effects() -> void:
	"""Update visual effects based on height and position"""
	if not sprite:
		return
	
	# Update sprite position based on height (GrenadeSprite moves up and down)
	sprite.position.y = -z
	
	# Update sprite scale based on height (perspective effect)
	var height_scale = 1.0 - (z / MAX_LAUNCH_HEIGHT) * 0.3  # Reduce scale by up to 30% at max height
	height_scale = clamp(height_scale, 0.7, 1.0)
	sprite.scale = base_scale * height_scale
	
	# Update shadow scale and opacity based on height
	if shadow:
		var shadow_scale = 1.0 + (z / MAX_LAUNCH_HEIGHT) * 0.5  # Increase shadow size with height
		shadow_scale = clamp(shadow_scale, 1.0, 1.5)
		shadow.scale = Vector2(shadow_scale, shadow_scale)
		
		var shadow_alpha = 0.3 - (z / MAX_LAUNCH_HEIGHT) * 0.2  # Reduce shadow opacity with height
		shadow_alpha = clamp(shadow_alpha, 0.1, 0.3)
		shadow.modulate.a = shadow_alpha

func update_y_sort():
	"""Update the grenade's z_index using the same global Y-sort system as the golf ball"""
	# Use the global Y-sort system like the golf ball
	# Use the YSortPoint for proper Y-sorting
	var ysort_point = get_node_or_null("YSortPoint")
	if ysort_point:
		Global.update_ball_y_sort(ysort_point)
	else:
		Global.update_ball_y_sort(self)

func check_target_hits():
	# Check if grenade hit any targets (enemies, etc.)
	var shadow = get_node_or_null("Shadow")
	if shadow:
		var area = shadow.get_node_or_null("Area2D")
		if area:
			var overlapping_bodies = area.get_overlapping_bodies()
			for body in overlapping_bodies:
				if body.has_method("take_damage") or body.has_method("hit"):
					# Grenade hit a target
					if not has_hit_target:
						has_hit_target = true
						target_hit = true
						
						# Play impact sound
						var grenade_impact = get_node_or_null("GrenadeImpact")
						if grenade_impact:
							grenade_impact.play()

func explode() -> void:
	"""Trigger the grenade explosion"""
	if exploded_flag:
		return  # Already exploded
	
	exploded_flag = true
	
	# Play explosion sound
	var explosion_sound = get_node_or_null("Explosion")
	if explosion_sound:
		explosion_sound.play()
	
	# Create explosion effect
	create_explosion_effect()
	
	# Deal damage to nearby targets
	deal_explosion_damage()
	
	# Emit explosion signal
	emit_signal("grenade_exploded", global_position)
	
	# Remove the grenade after explosion
	queue_free()

func create_explosion_effect() -> void:
	"""Create visual explosion effect"""
	# Create explosion particles or sprite
	var explosion_scene = preload("res://Particles/Explosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position
		
		# Add to the scene
		var course = _find_course_script()
		if course:
			course.add_child(explosion)
		else:
			get_tree().current_scene.add_child(explosion)

func deal_explosion_damage() -> void:
	"""Deal damage to all targets within explosion radius"""
	var course = _find_course_script()
	if not course:
		return
	
	# Get all entities in the scene
	var entities = course.get_node_or_null("Entities")
	if entities:
		var npcs = entities.get_npcs()
		for npc in npcs:
			if is_instance_valid(npc) and npc.has_method("take_damage"):
				var distance = npc.global_position.distance_to(global_position)
				if distance <= explosion_radius:
					# Deal damage based on distance (more damage closer to center)
					var damage_multiplier = 1.0 - (distance / explosion_radius)
					var final_damage = int(explosion_damage * damage_multiplier)
					
					# Apply damage to NPC
					if npc.get_script() and npc.get_script().resource_path.ends_with("GangMember.gd"):
						npc.take_damage(final_damage, false, global_position)
					else:
						npc.take_damage(final_damage)
	
	# Also check for oil drums and other destructible objects
	var hitboxes = get_tree().get_nodes_in_group("hitboxes")
	for hitbox in hitboxes:
		if is_instance_valid(hitbox):
			var parent = hitbox.get_parent()
			if parent and parent.has_method("take_damage"):
				var distance = parent.global_position.distance_to(global_position)
				if distance <= explosion_radius:
					var damage_multiplier = 1.0 - (distance / explosion_radius)
					var final_damage = int(explosion_damage * damage_multiplier)
					parent.take_damage(final_damage)

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			return current_node
		current_node = current_node.get_parent()
	return null

func _process(delta):
	if landed_flag or exploded_flag:
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
		# Grenade is in the air
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Rotate the grenade while in flight
		if sprite:
			sprite.rotation_degrees += rotation_speed * delta
		
		# Check for landing (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Handle bounce or final landing
			if bounce_count < max_bounces and velocity.length() > min_bounce_speed:
				# Bounce
				bounce_count += 1
				vz = clamp(velocity.length() * bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
				velocity *= bounce_factor
				
				# Reduce rotation speed after bounce (keep same direction)
				rotation_speed *= 0.8
				
				# Play bounce sound
				var bounce_sound = get_node_or_null("GrenadeBounce")
				if bounce_sound:
					bounce_sound.play()
			else:
				# Final landing - explode
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				# Play landing sound
				var land_sound = get_node_or_null("GrenadeLand")
				if land_sound:
					land_sound.play()
				
				# Emit landed signals
				emit_signal("grenade_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(global_position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
				
				# Disable collision detection since grenade has landed
				_disable_collision_detection()
				
				# Trigger explosion after a short delay
				var explosion_timer = Timer.new()
				explosion_timer.wait_time = 0.5  # 0.5 second delay before explosion
				explosion_timer.one_shot = true
				explosion_timer.timeout.connect(explode)
				add_child(explosion_timer)
				explosion_timer.start()
	
	elif vz > 0.0:
		# Grenade is bouncing up from ground
		z += vz * delta
		vz -= gravity * delta
		
		# Track maximum height for scaling reference
		max_height = max(max_height, z)
		
		# Rotate the grenade while in flight
		if sprite:
			sprite.rotation_degrees += rotation_speed * delta
		
		# Check if grenade has landed again (using current ground level)
		if z <= current_ground_level:
			z = current_ground_level
			
			# Check tile type before handling bounce or landing
			check_tile_type()
			
			# If grenade was handled by tile check (water/out of bounds), return early
			if landed_flag or exploded_flag:
				return
			
			# Handle bounce or final landing
			if bounce_count < max_bounces and velocity.length() > min_bounce_speed:
				# Bounce
				bounce_count += 1
				vz = clamp(velocity.length() * bounce_factor * 4.0, 0, MAX_BOUNCE_VZ)  # Moderate bounce height, clamped
				velocity *= bounce_factor
				
				# Reduce rotation speed after bounce (keep same direction)
				rotation_speed *= 0.8
				
				# Play bounce sound
				var bounce_sound = get_node_or_null("GrenadeBounce")
				if bounce_sound:
					bounce_sound.play()
			else:
				# Final landing - explode
				vz = 0.0
				landed_flag = true
				velocity = Vector2.ZERO
				rotation_speed = 0.0
				
				# Play landing sound
				var land_sound = get_node_or_null("GrenadeLand")
				if land_sound:
					land_sound.play()
				
				# Emit landed signals
				emit_signal("grenade_landed", global_position)
				
				# Emit landed signal for course compatibility (convert position to tile)
				if map_manager and map_manager.has_method("world_to_map"):
					var final_tile = map_manager.world_to_map(global_position)
					emit_signal("landed", final_tile)
				else:
					# Fallback if no map manager or no world_to_map method
					emit_signal("landed", Vector2i.ZERO)
				
				# Check for target hits
				check_target_hits()
				
				# Disable collision detection since grenade has landed
				_disable_collision_detection()
				
				# Trigger explosion after a short delay
				var explosion_timer = Timer.new()
				explosion_timer.wait_time = 0.5  # 0.5 second delay before explosion
				explosion_timer.one_shot = true
				explosion_timer.timeout.connect(explode)
				add_child(explosion_timer)
				explosion_timer.start()
	
	# Update visual effects
	update_visual_effects()

func is_in_flight() -> bool:
	"""Check if the grenade is currently in flight"""
	return not landed_flag and not exploded_flag and (z > 0.0 or velocity.length() > 0.1)

func get_velocity() -> Vector2:
	"""Get the current velocity of the grenade"""
	return velocity

func set_velocity(new_velocity: Vector2) -> void:
	"""Set the velocity of the grenade for collision handling"""
	velocity = new_velocity

func get_ground_position() -> Vector2:
	"""Return the grenade's position on the ground (ignoring height) for Y-sorting"""
	# The grenade's position is already the ground position
	# The height (z) is only used for visual effects (sprite.position.y = -z)
	# Use YSortPoint position for more accurate ground positioning
	var ysort_point = get_node_or_null("YSortPoint")
	if ysort_point:
		return ysort_point.global_position
	return global_position

func get_height() -> float:
	"""Return the grenade's current height for Y-sorting and collision handling"""
	return z

# Method to set club info (called by LaunchManager)
func set_club_info(info: Dictionary):
	club_info = info
	
	# Update power constants based on character-specific club data
	MAX_LAUNCH_POWER = info.get("max_distance", 400.0)
	MIN_LAUNCH_POWER = info.get("min_distance", 200.0)

# Method to set time percentage (called by LaunchManager)
func set_time_percentage(percentage: float):
	time_percentage = percentage

# Method to get final power (called by course)
func get_final_power() -> float:
	"""Get the final power used for this throw"""
	return velocity.length() if velocity.length() > 0 else 0.0

# Method to check if this is a grenade (called by course)
func is_grenade_weapon() -> bool:
	"""Check if this is a grenade"""
	return true

func check_tile_type() -> void:
	"""Check the tile type at the grenade's position and handle accordingly"""
	if not map_manager or not map_manager.has_method("get_tile_type"):
		return
	
	# Get tile coordinates
	var tile_x = int(floor(global_position.x / cell_size))
	var tile_y = int(floor(global_position.y / cell_size))
	var tile_type = map_manager.get_tile_type(tile_x, tile_y)
	
	# Check for out of bounds
	if tile_x < 0 or tile_y < 0 or tile_x >= map_manager.grid_width or tile_y >= map_manager.grid_height:
		# Grenade is out of bounds
		velocity = Vector2.ZERO
		vz = 0.0
		landed_flag = true
		exploded_flag = true
		emit_signal("out_of_bounds")
		queue_free()
		return
	
	# Check for water tile
	if tile_type == "W":
		# Grenade landed in water
		velocity = Vector2.ZERO
		vz = 0.0
		landed_flag = true
		exploded_flag = true
		
		# Play water plunk sound
		if water_plunk_sound:
			water_plunk_sound.play()
		
		# Emit signals for course compatibility
		if map_manager and map_manager.has_method("world_to_map"):
			var final_tile = map_manager.world_to_map(global_position)
			emit_signal("landed", final_tile)
		
		# Disable collision detection
		_disable_collision_detection()
		
		# Queue free after a short delay to let the sound play
		var water_timer = Timer.new()
		water_timer.wait_time = 0.3  # Short delay to let water sound play
		water_timer.one_shot = true
		water_timer.timeout.connect(queue_free)
		add_child(water_timer)
		water_timer.start()
		return
	
	# Check for sand tile
	if tile_type == "S":
		# Grenade landed in sand
		velocity = Vector2.ZERO
		vz = 0.0
		landed_flag = true
		rotation_speed = 0.0
		
		# Play sand landing sound
		var land_sound = get_node_or_null("BallLand")
		if land_sound:
			land_sound.play()
		
		# Emit sand landing signal
		emit_signal("sand_landing")
		
		# Emit landed signal for course compatibility
		if map_manager and map_manager.has_method("world_to_map"):
			var final_tile = map_manager.world_to_map(global_position)
			emit_signal("landed", final_tile)
		
		# Check for target hits
		check_target_hits()
		
		# Disable collision detection since grenade has landed
		_disable_collision_detection()
		
		# Trigger explosion after a short delay
		var explosion_timer = Timer.new()
		explosion_timer.wait_time = 0.5  # 0.5 second delay before explosion
		explosion_timer.one_shot = true
		explosion_timer.timeout.connect(explode)
		add_child(explosion_timer)
		explosion_timer.start()
		return

# Simple collision system methods
func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""
	Simple collision handler: if projectile height < object height, reflect.
	If projectile height > object height, set ground to object height.
	"""
	var object_height = Global.get_object_height_from_marker(object)
	
	# Check if grenade is above the object
	if z > object_height:
		current_ground_level = object_height
	else:
		_reflect_off_object(object)

func _reflect_off_object(object: Node2D) -> void:
	"""
	Simple reflection off an object when grenade is below object height.
	"""
	# Get the grenade's current velocity
	var grenade_velocity = velocity
	
	# Play collision sound if available
	if object.has_method("_play_trunk_thunk_sound"):
		object._play_trunk_thunk_sound()
	elif object.has_method("_play_oil_drum_sound"):
		object._play_oil_drum_sound()
	
	var grenade_pos = global_position
	var object_center = object.global_position
	
	# Calculate the direction from object center to grenade
	var to_grenade_direction = (grenade_pos - object_center).normalized()
	
	# Simple reflection: reflect the velocity across the object center
	var reflected_velocity = grenade_velocity - 2 * grenade_velocity.dot(to_grenade_direction) * to_grenade_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= bounce_factor
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	# Apply the reflected velocity to the grenade
	velocity = reflected_velocity 
