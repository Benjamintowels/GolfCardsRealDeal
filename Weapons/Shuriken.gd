extends Node2D

signal shuriken_landed(final_position: Vector2)
signal shuriken_hit_target(target: Node2D)
signal landed(final_tile: Vector2i)  # Add landed signal for compatibility with course
signal out_of_bounds()  # Signal for out of bounds
signal sand_landing()  # Signal for sand landing

var cell_size: int = 48 # This will be set by the main script
var map_manager: Node = null  # Will be set by the course to check tile types
var chosen_landing_spot: Vector2 = Vector2.ZERO  # Target landing spot from red circle

# Audio
var shuriken_impact_sound: AudioStreamPlayer2D
var throw_sound: AudioStreamPlayer2D

var velocity := Vector2.ZERO
var gravity := 1200.0  # Adjusted for pixel perfect system
var z := 0.0 # Height above ground
var vz := 0.0 # Vertical velocity (for arc)
var landed_flag := false

# Shuriken-specific properties
var is_shuriken := true
var rotation_speed := 1080.0  # Degrees per second rotation (faster than knife)
var has_hit_target := false
var target_hit := false
var last_collision_object: Node2D = null  # Track last collision to prevent duplicates

# Shuriken doesn't bounce - it sticks like a knife
var bounce_count := 0
var max_bounces := 0  # Shuriken don't bounce - they stick
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

func _ready():
	"""Initialize the shuriken when it's added to the scene"""
	add_to_group("shurikens")
	add_to_group("collision_objects")
	
	# Get audio references
	throw_sound = get_node_or_null("Throw")

# Call this to launch the shuriken
func launch(direction: Vector2, power: float, height: float, spin: float = 0.0, spin_strength_category: int = 0):
	# Reset state for new throw
	has_hit_target = false
	target_hit = false
	landed_flag = false
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
	
	if chosen_landing_spot != Vector2.ZERO:
		# Calculate the distance to the landing spot
		var shuriken_global_pos = global_position
		var distance_to_target = shuriken_global_pos.distance_to(chosen_landing_spot)
		
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
		
		# Use the direction passed in from LaunchManager (which is calculated from shuriken position to target)
		# The LaunchManager already calculates the correct direction, so we don't need to override it
		
		# Determine if this is a penalty throw (red circle below min distance)
		var min_distance = club_info.get("min_distance", 200.0)
		is_penalty_shot = distance_to_target < min_distance
		
		# Update the power variable to use the calculated value for physics
		power = final_power

	# Apply the resistance to the final velocity calculation
	velocity = direction.normalized() * power
	
	# Start shuriken at a height of 50 pixels
	z = 50.0
	# Shuriken flies straight and falls naturally - no initial vertical velocity
	vz = 0.0  # No vertical velocity - shuriken flies straight and falls
	landed_flag = false
	max_height = z  # Set initial height as max height
	
	# Get references to sprite and shadow
	sprite = $ShurikenSprite
	shadow = $Shadow
	
	# Set base scale from sprite's current scale
	if sprite:
		base_scale = sprite.scale
	
	# Set initial shadow position (same as shuriken but on ground)
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
		rotation_speed = 1080.0  # Clockwise rotation for right throws
	else:
		rotation_speed = -1080.0  # Counter-clockwise rotation for left throws
	
	update_visual_effects()
	
	# Store time percentage for sweet spot detection
	self.time_percentage = time_percentage

func _setup_collision_detection() -> void:
	"""Setup collision detection for the shuriken"""
	# The Area2D is attached to the Shadow node
	var shadow = get_node_or_null("Shadow")
	if shadow:
		var area = shadow.get_node_or_null("Area2D")
		if area:
			# Connect to area signals for collision detection
			if not area.area_entered.is_connected(_on_area_entered):
				area.area_entered.connect(_on_area_entered)
			if not area.area_exited.is_connected(_on_area_exited):
				area.area_exited.connect(_on_area_exited)

func _disable_collision_detection() -> void:
	"""Disable collision detection after shuriken has landed"""
	var shadow = get_node_or_null("Shadow")
	if shadow:
		var area = shadow.get_node_or_null("Area2D")
		if area:
			area.monitoring = false
			area.monitorable = false

