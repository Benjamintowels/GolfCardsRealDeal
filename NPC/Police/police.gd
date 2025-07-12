extends CharacterBody2D

# Police NPC - handles Police-specific functions
# Integrates with the Entities system for turn management

# Coin explosion system
const CoinExplosionManager = preload("res://CoinExplosionManager.gd")

signal turn_completed

@onready var police_sprite: Sprite2D = $Police
@onready var police_aim_leftright_sprite: Sprite2D = $PoliceAimLeftRight
@onready var police_aim_up_sprite: Sprite2D = $PoliceAimUp
@onready var police_aim_down_sprite: Sprite2D = $PoliceAimDown
@onready var pistol_shot_sound: AudioStreamPlayer2D = $PistolShot
@onready var death_groan_sound: AudioStreamPlayer2D = $DeathGroan

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# Police specific properties
var movement_range: int = 2
var vision_range: int = 10
var attack_range: int = 10  # Same as vision range for immediate attack
var current_action: String = "idle"

# Sprite state management
enum SpriteState {NORMAL, AIMING, DEAD}
var current_sprite_state: SpriteState = SpriteState.NORMAL

# Aiming direction management
enum AimDirection {LEFT_RIGHT, UP, DOWN}
var current_aim_direction: AimDirection = AimDirection.LEFT_RIGHT

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3
var movement_start_position: Vector2  # Track where movement started

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)

# Health and damage properties
var max_health: int = 100
var current_health: int = 100
var is_alive: bool = true
var is_dead: bool = false

# Attack properties
var is_attacking: bool = false
var attack_damage: int = 50
var attack_cooldown: float = 2.0
var last_attack_time: float = -10.0  # Start with negative value so first attack is allowed

# Turn safety properties
var turn_start_time: float = 0.0
var max_turn_duration: float = 5.0  # Maximum time a turn can take before forcing completion
var is_my_turn: bool = false  # Track if this Police is currently taking its turn

# Collision and height properties
var base_collision_area: Area2D

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE, ATTACK, DEAD}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

