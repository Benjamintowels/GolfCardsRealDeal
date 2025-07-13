extends CharacterBody2D

# Squirrel NPC - handles Squirrel-specific functions
# Integrates with the Entities system for turn management



signal turn_completed

# Sprite references for different directions
@onready var sprite_left_right: Sprite2D = $SquirrelSpriteLeftRight
@onready var sprite_up: Sprite2D = $SquirrelSpriteUp
@onready var sprite_down: Sprite2D = $SquirrelSpriteDown
@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Area2D references for body collision only
@onready var body_area: Area2D = $BodyArea2D
@onready var vision_area: Area2D = $VisionArea2D

# Footstep sound system
@onready var footsteps_grass_sound: AudioStreamPlayer2D = $FootstepsGrass
@onready var footsteps_snow_sound: AudioStreamPlayer2D = $FootstepsSnow
var footstep_sound_enabled: bool = true
var last_footstep_time: float = 0.0
var footstep_interval: float = 0.3  # Time between footstep sounds during movement

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# Squirrel specific properties
var movement_range: int = 1  # Patrol up to 1 tile away
var chase_movement_range: int = 5  # Chase up to 5 tiles away (matches vision range)
var vision_range: int = 5  # Vision range for ball detection (reduced from 20)
var current_action: String = "idle"

# Movement animation properties
var is_moving: bool = false
var movement_tween: Tween
var movement_duration: float = 0.3  # Duration of movement animation in seconds
var movement_start_position: Vector2  # Track where movement started
var turn_completion_emitted: bool = false  # Prevent double turn completion

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)  # Track last movement direction

# Health and damage properties
var max_health: int = 1
var current_health: int = 1
var is_alive: bool = true
var is_dead: bool = false
var damage_cooldown: float = 0.1  # Prevent multiple damage calls in short time
var last_damage_time: float = 0.0

# Retreat animation properties
var is_retreating: bool = false
var retreat_tween: Tween
var retreat_duration: float = 2.0  # Duration of retreat animation

# Collision and height properties
var dead_height: float = 50.0  # Lower height when dead (laying down)
var base_collision_area: Area2D

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE_BALL, DEAD, RETREATING}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

# Golf ball detection - tile-based system
var detected_golf_balls: Array[Node] = []
var nearest_golf_ball: Node = null
var vision_tile_range: int = 5  # How many tiles away the squirrel can see (reduced from 20)

# Player movement tracking for damage system
var previous_player_grid_pos: Vector2i = Vector2i.ZERO
var player_movement_damage_cooldown: float = 0.5  # Prevent multiple damage calls from rapid movement
var last_player_movement_damage_time: float = 0.0

func _ready():
	# Add to groups for smart optimization and roof bounce system
	add_to_group("collision_objects")
	add_to_group("NPC")
	
	print("=== SQUIRREL READY DEBUG ===")
	print("Squirrel name: ", name)
	print("Squirrel position: ", global_position)
	
	# Get grid position from metadata set by build system, or calculate from position if not set
	if has_meta("grid_position"):
		grid_position = get_meta("grid_position")
		print("Squirrel grid position from metadata: ", grid_position)
	else:
		# Fallback: calculate from position (but this should not happen with proper setup)
		grid_position = Vector2i(floor(position.x / cell_size), floor(position.y / cell_size))
		print("Squirrel grid position calculated from position: ", grid_position)
	
	# After setting position, ensure grid_position is synced with actual world position
	# Note: We don't call update_grid_position_from_world() here because the metadata
	# should contain the correct grid position from the build system
	
	# If this is a manually placed squirrel (no metadata), ensure it's on a valid position
	if not has_meta("grid_position"):
		if not _is_position_valid(grid_position):
			var valid_pos = _find_nearest_valid_position(grid_position)
			if valid_pos != grid_position:
				grid_position = valid_pos
				position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
				update_grid_position_from_world()
	
	# Connect to WorldTurnManager
	course = _find_course_script()
	
	# Try different paths to find WorldTurnManager
	var world_turn_manager = null
	var possible_paths = ["WorldTurnManager", "NPC/WorldTurnManager", "NPC/world_turn_manager"]
	
	for path in possible_paths:
		if course and course.has_node(path):
			world_turn_manager = course.get_node(path)
			break
	
	if world_turn_manager:
		world_turn_manager.register_npc(self)
		world_turn_manager.npc_turn_started.connect(_on_turn_started)
		world_turn_manager.npc_turn_ended.connect(_on_turn_ended)
		
		# Connect turn_completed signal to a debug function
		turn_completed.connect(_on_turn_completed_debug)
		if course:
			var npc_node = course.get_node_or_null("NPC")
	
	# Initialize state machine
	state_machine = StateMachine.new()
	state_machine.add_state("patrol", PatrolState.new(self))
	state_machine.add_state("chase_ball", ChaseBallState.new(self))
	state_machine.add_state("dead", DeadState.new(self))
	state_machine.add_state("retreating", RetreatingState.new(self))
	
	# Setup base collision area
	_setup_base_collision()
	
	# Create health bar
	_create_health_bar()
	
	# Defer player finding until after scene is fully loaded
	call_deferred("_find_player_reference")
	
	# Setup tile-based golf ball detection
	_setup_tile_based_vision()
	
	# Set initial state based on whether there's a ball detected (after vision is set up)
	call_deferred("_set_initial_state")
	
	# Setup footstep sound system
	_setup_footstep_sounds()

func _set_initial_state() -> void:
	"""Set the initial state after vision system is set up"""
	print("=== SQUIRREL SETTING INITIAL STATE ===")
	
	# Check if player is already within vision range when Squirrel is created
	if player and "grid_pos" in player:
		var player_tile_distance = abs(player.grid_pos.x - grid_position.x) + abs(player.grid_pos.y - grid_position.y)
		
		if player_tile_distance <= vision_tile_range:
			take_damage(1, false, player.global_position if player else Vector2.ZERO)
		else:
			print("✗ Player outside Squirrel vision range on creation - no damage")
	else:
		print("⚠ No player reference or grid_pos property for initial damage check")
	
	if has_detected_golf_ball():
		state_machine.set_state("chase_ball")
		print("Squirrel starting in chase mode - ball detected")
	else:
		state_machine.set_state("patrol")
		print("Squirrel starting in patrol mode - no ball detected")
	
	print("=== END INITIAL STATE SETUP ===")