func _on_area_entered(area: Area2D) -> void:
	"""Handle collisions with objects when shuriken enters their collision area"""
	if landed_flag:
		return  # Don't handle collisions if shuriken has already landed
	
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

func _on_area_exited(area: Area2D) -> void:
	"""Handle when shuriken exits collision area"""
	# Not needed for shuriken, but keeping for consistency
	pass

func _handle_roof_bounce_collision(object: Node2D) -> void:
	"""Handle collision with roof-like objects (trees, NPCs)"""
	if landed_flag:
		return
	
	# Shuriken sticks to objects - no bouncing
	landed_flag = true
	velocity = Vector2.ZERO
	vz = 0.0
	
	# Disable collision detection since shuriken has landed
	_disable_collision_detection()
	
	# Emit landed signal
	emit_signal("shuriken_landed", global_position)
	
	# Check if we hit a target (NPC)
	if object.has_method("take_damage"):
		has_hit_target = true
		target_hit = true
		emit_signal("shuriken_hit_target", object)
		
		# Deal damage to the target
		object.take_damage(200, false, global_position)  # 200 damage, not headshot, weapon position

func _physics_process(delta: float):
	if landed_flag:
		return
	
	# Update position
	global_position += velocity * delta
	
	# Update height and vertical velocity
	z += vz * delta
	vz -= gravity * delta
	
	# Track maximum height reached
	if z > max_height:
		max_height = z
	
	# Check for ground collision
	if z <= 0.0 and vz < 0.0:
		# Shuriken has hit the ground
		z = 0.0
		vz = 0.0
		landed_flag = true
		velocity = Vector2.ZERO
		
		# Disable collision detection since shuriken has landed
		_disable_collision_detection()
		
		# Emit landed signal
		emit_signal("shuriken_landed", global_position)
		
		# Convert to tile coordinates for course compatibility
		if map_manager:
			var tile_pos = map_manager.world_to_map(global_position)
			emit_signal("landed", tile_pos)
	
	# Update visual effects
	update_visual_effects()

func update_visual_effects():
	"""Update visual effects like sprite position, shadow, and rotation"""
	if not sprite:
		return
	
	# Update sprite position based on height
	sprite.position.y = -z
	
	# Update shadow scale based on height
	if shadow:
		var shadow_scale = 1.0 - (z / 200.0)  # Shadow gets smaller as shuriken gets higher
		shadow_scale = clamp(shadow_scale, 0.3, 1.0)
		shadow.scale = Vector2(shadow_scale, shadow_scale)
		
		# Update shadow opacity based on height
		var shadow_alpha = 1.0 - (z / 100.0)  # Shadow fades as shuriken gets higher
		shadow_alpha = clamp(shadow_alpha, 0.0, 0.5)
		shadow.modulate.a = shadow_alpha
	
	# Update sprite scale based on height (perspective effect)
	var scale_factor = 1.0 + (z / 400.0)  # Shuriken appears larger when higher
	scale_factor = clamp(scale_factor, 0.8, 1.5)
	sprite.scale = base_scale * scale_factor
	
	# Update sprite rotation
	if sprite:
		sprite.rotation_degrees += rotation_speed * get_process_delta_time()

func is_in_flight() -> bool:
	"""Check if the shuriken is currently in flight"""
	return not landed_flag and (z > 0.0 or velocity.length() > 0.1)

func is_shuriken_weapon() -> bool:
	"""Check if this is a shuriken"""
	return true

func get_velocity() -> Vector2:
	"""Get the current velocity of the shuriken"""
	return velocity

func set_velocity(new_velocity: Vector2) -> void:
	"""Set the velocity of the shuriken for collision handling"""
	velocity = new_velocity

func get_ground_position() -> Vector2:
	"""Return the shuriken's position on the ground (ignoring height) for Y-sorting"""
	# The shuriken's position is already the ground position
	# The height (z) is only used for visual effects (sprite.position.y = -z)
	return global_position

func get_height() -> float:
	"""Return the shuriken's current height for Y-sorting and collision handling"""
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
	return velocity.length() 