func _ready():
	add_to_group("NPC")
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	
	# Connect to WorldTurnManager
	course = _find_course_script()
	print("Police course reference: ", course.name if course else "None")
	
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
		world_turn_manager.register_npc(self)
		world_turn_manager.npc_turn_started.connect(_on_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
		print("✓ Police registered with WorldTurnManager")
	else:
		print("✗ ERROR: Could not register with WorldTurnManager")
		print("Tried paths: ", possible_paths)
	
	# Initialize state machine
	state_machine = StateMachine.new()
	state_machine.add_state("patrol", PatrolState.new(self))
	state_machine.add_state("chase", ChaseState.new(self))
	state_machine.add_state("attack", AttackState.new(self))
	state_machine.add_state("dead", DeadState.new(self))
	state_machine.set_state("patrol")
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded
	call_deferred("_find_player_reference")

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
	base_collision_area = get_node_or_null("BaseCollisionArea")
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		base_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		base_collision_area.connect("area_exited", _on_area_exited)
		print("✓ Police base collision area setup complete")
	else:
		print("✗ ERROR: BaseCollisionArea not found!")
	
	# Setup HitBox for gun collision detection
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		# Set collision layer to 2 so gun can detect it (separate from golf balls on layer 1)
		hitbox.collision_layer = 2
		# Set collision mask to 0 (gun doesn't need to detect this)
		hitbox.collision_mask = 0
		print("✓ Police HitBox setup complete for gun collision (layer 2)")
	else:
		print("✗ ERROR: HitBox not found!")

func _create_health_bar() -> void:
	"""Create and setup the health bar"""
	# Create container for health bar
	health_bar_container = Control.new()
	health_bar_container.name = "HealthBarContainer"
	health_bar_container.custom_minimum_size = Vector2(60, 30)
	health_bar_container.size = Vector2(60, 30)
	health_bar_container.position = Vector2(-30, 11.145)
	health_bar_container.scale = Vector2(0.35, 0.35)
	add_child(health_bar_container)
	
	# Create health bar
	var health_bar_scene = preload("res://HealthBar.tscn")
	health_bar = health_bar_scene.instantiate()
	health_bar_container.add_child(health_bar)
	
	# Set initial health
	health_bar.set_health(current_health, max_health)

func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collisions with the base collision area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		_handle_area_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the Police area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _on_dead_area_entered(area: Area2D) -> void:
	"""Handle collisions with the dead Police area"""
	var projectile = area.get_parent()
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		_handle_dead_area_collision(projectile)

func _on_dead_area_exited(area: Area2D) -> void:
	"""Handle when projectile exits the dead Police area - reset ground level"""
	var projectile = area.get_parent()
	if projectile and projectile.has_method("get_height"):
		if projectile.has_method("_reset_ground_level"):
			projectile._reset_ground_level()
		else:
			if "current_ground_level" in projectile:
				projectile.current_ground_level = 0.0

func _handle_dead_area_collision(projectile: Node2D):
	"""Handle dead Police area collisions using proper Area2D detection"""
	print("=== HANDLING DEAD POLICE AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and dead Police heights
	var projectile_height = projectile.get_height()
	var dead_police_height = Global.get_object_height_from_marker(get_node_or_null("Dead"))
	
	print("Projectile height:", projectile_height)
	print("Dead Police height:", dead_police_height)
	
	# Apply the collision logic:
	# If projectile height > dead Police height: allow entry and set ground level
	# If projectile height < dead Police height: reflect
	if projectile_height > dead_police_height:
		print("✓ Projectile is above dead Police - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, dead_police_height)
	else:
		print("✗ Projectile is below dead Police height - reflecting")
		_reflect_projectile(projectile)

func _handle_area_collision(projectile: Node2D):
	"""Handle Police area collisions using proper Area2D detection"""
	print("=== HANDLING POLICE AREA COLLISION ===")
	print("Projectile name:", projectile.name)
	
	# Check if projectile has height information
	if not projectile.has_method("get_height"):
		print("✗ Projectile doesn't have height method - using fallback reflection")
		_reflect_projectile(projectile)
		return
	
	# Get projectile and Police heights
	var projectile_height = projectile.get_height()
	var police_height = Global.get_object_height_from_marker(self)
	
	print("Projectile height:", projectile_height)
	print("Police height:", police_height)
	
	# Apply the collision logic:
	# If projectile height > Police height: allow entry and set ground level
	# If projectile height < Police height: reflect
	if projectile_height > police_height:
		print("✓ Projectile is above Police - allowing entry and setting ground level")
		_allow_projectile_entry(projectile, police_height)
	else:
		print("✗ Projectile is below Police height - reflecting")
		_reflect_projectile(projectile)

func _allow_projectile_entry(projectile: Node2D, police_height: float):
	"""Allow projectile to enter Police area and set ground level"""
	print("=== ALLOWING PROJECTILE ENTRY (POLICE) ===")
	
	# Set the projectile's ground level to the Police height
	if projectile.has_method("_set_ground_level"):
		projectile._set_ground_level(police_height)
	else:
		if "current_ground_level" in projectile:
			projectile.current_ground_level = police_height
			print("✓ Set projectile ground level to Police height:", police_height)

func _reflect_projectile(projectile: Node2D):
	"""Reflect projectile off the Police"""
	print("=== REFLECTING PROJECTILE ===")
	
	# Get the projectile's current velocity
	var projectile_velocity = Vector2.ZERO
	if projectile.has_method("get_velocity"):
		projectile_velocity = projectile.get_velocity()
	elif "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	var projectile_pos = projectile.global_position
	var police_center = global_position
	
	# Calculate the direction from Police center to projectile
	var to_projectile_direction = (projectile_pos - police_center).normalized()
	
	# Simple reflection: reflect the velocity across the Police center
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
	"""Handle collision with a ball - called by collision system"""
	# Use the Entities system for collision handling (includes moving NPC push system)
	if entities_manager and entities_manager.has_method("handle_npc_ball_collision"):
		entities_manager.handle_npc_ball_collision(self, ball)
		return
	
	# Fallback to original collision logic if Entities system is not available
	# This method is required for the player's jump roof bounce system
	# The actual collision logic is handled in _handle_area_collision
	# This method just ensures the Police can be detected by the jump system
	_handle_area_collision(ball)

func _find_player_reference() -> void:
	"""Find the player reference in the scene"""
	# First try to find the player by name
	player = get_tree().get_first_node_in_group("players")
	if player:
		print("✓ Police found player reference via group: ", player.name)
		return
	
	# Fallback: search for any node with grid_pos property and take_damage method
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	
	for node in all_nodes:
		if "grid_pos" in node and node.has_method("take_damage"):
			player = node
			print("✓ Police found player reference via search: ", player.name)
			break
	
	if not player:
		print("✗ ERROR: Police could not find player reference!")

func take_turn() -> void:
	"""Take the Police's turn"""
	print("=== POLICE TURN STARTED ===")
	
	# Mark that this is our turn
	is_my_turn = true
	
	# Record turn start time for safety timeout
	turn_start_time = Time.get_ticks_msec() / 1000.0
	
	if is_dead:
		print("Police is dead, skipping turn")
		_complete_turn()
		return
	
	# Check player vision and update state
	_check_player_vision()
	
	# Update state machine
	state_machine.update()
	
	# Check if turn was already completed by the state machine
	if not is_my_turn:
		print("Turn was completed by state machine, exiting take_turn()")
		return
	
	# Start safety timer to prevent turn from getting stuck
	_start_turn_safety_timer()
	
	print("=== POLICE TURN PROCESSING ===")

func _start_turn_safety_timer() -> void:
	"""Start a safety timer to prevent turns from getting stuck"""
	# Create a timer that will force turn completion if it takes too long
	var safety_timer = get_tree().create_timer(max_turn_duration)
	safety_timer.timeout.connect(_on_turn_safety_timeout)

func _on_turn_safety_timeout() -> void:
	"""Called when the turn safety timer expires - force turn completion"""
	# Only act if this is actually our turn
	if not is_my_turn:
		print("Safety timeout triggered but not our turn - ignoring")
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var turn_duration = current_time - turn_start_time
	
	print("⚠️ TURN SAFETY TIMEOUT - Turn has been running for ", turn_duration, " seconds")
	print("⚠️ Forcing turn completion to prevent game lock")
	
	# Force completion of any ongoing actions
	is_attacking = false
	is_moving = false
	
	# Ensure normal sprite is visible
	if not is_dead:
		ensure_normal_sprite_visible()
	
	# Force turn completion
	_complete_turn()

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to appropriate state"""
	if not player or is_dead:
		if is_dead:
			print("Police is dead, skipping vision check")
		else:
			print("No player reference found for vision check")
		return
	
	print("=== POLICE VISION CHECK ===")
	print("Police position:", grid_position)
	print("Player reference:", player.name if player else "None")
	print("Player has grid_pos:", "grid_pos" in player)
	
	var player_pos = player.grid_pos
	var distance = grid_position.distance_to(player_pos)
	
	print("Vision check - Player at ", player_pos, ", Police at ", grid_position, ", distance: ", distance, ", vision range: ", vision_range, ", attack range: ", attack_range)
	
	if distance <= attack_range:
		if current_state != State.ATTACK:
			print("Player in attack range! Switching to attack state")
			current_state = State.ATTACK
			state_machine.set_state("attack")
		else:
			print("Already in attack state, player still in range")
		
		# Face the player when in attack mode
		_face_player()
	elif distance <= vision_range:
		if current_state != State.CHASE:
			print("Player detected! Switching to chase state")
			current_state = State.CHASE
			state_machine.set_state("chase")
		else:
			print("Already in chase state, player still in range")
		
		# Face the player when in chase mode
		_face_player()
	else:
		if current_state != State.PATROL:
			print("Player out of range, returning to patrol")
			current_state = State.PATROL
			state_machine.set_state("patrol")
		else:
			print("Already in patrol state, player still out of range")
	
	print("=== END VISION CHECK ===")

func _on_turn_started(npc: Node) -> void:
	"""Called when an NPC's turn starts"""
	if npc == self:
		print("Police turn started: ", name)

func _on_turn_ended(npc: Node) -> void:
	"""Called when an NPC's turn ends"""
	if npc == self:
		print("Police turn ended: ", name)

func _complete_turn() -> void:
	"""Complete the current turn"""
	print("=== POLICE COMPLETING TURN ===")
	print("Police: ", name)
	print("Setting is_my_turn to false")
	is_my_turn = false
	
	# Ensure we're not in an attacking state when completing turn
	if is_attacking:
		print("⚠️ WARNING: Police is still attacking when completing turn - forcing completion")
		is_attacking = false
		_switch_to_normal_sprite()
	
	# Ensure normal sprite is visible (unless dead)
	if not is_dead:
		ensure_normal_sprite_visible()
	
	print("Emitting turn_completed signal")
	turn_completed.emit()
	print("Turn completed signal emitted successfully")
	
	# Note: Entities manager notification removed - turn management now handled by course_1.gd
	
	print("=== END POLICE TURN COMPLETION ===")

func get_grid_position() -> Vector2i:
	"""Get the current grid position"""
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	"""Set the grid position and update world position"""
	grid_position = pos
	position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions the Police can move to"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_position_valid(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a position is valid for the Police to move to"""
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# Check if position is occupied by the player
	if player and player.grid_pos == pos:
		print("Position ", pos, " is occupied by player")
		return false
	
	# For now, allow movement to any position within bounds
	return true

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the Police to a new position with smooth animation"""
	if is_dead:
		print("Police is dead, cannot move")
		_check_turn_completion()
		return
	
	var old_pos = grid_position
	grid_position = target_pos
	
	# Calculate movement direction and update facing
	var movement_direction = target_pos - old_pos
	if movement_direction != Vector2i.ZERO:
		last_movement_direction = movement_direction
		# Only update facing direction in patrol mode (not when chasing player)
		if current_state == State.PATROL:
			facing_direction = last_movement_direction
			_update_sprite_facing()
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Animated movement using tween
	_animate_movement_to_position(target_world_pos)
	
	print("Police moving from ", old_pos, " to ", target_pos, " with direction: ", movement_direction)

func _animate_movement_to_position(target_world_pos: Vector2) -> void:
	"""Animate the Police's movement to the target position using a tween"""
	if is_dead:
		print("Police is dead, cannot animate movement")
		_check_turn_completion()
		return
	
	# Set moving state
	is_moving = true
	
	# Store the starting position for movement direction calculation
	movement_start_position = global_position
	
	# Stop any existing movement tween
	if movement_tween and movement_tween.is_valid():
		movement_tween.kill()
	
	# Create new tween for movement
	movement_tween = create_tween()
	movement_tween.set_trans(Tween.TRANS_QUAD)
	movement_tween.set_ease(Tween.EASE_OUT)
	
	# Start the movement animation
	movement_tween.tween_property(self, "position", target_world_pos, movement_duration)
	
	# Update Y-sorting during movement
	movement_tween.tween_callback(update_z_index_for_ysort)
	
	# When movement completes
	movement_tween.tween_callback(_on_movement_completed)
	
	print("Started movement animation to position: ", target_world_pos)

func _on_movement_completed() -> void:
	"""Called when movement animation completes"""
	is_moving = false
	print("Police movement animation completed")
	
	# Only ensure normal sprite if not currently attacking and not dead
	if not is_attacking and not is_dead:
		ensure_normal_sprite_visible()
	
	# Update Y-sorting one final time
	update_z_index_for_ysort()
	
	# Check if we can complete the turn now
	_check_turn_completion()

func _check_turn_completion() -> void:
	"""Check if the turn can be completed (waits for movement animation to finish)"""
	print("=== POLICE TURN COMPLETION CHECK ===")
	print("Police: ", name)
	print("Is my turn: ", is_my_turn)
	print("Is moving: ", is_moving)
	print("Is attacking: ", is_attacking)
	print("Is dead: ", is_dead)
	print("Current state: ", current_state)
	
	# Only check turn completion if this is actually our turn
	if not is_my_turn:
		print("Turn completion check called but not our turn - ignoring")
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	# Check for turn timeout
	var current_time = Time.get_ticks_msec() / 1000.0
	var turn_duration = current_time - turn_start_time
	
	if turn_duration > max_turn_duration:
		print("⚠️ TURN TIMEOUT DETECTED - Forcing completion after ", turn_duration, " seconds")
		_complete_turn()
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	if is_moving:
		print("Police is still moving, waiting for animation to complete...")
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	if is_attacking:
		print("Police is still attacking, waiting for animation to complete...")
		print("=== END TURN COMPLETION CHECK ===")
		return
	
	# Ensure normal sprite is visible before completing turn (unless dead or attacking)
	if not is_dead and not is_attacking:
		ensure_normal_sprite_visible()
	
	# Final sprite state verification
	_verify_sprite_state()
	
	print("Police movement finished, completing turn")
	_complete_turn()
	print("=== END TURN COMPLETION CHECK ===")

func _verify_sprite_state() -> void:
	"""Verify that sprite visibility matches the current sprite state"""
	if is_dead:
		if current_sprite_state != SpriteState.DEAD:
			print("⚠️ WARNING: Police is dead but sprite state is not DEAD!")
			current_sprite_state = SpriteState.DEAD
		return
	
	if is_attacking:
		if current_sprite_state != SpriteState.AIMING:
			print("⚠️ WARNING: Police is attacking but sprite state is not AIMING!")
			current_sprite_state = SpriteState.AIMING
		return
	
	# Should be in normal state
	if current_sprite_state != SpriteState.NORMAL:
		print("⚠️ WARNING: Police should be in normal state but sprite state is: ", current_sprite_state)
		current_sprite_state = SpriteState.NORMAL
		ensure_normal_sprite_visible()

func _face_player() -> void:
	"""Face the player"""
	if not player or is_dead:
		return
	
	var player_pos = player.grid_pos
	var direction = player_pos - grid_position
	
	if direction.x != 0 or direction.y != 0:
		# Normalize the direction vector for Vector2i
		if direction.x != 0:
			direction.x = 1 if direction.x > 0 else -1
		if direction.y != 0:
			direction.y = 1 if direction.y > 0 else -1
		
		facing_direction = direction
		_update_sprite_facing()

func _update_sprite_facing() -> void:
	"""Update the sprite facing direction based on facing_direction"""
	if not police_sprite or is_dead:
		return
	
	# Flip sprite horizontally based on facing direction
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		police_sprite.flip_h = true
		if police_aim_leftright_sprite:
			police_aim_leftright_sprite.flip_h = true
	elif facing_direction.x > 0:
		police_sprite.flip_h = false
		if police_aim_leftright_sprite:
			police_aim_leftright_sprite.flip_h = false
	
	print("Updated sprite facing - Direction: ", facing_direction, ", Flip H: ", police_sprite.flip_h)

func _determine_aim_direction() -> AimDirection:
	"""Determine which direction to aim based on player position"""
	if not player:
		return AimDirection.LEFT_RIGHT
	
	var player_pos = player.grid_pos
	var direction = player_pos - grid_position
	
	# Calculate the absolute differences
	var abs_x = abs(direction.x)
	var abs_y = abs(direction.y)
	
	# Determine which direction has the greater difference
	if abs_y > abs_x:
		# Vertical difference is greater
		if direction.y > 0:
			return AimDirection.DOWN  # Player is below
		else:
			return AimDirection.UP    # Player is above
	else:
		# Horizontal difference is greater or equal
		return AimDirection.LEFT_RIGHT  # Player is to the left or right

func _switch_to_directional_aim_sprite() -> void:
	"""Switch to the appropriate aim sprite based on player direction"""
	if is_dead:
		return
	
	current_sprite_state = SpriteState.AIMING
	
	# Determine which direction to aim
	current_aim_direction = _determine_aim_direction()
	
	# Hide all aim sprites first
	if police_aim_leftright_sprite:
		police_aim_leftright_sprite.visible = false
	if police_aim_up_sprite:
		police_aim_up_sprite.visible = false
	if police_aim_down_sprite:
		police_aim_down_sprite.visible = false
	
	# Show the appropriate aim sprite
	match current_aim_direction:
		AimDirection.LEFT_RIGHT:
			if police_aim_leftright_sprite:
				police_aim_leftright_sprite.visible = true
				print("✓ Police switched to LEFT_RIGHT aim sprite")
		AimDirection.UP:
			if police_aim_up_sprite:
				police_aim_up_sprite.visible = true
				print("✓ Police switched to UP aim sprite")
		AimDirection.DOWN:
			if police_aim_down_sprite:
				police_aim_down_sprite.visible = true
				print("✓ Police switched to DOWN aim sprite")
	
	# Hide the normal sprite
	if police_sprite:
		police_sprite.visible = false

func update_z_index_for_ysort() -> void:
	"""Update Police Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

func get_y_sort_point() -> float:
	# Use dead sprite's Y-sort point if Police is dead
	if is_dead:
		var dead_ysort_point = get_node_or_null("Dead/YSortPoint")
		if dead_ysort_point:
			return dead_ysort_point.global_position.y
		else:
			# Fallback to dead sprite's position
			var dead_sprite = get_node_or_null("Dead")
			if dead_sprite:
				return dead_sprite.global_position.y
	
	# Use normal sprite's Y-sort point
	var ysort_point_node = get_node_or_null("Police/YSortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func setup(pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the Police with specific parameters"""
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("Police setup at ", pos)

func take_damage(amount: int, is_headshot: bool = false, weapon_position: Vector2 = Vector2.ZERO) -> void:
	"""Take damage and handle death if health reaches 0"""
	if not is_alive:
		print("Police is already dead, ignoring damage")
		return
	
	current_health = current_health - amount
	print("Police took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Update health bar
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)
	
	# Flash damage effect
	flash_damage()
	
	if current_health <= 0 and not is_dead:
		print("Police health reached 0, calling die()")
		die()
	else:
		print("Police survived with", current_health, "health")

func flash_damage() -> void:
	"""Flash the Police red to indicate damage taken"""
	if not police_sprite:
		return
	
	var original_modulate = police_sprite.modulate
	var tween = create_tween()
	tween.tween_property(police_sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(police_sprite, "modulate", original_modulate, 0.2)

func _play_collision_sound() -> void:
	"""Play collision sound for Police"""
	# For now, just print a message - you can add actual sound effects later
	print("Police collision sound played")

func _trigger_coin_explosion() -> void:
	"""Trigger a coin explosion when the Police dies"""
	# Use the static method from CoinExplosionManager
	CoinExplosionManager.trigger_coin_explosion(global_position)
	print("✓ Triggered coin explosion for Police at:", global_position)

func die() -> void:
	"""Handle Police death"""
	if is_dead:
		return
	
	print("=== POLICE DEATH ===")
	is_dead = true
	is_alive = false
	
	# Play death sound
	if death_groan_sound:
		death_groan_sound.play()
	
	# Trigger coin explosion
	_trigger_coin_explosion()
	
	# Switch to dead state
	current_state = State.DEAD
	state_machine.set_state("dead")
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Switch to dead collision system
	_switch_to_dead_collision()
	
	# Update sprite state to dead
	current_sprite_state = SpriteState.DEAD
	
	# Hide normal sprites
	if police_sprite:
		police_sprite.visible = false
	if police_aim_leftright_sprite:
		police_aim_leftright_sprite.visible = false
	if police_aim_up_sprite:
		police_aim_up_sprite.visible = false
	if police_aim_down_sprite:
		police_aim_down_sprite.visible = false
	
	# Show dead sprite
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite:
		dead_sprite.visible = true
		print("✓ Police dead sprite activated")
	else:
		print("✗ ERROR: Dead sprite not found!")

func attack_player() -> void:
	"""Attack the player with a pistol shot"""
	if is_attacking or not player or is_dead:
		if is_dead:
			print("Police is dead, cannot attack")
		_check_turn_completion()
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
	var time_since_last_attack = current_time - last_attack_time
	
	if time_since_last_attack < attack_cooldown:
		print("Attack on cooldown, time remaining:", attack_cooldown - time_since_last_attack)
		# Ensure normal sprite is visible when attack is on cooldown
		ensure_normal_sprite_visible()
		_check_turn_completion()
		return
	
	print("=== POLICE ATTACKING PLAYER ===")
	is_attacking = true
	last_attack_time = current_time
	
	# Switch to aim sprite
	_switch_to_aim_sprite()
	
	# Play pistol shot sound
	if pistol_shot_sound:
		pistol_shot_sound.play()
	
	# Perform raycast to check if player is in line of sight
	var hit_target = _perform_attack_raycast()
	if hit_target:
		# Deal damage to whatever was hit
		if hit_target.has_method("take_damage"):
			hit_target.take_damage(attack_damage)
			print("Police dealt", attack_damage, "damage to", hit_target.name)
		else:
			print("Target doesn't have take_damage method")
	else:
		print("No target hit, attack missed")
	
	# Switch back to normal sprite after a delay
	# Use a timer that won't block the turn completion
	var attack_timer = get_tree().create_timer(0.5)
	attack_timer.timeout.connect(_on_attack_timer_completed)

func _on_attack_timer_completed() -> void:
	"""Called when the attack timer completes"""
	print("=== POLICE ATTACK TIMER COMPLETED ===")
	_switch_to_normal_sprite()
	
	is_attacking = false
	
	# Only check turn completion if this is our turn
	if is_my_turn:
		_check_turn_completion()
	else:
		print("Attack timer completed but not our turn - not checking turn completion")

func _switch_to_aim_sprite() -> void:
	"""Switch to the aiming sprite"""
	if is_dead:
		# If dead, don't switch sprites - keep dead sprite visible
		return
	
	# Use the new directional aiming system
	_switch_to_directional_aim_sprite()

func _switch_to_normal_sprite() -> void:
	"""Switch back to the normal sprite"""
	if is_dead:
		# If dead, don't switch sprites - keep dead sprite visible
		return
	
	current_sprite_state = SpriteState.NORMAL
	if police_sprite:
		police_sprite.visible = true
	if police_aim_leftright_sprite:
		police_aim_leftright_sprite.visible = false
	if police_aim_up_sprite:
		police_aim_up_sprite.visible = false
	if police_aim_down_sprite:
		police_aim_down_sprite.visible = false
	print("✓ Police switched to normal sprite")

func ensure_normal_sprite_visible() -> void:
	"""Safety function to ensure the normal sprite is visible when not attacking"""
	if is_dead:
		# If dead, ensure dead sprite is visible and normal sprites are hidden
		current_sprite_state = SpriteState.DEAD
		var dead_sprite = get_node_or_null("Dead")
		if dead_sprite:
			dead_sprite.visible = true
		if police_sprite:
			police_sprite.visible = false
		if police_aim_leftright_sprite:
			police_aim_leftright_sprite.visible = false
		if police_aim_up_sprite:
			police_aim_up_sprite.visible = false
		if police_aim_down_sprite:
			police_aim_down_sprite.visible = false
		print("✓ Police dead sprite visibility ensured")
		return
	
	# Only switch to normal if not currently attacking
	if not is_attacking:
		current_sprite_state = SpriteState.NORMAL
		if police_sprite:
			police_sprite.visible = true
		if police_aim_leftright_sprite:
			police_aim_leftright_sprite.visible = false
		if police_aim_up_sprite:
			police_aim_up_sprite.visible = false
		if police_aim_down_sprite:
			police_aim_down_sprite.visible = false
		print("✓ Police normal sprite visibility ensured")

func _switch_to_dead_collision() -> void:
	"""Switch to the dead collision system"""
	print("=== SWITCHING TO DEAD COLLISION SYSTEM ===")
	
	# Disable normal collision areas
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
		print("✓ Disabled base collision area")
	
	var hitbox = get_node_or_null("HitBox")
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
		print("✓ Disabled HitBox")
	
	# Enable dead collision area
	var dead_area = get_node_or_null("Dead/Area2D")
	if dead_area:
		dead_area.monitoring = true
		dead_area.monitorable = true
		# Set collision layer to 1 so golf balls can detect it
		dead_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		dead_area.collision_mask = 1
		# Connect to area_entered and area_exited signals for collision detection
		if not dead_area.area_entered.is_connected(_on_dead_area_entered):
			dead_area.connect("area_entered", _on_dead_area_entered)
		if not dead_area.area_exited.is_connected(_on_dead_area_exited):
			dead_area.connect("area_exited", _on_dead_area_exited)
		print("✓ Enabled dead collision area")
	else:
		print("✗ ERROR: Dead Area2D not found!")
	
	print("=== DEAD COLLISION SYSTEM ACTIVATED ===")

func _perform_attack_raycast() -> Node:
	"""Perform a raycast to check what's in the line of fire"""
	if not player:
		return null
	
	print("=== POLICE RAYCAST DEBUG ===")
	
	# Get the bullet origin position
	var bullet_origin = get_node_or_null("BulletOrigin")
	if not bullet_origin:
		print("✗ ERROR: BulletOrigin marker not found!")
		return null
	
	var bullet_start_pos = bullet_origin.global_position
	print("Bullet origin position:", bullet_start_pos)
	print("Player position:", player.global_position)
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(bullet_start_pos, player.global_position)
	query.collision_mask = 2  # Layer 2 for HitBoxes (weapons layer)
	query.collide_with_bodies = false
	query.collide_with_areas = true
	
	print("Raycast from", bullet_start_pos, "to", player.global_position, "on layer 2")
	
	var result = space_state.intersect_ray(query)
	
	if result:
		print("✓ Raycast hit something!")
		# Check if the hit object is a HitBox
		var hit_object = result.collider
		print("Hit object:", hit_object.name, "Type:", hit_object.get_class())
		
		if hit_object.name == "HitBox":
			var parent = hit_object.get_parent()
			print("HitBox parent:", parent.name if parent else "None")
			
			# Check if this is our own HitBox - if so, ignore it
			if parent == self:
				print("✗ Hit our own HitBox - ignoring")
				return null
			
			if parent and parent.has_method("take_damage"):
				print("✓ HitBox parent has take_damage method - returning parent")
				return parent  # Return the parent object (player, NPC, etc.)
			else:
				print("✗ HitBox parent doesn't have take_damage method")
				return null
		else:
			print("✗ Raycast hit non-HitBox object:", hit_object.name)
			return null
	else:
		print("✗ Raycast missed - no HitBoxes hit")
		# No HitBoxes hit, check if player is directly in the path
		var distance = bullet_start_pos.distance_to(player.global_position)
		print("Distance to player:", distance, "pixels, attack range:", attack_range * 48, "pixels")
		
		if distance <= attack_range * 48:  # Convert tiles to pixels
			# Check if player is in the direct line of fire
			var direction = (player.global_position - bullet_start_pos).normalized()
			var to_player = player.global_position - bullet_start_pos
			var dot_product = to_player.normalized().dot(direction)
			
			print("Dot product for direct line check:", dot_product)
			
			if dot_product > 0.99:  # Very precise aim required
				print("✓ Player in direct line of fire - returning player")
				return player
			else:
				print("✗ Player not in direct line of fire")
		else:
			print("✗ Player too far away")
		
		print("=== END RAYCAST DEBUG ===")
		return null

# State Machine Class
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
	var police: Node
	
	func _init(p: Node):
		police = p
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State
class PatrolState extends BaseState:
	func enter() -> void:
		print("Police entering patrol state")
		# Ensure normal sprite is visible when entering patrol state
		police.ensure_normal_sprite_visible()
	
	func exit() -> void:
		print("Police exiting patrol state")
	
	func update() -> void:
		print("PatrolState update called")
		# Random movement up to 2 spaces away
		var move_distance = randi_range(1, police.movement_range)
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != police.grid_position:
			print("Moving to new position")
			police._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			police.facing_direction = police.last_movement_direction
			police._update_sprite_facing()
			# Complete turn immediately since no movement is needed
			print("Patrol state calling _check_turn_completion()")
			police._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 10
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = police.grid_position + random_direction
			
			if police._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = police._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return police.grid_position

# Chase State
class ChaseState extends BaseState:
	func enter() -> void:
		print("Police entering chase state")
		# Ensure normal sprite is visible when entering chase state
		police.ensure_normal_sprite_visible()
	
	func exit() -> void:
		print("Police exiting chase state")
		# Ensure normal sprite is visible when leaving chase state
		police.ensure_normal_sprite_visible()
	
	func update() -> void:
		print("ChaseState update called")
		if not police.player:
			print("No player found for chase")
			return
		
		var player_pos = police.player.grid_pos
		print("Player position: ", player_pos)
		var path = _get_path_to_player(player_pos)
		print("Chase path: ", path)
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards player
			print("Moving towards player to: ", next_pos)
			police._move_to_position(next_pos)
		else:
			print("No path found to player")
			# Complete turn immediately since no movement is needed
			police._check_turn_completion()
		
		# Always face the player when in chase mode
		police._face_player()

	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards player
		var path: Array[Vector2i] = [police.grid_position]
		var current_pos = police.grid_position
		var max_steps = police.movement_range
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
			
			if police._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = police._get_valid_adjacent_positions()
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

# Attack State
class AttackState extends BaseState:
	func enter() -> void:
		print("Police entering attack state")
	
	func update() -> void:
		print("=== ATTACK STATE UPDATE ===")
		if not police.player:
			print("No player found for attack")
			return
		
		print("Police in attack state, calling attack_player()")
		# Attack the player
		police.attack_player()
		print("=== END ATTACK STATE UPDATE ===")
	
	func exit() -> void:
		print("Police exiting attack state")
		# Ensure normal sprite is visible when leaving attack state
		police.ensure_normal_sprite_visible()

# Dead State
class DeadState extends BaseState:
	func enter() -> void:
		print("Police entering dead state")
		# Hide health bar
		if police.health_bar_container:
			police.health_bar_container.visible = false
	
	func update() -> void:
		# Dead Police don't move or take actions
		pass
	
	func exit() -> void:
		pass

func is_currently_ragdolling() -> bool:
	"""Check if the Police is currently ragdolling"""
	return false  # Police don't have ragdoll system

# Ball pushing system methods
func get_movement_direction() -> Vector2:
	"""Get the current movement direction as a Vector2"""
	# If currently moving, return the actual movement direction
	if is_moving and movement_tween and movement_tween.is_valid():
		# Calculate the actual movement direction from start to current position
		var direction = (global_position - movement_start_position).normalized()
		return direction
	
	# If not moving, return the last movement direction
	return Vector2(last_movement_direction.x, last_movement_direction.y)

func get_last_movement_direction() -> Vector2i:
	"""Get the last movement direction as Vector2i"""
	return last_movement_direction
