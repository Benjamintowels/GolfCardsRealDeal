extends Node2D

# Wraith Boss NPC - handles Wraith-specific functions
# Integrates with the Entities system for turn management

# Coin explosion system
const CoinExplosionManager = preload("res://CoinExplosionManager.gd")

signal turn_completed

@onready var sprite: Sprite2D = $WraithSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Wraith specific properties
var wraith_type: String = "default"
var movement_range: int = 10  # Can move up to 10 tiles on the green
var vision_range: int = 15
var current_action: String = "idle"

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds
var movement_start_position: Vector2  # Track where movement started

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)  # Track last movement direction

# Health and damage properties
var max_health: int = 250
var current_health: int = 250
var is_alive: bool = true
var is_dead: bool = false

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# Freeze effect properties
var is_frozen: bool = false
var freeze_turns_remaining: int = 0
var original_modulate: Color
var freeze_sound: AudioStream

# Ice sprite and collision references
var ice_sprite: Sprite2D
var ice_collision_area: Area2D
var ice_top_height_marker: Marker2D
var ice_ysort_point: Node2D

# Collision and height properties
var dead_height: float = 150.0  # Lower height when dead (laying down)
var base_collision_area: Area2D

# Headshot mechanics
const HEADSHOT_MIN_HEIGHT = 150.0  # Minimum height for headshot (150-200 range)
const HEADSHOT_MAX_HEIGHT = 200.0  # Maximum height for headshot (150-200 range)
const HEADSHOT_MULTIPLIER = 1.5    # Damage multiplier for headshots

func _is_headshot(ball_height: float) -> bool:
	"""Check if a ball/knife hit is a headshot based on height"""
	# Headshot occurs when the ball/knife hits in the head region (150-200 height)
	return ball_height >= HEADSHOT_MIN_HEIGHT and ball_height <= HEADSHOT_MAX_HEIGHT

func get_headshot_info() -> Dictionary:
	"""Get information about the headshot system for debugging and UI"""
	return {
		"min_height": HEADSHOT_MIN_HEIGHT,
		"max_height": HEADSHOT_MAX_HEIGHT,
		"multiplier": HEADSHOT_MULTIPLIER,
		"total_height": Global.get_object_height_from_marker(self),
		"headshot_range": HEADSHOT_MAX_HEIGHT - HEADSHOT_MIN_HEIGHT
	}

# Grid system
var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# State machine
var state_machine: StateMachine
var current_state: String = "patrol"

# Player reference
var player: Node = null
var course: Node = null

# Turn management
var turn_in_progress: bool = false
var turn_finished: bool = false

# Ragdoll system
var is_ragdolling: bool = false
var ragdoll_landing_position: Vector2i

# Audio references
@onready var wraith_hurt_sound: AudioStreamPlayer2D = $WraithHurt

