extends CharacterBody2D

# Wraith Boss NPC - handles Wraith-specific functions
# Integrates with the Entities system for turn management

signal turn_completed
signal boss_defeated

@onready var sprite: Sprite2D = $WraithSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# Wraith specific properties
var boss_type: String = "wraith"
var movement_range: int = 10  # Can move up to 10 tiles on the green
var vision_range: int = 15
var current_action: String = "idle"

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.4  # Slightly slower than GangMember for boss feel
var movement_start_position: Vector2

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)

# Health and damage properties
var max_health: int = 200  # Boss health
var current_health: int = 200
var is_alive: bool = true
var is_dead: bool = false

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
var dead_height: float = 50.0
var base_collision_area: Area2D

# Headshot mechanics (same as GangMember)
const HEADSHOT_MIN_HEIGHT = 150.0
const HEADSHOT_MAX_HEIGHT = 200.0
const HEADSHOT_MULTIPLIER = 1.5

func _is_headshot(ball_height: float) -> bool:
	"""Check if a ball/knife hit is a headshot based on height"""
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

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE, DEAD}
var current_state: State = State.PATROL
var state_machine: Node

# References
var player: Node
var course: Node

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	add_to_group("NPC")
	add_to_group("Boss")  # Special boss group
	
	# Get references to ice sprite and collision areas
	_setup_ice_references()
	
	# Connect to WorldTurnManager
	course = _find_course_script()
	print("Wraith course reference: ", course.name if course else "None")
	
	var world_turn_manager = null
	var possible_paths = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
	
	for path in possible_paths:
		if course and course.has_node(path):
			world_turn_manager = course.get_node(path)
			print("Found WorldTurnManager at path: ", path)
			break
	
	if world_turn_manager:
		print("Found WorldTurnManager: ", world_turn_manager.name)
		world_turn_manager.register_npc(self)
		world_turn_manager.npc_turn_started.connect(_on_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
		print("✓ Wraith registered with WorldTurnManager")
	else:
		print("✗ ERROR: Could not register with WorldTurnManager")
	
	# Initialize state machine (will be implemented in next chunk)
	# state_machine = StateMachine.new()
	# state_machine.add_state("patrol", PatrolState.new(self))
	# state_machine.add_state("chase", ChaseState.new(self))
	# state_machine.add_state("dead", DeadState.new(self))
	# state_machine.set_state("patrol")
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded with a longer delay
	call_deferred("_delayed_find_player")
	
	# Initialize freeze effect system
	_setup_freeze_system()

func _setup_ice_references() -> void:
	"""Setup references to ice sprite and collision areas"""
	ice_sprite = get_node_or_null("WraithIce")
	ice_collision_area = get_node_or_null("WraithIce/BaseArea2D")
	ice_top_height_marker = get_node_or_null("WraithIce/TopHeight")
	ice_ysort_point = get_node_or_null("WraithIce/YSortPoint")
	
	if ice_sprite:
		print("✓ WraithIce sprite reference found")
	else:
		print("✗ ERROR: WraithIce sprite not found!")
	
	if ice_collision_area:
		print("✓ WraithIce collision area reference found")
	else:
		print("✗ ERROR: WraithIce/BaseArea2D not found!")

func _find_course_script() -> Node:
	"""Find the course_1.gd script by searching up the scene tree"""
	var current_node = self
	while current_node:
		if current_node.get_script() and current_node.get_script().resource_path.ends_with("course_1.gd"):
			print("Found course_1.gd script at: ", current_node.name)
			return current_node
		current_node = current_node.get_parent()
	
	print("ERROR: Could not find course_1.gd script in scene tree!")
	return null

func _setup_base_collision() -> void:
	"""Setup the base collision area for ball detection"""
	base_collision_area = get_node_or_null("WraithBaseArea2D")
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		base_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		base_collision_area.connect("area_exited", _on_area_exited)
		print("✓ Wraith base collision area setup complete")
	else:
		print("✗ ERROR: WraithBaseArea2D not found!")
	
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

func _create_health_bar() -> void:
	"""Create and setup the health bar"""
	# Create container for health bar
	health_bar_container = Control.new()
	health_bar_container.name = "HealthBarContainer"
	health_bar_container.custom_minimum_size = Vector2(80, 40)  # Larger for boss
	health_bar_container.size = Vector2(80, 40)
	health_bar_container.position = Vector2(-40, -80)  # Position above the wraith
	health_bar_container.scale = Vector2(0.5, 0.5)  # Larger scale for boss
	add_child(health_bar_container)
	
	# Create health bar
	var health_bar_scene = preload("res://HealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar_container.add_child(health_bar)
	
	# Set initial health
	health_bar.set_health(current_health, max_health)

func _find_player_reference() -> void:
	"""Find the player reference for AI behavior"""
	# Try multiple methods to find the player
	player = null
	
	# Method 1: Look for player in the "player" group
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("✓ Wraith found player reference via group: Player")
		return
	
	# Method 2: Look for a node named "Player"
	player = get_tree().get_first_node_in_group("Player")
	if player:
		print("✓ Wraith found player reference via group: Player")
		return
	
	# Method 3: Search for player by name
	var player_node = get_tree().get_first_node_in_group("Player")
	if player_node:
		player = player_node
		print("✓ Wraith found player reference by name: Player")
		return
	
	# Method 4: Try to get player from course
	var course = _find_course_script()
	if course and course.has_method("get_player_reference"):
		player = course.get_player_reference()
		if player:
			print("✓ Wraith found player reference via course: Player")
			return
	
	# Method 5: Search the entire scene tree for a node with "Player" in the name
	var all_nodes = get_tree().get_nodes_in_group("")
	for node in all_nodes:
		if "Player" in node.name:
			player = node
			print("✓ Wraith found player reference by searching scene tree: Player")
			return
	
	# If still not found, try again after a delay
	print("✗ Wraith could not find player reference, will retry...")
	call_deferred("_retry_find_player")

func _delayed_find_player() -> void:
	"""Find player reference with a longer delay to ensure player is ready"""
	await get_tree().create_timer(2.0).timeout
	_find_player_reference()

func _retry_find_player() -> void:
	"""Retry finding the player reference after a delay"""
	await get_tree().create_timer(1.0).timeout
	_find_player_reference()

func _setup_freeze_system() -> void:
	"""Setup the freeze effect system"""
	original_modulate = sprite.modulate if sprite else Color.WHITE
	freeze_sound = preload("res://Sounds/Icy.mp3")

func _on_turn_started() -> void:
	"""Handle turn start for the Wraith"""
	if is_dead or is_frozen:
		_process_freeze_turn()
		return
	
	# Simple random movement within 10 tiles
	var move_distance = randi_range(1, movement_range)
	var target_pos = _get_random_position(move_distance)
	
	if target_pos != grid_position:
		_move_to_position(target_pos)
	else:
		# Face random direction when not moving
		var random_direction = Vector2i(
			randi_range(-1, 1),
			randi_range(-1, 1)
		)
		if random_direction != Vector2i.ZERO:
			facing_direction = random_direction
			_update_sprite_facing()
		_check_turn_completion()

func _on_turn_ended() -> void:
	"""Handle turn end for the Wraith"""
	turn_completed.emit()

func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collisions with the base collision area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the Wraith area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
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
	var wraith_height = Global.get_object_height_from_marker(self)
	
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
	if projectile_height > wraith_height:
		# Check for ice element and apply freeze effect
		if projectile.has_method("get_element"):
			var projectile_element = projectile.get_element()
			if projectile_element and projectile_element.name == "Ice":
				print("Ice element detected on projectile landing! Applying freeze effect")
				freeze()
	
	# Set the projectile's ground level to the Wraith height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(wraith_height)
	else:
		if "current_ground_level" in projectile:
			projectile.current_ground_level = wraith_height
			print("✓ Set projectile ground level to Wraith height:", wraith_height)

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the Wraith"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Get projectile height for freeze effect logic
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	
	var wraith_height = Global.get_object_height_from_marker(self)
	
	# Only apply freeze effect if projectile is below Wraith height
	if projectile_height < wraith_height:
		# Check for ice element and apply freeze effect
		if projectile.has_method("get_element"):
			var projectile_element = projectile.get_element()
			if projectile_element and projectile_element.name == "Ice":
				print("Ice element detected on projectile reflection! Applying freeze effect")
				freeze()
	
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
	
	# Use the Entities system for collision handling
	if entities_manager and entities_manager.has_method("handle_npc_ball_collision"):
		entities_manager.handle_npc_ball_collision(self, ball)
		return
	
	# Fallback to original collision logic
	if Global.is_object_above_obstacle(ball, self):
		print("Ball/knife is above Wraith entirely - passing through")
		return
	else:
		print("Ball/knife is within Wraith height - handling collision")
		
		# Check if this is a throwing knife
		if ball.has_method("is_throwing_knife") and ball.is_throwing_knife():
			_handle_knife_collision(ball)
		else:
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
			freeze()
	
	# Let the knife handle its own collision logic
	if knife.has_method("_handle_npc_collision"):
		knife._handle_npc_collision(self)
	else:
		_apply_knife_reflection(knife)

func _apply_knife_reflection(knife: Node2D) -> void:
	"""Apply reflection to knife when it hits the Wraith"""
	var knife_velocity = Vector2.ZERO
	if knife.has_method("get_velocity"):
		knife_velocity = knife.get_velocity()
	elif "velocity" in knife:
		knife_velocity = knife.velocity
	
	var knife_pos = knife.global_position
	var wraith_center = global_position
	
	# Calculate reflection direction
	var to_knife_direction = (knife_pos - wraith_center).normalized()
	var reflected_velocity = knife_velocity - 2 * knife_velocity.dot(to_knife_direction) * to_knife_direction
	
	# Apply reflected velocity
	if knife.has_method("set_velocity"):
		knife.set_velocity(reflected_velocity)
	elif "velocity" in knife:
		knife.velocity = reflected_velocity

func _handle_regular_ball_collision(ball: Node2D) -> void:
	"""Handle regular ball collision with Wraith"""
	print("Handling regular ball collision with Wraith")
	
	# Play collision sound
	_play_collision_sound()
	
	# Check for ice element and apply freeze effect
	if ball.has_method("get_element"):
		var ball_element = ball.get_element()
		if ball_element and ball_element.name == "Ice":
			print("Ice element detected on ball! Applying freeze effect")
			freeze()
	
	# Deal damage to the Wraith
	take_damage(10)  # Base damage from ball collision
	
	# Reflect the ball
	_reflect_projectile(ball)

func _play_collision_sound() -> void:
	"""Play collision sound for the Wraith"""
	# Play Wraith hurt sound
	var wraith_hurt = get_node_or_null("WraithHurt")
	if wraith_hurt:
		wraith_hurt.play()

func take_damage(damage: int) -> void:
	"""Take damage and handle health updates"""
	if is_dead:
		return
	
	# Check for headshot
	var is_headshot_hit = false
	if damage > 0:  # Only check headshot for positive damage
		is_headshot_hit = _is_headshot(damage)
		if is_headshot_hit:
			damage = int(damage * HEADSHOT_MULTIPLIER)
			print("HEADSHOT! Damage multiplied to:", damage)
	
	current_health -= damage
	print("Wraith took damage:", damage, "Current health:", current_health)
	
	# Play hurt sound
	_play_collision_sound()
	
	# Update health bar
	if health_bar:
		health_bar.set_health(current_health, max_health)
	
	# Check if dead
	if current_health <= 0:
		die()
	else:
		# Visual feedback for taking damage
		_flash_damage()

func _flash_damage() -> void:
	"""Flash the sprite when taking damage"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", original_modulate, 0.1)

func die() -> void:
	"""Handle Wraith death"""
	if is_dead:
		return
	
	is_dead = true
	is_alive = false
	current_health = 0
	
	print("Wraith has been defeated!")
	
	# Update health bar
	if health_bar:
		health_bar.set_health(current_health, max_health)
	
	# Visual feedback for death
	if sprite:
		sprite.modulate = Color(0.5, 0.5, 0.5, 0.8)  # Gray out
	
	# Play death sound if available
	var death_sound = get_node_or_null("DeathSound")
	if death_sound:
		death_sound.play()
	
	# Emit boss defeated signal
	boss_defeated.emit()

func freeze() -> void:
	"""Apply freeze effect to the Wraith"""
	if is_frozen or is_dead:
		return
	
	print("Wraith is frozen!")
	is_frozen = true
	freeze_turns_remaining = 2  # Freeze for 2 turns
	
	# Show ice sprite
	if ice_sprite:
		ice_sprite.visible = true
		sprite.visible = false
	
	# Play freeze sound
	if freeze_sound:
		var audio_player = AudioStreamPlayer2D.new()
		audio_player.stream = freeze_sound
		audio_player.volume_db = -10
		add_child(audio_player)
		audio_player.play()
		audio_player.finished.connect(func(): audio_player.queue_free())
	
	# Visual freeze effect
	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0, 0.8)  # Light blue tint

func unfreeze() -> void:
	"""Remove freeze effect from the Wraith"""
	if not is_frozen:
		return
	
	print("Wraith is unfrozen!")
	is_frozen = false
	freeze_turns_remaining = 0
	
	# Hide ice sprite
	if ice_sprite:
		ice_sprite.visible = false
		sprite.visible = true
	
	# Reset visual effects
	if sprite:
		sprite.modulate = original_modulate

func _process_freeze_turn() -> void:
	"""Process freeze effect for the current turn"""
	if is_frozen and freeze_turns_remaining > 0:
		freeze_turns_remaining -= 1
		print("Wraith freeze turns remaining:", freeze_turns_remaining)
		
		if freeze_turns_remaining <= 0:
			unfreeze()

# Movement and AI functions
func _move_to_position(target_grid_pos: Vector2i) -> void:
	"""Move the Wraith to a target grid position"""
	if is_moving or is_dead or is_frozen:
		return
	
	print("Wraith moving to grid position:", target_grid_pos)
	
	# Calculate world position
	var target_world_pos = Vector2(target_grid_pos.x * cell_size, target_grid_pos.y * cell_size)
	
	# Update facing direction based on movement
	var direction = target_grid_pos - grid_position
	if direction != Vector2i.ZERO:
		last_movement_direction = direction
		facing_direction = direction
		_update_sprite_facing()
	
	# Start movement animation
	is_moving = true
	movement_start_position = global_position
	
	# Create tween for smooth movement
	movement_tween = create_tween()
	movement_tween.tween_property(self, "global_position", target_world_pos, movement_duration)
	movement_tween.tween_callback(_on_movement_complete)
	
	# Update grid position
	grid_position = target_grid_pos

func _on_movement_complete() -> void:
	"""Handle completion of movement"""
	is_moving = false
	print("Wraith movement complete")
	_check_turn_completion()

func _update_sprite_facing() -> void:
	"""Update sprite facing direction"""
	if not sprite:
		return
	
	# Flip sprite based on facing direction
	if facing_direction.x < 0:
		sprite.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a grid position is valid for the Wraith to move to"""
	# For now, assume all positions on the green are valid
	# This can be enhanced later with proper green boundary detection
	return true

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions for the Wraith"""
	var adjacent: Array[Vector2i] = []
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	for direction in directions:
		var pos = grid_position + direction
		if _is_position_valid(pos):
			adjacent.append(pos)
	
	return adjacent

func _check_turn_completion() -> void:
	"""Check if the Wraith's turn is complete"""
	if not is_moving:
		print("Wraith turn complete")
		turn_completed.emit()

func _face_player() -> void:
	"""Make the Wraith face the player"""
	if not player:
		return
	
	var player_pos = player.global_position
	var direction = (player_pos - global_position).normalized()
	
	# Convert to grid direction
	var grid_direction = Vector2i(
		1 if direction.x > 0 else (-1 if direction.x < 0 else 0),
		1 if direction.y > 0 else (-1 if direction.y < 0 else 0)
	)
	
	if grid_direction != Vector2i.ZERO:
		facing_direction = grid_direction
		_update_sprite_facing()



func _get_random_position(max_distance: int) -> Vector2i:
	"""Get a random position within the movement range"""
	var attempts = 0
	var max_attempts = 10
	
	while attempts < max_attempts:
		var random_direction = Vector2i(
			randi_range(-max_distance, max_distance),
			randi_range(-max_distance, max_distance)
		)
		
		var target_pos = grid_position + random_direction
		
		if _is_position_valid(target_pos):
			return target_pos
		
		attempts += 1
	
	# If no valid position found, stay in place
	return grid_position