func setup(pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the Squirrel with specific parameters"""
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	# Note: We don't call update_grid_position_from_world() here because we want to keep
	# the grid position from the build system, not recalculate it from world position
	
	# Check if the position is valid
	if course:
		var course_bounds = course.get_course_bounds()
		var is_valid = _is_position_valid(pos)
		
		# If position is invalid, try to find a valid nearby position
		if not is_valid:
			var valid_pos = _find_nearest_valid_position(pos)
			if valid_pos != pos:
				grid_position = valid_pos
				position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
				update_grid_position_from_world() # Ensure grid_position is synced after moving
	
	# Force a vision update after setup
	call_deferred("_check_vision_for_golf_balls")

func _find_nearest_valid_position(invalid_pos: Vector2i) -> Vector2i:
	"""Find the nearest valid position to the given invalid position"""
	if not course:
		return invalid_pos
	
	var course_bounds = course.get_course_bounds()
	var search_radius = 5  # Search within 5 tiles
	
	for radius in range(1, search_radius + 1):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var test_pos = invalid_pos + Vector2i(dx, dy)
				
				# Check if position is within bounds and walkable
				if _is_position_valid(test_pos):
					print("Found valid position at ", test_pos, " (distance: ", radius, ")")
					return test_pos
	
	# If no valid position found, return the original position
	return invalid_pos

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
	"""Setup the body collision area for taking damage from balls"""
	base_collision_area = body_area
	if base_collision_area:
		# Set collision layer to 1 so golf balls can detect it
		base_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		base_collision_area.collision_mask = 1
		# Make sure the body area is monitorable and monitoring
		base_collision_area.monitorable = true
		base_collision_area.monitoring = true
		# Connect to area_entered and area_exited signals for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		base_collision_area.connect("area_exited", _on_area_exited)
	else:
		print("✗ ERROR: BodyArea2D not found!")
	
	# Setup vision area for player detection (separate from ball collision)
	if vision_area:
		# Set collision layer to 0 so golf balls DON'T detect it
		vision_area.collision_layer = 0
		# Set collision mask to 2 so it can detect player on layer 2
		vision_area.collision_mask = 2
		# Make sure the vision area is monitorable and monitoring
		vision_area.monitorable = false  # Don't want other things to detect this
		vision_area.monitoring = true   # But we want to detect the player
		# Connect to area_entered and area_exited signals for player detection
		vision_area.connect("area_entered", _on_vision_area_entered)
		vision_area.connect("area_exited", _on_vision_area_exited)
		print("✓ Squirrel vision area setup complete")
	else:
		print("✗ ERROR: VisionArea2D not found!")

func _setup_tile_based_vision() -> void:
	"""Setup tile-based vision system for detecting golf balls"""
	print("✓ Setting up tile-based vision system")
	print("✓ Vision tile range: ", vision_tile_range, " tiles")
	
	# VisionArea2D removed - using tile-based vision instead
	print("✓ Using tile-based vision system")
	
	# Start the vision check timer
	_start_vision_check_timer()

func _start_vision_check_timer() -> void:
	"""Start a timer to periodically check for golf balls in vision range"""
	var vision_timer = Timer.new()
	vision_timer.name = "VisionCheckTimer"
	vision_timer.wait_time = 0.5  # Check every 0.5 seconds for more responsive ball detection
	vision_timer.timeout.connect(_check_vision_for_golf_balls)
	add_child(vision_timer)
	vision_timer.start()

func _check_vision_for_golf_balls() -> void:
	"""Check for golf balls within vision tile range"""
	if not course:
		return
	
	# Clear old detected balls
	detected_golf_balls.clear()
	
	# Get all golf balls in the scene
	var golf_balls = get_tree().get_nodes_in_group("golf_balls")
	if golf_balls.is_empty():
		# Also check for balls by name as fallback
		golf_balls = get_tree().get_nodes_in_group("balls")
	
	# Check each golf ball
	for ball in golf_balls:
		if not is_instance_valid(ball):
			continue
		
		# Get ball's tile position (accounting for camera offset)
		var ball_tile_pos: Vector2i
		if course and "camera_offset" in course:
			var camera_offset = course.camera_offset
			var adjusted_ball_pos = ball.global_position - camera_offset
			ball_tile_pos = Vector2i(floor(adjusted_ball_pos.x / cell_size), floor(adjusted_ball_pos.y / cell_size))
		else:
			# Fallback: use direct calculation without camera offset
			ball_tile_pos = Vector2i(floor(ball.global_position.x / cell_size), floor(ball.global_position.y / cell_size))
		
		var squirrel_tile_pos = grid_position
		
		# Calculate tile distance
		var tile_distance = abs(ball_tile_pos.x - squirrel_tile_pos.x) + abs(ball_tile_pos.y - squirrel_tile_pos.y)
		
		# Only print ball info if it's within vision range or was previously detected
		var was_detected = ball in detected_golf_balls

		# Check if ball is within vision range
		if tile_distance <= vision_tile_range:
			if ball not in detected_golf_balls:
				detected_golf_balls.append(ball)
				print("✓ Squirrel ", name, " detected ball at tile ", ball_tile_pos, " (distance: ", tile_distance, ")")
		else:
			# Remove ball from detected list if it's no longer in range
			if ball in detected_golf_balls:
				detected_golf_balls.erase(ball)
				print("✗ Squirrel ", name, " lost ball at tile ", ball_tile_pos, " (distance: ", tile_distance, ")")

	
	# Update nearest ball
	_update_nearest_golf_ball()

# Removed old vision area collision functions - now using tile-based vision

func _update_nearest_golf_ball() -> void:
	"""Update the nearest golf ball reference"""
	nearest_golf_ball = null
	var nearest_distance = INF
	
	for ball in detected_golf_balls:
		if is_instance_valid(ball):
			var distance = global_position.distance_to(ball.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_golf_ball = ball

func has_detected_golf_ball() -> bool:
	"""Check if the squirrel has detected any golf balls in its vision range"""
	# Update the detected golf balls list first
	_update_nearest_golf_ball()
	
	# Check if we have a valid nearest golf ball
	var has_ball = nearest_golf_ball != null and is_instance_valid(nearest_golf_ball)
	
	
	return has_ball

func is_player_visible() -> bool:
	"""Check if the player can see this squirrel (for patrol mode)"""
	if not player or not is_instance_valid(player):
		return false
	
	# Check if player is within vision range
	var distance_to_player = global_position.distance_to(player.global_position)
	return distance_to_player <= vision_range

func get_grid_position() -> Vector2i:
	"""Get the current grid position of the squirrel"""
	return grid_position

func _create_health_bar() -> void:
	"""Create and setup the health bar for the Squirrel"""
	# Create health bar container
	health_bar_container = Control.new()
	health_bar_container.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	health_bar_container.position.y = -80  # Position above the Squirrel
	add_child(health_bar_container)
	
	# Create health bar
	health_bar = preload("res://HealthBar.tscn").instantiate()
	health_bar_container.add_child(health_bar)
	health_bar.set_health(current_health, max_health)

func _find_player_reference() -> void:
	"""Find the player reference after scene is loaded"""
	print("=== SQUIRREL FINDING PLAYER REFERENCE ===")
	if course:
		print("Course found: ", course.name)
		
		# Method 1: Try to get player from course method (most reliable)
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			if player:
				_connect_to_player_movement()
				return
			else:
				print("course.get_player_reference returned null")
		
		# Method 2: Try different paths to find the player
		var possible_paths = [
			"Player",  # Direct child of course
			"player_node",  # Alternative name
			"CameraContainer/GridContainer/Player",  # Correct path based on scene hierarchy
			"CameraContainer/Player"  # Fallback path
		]
		
		for path in possible_paths:
			player = course.get_node_or_null(path)
			if player:
				if "grid_pos" in player:
					print("Player grid_pos: ", player.grid_pos)
				# Connect to player's movement signal
				_connect_to_player_movement()
				return
		
		# Method 3: Try to find player in scene tree by name
		var scene_tree = get_tree()
		var all_nodes = scene_tree.get_nodes_in_group("")
		print("Searching ", all_nodes.size(), " nodes in scene tree for player...")
		
		for node in all_nodes:
			if node.name == "Player":
				player = node
				print("✓ Squirrel found player in scene tree: ", player.name)
				_connect_to_player_movement()
				return
		
		# Method 4: Try to find by script type
		for node in all_nodes:
			if node.get_script():
				var script_path = node.get_script().resource_path
				if script_path.ends_with("Player.gd"):
					player = node
					print("✓ Squirrel found player by script: ", player.name)
					_connect_to_player_movement()
					return
		
		print("✗ ERROR: Player not found via any method!")
		
		# Check if CameraContainer exists and what's in it
		var camera_container = course.get_node_or_null("CameraContainer")
		if camera_container:
			print("CameraContainer found, children: ", camera_container.get_children())
			var grid_container = camera_container.get_node_or_null("GridContainer")
			if grid_container:
				print("GridContainer found, children: ", grid_container.get_children())
		
		# Set up a retry timer to try again later
		_setup_player_reference_retry()
	else:
		print("✗ ERROR: Course reference not found!")
		# Set up a retry timer to try again later
		_setup_player_reference_retry()
	print("=== END PLAYER REFERENCE SEARCH ===")

func _connect_to_player_movement() -> void:
	"""Connect to the player's movement signal to track when they move within vision range"""
	print("=== SQUIRREL CONNECTING TO PLAYER MOVEMENT ===")
	if player and player.has_signal("moved_to_tile"):
		player.moved_to_tile.connect(_on_player_moved_to_tile)
		print("✓ Squirrel connected to player movement signal")
		
		# Initialize previous player position
		if "grid_pos" in player:
			previous_player_grid_pos = player.grid_pos
			print("✓ Squirrel initialized previous player position: ", previous_player_grid_pos)
		else:
			print("⚠ WARNING: Player doesn't have grid_pos property")
	else:
		print("✗ ERROR: Player doesn't have moved_to_tile signal or grid_pos property")
		if player:
			print("Player signals: ", player.get_signal_list())
	print("=== END PLAYER MOVEMENT CONNECTION ===")

func _on_player_moved_to_tile(new_grid_pos: Vector2i) -> void:
	"""Called when the player moves to a new tile - check if they moved within vision range"""
	if not is_alive or is_dead:
		return
	
	# Check damage cooldown to prevent multiple damage calls from rapid movement
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_player_movement_damage_time < player_movement_damage_cooldown:
		return
	
	# Calculate tile distance between squirrel and new player position
	var tile_distance = abs(new_grid_pos.x - grid_position.x) + abs(new_grid_pos.y - grid_position.y)
	
	# Check if player moved within vision range
	if tile_distance <= vision_tile_range:
		print("✓ Player moved within Squirrel vision range - taking 1 damage")
		last_player_movement_damage_time = current_time
		take_damage(1, false, player.global_position if player else Vector2.ZERO)
	else:
		print("✗ Player moved outside Squirrel vision range - no damage")
	
	# Update previous player position
	previous_player_grid_pos = new_grid_pos
	print("=== END PLAYER MOVEMENT CHECK ===")

func _on_vision_area_entered(area: Area2D) -> void:
	"""Called when the player enters the vision area"""
	
	# Check if this is the player
	if area.get_parent() and area.get_parent().name == "Player":
		print("✓ Player entered Squirrel vision area")
		# The player movement signal will handle the damage, this is just for detection
	else:
		print("✗ Non-player entered vision area: ", area.get_parent().name if area.get_parent() else "None")
	print("=== END VISION AREA ENTERED ===")

func _on_vision_area_exited(area: Area2D) -> void:
	"""Called when the player exits the vision area"""
	
	# Check if this is the player
	if area.get_parent() and area.get_parent().name == "Player":
		print("✓ Player exited Squirrel vision area")
	else:
		print("✗ Non-player exited vision area: ", area.get_parent().name if area.get_parent() else "None")
	print("=== END VISION AREA EXITED ===")

func _on_turn_started(npc: Node) -> void:
	"""Called when this NPC's turn starts"""
	
	if npc == self:
		
		# Update detected golf balls before taking turn
		_check_vision_for_golf_balls()
		_update_nearest_golf_ball()
		
		# Check if we should switch states based on current conditions
		var has_ball = has_detected_golf_ball()
		var current_state = state_machine.current_state
		
		print("Has ball detected: ", has_ball)
		print("Current state: ", current_state)
		
		# Squirrels always chase balls when detected, regardless of player visibility
		if has_ball and current_state == "patrol":
			print("Ball detected during patrol, switching to chase mode")
			state_machine.set_state("chase_ball")
		elif not has_ball and current_state == "chase_ball":
			print("No ball detected during chase, switching to patrol mode")
			state_machine.set_state("patrol")
		
		print("Final state after turn start: ", state_machine.current_state)
		print("=== END TURN STARTED ===")
		
		# Call take_turn() to execute the turn
		print("About to call take_turn()")
		take_turn()
		print("take_turn() completed")
	else:
		print("Not this squirrel's turn")
	print("=== END TURN STARTED SIGNAL ===")

func _on_turn_ended(npc: Node) -> void:
	"""Called when this NPC's turn ends"""
	if npc == self:
		print("Squirrel turn ended")

func _on_turn_completed_debug() -> void:
	"""Debug function to confirm turn_completed signal is emitted"""
	print("=== TURN_COMPLETED SIGNAL EMITTED ===")
	print("Squirrel: ", name)
	print("Signal emitted successfully")
	print("=== END TURN_COMPLETED SIGNAL ===")

func take_turn() -> void:
	"""Take the Squirrel's turn"""
	print("=== SQUIRREL TAKE_TURN CALLED ===")
	print("Squirrel: ", name)
	print("Is alive: ", is_alive)
	print("Is dead: ", is_dead)
	print("Is retreating: ", is_retreating)
	
	# Reset turn completion flag
	turn_completion_emitted = false
	
	if not is_alive or is_dead or is_retreating:
		print("Squirrel is dead or retreating, skipping turn")
		turn_completed.emit()
		return
	
	print("=== SQUIRREL TURN START ===")
	print("Squirrel: ", name)
	print("Current state: ", state_machine.current_state)
	print("Has detected golf ball: ", has_detected_golf_ball())
	print("Nearest golf ball: ", nearest_golf_ball.name if nearest_golf_ball else "None")
	print("Grid position: ", grid_position)
	
	# Check if we should switch states based on current conditions
	var has_ball = has_detected_golf_ball()
	var current_state = state_machine.current_state
	
	print("Has ball detected: ", has_ball)
	print("Current state: ", current_state)
	
	# Squirrels always chase balls when detected, regardless of player visibility
	if has_ball and current_state == "patrol":
		print("Ball detected during patrol, switching to chase mode")
		state_machine.set_state("chase_ball")
	elif not has_ball and current_state == "chase_ball":
		print("No ball detected during chase, switching to patrol mode")
		state_machine.set_state("patrol")
	
	print("Final state after turn start: ", state_machine.current_state)
	
	# Update state machine - this will handle the turn logic and completion
	print("About to call state_machine.update()")
	state_machine.update()
	print("state_machine.update() completed")
	
	# The state machine should handle turn completion, so we don't need to call it again
	# Only check turn completion if the state machine didn't handle it
	if not is_moving:
		print("State machine didn't start movement, checking turn completion")
		_check_turn_completion()
	
	print("=== SQUIRREL TURN END ===")

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the Squirrel to a target grid position"""
	print("=== SQUIRREL MOVE TO POSITION CALLED ===")
	print("Target position: ", target_pos)
	print("Current grid position: ", grid_position)
	print("Is moving: ", is_moving)
	print("Target valid: ", _is_position_valid(target_pos))
	
	if is_moving:
		print("Squirrel is already moving, ignoring movement command")
		return
	
	if target_pos == grid_position:
		print("Squirrel target position is same as current position")
		_check_turn_completion()
		return
	
	if not _is_position_valid(target_pos):
		print("Squirrel target position is invalid: ", target_pos)
		_check_turn_completion()
		return
	
	# Calculate movement direction
	var direction = target_pos - grid_position
	last_movement_direction = direction
	facing_direction = direction
	# Do NOT update grid_position here! It will be updated after movement completes.
	# grid_position = target_pos
	
	# Update sprite facing before movement
	_update_sprite_facing()
	
	# Calculate world position
	var world_pos: Vector2
	if course and "camera_offset" in course:
		var camera_offset = course.camera_offset
		world_pos = Vector2(
			target_pos.x * cell_size + cell_size / 2,
			target_pos.y * cell_size + cell_size / 2
		) + camera_offset
	else:
		# Fallback: calculate without camera offset
		world_pos = Vector2(
			target_pos.x * cell_size + cell_size / 2,
			target_pos.y * cell_size + cell_size / 2
		)
	
	print("Squirrel moving from ", grid_position, " to ", target_pos, " with direction: ", direction)
	print("Started movement animation to position: ", world_pos)
	
	# Play footstep sound right before movement starts
	_play_footstep_sound_before_movement()
	
	# Start movement animation
	is_moving = true
	movement_start_position = global_position
	
	if movement_tween:
		movement_tween.kill()
	
	movement_tween = create_tween()
	movement_tween.tween_property(self, "global_position", world_pos, movement_duration)
	movement_tween.tween_callback(_on_movement_completed)
	
	# Play movement sound
	var move_sound = get_node_or_null("SquirrelMove")
	if move_sound:
		move_sound.play()
	
	print("=== MOVEMENT STARTED ===")
	print("Movement tween created: ", movement_tween != null)
	print("Target world position: ", world_pos)
	print("=== END MOVE TO POSITION ===")

func _on_movement_completed() -> void:
	"""Called when movement animation completes"""
	print("Squirrel movement animation completed")
	is_moving = false
	# Recalculate grid_position from global_position with camera offset correction
	update_grid_position_from_world()
	_check_turn_completion()

func _check_turn_completion() -> void:
	"""Check if the turn should be completed"""
	print("=== TURN COMPLETION CHECK ===")
	print("Is moving: ", is_moving)
	print("Current state: ", state_machine.current_state)
	print("Turn completion already emitted: ", turn_completion_emitted)
	
	if not is_moving and not turn_completion_emitted:
		print("Squirrel movement finished, completing turn")
		print("About to emit turn_completed signal")
		turn_completion_emitted = true
		turn_completed.emit()
		print("Turn completed signal emitted successfully")
	elif turn_completion_emitted:
		print("Turn completion already emitted, skipping")
	else:
		print("Squirrel still moving, waiting for completion")
	print("=== END TURN COMPLETION CHECK ===")

func _is_position_valid(pos: Vector2i) -> bool:
	# Basic bounds checking - ensure position is within reasonable grid bounds
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false

	# Check if position is occupied by the player
	if player and player.grid_pos == pos:
		print("Position ", pos, " is occupied by player")
		return false

	# For now, allow movement to any position within bounds
	return true

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get all valid adjacent positions"""
	var adjacent: Array[Vector2i] = []
	var directions = [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	
	print("=== CHECKING ADJACENT POSITIONS ===")
	print("Squirrel at: ", grid_position)
	
	for direction in directions:
		var pos = grid_position + direction
		print("Checking adjacent position: ", pos, " (direction: ", direction, ")")
		if _is_position_valid(pos):
			adjacent.append(pos)
			print("✓ Position ", pos, " is valid")
		else:
			print("✗ Position ", pos, " is invalid")
	
	print("Valid adjacent positions found: ", adjacent.size())
	print("=== END ADJACENT POSITIONS CHECK ===")
	return adjacent

func _update_sprite_facing() -> void:
	"""Update the sprite facing direction based on facing_direction"""
	# Hide all sprites first
	sprite_left_right.visible = false
	sprite_up.visible = false
	sprite_down.visible = false
	
	# Show appropriate sprite based on direction
	if facing_direction.x != 0:
		# Moving left or right
		sprite_left_right.visible = true
		sprite_left_right.flip_h = (facing_direction.x < 0)
	elif facing_direction.y < 0:
		# Moving up
		sprite_up.visible = true
	elif facing_direction.y > 0:
		# Moving down
		sprite_down.visible = true
	
	print("Updated Squirrel sprite facing - Direction: ", facing_direction)

func _face_direction(direction: Vector2i) -> void:
	"""Make the Squirrel face a specific direction"""
	facing_direction = direction
	_update_sprite_facing()
	print("Squirrel facing direction: ", facing_direction)

func _face_ball() -> void:
	"""Make the Squirrel face the nearest golf ball"""
	if not nearest_golf_ball or not is_instance_valid(nearest_golf_ball):
		return
	
	var ball_pos = nearest_golf_ball.global_position
	var direction_to_ball = ball_pos - global_position
	
	# Normalize the direction to get primary direction
	if direction_to_ball.x != 0:
		direction_to_ball.x = 1 if direction_to_ball.x > 0 else -1
	if direction_to_ball.y != 0:
		direction_to_ball.y = 1 if direction_to_ball.y > 0 else -1
	
	# Update facing direction to face the ball
	facing_direction = Vector2i(direction_to_ball.x, direction_to_ball.y)
	_update_sprite_facing()
	
	print("Facing ball - Direction: ", facing_direction)

func _push_ball_away() -> void:
	"""Push the golf ball away from the squirrel"""
	if not nearest_golf_ball or not is_instance_valid(nearest_golf_ball):
		print("No valid golf ball to push")
		_check_turn_completion()
		return
	
	print("=== SQUIRREL PUSHING BALL AWAY ===")
	print("Squirrel position: ", grid_position)
	print("Ball position: ", nearest_golf_ball.global_position)
	
	# Face the ball first
	_face_ball()
	
	# Calculate direction from squirrel to ball
	var ball_pos = nearest_golf_ball.global_position
	var squirrel_pos = global_position
	var direction_to_ball = (ball_pos - squirrel_pos).normalized()
	
	# Calculate push direction (away from squirrel)
	var push_direction = direction_to_ball
	
	# Calculate push force (stronger than normal ball movement)
	var push_force = 400.0  # Strong push force
	
	# Apply push to the ball
	if nearest_golf_ball.has_method("set_velocity"):
		var new_velocity = push_direction * push_force
		nearest_golf_ball.set_velocity(new_velocity)
		print("Applied push velocity to ball: ", new_velocity)
		
		# Re-enable ball rolling if it was stopped
		if nearest_golf_ball.has_method("set_rolling_state"):
			nearest_golf_ball.set_rolling_state(true)
		if nearest_golf_ball.has_method("set_landed_flag"):
			nearest_golf_ball.set_landed_flag(false)
		
		# Play push sound if available
		var push_sound = get_node_or_null("SquirrelPush")
		if push_sound and push_sound.stream:
			push_sound.play()
			print("Playing squirrel push sound")
	else:
		print("Ball doesn't have set_velocity method")
	
	# Wait a moment to show the push animation
	await get_tree().create_timer(0.3).timeout
	
	# Complete the turn
	_check_turn_completion()
	print("=== END SQUIRREL PUSHING BALL ===")

# Health and damage methods
func take_damage(amount: int, is_headshot: bool = false, weapon_position: Vector2 = Vector2.ZERO) -> void:
	"""Take damage and handle death if health reaches 0"""
	print("=== SQUIRREL TAKE_DAMAGE CALLED ===")
	print("Amount: ", amount)
	print("Is headshot: ", is_headshot)
	print("Weapon position: ", weapon_position)
	print("Call stack: ", get_stack())
	
	if not is_alive:
		print("Squirrel is already dead, ignoring damage")
		return
	
	# Check damage cooldown to prevent duplicate damage calls
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_damage_time < damage_cooldown:
		print("Squirrel damage cooldown active, ignoring damage")
		return
	
	last_damage_time = current_time
	
	current_health = current_health - amount
	print("Squirrel took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Update health bar
	if health_bar:
		health_bar.set_health(current_health, max_health)
	
	# Play hit sound
	var hit_sound = get_node_or_null("SquirrelHit")
	if hit_sound:
		hit_sound.play()
	
	if current_health <= 0 and not is_dead:
		print("Squirrel health reached 0, calling die()")
		die()

func die() -> void:
	"""Handle Squirrel death - start retreat animation"""
	if is_dead:
		return
	
	print("Squirrel dying - starting retreat animation")
	is_dead = true
	is_alive = false
	
	# Give death reward (Squirrels give 0 $Looty)
	Global.give_npc_death_reward("Squirrel")
	
	# Hide health bar
	if health_bar_container:
		health_bar_container.visible = false
	
	# Change to retreating state
	state_machine.set_state("retreating")

func _start_retreat_animation() -> void:
	"""Start the retreat animation - move to bottom of screen"""
	if is_retreating:
		return
	
	is_retreating = true
	print("Starting Squirrel retreat animation")
	
	# Calculate retreat position (bottom of screen)
	var retreat_pos = global_position
	retreat_pos.y = 1000  # Move to bottom of screen
	
	if retreat_tween:
		retreat_tween.kill()
	
	retreat_tween = create_tween()
	retreat_tween.tween_property(self, "global_position", retreat_pos, retreat_duration)
	retreat_tween.tween_callback(_on_retreat_completed)

func _on_retreat_completed() -> void:
	"""Called when retreat animation completes"""
	print("Squirrel retreat animation completed")
	# Remove from Entities system
	if entities_manager:
		entities_manager.unregister_npc(self)
	
	# Queue free the Squirrel
	queue_free()

# Collision handling
func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collision with projectiles"""
	var projectile = area.get_parent()
	print("=== BASE AREA COLLISION DEBUG ===")
	print("Area entered: ", area.name)
	print("Area parent: ", area.get_parent().name if area.get_parent() else "None")
	print("Projectile name:", projectile.name if projectile else "None")
	print("Projectile type:", projectile.get_class() if projectile else "None")
	print("Base collision area name: ", base_collision_area.name if base_collision_area else "None")
	print("Is body area collision: ", area == base_collision_area)
	print("Area path: ", area.get_path())
	print("Base collision area path: ", base_collision_area.get_path() if base_collision_area else "None")
	
	# Only handle collisions with the body area, not the vision area
	if area != base_collision_area:
		print("Collision with vision area, ignoring")
		return
	
	if projectile and (projectile.name == "GolfBall" or projectile.name == "GhostBall" or projectile.has_method("is_throwing_knife")):
		print("=== HANDLING SQUIRREL AREA COLLISION ===")
		print("Projectile name:", projectile.name)
		print("Projectile type:", projectile.get_class())
		
		# Get projectile height
		var projectile_height = 0.0
		if projectile.has_method("get_height"):
			projectile_height = projectile.get_height()
		elif "height" in projectile:
			projectile_height = projectile.height
		
		print("Projectile height:", projectile_height)
		print("Squirrel height:", get_height())
		
		# Check if projectile is above Squirrel height
		if projectile_height > get_height():
			print("✓ Projectile is above Squirrel height - no collision")
			return
		else:
			print("✗ Projectile is below Squirrel height - reflecting")
			_reflect_projectile(projectile)
		
		# Handle ball/knife collision
		_handle_ball_knife_collision(projectile)

func _on_area_exited(area: Area2D) -> void:
	"""Handle projectile exit"""
	pass

func _reflect_projectile(projectile: Node2D) -> void:
	"""Reflect a projectile that hits the Squirrel"""
	print("=== REFLECTING PROJECTILE ===")
	
	var projectile_velocity = Vector2.ZERO
	if "velocity" in projectile:
		projectile_velocity = projectile.velocity
	
	print("Reflecting projectile with velocity:", projectile_velocity)
	
	# Calculate reflection direction (reverse the velocity)
	var reflected_velocity = -projectile_velocity
	
	# Apply reflected velocity
	if "velocity" in projectile:
		projectile.velocity = reflected_velocity
	
	print("Reflected velocity:", reflected_velocity)

func _handle_ball_knife_collision(projectile: Node2D) -> void:
	"""Handle collision with ball or knife"""
	print("Handling ball/knife collision - checking ball/knife height")
	
	# Get projectile height
	var projectile_height = 0.0
	if projectile.has_method("get_height"):
		projectile_height = projectile.get_height()
	elif "height" in projectile:
		projectile_height = projectile.height
	
	# Check if this is a throwing knife
	if projectile.has_method("is_throwing_knife") and projectile.is_throwing_knife():
		print("=== THROWING KNIFE COLLISION ===")
		_handle_throwing_knife_collision(projectile, projectile_height)
	else:
		print("=== GOLF BALL COLLISION ===")
		_handle_golf_ball_collision(projectile, projectile_height)

func _handle_throwing_knife_collision(knife: Node2D, knife_height: float) -> void:
	"""Handle collision with throwing knife"""
	print("=== HANDLING THROWING KNIFE COLLISION ===")
	print("Knife height:", knife_height)
	print("Squirrel height:", get_height())
	
	# Check if knife hits in valid height range
	if knife_height > get_height():
		print("✓ Knife is above Squirrel - no damage")
		return
	
	# Calculate damage based on knife velocity
	var knife_velocity = Vector2.ZERO
	if "velocity" in knife:
		knife_velocity = knife.velocity
	
	var damage = int(knife_velocity.length() / 10.0)  # Scale velocity to damage
	damage = max(1, min(damage, 5))  # Clamp damage between 1-5
	
	print("Knife velocity:", knife_velocity, "Calculated damage:", damage)
	
	# Apply damage
	take_damage(damage, false, knife.global_position)
	
	# Destroy the knife
	if knife.has_method("destroy"):
		knife.destroy()
	else:
		knife.queue_free()

func _handle_golf_ball_collision(ball: Node2D, ball_height: float) -> void:
	"""Handle collision with golf ball"""
	print("=== HANDLING GOLF BALL COLLISION ===")
	print("Ball height:", ball_height)
	print("Squirrel height:", get_height())
	
	# Check if ball hits in valid height range
	if ball_height > get_height():
		print("✓ Ball is above Squirrel - no damage")
		return
	
	# Calculate damage based on ball velocity
	var ball_velocity = Vector2.ZERO
	if "velocity" in ball:
		ball_velocity = ball.velocity
	
	var damage = int(ball_velocity.length() / 20.0)  # Scale velocity to damage
	damage = max(1, min(damage, 3))  # Clamp damage between 1-3
	
	print("Ball velocity:", ball_velocity, "Calculated damage:", damage)
	
	# Apply damage
	take_damage(damage, false, ball.global_position)
	
	# Handle ball bounce/reflection
	if ball.has_method("bounce"):
		ball.bounce()
	elif "velocity" in ball:
		ball.velocity = -ball.velocity * 0.5  # Reverse and reduce velocity

# Height and collision methods for Entities system
func get_height() -> float:
	"""Get the height of this Squirrel for collision detection"""
	return Global.get_object_height_from_marker(self)

func get_y_sort_point() -> float:
	"""Get the Y-sort reference point for this Squirrel"""
	var ysort_point_node = get_node_or_null("YSortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func get_base_collision_shape() -> Dictionary:
	"""Get the base collision shape dimensions for this Squirrel"""
	return {
		"width": 10.0,
		"height": 6.5,
		"offset": Vector2(0, 25)  # Offset from Squirrel center to base
	}

func handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by Entities system"""
	_handle_ball_knife_collision(ball)

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by GolfBall system"""
	print("=== SQUIRREL BALL COLLISION HANDLER CALLED ===")
	print("Ball name: ", ball.name if ball else "None")
	print("Ball type: ", ball.get_class() if ball else "None")
	_handle_ball_knife_collision(ball)

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
			print("StateMachine: Switched to state: ", state_name)
	
	func update() -> void:
		print("=== STATEMACHINE UPDATE CALLED ===")
		print("Current state: ", current_state)
		print("Available states: ", states.keys())
		if current_state != "" and current_state in states:
			print("StateMachine updating state: ", current_state)
			states[current_state].update()
			print("StateMachine update completed for state: ", current_state)
		else:
			print("StateMachine: No current state or state not found")
			print("Current state is empty: ", current_state == "")
			print("Current state in states: ", current_state in states)

class BaseState extends Node:
	var squirrel: Node
	
	func _init(s: Node):
		squirrel = s
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State
class PatrolState extends BaseState:
	func enter() -> void:
		print("Squirrel entering patrol state")
	
	func update() -> void:
		print("PatrolState update called")
		
		# Check if there's a golf ball in vision - if so, switch to chase
		if squirrel.nearest_golf_ball and is_instance_valid(squirrel.nearest_golf_ball):
			print("Golf ball detected in vision, switching to chase state")
			squirrel.state_machine.set_state("chase_ball")
			return
		
		# Squirrels can patrol regardless of player visibility (they're always active)
		# This allows them to move around and potentially detect balls even when player can't see them
		
		# Random patrol movement up to 1 tile away
		var move_distance = randi_range(1, squirrel.movement_range)
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != squirrel.grid_position:
			print("Moving to new position")
			squirrel._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			squirrel._face_direction(squirrel.last_movement_direction)
			# Complete turn immediately since no movement is needed
			squirrel._check_turn_completion()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 10
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = squirrel.grid_position + random_direction
			
			if squirrel._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = squirrel._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return squirrel.grid_position

# Chase Ball State
class ChaseBallState extends BaseState:
	func enter() -> void:
		print("Squirrel entering chase ball state")
	
	func update() -> void:
		print("=== CHASE BALL STATE UPDATE ===")
		print("Squirrel: ", squirrel.name)
		print("Squirrel grid position: ", squirrel.grid_position)
		
		# Check if golf ball is still valid
		if not squirrel.nearest_golf_ball or not is_instance_valid(squirrel.nearest_golf_ball):
			print("Golf ball no longer valid, switching to patrol")
			squirrel.state_machine.set_state("patrol")
			return
		
		var ball_pos = squirrel.nearest_golf_ball.global_position
		var ball_grid_pos: Vector2i
		if squirrel.course and "camera_offset" in squirrel.course:
			var camera_offset = squirrel.course.camera_offset
			var adjusted_ball_pos = ball_pos - camera_offset
			ball_grid_pos = Vector2i(floor(adjusted_ball_pos.x / squirrel.cell_size), floor(adjusted_ball_pos.y / squirrel.cell_size))
		else:
			# Fallback: use direct calculation without camera offset
			ball_grid_pos = Vector2i(floor(ball_pos.x / squirrel.cell_size), floor(ball_pos.y / squirrel.cell_size))
		
		print("Ball global position: ", ball_pos)
		print("Ball grid position: ", ball_grid_pos)
		print("Distance to ball: ", squirrel.grid_position.distance_to(ball_grid_pos))
		
		# Check if squirrel is already at the ball's position or very close
		var distance_to_ball = squirrel.grid_position.distance_to(ball_grid_pos)
		if distance_to_ball <= 1.0:
			print("Squirrel is at or very close to ball position (distance: ", distance_to_ball, ") - pushing ball away")
			squirrel._push_ball_away()
			print("=== END CHASE BALL STATE UPDATE ===")
			return
		
		# Check if squirrel is trapped (no valid adjacent positions)
		var adjacent_positions = squirrel._get_valid_adjacent_positions()
		if adjacent_positions.size() == 0:
			print("Squirrel is trapped - no valid adjacent positions, facing ball and completing turn")
			squirrel._face_ball()
			squirrel._check_turn_completion()
			print("=== END CHASE BALL STATE UPDATE ===")
			return
		
		var path = _get_path_to_ball(ball_grid_pos)
		print("Chase path: ", path)
		print("Path size: ", path.size())
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards ball
			print("Moving towards ball to: ", next_pos)
			print("Next position valid: ", squirrel._is_position_valid(next_pos))
			print("Distance to ball after move: ", next_pos.distance_to(ball_grid_pos))
			squirrel._move_to_position(next_pos)
		else:
			print("No path found to ball - path size: ", path.size())
			print("Current position: ", squirrel.grid_position)
			print("Ball position: ", ball_grid_pos)
			print("Distance: ", squirrel.grid_position.distance_to(ball_grid_pos))
			print("Chase movement range: ", squirrel.chase_movement_range)
			# Face the ball when no movement is needed
			squirrel._face_ball()
			# Complete turn immediately since no movement is needed
			squirrel._check_turn_completion()
		
		print("=== END CHASE BALL STATE UPDATE ===")
	
	func _get_path_to_ball(ball_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards ball
		var path: Array[Vector2i] = [squirrel.grid_position]
		var current_pos = squirrel.grid_position
		var max_steps = squirrel.chase_movement_range
		var steps = 0
		
		print("=== PATHFINDING DEBUG ===")
		print("Starting from ", current_pos, " to ", ball_pos, " with max steps: ", max_steps)
		print("Chase movement range: ", squirrel.chase_movement_range)
		
		while current_pos != ball_pos and steps < max_steps:
			var direction = (ball_pos - current_pos)
			# Normalize the direction vector for Vector2i
			if direction.x != 0:
				direction.x = 1 if direction.x > 0 else -1
			if direction.y != 0:
				direction.y = 1 if direction.y > 0 else -1
			var next_pos = current_pos + direction
			
			print("Pathfinding step ", steps, " - Direction: ", direction, ", Next pos: ", next_pos)
			print("Next position valid: ", squirrel._is_position_valid(next_pos))
			
			if squirrel._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = squirrel._get_valid_adjacent_positions()
				print("Adjacent positions found: ", adjacent.size())
				if adjacent.size() > 0:
					# Find the adjacent position closest to ball
					var best_pos = adjacent[0]
					var best_distance = (best_pos - ball_pos).length()
					
					for pos in adjacent:
						var distance = (pos - ball_pos).length()
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
		
		# Check if we're very close to the ball (within 1 tile)
		var distance_to_ball = current_pos.distance_to(ball_pos)
		if distance_to_ball <= 1.0:
			print("Pathfinding - Very close to ball, staying in place")
			# Don't add any movement - just stay where we are
			return path
		
		# Check if we're trapped (no valid adjacent positions)
		var adjacent = squirrel._get_valid_adjacent_positions()
		if adjacent.size() == 0:
			print("Pathfinding - Squirrel is trapped, cannot move")
			# Squirrel is trapped, return current path without movement
			return path
		
		# Ensure we always return at least one step towards the ball if we haven't reached it
		if path.size() == 1 and current_pos != ball_pos:
			print("Pathfinding - No valid path found, but ball is within range")
			print("Current pos: ", current_pos, " Ball pos: ", ball_pos)
			print("Distance: ", current_pos.distance_to(ball_pos))
			print("Max steps: ", max_steps)
			print("Steps taken: ", steps)
			
			# Try to add at least one step towards the ball
			var direction = (ball_pos - current_pos)
			if direction.x != 0:
				direction.x = 1 if direction.x > 0 else -1
			if direction.y != 0:
				direction.y = 1 if direction.y > 0 else -1
			var next_pos = current_pos + direction
			if squirrel._is_position_valid(next_pos):
				path.append(next_pos)
				print("Pathfinding - Added fallback step to: ", next_pos)
		
		print("Pathfinding - Final path: ", path)
		print("=== END PATHFINDING DEBUG ===")
		return path



# Dead State
class DeadState extends BaseState:
	func enter() -> void:
		print("Squirrel entering dead state")
		# Hide health bar
		if squirrel.health_bar_container:
			squirrel.health_bar_container.visible = false
	
	func update() -> void:
		# Dead Squirrels don't move or take actions
		pass
	
	func exit() -> void:
		pass

# Retreating State
class RetreatingState extends BaseState:
	func enter() -> void:
		print("Squirrel entering retreating state")
		squirrel._start_retreat_animation()
	
	func update() -> void:
		# Retreating Squirrels don't take normal actions
		pass
	
	func exit() -> void:
		pass 

func update_grid_position_from_world():
	"""Update grid position from world position, accounting for camera offset"""
	if course and "camera_offset" in course:
		var camera_offset = course.camera_offset
		var adjusted_position = global_position - camera_offset
		grid_position = Vector2i(floor(adjusted_position.x / cell_size), floor(adjusted_position.y / cell_size))
	else:
		# Fallback: use direct calculation without camera offset
		grid_position = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))

func _process(delta):
	"""Process function with corrected grid position calculation"""
	var calc_grid: Vector2i
	if course and "camera_offset" in course:
		var camera_offset = course.camera_offset
		var adjusted_position = global_position - camera_offset
		calc_grid = Vector2i(floor(adjusted_position.x / cell_size), floor(adjusted_position.y / cell_size))
	else:
		# Fallback: use direct calculation without camera offset
		calc_grid = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
	
	# Fallback proximity check - check for player proximity every frame as backup
	_check_player_proximity_fallback()

func _check_player_proximity_fallback() -> void:
	"""Fallback system to check player proximity every frame in case signal connection fails"""
	if not is_alive or is_dead:
		return
	
	# Only check if we have a player reference
	if not player or not is_instance_valid(player):
		return
	
	# Only check if player has grid_pos property
	if not "grid_pos" in player:
		return
	
	var current_player_pos = player.grid_pos
	
	# Skip if player hasn't moved
	if current_player_pos == previous_player_grid_pos:
		return
	
	# Check damage cooldown
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_player_movement_damage_time < player_movement_damage_cooldown:
		return
	
	# Calculate tile distance
	var tile_distance = abs(current_player_pos.x - grid_position.x) + abs(current_player_pos.y - grid_position.y)
	
	# Only print debug info occasionally to avoid spam
	if randf() < 0.01:  # 1% chance per frame
		print("=== SQUIRREL FALLBACK PROXIMITY CHECK ===")
		print("Squirrel: ", name, " at grid position: ", grid_position)
		print("Player moved from: ", previous_player_grid_pos, " to: ", current_player_pos)
		print("Tile distance to player: ", tile_distance)
		print("Vision tile range: ", vision_tile_range)
		print("=== END FALLBACK CHECK ===")
	
	# Check if player moved within vision range
	if tile_distance <= vision_tile_range:
		print("✓ FALLBACK: Player moved within Squirrel vision range - taking 1 damage")
		last_player_movement_damage_time = current_time
		take_damage(1, false, player.global_position if player else Vector2.ZERO)
	
	# Update previous player position
	previous_player_grid_pos = current_player_pos

# Manual test functions for debugging
func test_damage_system() -> void:
	"""Manual test function to verify the damage system is working"""
	print("=== MANUAL SQUIRREL DAMAGE TEST ===")
	print("Squirrel: ", name)
	print("Current health: ", current_health, "/", max_health)
	print("Is alive: ", is_alive)
	print("Is dead: ", is_dead)
	print("Player reference: ", player.name if player else "None")
	print("Player grid position: ", player.grid_pos if player and "grid_pos" in player else "Unknown")
	print("Squirrel grid position: ", grid_position)
	print("Vision tile range: ", vision_tile_range)
	
	# Test taking damage directly
	print("Testing direct damage...")
	take_damage(1, false, Vector2.ZERO)
	print("Health after test damage: ", current_health, "/", max_health)
	print("=== END MANUAL DAMAGE TEST ===")

func test_player_movement_damage(player_test_pos: Vector2i) -> void:
	"""Manual test function to simulate player movement to a specific position"""
	print("=== MANUAL PLAYER MOVEMENT TEST ===")
	print("Testing player movement to: ", player_test_pos)
	_on_player_moved_to_tile(player_test_pos)
	print("=== END PLAYER MOVEMENT TEST ===")

func test_ball_detection() -> void:
	"""Manual test function to trigger ball detection check"""
	print("=== MANUAL BALL DETECTION TEST ===")
	_check_vision_for_golf_balls()
	print("=== END BALL DETECTION TEST ===")

func retry_player_reference() -> void:
	"""Manual function to retry finding the player reference"""
	print("=== MANUAL PLAYER REFERENCE RETRY ===")
	print("Current player reference: ", player.name if player else "None")
	print("Retrying player reference search...")
	_find_player_reference()
	print("=== END MANUAL PLAYER REFERENCE RETRY ===")

func debug_coordinate_system() -> void:
	"""Debug function to check coordinate system alignment"""
	print("=== SQUIRREL COORDINATE SYSTEM DEBUG ===")
	print("Squirrel name: ", name)
	print("Global position: ", global_position)
	print("Position: ", position)
	print("Grid position: ", grid_position)
	
	if course and "camera_offset" in course:
		var camera_offset = course.camera_offset
		var adjusted_position = global_position - camera_offset
		var calculated_grid = Vector2i(floor(adjusted_position.x / cell_size), floor(adjusted_position.y / cell_size))
		print("Camera offset: ", camera_offset)
		print("Adjusted position: ", adjusted_position)
		print("Calculated grid position: ", calculated_grid)
		print("Grid position matches calculated: ", grid_position == calculated_grid)
	else:
		print("No camera offset available")
		var calculated_grid = Vector2i(floor(global_position.x / cell_size), floor(global_position.y / cell_size))
		print("Calculated grid position (no offset): ", calculated_grid)
		print("Grid position matches calculated: ", grid_position == calculated_grid)
	
	if player and "grid_pos" in player:
		var tile_distance = abs(player.grid_pos.x - grid_position.x) + abs(player.grid_pos.y - grid_position.y)
		print("Player grid position: ", player.grid_pos)
		print("Tile distance to player: ", tile_distance)
		print("Vision tile range: ", vision_tile_range)
		print("Player in vision range: ", tile_distance <= vision_tile_range)
	
	print("=== END COORDINATE SYSTEM DEBUG ===")

func debug_ball_detection() -> void:
	"""Debug function to check ball detection system"""
	print("=== SQUIRREL BALL DETECTION DEBUG ===")
	print("Squirrel name: ", name)
	print("Squirrel grid position: ", grid_position)
	print("Vision tile range: ", vision_tile_range)
	
	# Get all golf balls in the scene
	var golf_balls = get_tree().get_nodes_in_group("golf_balls")
	if golf_balls.is_empty():
		golf_balls = get_tree().get_nodes_in_group("balls")
	
	print("Total golf balls found: ", golf_balls.size())
	
	for ball in golf_balls:
		if not is_instance_valid(ball):
			continue
		
		# Get ball's tile position (accounting for camera offset)
		var ball_tile_pos: Vector2i
		if course and "camera_offset" in course:
			var camera_offset = course.camera_offset
			var adjusted_ball_pos = ball.global_position - camera_offset
			ball_tile_pos = Vector2i(floor(adjusted_ball_pos.x / cell_size), floor(adjusted_ball_pos.y / cell_size))
		else:
			ball_tile_pos = Vector2i(floor(ball.global_position.x / cell_size), floor(ball.global_position.y / cell_size))
		
		var tile_distance = abs(ball_tile_pos.x - grid_position.x) + abs(ball_tile_pos.y - grid_position.y)
		var in_range = tile_distance <= vision_tile_range
		
		print("Ball: ", ball.name)
		print("  Global position: ", ball.global_position)
		print("  Calculated tile position: ", ball_tile_pos)
		print("  Tile distance: ", tile_distance)
		print("  In vision range: ", in_range)
		print("  Currently detected: ", ball in detected_golf_balls)
	
	print("Currently detected balls: ", detected_golf_balls.size())
	print("Nearest ball: ", nearest_golf_ball.name if nearest_golf_ball else "None")
	print("Has detected ball: ", has_detected_golf_ball())
	print("=== END BALL DETECTION DEBUG ===")

func _setup_player_reference_retry() -> void:
	"""Set up a retry timer to find the player reference later"""
	var retry_timer = Timer.new()
	retry_timer.name = "PlayerReferenceRetryTimer"
	retry_timer.wait_time = 1.0  # Wait 1 second before retrying
	retry_timer.one_shot = true
	retry_timer.timeout.connect(_retry_find_player_reference)
	add_child(retry_timer)
	retry_timer.start()
	print("✓ Set up player reference retry timer")

func _retry_find_player_reference() -> void:
	"""Retry finding the player reference after a delay"""
	print("=== SQUIRREL RETRYING PLAYER REFERENCE SEARCH ===")
	
	# Remove the retry timer
	var retry_timer = get_node_or_null("PlayerReferenceRetryTimer")
	if retry_timer:
		retry_timer.queue_free()
	
	# Try to find course reference again if we don't have it
	if not course:
		course = _find_course_script()
	
	if course:
		print("Course found on retry: ", course.name)
		
		# Method 1: Try to get player from course method (most reliable)
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			if player:
				print("✓ Squirrel found player reference on retry via course.get_player_reference(): ", player.name)
				_connect_to_player_movement()
				return
			else:
				print("course.get_player_reference returned null on retry")
		
		# Method 2: Try different paths to find the player
		var possible_paths = [
			"Player",  # Direct child of course
			"player_node",  # Alternative name
			"CameraContainer/GridContainer/Player",  # Correct path based on scene hierarchy
			"CameraContainer/Player"  # Fallback path
		]
		
		for path in possible_paths:
			player = course.get_node_or_null(path)
			if player:
				print("✓ Squirrel found player reference on retry via path '", path, "': ", player.name)
				_connect_to_player_movement()
				return
		
		# Method 3: Try to find player in scene tree by name
		var scene_tree = get_tree()
		var all_nodes = scene_tree.get_nodes_in_group("")
		print("Searching ", all_nodes.size(), " nodes in scene tree for player on retry...")
		
		for node in all_nodes:
			if node.name == "Player":
				player = node
				print("✓ Squirrel found player in scene tree on retry: ", player.name)
				_connect_to_player_movement()
				return
		
		# Method 4: Try to find by script type
		for node in all_nodes:
			if node.get_script():
				var script_path = node.get_script().resource_path
				if script_path.ends_with("Player.gd"):
					player = node
					print("✓ Squirrel found player by script on retry: ", player.name)
					_connect_to_player_movement()
					return
		
		print("✗ Player still not found on retry")
		# Try one more time with a longer delay
		_setup_player_reference_final_retry()
	else:
		print("✗ Course reference still not found on retry")
		_setup_player_reference_final_retry()
	
	print("=== END PLAYER REFERENCE RETRY ===")

func _setup_player_reference_final_retry() -> void:
	"""Set up a final retry with longer delay"""
	var final_retry_timer = Timer.new()
	final_retry_timer.name = "PlayerReferenceFinalRetryTimer"
	final_retry_timer.wait_time = 3.0  # Wait 3 seconds for final retry
	final_retry_timer.one_shot = true
	final_retry_timer.timeout.connect(_final_retry_find_player_reference)
	add_child(final_retry_timer)
	final_retry_timer.start()
	print("✓ Set up final player reference retry timer")

func _final_retry_find_player_reference() -> void:
	"""Final retry to find player reference"""
	print("=== SQUIRREL FINAL PLAYER REFERENCE RETRY ===")
	
	# Remove the final retry timer
	var final_retry_timer = get_node_or_null("PlayerReferenceFinalRetryTimer")
	if final_retry_timer:
		final_retry_timer.queue_free()
	
	# Try to find course reference again
	if not course:
		course = _find_course_script()
	
	if course:
		print("Course found on final retry: ", course.name)
		
		# Method 1: Try to get player from course method (most reliable)
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			if player:
				print("✓ Squirrel found player reference on final retry via course.get_player_reference(): ", player.name)
				_connect_to_player_movement()
				return
			else:
				print("course.get_player_reference returned null on final retry")
		
		# Method 2: Try different paths to find the player
		var possible_paths = [
			"Player",  # Direct child of course
			"player_node",  # Alternative name
			"CameraContainer/GridContainer/Player",  # Correct path based on scene hierarchy
			"CameraContainer/Player"  # Fallback path
		]
		
		for path in possible_paths:
			player = course.get_node_or_null(path)
			if player:
				print("✓ Squirrel found player reference on final retry via path '", path, "': ", player.name)
				_connect_to_player_movement()
				return
		
		# Method 3: Try to find player in scene tree by name
		var scene_tree = get_tree()
		var all_nodes = scene_tree.get_nodes_in_group("")
		print("Searching ", all_nodes.size(), " nodes in scene tree for player on final retry...")
		
		for node in all_nodes:
			if node.name == "Player":
				player = node
				print("✓ Squirrel found player in scene tree on final retry: ", player.name)
				_connect_to_player_movement()
				return
		
		# Method 4: Try to find by script type
		for node in all_nodes:
			if node.get_script():
				var script_path = node.get_script().resource_path
				if script_path.ends_with("Player.gd"):
					player = node
					print("✓ Squirrel found player by script on final retry: ", player.name)
					_connect_to_player_movement()
					return
		
		print("✗ CRITICAL: Player reference not found after all retries!")
		print("This Squirrel will not react to player movement")
		print("Available course children: ", course.get_children())
		
		# Check if CameraContainer exists and what's in it
		var camera_container = course.get_node_or_null("CameraContainer")
		if camera_container:
			print("CameraContainer found, children: ", camera_container.get_children())
			var grid_container = camera_container.get_node_or_null("GridContainer")
			if grid_container:
				print("GridContainer found, children: ", grid_container.get_children())
	else:
		print("✗ CRITICAL: Course reference not found after all retries!")
	
	print("=== END FINAL PLAYER REFERENCE RETRY ===") 

# Footstep sound system functions
func _setup_footstep_sounds() -> void:
	"""Setup the footstep sound system"""
	print("✓ Setting up Squirrel footstep sound system")
	
	# Find the footstep sound nodes
	footsteps_grass_sound = get_node_or_null("FootstepsGrass")
	footsteps_snow_sound = get_node_or_null("FootstepsSnow")
	
	if footsteps_grass_sound:
		print("✓ Squirrel grass footstep sound found")
	else:
		print("✗ Squirrel grass footstep sound not found")
	
	if footsteps_snow_sound:
		print("✓ Squirrel snow footstep sound found")
	else:
		print("✗ Squirrel snow footstep sound not found")

func _play_footstep_sound_before_movement() -> void:
	"""Play footstep sound right before movement starts"""
	if not footstep_sound_enabled:
		return
	
	# Check if enough time has passed since last footstep
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_footstep_time < footstep_interval:
		return
	
	# Play appropriate footstep sound based on terrain
	if course and course.has_method("get_terrain_type"):
		var terrain_type = course.get_terrain_type(grid_position)
		if terrain_type == "snow" or terrain_type == "ice":
			_play_snow_footstep()
		else:
			_play_grass_footstep()
	else:
		# Default to grass footstep if terrain detection is not available
		_play_grass_footstep()
	
	# Update the last footstep time to prevent rapid successive sounds
	last_footstep_time = current_time

func _play_footstep_sounds_during_movement(progress: float) -> void:
	"""Play footstep sounds during movement animation"""
	if not footstep_sound_enabled:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_footstep_time < footstep_interval:
		return
	
	# Play appropriate footstep sound based on terrain
	if course and course.has_method("get_terrain_type"):
		var terrain_type = course.get_terrain_type(grid_position)
		if terrain_type == "snow" or terrain_type == "ice":
			_play_snow_footstep()
		else:
			_play_grass_footstep()
	else:
		# Default to grass footstep if terrain detection is not available
		_play_grass_footstep()
	
	last_footstep_time = current_time

func _play_grass_footstep() -> void:
	"""Play grass footstep sound"""
	if footsteps_grass_sound and footsteps_grass_sound.stream:
		footsteps_grass_sound.play()
		print("✓ Squirrel played grass footstep sound")

func _play_snow_footstep() -> void:
	"""Play snow footstep sound (for ice and sand)"""
	if footsteps_snow_sound and footsteps_snow_sound.stream:
		footsteps_snow_sound.play()
		print("✓ Squirrel played snow footstep sound")

func enable_footstep_sounds() -> void:
	"""Enable footstep sound effects"""
	footstep_sound_enabled = true
	print("✓ Squirrel footstep sounds enabled")

func disable_footstep_sounds() -> void:
	"""Disable footstep sound effects"""
	footstep_sound_enabled = false
	print("✓ Squirrel footstep sounds disabled")

func set_footstep_interval(interval: float) -> void:
	"""Set the interval between footstep sounds during movement"""
	footstep_interval = max(0.1, interval)  # Minimum 0.1 seconds
	print("✓ Squirrel footstep interval set to:", footstep_interval, "seconds") 