# Death animation properties
var death_animation_tween: Tween
var death_animation_duration: float = 1.5  # Duration of death animation
var is_dying: bool = false

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	add_to_group("NPC")
	add_to_group("bosses")
	
	# Get references to ice sprite and collision areas
	_setup_ice_references()
	
	# Connect to WorldTurnManager
	course = _find_course_script()
	print("Wraith course reference: ", course.name if course else "None")
	
	# Try different paths to find WorldTurnManager
	var world_turn_manager = null
	var possible_paths = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
	
	for path in possible_paths:
		if course and course.has_node(path):
			world_turn_manager = course.get_node(path)
			print("Found WorldTurnManager at path: ", path)
			break
	
	if world_turn_manager:
		print("Found WorldTurnManager: ", world_turn_manager.name)
		# Register with WorldTurnManager
		world_turn_manager.register_npc(self)
		# Connect to turn signals
		world_turn_manager.npc_turn_started.connect(_on_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
		print("✓ Wraith registered with WorldTurnManager and connected to signals")
	else:
		print("✗ ERROR: Could not connect to WorldTurnManager")
	
	# Initialize state machine
	state_machine = StateMachine.new()
	state_machine.add_state("patrol", PatrolState.new(self))
	state_machine.add_state("chase", ChaseState.new(self))
	state_machine.add_state("dead", DeadState.new(self))
	state_machine.set_state("patrol")
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded
	call_deferred("_find_player_reference")
	
	# Initialize freeze effect system
	_setup_freeze_system()
	
	# Setup entities manager reference
	_setup_entities_manager()
	
	# Initial Y-sort update
	call_deferred("update_z_index_for_ysort")

func _setup_entities_manager():
	"""Setup the entities manager reference"""
	if course:
		entities_manager = course.get_node_or_null("Entities")
		if entities_manager:
			print("✓ Wraith found entities manager")
		else:
			print("✗ Wraith could not find entities manager")
	else:
		print("✗ Wraith could not find course for entities manager setup")

func _setup_ice_references():
	"""Setup references to ice sprite and collision areas"""
	ice_sprite = get_node_or_null("WraithIce")
	ice_collision_area = get_node_or_null("WraithIce/BodyArea2D")
	
	# Use the ice-specific markers for proper Y-sorting and height detection
	ice_top_height_marker = get_node_or_null("WraithIce/IceTopHeight")
	ice_ysort_point = get_node_or_null("WraithIce/IceYSortPoint")
	
	if ice_sprite:
		original_modulate = ice_sprite.modulate
		ice_sprite.visible = false
		print("✓ Ice sprite reference found")
	else:
		print("✗ ERROR: WraithIce sprite not found!")
	
	if ice_collision_area:
		# Immediately disable the ice collision area to prevent early collisions
		ice_collision_area.monitoring = false
		ice_collision_area.monitorable = false
		print("✓ Ice collision area reference found and disabled")
	else:
		print("✗ ERROR: WraithIce/BodyArea2D not found!")
	
	if ice_top_height_marker:
		print("✓ Ice top height marker reference found (WraithIce/IceTopHeight)")
	else:
		print("✗ ERROR: WraithIce/IceTopHeight marker not found!")
	
	if ice_ysort_point:
		print("✓ Ice Y-sort point reference found (WraithIce/IceYSortPoint)")
	else:
		print("✗ ERROR: WraithIce/IceYSortPoint marker not found!")

func _setup_base_collision():
	"""Setup the base collision area for ball collisions"""
	base_collision_area = get_node_or_null("BodyArea2D")
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		base_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		base_collision_area.connect("area_exited", _on_area_exited)
		print("✓ Wraith base collision area setup complete")
		print("  - Base collision area monitoring:", base_collision_area.monitoring)
		print("  - Base collision area monitorable:", base_collision_area.monitorable)
	else:
		print("✗ ERROR: BodyArea2D not found!")
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ Wraith HitBox setup complete for gun collision (layer 2)")
	else:
		print("✗ ERROR: HitBox not found!")
	
	# Setup ice collision area (initially disabled, will be enabled when frozen)
	if ice_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		ice_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		ice_collision_area.collision_mask = 1
		# Initially disabled - will be enabled when frozen
		ice_collision_area.monitoring = false
		ice_collision_area.monitorable = false
		print("✓ Wraith ice collision area setup complete (initially disabled)")
		print("  - Ice collision area monitoring:", ice_collision_area.monitoring)
		print("  - Ice collision area monitorable:", ice_collision_area.monitorable)
	else:
		print("✗ ERROR: Ice collision area not found!")

func _create_health_bar():
	"""Create and setup the health bar"""
	# Create container for health bar
	health_bar_container = Control.new()
	health_bar_container.name = "HealthBarContainer"
	health_bar_container.custom_minimum_size = Vector2(60, 30)
	health_bar_container.size = Vector2(60, 30)
	health_bar_container.position = Vector2(-30, -144.96)
	health_bar_container.scale = Vector2(0.35, 0.35)
	add_child(health_bar_container)
	
	# Create health bar
	var health_bar_scene = preload("res://HealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar_container.add_child(health_bar)
	
	# Set initial health
	health_bar.set_health(current_health, max_health)

func _find_player_reference():
	"""Find the player reference after scene is loaded"""
	# Try to find player in the course
	if course:
		player = course.get_node_or_null("Player")
		if not player:
			# Try alternative paths
			player = course.get_node_or_null("player_node")
		if not player:
			# Search for player in the scene tree
			player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("✓ Wraith found player reference: ", player.name)
	else:
		print("✗ Wraith could not find player reference")

func _exit_tree():
	# Stop death animation if running
	stop_death_animation()
	
	# Unregister from Entities manager when destroyed
	if entities_manager:
		entities_manager.unregister_npc(self)

func _find_course_script() -> Node:
	"""Find the course script by searching up the scene tree"""
	var current = self
	while current:
		if current.has_method("_on_hole_in_one") or current.has_method("build_map_from_layout_with_randomization"):
			return current
		current = current.get_parent()
	return null

func _on_base_area_entered(area: Area2D):
	"""Handle ball entering the Wraith's base collision area"""
	print("=== WRAITH BASE AREA ENTERED ===")
	print("Area name:", area.name)
	print("Area parent:", area.get_parent().name if area.get_parent() else "None")
	print("Area path:", area.get_path())
	
	# Check if this is a ball or projectile
	var ball = area.get_parent()
	if ball and (ball.name == "GolfBall" or ball.has_method("get_height")):
		_handle_area_collision(ball)

func _on_area_exited(area: Area2D):
	"""Handle when projectile exits the Wraith area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		# Reset the projectile's ground level to normal (0.0)
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			# Fallback: directly reset ground level if method doesn't exist
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _handle_area_collision(projectile: Node2D):
	"""Handle Wraith area collisions using proper Area2D detection"""
	print("=== HANDLING WRAITH AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	print("Projectile type:", projectile.get_class())
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and Wraith heights
	var projectile_height = projectile.get_height()
	var wraith_height = get_height()
	
	print("Projectile height:", projectile_height)
	print("Wraith height:", wraith_height)
	
	# Check if this is a throwing knife (special handling)
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		_handle_knife_area_collision(projectile, projectile_height, wraith_height)
		return
	
	# Apply the collision logic:
	# If projectile height > Wraith height: allow entry and set ground level
	# If projectile height < Wraith height: deal damage and reflect
	if projectile_height > wraith_height:
		print("✓ Projectile is above Wraith - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, wraith_height)
	else:
		print("✗ Projectile is below Wraith height - dealing damage and reflecting")
		# Deal damage first, then reflect
		_handle_ball_collision(projectile)

func _handle_knife_area_collision(knife: Node2D, knife_height: float, wraith_height: float):
	"""Handle knife collision with Wraith area"""
	print("Handling knife Wraith area collision")
	
	if knife_height > wraith_height:
		print("✓ Knife is above Wraith - allowing entry and setting ground level")
		_allow_projectile_entry(knife, wraith_height)
	else:
		print("✗ Knife is below Wraith height - reflecting")
		_reflect_projectile(knife)

func _allow_projectile_entry(projectile: Node2D, wraith_height: float):
	"""Allow projectile to enter Wraith area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (WRAITH) ===")
	
	# Get projectile height for freeze effect logic
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	
	# Only apply freeze effect if projectile is above Wraith height
	# This handles the case where ball bounces off roof and lands on Wraith's head
	if projectile_height > wraith_height:
		# Check for ice element and apply freeze effect (for roof bounces landing on head)
		if projectile.has_method("get_element"):
			var projectile_element = projectile.get_element()
			if projectile_element and projectile_element.name == "Ice":
				print("Ice element detected on projectile landing (roof bounce)! Applying freeze effect")
				apply_freeze_effect(3)  # Freeze for 3 turns
	
	# Set the projectile's ground level to the Wraith height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(wraith_height)
	else:
		# Fallback: directly set ground level if method doesn't exist
		if "current_ground_level" in projectile:
			projectile.current_ground_level = wraith_height
			print("✓ Set projectile ground level to Wraith height:", wraith_height)
	
	# The projectile will now land on the Wraith's head instead of passing through
	# When it exits the area, _on_area_exited will reset the ground level

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the Wraith"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Get projectile height for freeze effect logic
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	
	var wraith_height = get_height()
	
	# Only apply freeze effect if projectile is below Wraith height (wall bounces)
	# This handles the case where ball hits Wraith's body and reflects
	if projectile_height < wraith_height:
		# Check for ice element and apply freeze effect (for wall bounces)
		if projectile.has_method("get_element"):
			var projectile_element = projectile.get_element()
			if projectile_element and projectile_element.name == "Ice":
				print("Ice element detected on projectile reflection (wall bounce)! Applying freeze effect")
				apply_freeze_effect(3)  # Freeze for 3 turns
	
	# Play collision sound for Wraith collision
	_play_collision_sound()
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var wraith_center = global_position
	
	# Calculate the direction from Wraith center to projectile
	var to_projectile_direction = (projectile_pos - wraith_center).normalized()
	
	# Simple reflection: reflect the velocity across the Wraith center
	var reflected_velocity = projectile_velocity - 2 * projectile_velocity.dot(to_projectile_direction) * to_projectile_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the projectile
	if projectile.has_method("set_velocity"):
		projectile.set_velocity(reflected_velocity)
	elif "velocity" in projectile:
		projectile.velocity = reflected_velocity

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball/knife collisions - check height to determine if ball/knife should pass through"""
	print("Handling ball/knife collision - checking ball/knife height")
	
	# Handle collision directly (bypass Entities system to avoid cooldown issues)
	# Use enhanced height collision detection with TopHeight markers
	if Global.is_object_above_obstacle(ball, self):
		# Ball/knife is above Wraith entirely - let it pass through
		print("Ball/knife is above Wraith entirely - passing through")
		return
	else:
		# Ball/knife is within or below Wraith height - handle collision
		print("Ball/knife is within Wraith height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			# Handle knife collision with Wraith
			_handle_knife_collision(ball)
		else:
			# Handle regular ball collision
			_handle_regular_ball_collision(ball)

func _handle_knife_collision(knife: Node2D) -> void:
	"""Handle knife collision with Wraith"""
	print("Handling knife collision with Wraith")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Check for ice element and apply freeze effect
	if knife.has_method("get_element"):
		var knife_element = knife.get_element()
		if knife_element and knife_element.name == "Ice":
			print("Ice element detected on knife! Applying freeze effect")
			apply_freeze_effect(3)  # Freeze for 3 turns
	
	# Let the knife handle its own collision logic
	# The knife will determine if it should bounce or stick based on which side hits
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		# Fallback: just reflect the knife
		_apply_knife_reflection(knife)

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with Wraith"""
	print("Handling regular ball collision with Wraith")
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Apply collision effect to the ball
	_apply_ball_collision_effect(ball)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection effect to a knife (fallback method)"""
	# Play collision sound effect
	_play_collision_sound()
	
	# Check for ice element and apply freeze effect
	if knife.has_method("get_element"):
		var knife_element = knife.get_element()
		if knife_element and knife_element.name == "Ice":
			print("Ice element detected on knife reflection! Applying freeze effect")
			apply_freeze_effect(3)  # Freeze for 3 turns
	
	# Get the knife's current velocity
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	print("Applying knife reflection with velocity:", knife_velocity)
	
	var knife_pos = knife.global_position
	var wraith_center = global_position
	
	# Calculate the direction from Wraith center to knife
	var to_knife_direction = (knife_pos - wraith_center).normalized()
	
	# Simple reflection: reflect the velocity across the Wraith center
	var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
	
	# Reduce speed slightly to prevent infinite bouncing
	reflected_velocity *= 0.8
	
	# Add a small amount of randomness to prevent infinite loops
	var random_angle = randf_range(-0.1, 0.1)
	reflected_velocity = reflected_velocity.rotated(random_angle)
	
	print("Reflected knife velocity:", reflected_velocity)
	
	# Apply the reflected velocity to the knife
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity

func _apply_ball_collision_effect(ball: Node2D) -> void:
	"""Apply collision effect to the ball (bounce, damage, etc.)"""
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if ball.has_method("is_ghost"):
		is_ghost_ball = ball.is_ghost
	elif "is_ghost" in ball:
		is_ghost_ball = ball.is_ghost
	elif ball.name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		print("Ghost ball detected - no damage dealt, just reflection")
		# Ghost balls only reflect, no damage
		var ball_velocity = Vector2.ZERO
		if ball.has_method("get_velocity"):
			ball_velocity = ball.get_velocity()
		elif "velocity" in ball:
			ball_velocity = ball.velocity
		
		var ball_pos = ball.global_position
		var wraith_center = global_position
		
		# Calculate the direction from Wraith center to ball
		var to_ball_direction = (ball_pos - wraith_center).normalized()
		
		# Simple reflection: reflect the velocity across the Wraith center
		var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		
		# Reduce speed slightly to prevent infinite bouncing
		reflected_velocity *= 0.8
		
		# Add a small amount of randomness to prevent infinite loops
		var random_angle = randf_range(-0.1, 0.1)
		reflected_velocity = reflected_velocity.rotated(random_angle)
		
		print("Ghost ball reflected velocity:", reflected_velocity)
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity
		return
	
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	print("Applying collision effect to ball with velocity:", ball_velocity)
	
	# Get ball height for headshot detection
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	# Check if this is a headshot
	var is_headshot = _is_headshot(ball_height)
	var damage_multiplier = HEADSHOT_MULTIPLIER if is_headshot else 1.0
	
	# Calculate base damage based on ball velocity
	var base_damage = _calculate_velocity_damage(ball_velocity.length())
	
	# Apply headshot multiplier if applicable
	var damage = int(base_damage * damage_multiplier)
	
	if is_headshot:
		print("HEADSHOT! Ball height:", ball_height, "Base damage:", base_damage, "Final damage:", damage)
	else:
		print("Body shot. Ball height:", ball_height, "Damage:", damage)
	
	# Check for ice element and apply freeze effect
	if ball.has_method("get_element"):
		var ball_element = ball.get_element()
		if ball_element and ball_element.name == "Ice":
			print("Ice element detected! Applying freeze effect")
			apply_freeze_effect(3)  # Freeze for 3 turns
	
	# Check if this damage will kill the Wraith
	var will_kill = damage >= current_health
	var overkill_damage = 0
	
	if will_kill:
		# Calculate overkill damage (negative health value)
		overkill_damage = damage - current_health
		print("Damage will kill Wraith! Overkill damage:", overkill_damage)
		
		# Apply damage to the Wraith (this will set health to negative)
		take_damage(damage, is_headshot)
		
		# Apply velocity dampening based on overkill damage
		var dampened_velocity = _calculate_kill_dampening(ball_velocity, overkill_damage)
		print("Ball passed through with dampened velocity:", dampened_velocity)
		
		# Apply the dampened velocity to the ball (no reflection)
		if ball.has_method("set_velocity"):
			ball.set_velocity(dampened_velocity)
		elif "velocity" in ball:
			ball.velocity = dampened_velocity
	else:
		# Normal collision - apply damage and reflect
		take_damage(damage, is_headshot)
		
		var ball_pos = ball.global_position
		var wraith_center = global_position
		
		# Calculate the direction from Wraith center to ball
		var to_ball_direction = (ball_pos - wraith_center).normalized()
		
		# Simple reflection: reflect the velocity across the Wraith center
		var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		
		# Reduce speed slightly to prevent infinite bouncing
		reflected_velocity *= 0.8
		
		# Add a small amount of randomness to prevent infinite loops
		var random_angle = randf_range(-0.1, 0.1)
		reflected_velocity = reflected_velocity.rotated(random_angle)
		
		print("Reflected velocity:", reflected_velocity)
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity

func _calculate_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate damage based on ball velocity magnitude"""
	# Define velocity ranges for damage scaling
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
	
	# Debug output
	print("=== VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END VELOCITY DAMAGE CALCULATION ===")
	
	return final_damage

func _calculate_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate velocity dampening when ball kills an NPC"""
	# Define dampening ranges
	const MIN_OVERKILL = 1  # Minimum overkill for maximum dampening
	const MAX_OVERKILL = 60  # Maximum overkill for minimum dampening
	
	# Clamp overkill damage to our defined range
	var clamped_overkill = clamp(overkill_damage, MIN_OVERKILL, MAX_OVERKILL)
	
	# Calculate dampening factor (0.0 = no dampening, 1.0 = maximum dampening)
	# Higher overkill = less dampening (ball keeps more speed)
	var dampening_percentage = 1.0 - ((clamped_overkill - MIN_OVERKILL) / (MAX_OVERKILL - MIN_OVERKILL))
	
	# Apply dampening factor to velocity
	# Maximum dampening reduces velocity to 20% of original
	# Minimum dampening reduces velocity to 80% of original
	var dampening_factor = 0.2 + (dampening_percentage * 0.6)  # 0.2 to 0.8 range
	var dampened_velocity = ball_velocity * dampening_factor
	
	# Debug output
	print("=== KILL DAMPENING CALCULATION ===")
	print("Overkill damage:", overkill_damage)
	print("Clamped overkill:", clamped_overkill)
	print("Dampening percentage:", dampening_percentage)
	print("Dampening factor:", dampening_factor)
	print("Original velocity magnitude:", ball_velocity.length())
	print("Dampened velocity magnitude:", dampened_velocity.length())
	print("=== END KILL DAMPENING CALCULATION ===")
	
	return dampened_velocity

func take_damage(damage: int, is_headshot: bool = false):
	"""Take damage and handle death"""
	if is_dead or is_frozen:
		return
	
	print("=== WRAITH TAKING DAMAGE ===")
	print("Damage: ", damage)
	print("Is headshot: ", is_headshot)
	print("Current health: ", current_health)
	
	current_health -= damage
	
	# Play hurt sound
	if wraith_hurt_sound and wraith_hurt_sound.stream:
		wraith_hurt_sound.play()
		print("✓ Wraith hurt sound played")
	
	# Update health bar (but don't show negative values to player)
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)
	
	print("New health: ", current_health)
	
	# Check for death
	if current_health <= 0:
		die()
	else:
		# Visual feedback for taking damage
		if is_headshot:
			flash_headshot()
		else:
			_flash_damage()

func _flash_damage():
	"""Flash the sprite to indicate damage taken"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func flash_headshot() -> void:
	"""Flash the Wraith with a special headshot effect"""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	var tween = create_tween()
	# Flash with a bright gold color for headshots
	tween.tween_property(sprite, "modulate", Color(1, 0.84, 0, 1), 0.15)  # Bright gold
	tween.tween_property(sprite, "modulate", Color(1, 0.65, 0, 1), 0.1)   # Deeper gold
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func die():
	"""Handle Wraith death"""
	if is_dying:
		return  # Prevent multiple death animations
	
	print("=== WRAITH DEATH ===")
	is_dying = true
	is_dead = true
	is_alive = false
	
	# Play death sound
	_play_death_sound()
	
	# Start death animation
	_start_death_animation()
	
	# Change to dead state
	state_machine.set_state("dead")
	
	# Trigger coin explosion
	_trigger_coin_explosion()
	
	# Remove from turn system
	if course:
		var world_turn_manager = course.get_node_or_null("WorldTurnManager")
		if world_turn_manager and world_turn_manager.has_method("remove_npc_from_turn_system"):
			world_turn_manager.remove_npc_from_turn_system(self)
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Remove from collision groups
	remove_from_group("collision_objects")
	remove_from_group("NPC")
	
	print("✓ Wraith death animation started")

func _start_death_animation():
	"""Start the Wraith death animation - grow vertically and fade out"""
	print("=== STARTING WRAITH DEATH ANIMATION ===")
	
	# Get the WraithDead sprite
	var wraith_dead_sprite = get_node_or_null("WraithDead")
	if not wraith_dead_sprite:
		print("✗ ERROR: WraithDead sprite not found!")
		_on_death_animation_complete()
		return
	
	# Stop any existing death animation
	if death_animation_tween and death_animation_tween.is_valid():
		death_animation_tween.kill()
	
	# Create new death animation tween
	death_animation_tween = create_tween()
	death_animation_tween.set_parallel(true)
	
	# Show the death sprite on top of current sprite
	wraith_dead_sprite.visible = true
	wraith_dead_sprite.modulate = Color.WHITE
	wraith_dead_sprite.scale = Vector2.ONE
	
	# Set initial position to match current sprite position
	var current_sprite = sprite if sprite and sprite.visible else ice_sprite if is_frozen and ice_sprite and ice_sprite.visible else null
	if current_sprite:
		wraith_dead_sprite.position = current_sprite.position
		# Match the facing direction
		wraith_dead_sprite.flip_h = current_sprite.flip_h
	
	print("Death sprite initial position:", wraith_dead_sprite.position)
	print("Death sprite initial scale:", wraith_dead_sprite.scale)
	
	# Phase 1: Grow vertically quickly (first 40% of animation)
	var grow_duration = death_animation_duration * 0.4
	var target_scale = Vector2(1.0, 3.0)  # Grow 3x vertically
	
	print("Phase 1 - Growing vertically for", grow_duration, "seconds to scale", target_scale)
	
	# Animate vertical growth
	death_animation_tween.tween_property(wraith_dead_sprite, "scale", target_scale, grow_duration)
	death_animation_tween.set_trans(Tween.TRANS_QUAD)
	death_animation_tween.set_ease(Tween.EASE_OUT)
	
	# Phase 2: Fade out (remaining 60% of animation)
	var fade_duration = death_animation_duration * 0.6
	var fade_start_time = grow_duration
	
	print("Phase 2 - Fading out for", fade_duration, "seconds starting at", fade_start_time)
	
	# Animate fade out (delayed to start after growth)
	death_animation_tween.tween_property(wraith_dead_sprite, "modulate:a", 0.0, fade_duration).set_delay(fade_start_time)
	death_animation_tween.set_trans(Tween.TRANS_QUAD)
	death_animation_tween.set_ease(Tween.EASE_IN)
	
	# Phase 3: Complete animation and cleanup
	death_animation_tween.tween_callback(_on_death_animation_complete).set_delay(death_animation_duration)
	
	print("✓ Death animation sequence started")

func _on_death_animation_complete():
	"""Called when the death animation is complete"""
	print("=== WRAITH DEATH ANIMATION COMPLETE ===")
	
	# Hide the death sprite
	var wraith_dead_sprite = get_node_or_null("WraithDead")
	if wraith_dead_sprite:
		wraith_dead_sprite.visible = false
		wraith_dead_sprite.modulate = Color.WHITE
		wraith_dead_sprite.scale = Vector2.ONE
	
	# Hide all other sprites
	if sprite:
		sprite.visible = false
	if ice_sprite:
		ice_sprite.visible = false
	
	# Disable all collision areas
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
	if ice_collision_area:
		ice_collision_area.monitoring = false
		ice_collision_area.monitorable = false
	
	# Queue free the Wraith (no corpse left behind)
	queue_free()
	
	print("✓ Wraith death animation complete and cleaned up")

func stop_death_animation():
	"""Stop the death animation if it's currently running"""
	if is_dying and death_animation_tween and death_animation_tween.is_valid():
		death_animation_tween.kill()
		is_dying = false
		print("✓ Wraith death animation stopped")

func _trigger_coin_explosion():
	"""Trigger a coin explosion when the Wraith dies"""
	# Use the static method from CoinExplosionManager
	CoinExplosionManager.trigger_coin_explosion(global_position)
	print("✓ Triggered coin explosion for Wraith at:", global_position)

# Turn management functions
func take_turn() -> void:
	"""Called by WorldTurnManager when it's this NPC's turn"""
	print("Wraith taking turn: ", name)
	
	# Skip turn if dead, frozen, or dying
	if is_dead:
		print("Wraith is dead, skipping turn")
		call_deferred("_check_turn_completion")
		return
	
	if is_frozen:
		print("Wraith is frozen, skipping turn")
		call_deferred("_check_turn_completion")
		return
	
	if is_dying:
		print("Wraith is dying, skipping turn")
		call_deferred("_check_turn_completion")
		return
	
	# Try to get player reference if we don't have one
	if not player and course:
		print("Attempting to get player reference from course...")
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			print("Got player reference during turn: ", player.name if player else "None")
		else:
			# Try direct access as fallback
			if "player_node" in course:
				player = course.player_node
				print("Got player reference via direct access: ", player.name if player else "None")
			else:
				print("Course does not have player_node property")
		
		# Final fallback: search scene tree for player
		if not player:
			print("Trying final fallback - searching scene tree for player...")
			var scene_tree = get_tree()
			var all_nodes = scene_tree.get_nodes_in_group("")
			for node in all_nodes:
				if node.name == "Player":
					player = node
					print("Found player in final fallback: ", player.name)
					break
	
	# Check if player is in vision range and switch states accordingly
	_check_player_vision()
	
	# Let the current state handle the turn
	state_machine.update()
	
	# Complete turn after state processing (will wait for movement if needed)
	_check_turn_completion()

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to chase if needed"""
	if not player:
		print("No player reference found for vision check")
		return
	
	var player_pos = player.grid_pos
	var distance = grid_position.distance_to(player_pos)
	
	print("Vision check - Player at ", player_pos, ", distance: ", distance, ", vision range: ", vision_range)
	
	if distance <= vision_range:
		if current_state != "chase":
			print("Player detected! Switching to chase state")
			current_state = "chase"
			state_machine.set_state("chase")
		else:
			print("Already in chase state, player still in range")
		
		# Face the player when in chase mode
		_face_player()
	else:
		if current_state != "patrol":
			print("Player out of range, returning to patrol")
			current_state = "patrol"
			state_machine.set_state("patrol")
		else:
			print("Already in patrol state, player still out of range")

func _on_turn_started():
	"""Called when NPC turn starts"""
	print("=== WRAITH TURN STARTED ===")
	turn_in_progress = true
	turn_finished = false
	
	if is_dead or is_frozen or is_dying:
		_check_turn_completion()
		return
	
	# Update state machine
	state_machine.update()

func _on_turn_ended():
	"""Called when NPC turn ends"""
	print("=== WRAITH TURN ENDED ===")
	turn_in_progress = false
	turn_finished = false

func _check_turn_completion():
	"""Check if turn is complete and signal completion"""
	# Don't complete turn if dying (wait for death animation)
	if is_dying:
		print("Wraith is dying, skipping turn completion")
		return
	
	if turn_in_progress and not turn_finished:
		turn_finished = true
		turn_completed.emit()
		print("✓ Wraith turn completed")

# Grid position management
func setup(wraith_type_param: String, pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the Wraith with specific parameters"""
	wraith_type = wraith_type_param
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Load appropriate sprite based on type
	_load_sprite_for_type(wraith_type)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("Wraith setup: ", wraith_type, " at ", pos)
	
	# Debug visual height
	if sprite:
		Global.debug_visual_height(sprite, "Wraith")

func _load_sprite_for_type(type: String) -> void:
	"""Load the appropriate sprite texture based on wraith type"""
	var texture_path = "res://NPC/Bosses/WraithLeftRight.png"  # Default
	
	# You can expand this to load different sprites based on type
	match type:
		"default":
			texture_path = "res://NPC/Bosses/WraithLeftRight.png"
		"variant1":
			texture_path = "res://NPC/Bosses/WraithLeftRight.png"  # Same for now
		"variant2":
			texture_path = "res://NPC/Bosses/WraithLeftRight.png"  # Same for now
		_:
			texture_path = "res://NPC/Bosses/WraithLeftRight.png"
	
	var texture = load(texture_path)
	if texture and sprite:
		sprite.texture = texture
		
		# Scale sprite to fit cell size
		if texture.get_size().x > 0 and texture.get_size().y > 0:
			var scale_x = cell_size / texture.get_size().x
			var scale_y = cell_size / texture.get_size().y
			sprite.scale = Vector2(scale_x, scale_y)

func get_grid_position() -> Vector2i:
	"""Get the current grid position"""
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	"""Set the grid position and update world position"""
	grid_position = pos
	position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions the Wraith can move to (only on green tiles)"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_position_valid(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a position is valid for the Wraith to move to (must be on green)"""
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# Check if position is occupied by the player
	if player and player.grid_pos == pos:
		print("Position ", pos, " is occupied by player")
		return false
	
	# Check if position is on a green tile (G)
	if course and course.has_method("get_tile_type_at_position"):
		var tile_type = course.get_tile_type_at_position(pos)
		if tile_type != "G":
			print("Position ", pos, " is not on green tile (type: ", tile_type, ")")
			return false
	
	return true

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the Wraith to a new position with smooth animation"""
	var old_pos = grid_position
	grid_position = target_pos
	
	# Calculate movement direction and update facing
	var movement_direction = target_pos - old_pos
	if movement_direction != Vector2i.ZERO:
		last_movement_direction = movement_direction
		# Only update facing direction in patrol mode (not when chasing player)
		if current_state == "patrol":
			facing_direction = last_movement_direction
			_update_sprite_facing()
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Animated movement using tween
	_animate_movement_to_position(target_world_pos)
	
	print("Wraith moving from ", old_pos, " to ", target_pos, " with direction: ", movement_direction)
	
	# Check if we moved to the same tile as the player (only if we weren't already there)
	if player and "grid_pos" in player and player.grid_pos == target_pos and old_pos != target_pos:
		print("Wraith collided with player! Dealing damage and pushing back...")
		var approach_direction = target_pos - old_pos
		_handle_player_collision(approach_direction)

func _animate_movement_to_position(target_pos: Vector2):
	"""Animate movement to the target position"""
	if movement_tween:
		movement_tween.kill()
	
	movement_tween = create_tween()
	movement_start_position = position
	
	is_moving = true
	movement_tween.tween_property(self, "position", target_pos, movement_duration)
	# Update Y-sorting during movement for smooth visual updates
	movement_tween.tween_callback(update_z_index_for_ysort)
	movement_tween.tween_callback(_on_movement_complete)

func _on_movement_complete():
	"""Called when movement animation is complete"""
	is_moving = false
	update_z_index_for_ysort()
	_check_turn_completion()

func _handle_player_collision(approach_direction: Vector2i):
	"""Handle collision with the player"""
	print("=== WRAITH PLAYER COLLISION ===")
	
	if not player or not "grid_pos" in player:
		print("✗ No valid player reference for collision")
		return
	
	# Deal damage to player (Wraith deals more damage than GangMember)
	var damage = 25  # Wraith deals 25 damage
	if player.has_method("take_damage"):
		player.take_damage(damage)
		print("✓ Dealt ", damage, " damage to player")
	
	# Push player back
	var pushback_pos = _find_nearest_available_adjacent_tile(player.grid_pos, approach_direction)
	if pushback_pos != player.grid_pos:
		print("Pushing player from ", player.grid_pos, " to ", pushback_pos)
		
		# Use animated pushback if the player supports it
		if player.has_method("push_back"):
			player.push_back(pushback_pos)
			print("Applied animated pushback to player")
		else:
			# Fallback to instant position change
			player.set_grid_position(pushback_pos)
			print("Applied instant pushback to player (no animation support)")
		
		print("Player grid position updated to: ", player.grid_pos)
	else:
		print("No available adjacent tile found for pushback")

func _find_nearest_available_adjacent_tile(player_pos: Vector2i, approach_direction: Vector2i = Vector2i.ZERO) -> Vector2i:
	"""Find the nearest available adjacent tile to push the player to based on Wraith's approach direction"""
	# Use the passed approach direction
	var wraith_approach_direction = approach_direction
	print("Wraith approach direction: ", wraith_approach_direction)
	
	# The pushback direction is the same as the approach direction (player gets pushed in the direction Wraith came from)
	var pushback_direction = wraith_approach_direction
	print("Pushback direction: ", pushback_direction)
	
	# Try the primary pushback direction first
	var primary_pushback_pos = player_pos + pushback_direction
	print("Checking primary pushback position: ", primary_pushback_pos)
	if _is_position_valid_for_player(primary_pushback_pos):
		print("Found valid primary pushback position: ", primary_pushback_pos)
		return primary_pushback_pos
	
	# If primary direction is blocked, try perpendicular directions
	var perpendicular_directions = _get_perpendicular_directions(pushback_direction)
	for direction in perpendicular_directions:
		var adjacent_pos = player_pos + direction
		print("Checking perpendicular position: ", adjacent_pos, " (direction: ", direction, ")")
		if _is_position_valid_for_player(adjacent_pos):
			print("Found valid perpendicular pushback position: ", adjacent_pos)
			return adjacent_pos
	
	# If perpendicular directions are blocked, try any available adjacent tile
	var all_directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	for direction in all_directions:
		var adjacent_pos = player_pos + direction
		if _is_position_valid_for_player(adjacent_pos):
			print("Found valid adjacent pushback position: ", adjacent_pos)
			return adjacent_pos
	
	# If no valid position found, return player's current position (no pushback)
	print("No valid pushback position found, player stays in place")
	return player_pos

func _get_perpendicular_directions(direction: Vector2i) -> Array[Vector2i]:
	"""Get perpendicular directions to the given direction"""
	var perpendicular: Array[Vector2i] = []
	
	if direction.x != 0:  # Horizontal movement
		perpendicular.append(Vector2i(0, 1))   # Up
		perpendicular.append(Vector2i(0, -1))  # Down
	elif direction.y != 0:  # Vertical movement
		perpendicular.append(Vector2i(1, 0))   # Right
		perpendicular.append(Vector2i(-1, 0))  # Left
	
	return perpendicular

func _is_position_valid_for_player(pos: Vector2i) -> bool:
	"""Check if a position is valid for the player to move to"""
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		print("Position ", pos, " is out of bounds")
		return false
	
	# Check if the position is occupied by an obstacle
	if course and "obstacle_map" in course:
		var obstacle = course.obstacle_map.get(pos)
		if obstacle and obstacle.has_method("blocks") and obstacle.blocks():
			print("Position ", pos, " is blocked by obstacle: ", obstacle.name)
			return false
	
	# Check if the position is occupied by another NPC
	if course:
		var entities = course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if npc != self and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						print("Position ", pos, " is occupied by NPC: ", npc.name)
						return false
	
	print("Position ", pos, " is valid for player pushback")
	return true

func _update_sprite_facing() -> void:
	"""Update the sprite facing direction based on facing_direction"""
	if not sprite:
		return
	
	# Flip sprite horizontally based on facing direction
	# Since the sprite image faces left by default, we need to invert the logic
	# If facing right (positive x), flip the sprite to face right
	if facing_direction.x > 0:
		sprite.flip_h = true
	elif facing_direction.x < 0:
		sprite.flip_h = false
	
	# Update ice sprite if it's visible
	if is_frozen and ice_sprite and ice_sprite.visible:
		_update_ice_sprite_facing()
	
	print("Updated sprite facing - Direction: ", facing_direction, ", Flip H: ", sprite.flip_h)

func _update_ice_sprite_facing() -> void:
	"""Update the ice sprite facing direction"""
	if not ice_sprite:
		return
	
	# Since the ice sprite image faces left by default, we need to invert the logic
	# If facing right (positive x), flip the sprite to face right
	if facing_direction.x > 0:
		ice_sprite.flip_h = true
	elif facing_direction.x < 0:
		ice_sprite.flip_h = false

func _setup_freeze_system():
	"""Setup the freeze effect system"""
	if ice_sprite:
		ice_sprite.visible = false

func apply_freeze_effect(turns: int):
	"""Apply freeze effect to the Wraith"""
	if is_dead:
		return
	
	print("=== WRAITH FREEZE EFFECT ===")
	print("Freeze turns: ", turns)
	
	is_frozen = true
	freeze_turns_remaining = turns
	
	# Show ice sprite
	if ice_sprite:
		ice_sprite.visible = true
		ice_sprite.modulate = Color.CYAN
	
	# Hide main sprite
	if sprite:
		sprite.visible = false
	
	# Switch collision areas
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
		print("✓ Disabled normal collision area")
	
	if ice_collision_area:
		ice_collision_area.monitoring = true
		ice_collision_area.monitorable = true
		# Connect to area_entered and area_exited signals for collision detection
		if not ice_collision_area.is_connected("area_entered", _on_base_area_entered):
			ice_collision_area.connect("area_entered", _on_base_area_entered)
		if not ice_collision_area.is_connected("area_exited", _on_area_exited):
			ice_collision_area.connect("area_exited", _on_area_exited)
		print("✓ Enabled ice collision area")
	
	print("✓ Wraith frozen for ", turns, " turns")

func remove_freeze_effect():
	"""Remove freeze effect from the Wraith"""
	if not is_frozen:
		return
	
	print("=== WRAITH FREEZE REMOVED ===")
	
	is_frozen = false
	freeze_turns_remaining = 0
	
	# Hide ice sprite
	if ice_sprite:
		ice_sprite.visible = false
		ice_sprite.modulate = original_modulate
	
	# Show main sprite
	if sprite:
		sprite.visible = true
	
	# Switch collision areas back
	if ice_collision_area:
		ice_collision_area.monitoring = false
		ice_collision_area.monitorable = false
		print("✓ Disabled ice collision area")
	
	if base_collision_area:
		base_collision_area.monitoring = true
		base_collision_area.monitorable = true
		print("✓ Enabled normal collision area")
	
	print("✓ Wraith freeze effect removed")

func update_freeze_turn():
	"""Update freeze effect for the current turn"""
	if not is_frozen:
		return
	
	freeze_turns_remaining -= 1
	print("Wraith freeze turns remaining: ", freeze_turns_remaining)
	
	if freeze_turns_remaining <= 0:
		remove_freeze_effect()

func update_z_index_for_ysort() -> void:
	"""Update Wraith Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

func get_y_sort_point() -> float:
	# Use ice Y-sort point when frozen
	if is_frozen and ice_ysort_point:
		return ice_ysort_point.global_position.y
	else:
		var ysort_point_node = get_node_or_null("YSortPoint")
		if ysort_point_node:
			return ysort_point_node.global_position.y
		else:
			return global_position.y

func get_base_collision_shape() -> Dictionary:
	"""Get the base collision shape dimensions for this Wraith"""
	return {
		"width": 10.0,
		"height": 6.5,
		"offset": Vector2(0, 25)  # Offset from Wraith center to base
	}

func handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by Entities system"""
	_handle_ball_collision(ball)

func _play_collision_sound() -> void:
	"""Play a sound effect when colliding with the player"""
	# Try to find an audio player in the course
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

func _play_death_sound() -> void:
	"""Play the death sound when the Wraith dies"""
	# Use the existing WraithHurt audio player on the Wraith
	var death_audio = get_node_or_null("WraithHurt")
	if death_audio:
		death_audio.volume_db = 0.0  # Set to full volume
		death_audio.play()
	else:
		pass

# Health-related utility methods
func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return float(current_health) / float(max_health)

func is_healthy() -> bool:
	"""Check if the Wraith is at full health"""
	return current_health >= max_health

func heal(amount: int) -> void:
	"""Heal the Wraith"""
	if not is_alive:
		return
	
	current_health = min(max_health, current_health + amount)
	print("Wraith healed", amount, "HP. Current health:", current_health, "/", max_health)
	
	# Update health bar
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)

# Height method for collision detection
func get_height() -> float:
	"""Get the height of this Wraith for collision detection"""
	# Use ice height marker when frozen
	if is_frozen and ice_top_height_marker:
		return ice_top_height_marker.global_position.y
	else:
		return Global.get_object_height_from_marker(self)

# State Machine Classes
class StateMachine:
	var states: Dictionary = {}
	var current_state: String = ""
	
	func add_state(state_name: String, state: Node) -> void:
		states[state_name] = state
	
	func set_state(state_name: String) -> void:
		if state_name in states:
			if current_state != "" and current_state in states:
				states[current_state].exit()
			current_state = state_name
			states[current_state].enter()
	
	func update() -> void:
		if current_state != "" and current_state in states:
			print("StateMachine updating state: ", current_state)
			states[current_state].update()
		else:
			print("StateMachine: No current state or state not found")

# Base State Class
class BaseState extends Node:
	var wraith: Node
	
	func _init(w: Node):
		wraith = w
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State - Wraith moves randomly on the green
class PatrolState extends BaseState:
	func enter() -> void:
		print("Wraith entering patrol state")
	
	func update() -> void:
		print("PatrolState update called")
		# Random movement up to 10 spaces away (but only on green tiles)
		var move_distance = randi_range(1, min(wraith.movement_range, 5))  # Limit to 5 for patrol
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != wraith.grid_position:
			print("Moving to new position")
			wraith._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			wraith.facing_direction = wraith.last_movement_direction
			wraith._update_sprite_facing()
			# Complete turn immediately since no movement is needed
			print("Patrol state calling _check_turn_completion()")
			wraith._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 20
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = wraith.grid_position + random_direction
			
			if wraith._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = wraith._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return wraith.grid_position

# Chase State - Wraith chases the player
class ChaseState extends BaseState:
	func enter() -> void:
		print("Wraith entering chase state")
	
	func update() -> void:
		print("ChaseState update called")
		if not wraith.player:
			print("No player found for chase")
			return
		
		var player_pos = wraith.player.grid_pos
		print("Player position: ", player_pos)
		var path = _get_path_to_player(player_pos)
		print("Chase path: ", path)
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards player
			print("Moving towards player to: ", next_pos)
			wraith._move_to_position(next_pos)
		else:
			print("No path found to player")
			# Complete turn immediately since no movement is needed
			wraith._check_turn_completion()
		
		# Always face the player when in chase mode
		wraith._face_player()
	
	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		"""Get path to player using simple pathfinding"""
		# Simple pathfinding - move towards player
		var path: Array[Vector2i] = [wraith.grid_position]
		var current_pos = wraith.grid_position
		var max_steps = wraith.movement_range
		var steps = 0
		
		print("Pathfinding - Starting from ", current_pos, " to ", player_pos, " with max steps: ", max_steps)
		
		while current_pos != player_pos and steps < max_steps:
			var direction = (player_pos - current_pos)
			# Normalize the direction vector for Vector2i
			if direction.x != 0:
				direction.x = 1 if direction.x > 0 else -1
			if direction.y != 0:
				direction.y = 1 if direction.y > 0 else -1
			var next_pos = current_pos + direction
			
			print("Pathfinding step ", steps, " - Direction: ", direction, ", Next pos: ", next_pos)
			
			if wraith._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = wraith._get_valid_adjacent_positions()
				if adjacent.size() > 0:
					# Find the adjacent position closest to player
					var best_pos = adjacent[0]
					var best_distance = (best_pos - player_pos).length()
					
					for pos in adjacent:
						var distance = (pos - player_pos).length()
						if distance < best_distance:
							best_distance = distance
							best_pos = pos
					
					current_pos = best_pos
					path.append(current_pos)
					print("Pathfinding - Using adjacent position: ", current_pos)
				else:
					print("Pathfinding - No valid adjacent positions found")
					break
			
			steps += 1
		
		print("Pathfinding - Final path: ", path)
		return path

# Dead State
class DeadState extends BaseState:
	func enter() -> void:
		print("Wraith entering dead state")
	
	func update() -> void:
		print("DeadState update called")
		# Complete turn immediately when dead
		wraith._check_turn_completion()
	
	func exit() -> void:
		print("Wraith exiting dead state")

# Helper function to face player
func _face_player():
	"""Make the Wraith face the player"""
	if not player:
		return
	
	var direction_to_player = player.grid_pos - grid_position
	if direction_to_player != Vector2i.ZERO:
		# Normalize to get facing direction
		if abs(direction_to_player.x) > abs(direction_to_player.y):
			facing_direction = Vector2i(1 if direction_to_player.x > 0 else -1, 0)
		else:
			facing_direction = Vector2i(0, 1 if direction_to_player.y > 0 else -1)
		
		_update_sprite_facing()
