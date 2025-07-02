extends CharacterBody2D

# GangMember NPC - handles GangMember-specific functions
# Integrates with the Entities system for turn management

signal turn_completed

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var grid_position: Vector2i
var cell_size: int = 48
var entities_manager: Node

# GangMember specific properties
var gang_member_type: String = "default"
var movement_range: int = 3
var vision_range: int = 12
var current_action: String = "idle"

# Facing direction properties
var facing_direction: Vector2i = Vector2i(1, 0)  # Start facing right
var last_movement_direction: Vector2i = Vector2i(1, 0)  # Track last movement direction

# Health and damage properties
var max_health: int = 30
var current_health: int = 30
var is_alive: bool = true
var is_dead: bool = false

# Collision and height properties
var height: float = 200.0  # Half of tree height (400/2)
var dead_height: float = 50.0  # Lower height when dead (laying down)
var base_collision_area: Area2D

# Health bar
var health_bar: HealthBar
var health_bar_container: Control

# State Machine
enum State {PATROL, CHASE, DEAD}
var current_state: State = State.PATROL
var state_machine: StateMachine

# References
var player: Node
var course: Node

func _ready():
	# Connect to Entities manager
	# Find the course_1.gd script by searching up the scene tree
	course = _find_course_script()
	print("GangMember course reference: ", course.name if course else "None")
	print("Course script: ", course.get_script().resource_path if course and course.get_script() else "None")
	if course and course.has_node("Entities"):
		entities_manager = course.get_node("Entities")
		entities_manager.register_npc(self)
		entities_manager.npc_turn_started.connect(_on_turn_started)
		entities_manager.npc_turn_ended.connect(_on_turn_ended)
	
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
		# Connect to area_entered signal for collision detection
		base_collision_area.connect("area_entered", _on_base_area_entered)
		print("✓ GangMember base collision area setup complete")
	else:
		print("✗ ERROR: BaseCollisionArea not found!")

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
	
	print("✓ GangMember health bar created")

func _on_base_area_entered(area: Area2D) -> void:
	"""Handle collisions with the base collision area"""
	var ball = area.get_parent()
	print("=== GANGMEMBER BASE COLLISION DETECTED ===")
	print("Area name:", area.name)
	print("Ball parent:", ball.name if ball else "No parent")
	print("Ball type:", ball.get_class() if ball else "Unknown")
	print("Ball position:", ball.global_position if ball else "Unknown")
	
	if ball and (ball.name == "GolfBall" or ball.name == "GhostBall"):
		print("Valid ball detected:", ball.name)
		# Handle the collision
		_handle_ball_collision(ball)
	else:
		print("Invalid ball or non-ball object:", ball.name if ball else "Unknown")
	print("=== END GANGMEMBER BASE COLLISION ===")

func _handle_ball_collision(ball: Node2D) -> void:
	"""Handle ball collisions - check height to determine if ball should pass through"""
	print("Handling ball collision - checking ball height")
	
	# Get ball height
	var ball_height = 0.0
	if ball.has_method("get_height"):
		ball_height = ball.get_height()
	elif "z" in ball:
		ball_height = ball.z
	
	print("Ball height:", ball_height, "GangMember height:", height)
	
	# Check if ball is above GangMember entirely
	if ball_height > height:
		# Ball is above GangMember entirely - let it pass through
		print("Ball is above GangMember entirely (height:", ball_height, "> GangMember height:", height, ") - passing through")
		return
	else:
		# Ball is within or below GangMember height - handle collision
		print("Ball is within GangMember height (height:", ball_height, "<= GangMember height:", height, ") - handling collision")
		
		# Play collision sound effect
		_play_collision_sound()
		
		# Apply collision effect to the ball
		_apply_ball_collision_effect(ball)

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
		var gang_member_center = global_position
		
		# Calculate the direction from GangMember center to ball
		var to_ball_direction = (ball_pos - gang_member_center).normalized()
		
		# Simple reflection: reflect the velocity across the GangMember center
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
	
	# Calculate damage based on ball velocity
	var damage = _calculate_velocity_damage(ball_velocity.length())
	print("Ball collision damage calculated:", damage)
	
	# Check if this damage will kill the GangMember
	var will_kill = damage >= current_health
	var overkill_damage = 0
	
	if will_kill:
		# Calculate overkill damage (negative health value)
		overkill_damage = damage - current_health
		print("Damage will kill GangMember! Overkill damage:", overkill_damage)
		
		# Apply damage to the GangMember (this will set health to negative)
		take_damage(damage)
		
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
		take_damage(damage)
		
		var ball_pos = ball.global_position
		var gang_member_center = global_position
		
		# Calculate the direction from GangMember center to ball
		var to_ball_direction = (ball_pos - gang_member_center).normalized()
		
		# Simple reflection: reflect the velocity across the GangMember center
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

func _process(delta):
	# Update Y-sort every frame to stay in sync with camera movement
	update_z_index_for_ysort()

func _find_player_reference() -> void:
	"""Find the player reference using multiple methods"""
	print("=== PLAYER FINDING DEBUG ===")
	
	# Method 1: Try to get player from course method (most reliable)
	if course and course.has_method("get_player_reference"):
		player = course.get_player_reference()
		if player:
			print("Found player from course get_player_reference: ", player.name)
			return
		else:
			print("course.get_player_reference returned null")
	
	# Method 2: Try to find player in course
	if course and course.has_node("Player"):
		player = course.get_node("Player")
		print("Found player in course: ", player.name if player else "None")
		if player:
			return
	
	# Method 3: Try to get player from course_1.gd script method
	if course and course.has_method("get_player_node"):
		player = course.get_player_node()
		print("Found player from course script: ", player.name if player else "None")
		if player:
			return
	
	# Method 4: Try to find player in scene tree by name
	var scene_tree = get_tree()
	var all_nodes = scene_tree.get_nodes_in_group("")
	print("Searching ", all_nodes.size(), " nodes in scene tree...")
	
	for node in all_nodes:
		if node.name == "Player":
			player = node
			print("Found player in scene tree: ", player.name)
			return
	
	# Method 5: Try to find by script type
	for node in all_nodes:
		if node.get_script():
			var script_path = node.get_script().resource_path
			print("Node ", node.name, " has script: ", script_path)
			if script_path.ends_with("Player.gd"):
				player = node
				print("Found player by script: ", player.name)
				return
	
	print("ERROR: Could not find player reference!")
	print("=== END PLAYER FINDING DEBUG ===")

func _exit_tree():
	# Unregister from Entities manager when destroyed
	if entities_manager:
		entities_manager.unregister_npc(self)

func setup(member_type: String, pos: Vector2i, cell_size_param: int = 48) -> void:
	"""Setup the GangMember with specific parameters"""
	gang_member_type = member_type
	grid_position = pos
	cell_size = cell_size_param
	
	# Set position based on grid position
	position = Vector2(grid_position.x, grid_position.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Load appropriate sprite based on type
	_load_sprite_for_type(member_type)
	
	# Initialize sprite facing direction
	_update_sprite_facing()
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("GangMember setup: ", member_type, " at ", pos)

func _load_sprite_for_type(type: String) -> void:
	"""Load the appropriate sprite texture based on gang member type"""
	var texture_path = "res://NPC/Gang/GangMember1.png"  # Default
	
	# You can expand this to load different sprites based on type
	match type:
		"default":
			texture_path = "res://NPC/Gang/GangMember1.png"
		"variant1":
			texture_path = "res://NPC/Gang/GangMember1.png"  # Same for now
		"variant2":
			texture_path = "res://NPC/Gang/GangMember1.png"  # Same for now
		_:
			texture_path = "res://NPC/Gang/GangMember1.png"
	
	var texture = load(texture_path)
	if texture and sprite:
		sprite.texture = texture
		
		# Scale sprite to fit cell size
		if texture.get_size().x > 0 and texture.get_size().y > 0:
			var scale_x = cell_size / texture.get_size().x
			var scale_y = cell_size / texture.get_size().y
			sprite.scale = Vector2(scale_x, scale_y)

func take_turn() -> void:
	"""Called by Entities manager when it's this NPC's turn"""
	print("GangMember taking turn: ", name)
	
	# Skip turn if dead
	if is_dead:
		print("GangMember is dead, skipping turn")
		call_deferred("_complete_turn")
		return
	
	# Try to get player reference if we don't have one
	if not player and course:
		print("Attempting to get player reference from course...")
		print("Course during turn: ", course.name if course else "None")
		print("Course script during turn: ", course.get_script().resource_path if course and course.get_script() else "None")
		if course.has_method("get_player_reference"):
			player = course.get_player_reference()
			print("Got player reference during turn: ", player.name if player else "None")
		else:
			print("Course does not have get_player_reference method")
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
	
	# Check if player is in vision range
	_check_player_vision()
	
	# Let the current state handle the turn
	state_machine.update()
	
	# Complete turn after state processing
	call_deferred("_complete_turn")

func _check_player_vision() -> void:
	"""Check if player is within vision range and switch to chase if needed"""
	if not player:
		print("No player reference found for vision check")
		return
	
	var player_pos = player.grid_pos
	var distance = grid_position.distance_to(player_pos)
	
	print("Vision check - Player at ", player_pos, ", distance: ", distance, ", vision range: ", vision_range)
	
	if distance <= vision_range:
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

func _on_turn_started(npc: Node) -> void:
	"""Called when an NPC's turn starts"""
	if npc == self:
		print("GangMember turn started: ", name)

func _on_turn_ended(npc: Node) -> void:
	"""Called when an NPC's turn ends"""
	if npc == self:
		print("GangMember turn ended: ", name)

func _complete_turn() -> void:
	"""Complete the current turn"""
	turn_completed.emit()
	
	# Notify Entities manager that turn is complete
	if entities_manager:
		entities_manager._on_npc_turn_completed()

func get_grid_position() -> Vector2i:
	"""Get the current grid position"""
	return grid_position

func set_grid_position(pos: Vector2i) -> void:
	"""Set the grid position and update world position"""
	grid_position = pos
	position = Vector2(pos.x, pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)

func _get_valid_adjacent_positions() -> Array[Vector2i]:
	"""Get valid adjacent positions the GangMember can move to"""
	var valid_positions: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	
	for direction in directions:
		var new_pos = grid_position + direction
		if _is_position_valid(new_pos):
			valid_positions.append(new_pos)
	
	return valid_positions

func _is_position_valid(pos: Vector2i) -> bool:
	"""Check if a position is valid for the GangMember to move to"""
	# Basic bounds checking - ensure position is within reasonable grid bounds
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		return false
	
	# For now, allow movement to any position within bounds
	# In the future, you can add obstacle checking here
	return true

func _move_to_position(target_pos: Vector2i) -> void:
	"""Move the GangMember to a new position"""
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
	
	# Simple movement - you could add tweening here for smooth movement
	position = target_world_pos
	
	# Update Y-sorting
	update_z_index_for_ysort()
	
	print("GangMember moved from ", old_pos, " to ", target_pos, " with direction: ", movement_direction)
	
	# Check if we moved to the same tile as the player (only if we weren't already there)
	if player and "grid_pos" in player and player.grid_pos == target_pos and old_pos != target_pos:
		print("GangMember collided with player! Dealing damage and pushing back...")
		var approach_direction = target_pos - old_pos
		_handle_player_collision(approach_direction)

func _handle_player_collision(approach_direction: Vector2i = Vector2i.ZERO) -> void:
	"""Handle collision with player - deal damage and push back"""
	if not player:
		return
	
	# Play collision sound effect
	_play_collision_sound()
	
	# Deal 15 damage to the player
	if course and course.has_method("take_damage"):
		course.take_damage(15)
		print("Player took 15 damage from GangMember collision")
		
		# Flash the player red to indicate damage
		if player and player.has_method("flash_damage"):
			player.flash_damage()
	
	# Push player back to nearest available adjacent tile
	var pushback_pos = _find_nearest_available_adjacent_tile(player.grid_pos, approach_direction)
	print("Pushback calculation - Player at: ", player.grid_pos, ", Pushback target: ", pushback_pos)
	if pushback_pos != player.grid_pos:
		print("Pushing player from ", player.grid_pos, " to ", pushback_pos)
		
		# Temporarily disconnect the moved_to_tile signal to prevent conflicts
		var signal_was_connected = false
		if player and player.has_signal("moved_to_tile") and course:
			signal_was_connected = true
			player.moved_to_tile.disconnect(course._on_player_moved_to_tile)
		
		player.set_grid_position(pushback_pos)
		print("Player grid position updated to: ", player.grid_pos)
		print("Player world position: ", player.position)
		
		# Reconnect the signal if it was connected
		if signal_was_connected:
			player.moved_to_tile.connect(course._on_player_moved_to_tile)
		
		# Update the course's player_grid_pos variable first
		if course and "player_grid_pos" in course:
			course.player_grid_pos = pushback_pos
			print("Course player_grid_pos updated to: ", course.player_grid_pos)
		
		# Update the course's player position reference
		if course and course.has_method("update_player_position"):
			course.update_player_position()
		
		# Verify the position was actually updated
		print("Final verification - Player grid_pos: ", player.grid_pos, ", Course player_grid_pos: ", course.player_grid_pos if course else "N/A")
		
		# The GangMember stays in the position where the collision occurred (player's original position)
		# No need to move the GangMember - it should occupy the tile the player was pushed from
		print("GangMember staying in collision position: ", grid_position)
		
		# Update Y-sorting for the new position
		update_z_index_for_ysort()
	else:
		print("No available adjacent tile found for pushback")

func _move_gang_member_away_from_player() -> void:
	"""Move the GangMember to a position away from the player to prevent immediate re-collision"""
	var current_pos = grid_position
	var player_pos = player.grid_pos if player else Vector2i.ZERO
	
	print("GangMember repositioning - Current pos: ", current_pos, ", Player pos after pushback: ", player_pos)
	
	# Try to find a position that's not the player's new position
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	
	for direction in directions:
		var new_pos = current_pos + direction
		print("Checking GangMember move to: ", new_pos, " (direction: ", direction, ")")
		if new_pos != player_pos and _is_position_valid(new_pos):
			print("Moving GangMember away from collision to: ", new_pos)
			grid_position = new_pos
			position = Vector2(new_pos.x, new_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			return
		else:
			if new_pos == player_pos:
				print("Position ", new_pos, " is occupied by player")
			else:
				print("Position ", new_pos, " is not valid for GangMember")
	
	# If no valid position found, try the opposite direction from the player
	var away_direction = (current_pos - player_pos)
	if away_direction.x != 0 or away_direction.y != 0:
		# Normalize the direction
		if away_direction.x != 0:
			away_direction.x = 1 if away_direction.x > 0 else -1
		if away_direction.y != 0:
			away_direction.y = 1 if away_direction.y > 0 else -1
		
		var new_pos = current_pos + away_direction
		print("Trying opposite direction: ", new_pos, " (away_direction: ", away_direction, ")")
		if _is_position_valid(new_pos):
			print("Moving GangMember in opposite direction to: ", new_pos)
			grid_position = new_pos
			position = Vector2(new_pos.x, new_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			return
		else:
			print("Opposite direction position ", new_pos, " is not valid")
	
	print("Could not move GangMember away from collision - staying in place")

func update_z_index_for_ysort() -> void:
	"""Update GangMember Y-sort using the simple global system"""
	# Use the global Y-sort system for characters
	Global.update_object_y_sort(self, "characters")

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

func _play_death_sound() -> void:
	"""Play the death groan sound when the GangMember dies"""
	print("_play_death_sound() called")
	# Use the existing DeathGroan audio player on the GangMember
	var death_audio = get_node_or_null("DeathGroan")
	if death_audio:
		print("DeathGroan audio player found, stream:", death_audio.stream)
		print("DeathGroan audio player volume:", death_audio.volume_db)
		print("DeathGroan audio player playing:", death_audio.playing)
		print("DeathGroan audio player autoplay:", death_audio.autoplay)
		
		# Ensure the audio player is not muted and has proper volume
		death_audio.volume_db = 0.0  # Set to full volume
		death_audio.play()
		print("Playing death groan sound using existing audio player")
		print("DeathGroan audio player playing after play():", death_audio.playing)
	else:
		print("ERROR: DeathGroan audio player not found on GangMember")

func _find_nearest_available_adjacent_tile(player_pos: Vector2i, approach_direction: Vector2i = Vector2i.ZERO) -> Vector2i:
	"""Find the nearest available adjacent tile to push the player to based on GangMember's approach direction"""
	# Use the passed approach direction
	var gang_member_approach_direction = approach_direction
	print("GangMember approach direction: ", gang_member_approach_direction)
	
	# The pushback direction is the same as the approach direction (player gets pushed in the direction GangMember came from)
	var pushback_direction = gang_member_approach_direction
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
		print("Checking fallback position: ", adjacent_pos, " (direction: ", direction, ")")
		if _is_position_valid_for_player(adjacent_pos):
			print("Found valid fallback pushback position: ", adjacent_pos)
			return adjacent_pos
	
	# If no valid adjacent tile found, return the original position
	print("No valid adjacent tile found for player pushback")
	return player_pos

func _get_gang_member_approach_direction() -> Vector2i:
	"""Get the direction the GangMember moved to reach the player"""
	# We need to track the previous position before the collision
	# For now, we'll calculate it based on the current movement
	# This assumes the collision just happened and we're still in the _move_to_position function
	
	# The approach direction is the direction from the old position to the current position
	# We can get this from the _move_to_position function's old_pos parameter
	# But since we're in a different function, we'll need to pass this information
	
	# For now, let's use a simple approach - we'll modify the collision handling to pass this info
	return Vector2i.ZERO  # Placeholder

func _get_perpendicular_directions(direction: Vector2i) -> Array[Vector2i]:
	"""Get the two perpendicular directions to the given direction"""
	var perpendicular_dirs: Array[Vector2i] = []
	
	if direction.x != 0:  # Horizontal movement
		perpendicular_dirs.append(Vector2i(0, -1))  # Up
		perpendicular_dirs.append(Vector2i(0, 1))   # Down
	elif direction.y != 0:  # Vertical movement
		perpendicular_dirs.append(Vector2i(-1, 0))  # Left
		perpendicular_dirs.append(Vector2i(1, 0))   # Right
	
	return perpendicular_dirs

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
	
	# Check if the position is occupied by another GangMember
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
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		sprite.flip_h = true
	elif facing_direction.x > 0:
		sprite.flip_h = false
	
	# Also update dead sprite if it's visible
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite and dead_sprite.visible:
		if facing_direction.x < 0:
			dead_sprite.flip_h = true
		elif facing_direction.x > 0:
			dead_sprite.flip_h = false
	
	print("Updated sprite facing - Direction: ", facing_direction, ", Flip H: ", sprite.flip_h)

func _face_player() -> void:
	"""Make the GangMember face the player"""
	if not player:
		return
	
	var player_pos = player.grid_pos
	var direction_to_player = player_pos - grid_position
	
	# Normalize the direction to get primary direction
	if direction_to_player.x != 0:
		direction_to_player.x = 1 if direction_to_player.x > 0 else -1
	if direction_to_player.y != 0:
		direction_to_player.y = 1 if direction_to_player.y > 0 else -1
	
	# Update facing direction to face the player
	facing_direction = direction_to_player
	_update_sprite_facing()
	
	print("Facing player - Direction: ", facing_direction)

func _update_dead_sprite_facing() -> void:
	"""Update the dead sprite facing direction based on facing_direction"""
	var dead_sprite = get_node_or_null("Dead")
	if not dead_sprite:
		return
	
	# Flip dead sprite horizontally based on facing direction
	# If facing left (negative x), flip the sprite
	if facing_direction.x < 0:
		dead_sprite.flip_h = true
	elif facing_direction.x > 0:
		dead_sprite.flip_h = false
	
	print("Updated dead sprite facing - Direction: ", facing_direction, ", Flip H: ", dead_sprite.flip_h)

# Height and collision shape methods for Entities system
func get_height() -> float:
	"""Get the height of this GangMember for collision detection"""
	return height

func get_y_sort_point() -> float:
	var ysort_point_node = get_node_or_null("YsortPoint")
	if ysort_point_node:
		return ysort_point_node.global_position.y
	else:
		return global_position.y

func get_base_collision_shape() -> Dictionary:
	"""Get the base collision shape dimensions for this GangMember"""
	return {
		"width": 10.0,
		"height": 6.5,
		"offset": Vector2(0, 25)  # Offset from GangMember center to base
	}

func handle_ball_collision(ball: Node2D) -> void:
	"""Handle collision with a ball - called by Entities system"""
	_handle_ball_collision(ball)

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
	var gang_member: Node
	
	func _init(gm: Node):
		gang_member = gm
	
	func enter() -> void:
		pass
	
	func update() -> void:
		pass
	
	func exit() -> void:
		pass

# Patrol State
class PatrolState extends BaseState:
	func enter() -> void:
		print("GangMember entering patrol state")
	
	func update() -> void:
		print("PatrolState update called")
		# Random movement up to 3 spaces away
		var move_distance = randi_range(1, gang_member.movement_range)
		print("Patrol move distance: ", move_distance)
		var target_pos = _get_random_patrol_position(move_distance)
		print("Patrol target position: ", target_pos)
		
		if target_pos != gang_member.grid_position:
			print("Moving to new position")
			gang_member._move_to_position(target_pos)
		else:
			print("Staying in same position")
			# Face the last movement direction when not moving
			gang_member.facing_direction = gang_member.last_movement_direction
			gang_member._update_sprite_facing()
	
	func _get_random_patrol_position(max_distance: int) -> Vector2i:
		var attempts = 0
		var max_attempts = 10
		
		while attempts < max_attempts:
			var random_direction = Vector2i(
				randi_range(-max_distance, max_distance),
				randi_range(-max_distance, max_distance)
			)
			
			var target_pos = gang_member.grid_position + random_direction
			
			if gang_member._is_position_valid(target_pos):
				return target_pos
			
			attempts += 1
		
		# If no valid position found, try adjacent positions
		var adjacent = gang_member._get_valid_adjacent_positions()
		if adjacent.size() > 0:
			return adjacent[randi() % adjacent.size()]
		
		return gang_member.grid_position

# Chase State
class ChaseState extends BaseState:
	func enter() -> void:
		print("GangMember entering chase state")
	
	func update() -> void:
		print("ChaseState update called")
		if not gang_member.player:
			print("No player found for chase")
			return
		
		var player_pos = gang_member.player.grid_pos
		print("Player position: ", player_pos)
		var path = _get_path_to_player(player_pos)
		print("Chase path: ", path)
		
		if path.size() > 1:
			var next_pos = path[1]  # First step towards player
			print("Moving towards player to: ", next_pos)
			gang_member._move_to_position(next_pos)
		else:
			print("No path found to player")
		
		# Always face the player when in chase mode
		gang_member._face_player()

	func _get_path_to_player(player_pos: Vector2i) -> Array[Vector2i]:
		# Simple pathfinding - move towards player
		var path: Array[Vector2i] = [gang_member.grid_position]
		var current_pos = gang_member.grid_position
		var max_steps = gang_member.movement_range
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
			
			if gang_member._is_position_valid(next_pos):
				current_pos = next_pos
				path.append(current_pos)
				print("Pathfinding - Valid position, moving to: ", current_pos)
			else:
				print("Pathfinding - Invalid position, trying adjacent positions")
				# Try to find an alternative path
				var adjacent = gang_member._get_valid_adjacent_positions()
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
		print("GangMember entering dead state")
		# Change sprite to dead version
		gang_member._change_to_dead_sprite()
		# Lower height for collision detection
		gang_member.height = gang_member.dead_height
		# Hide health bar
		if gang_member.health_bar_container:
			gang_member.health_bar_container.visible = false
		# Update dead sprite facing direction
		gang_member._update_dead_sprite_facing()
	
	func update() -> void:
		# Dead GangMembers don't move or take actions
		pass
	
	func exit() -> void:
		pass

# Health and damage methods
func take_damage(amount: int) -> void:
	"""Take damage and handle death if health reaches 0"""
	if not is_alive:
		print("GangMember is already dead, ignoring damage")
		return
	
	# Allow negative health for overkill calculations
	current_health = current_health - amount
	print("GangMember took", amount, "damage. Current health:", current_health, "/", max_health)
	
	# Update health bar (but don't show negative values to player)
	var display_health = max(0, current_health)
	if health_bar:
		health_bar.set_health(display_health, max_health)
	
	# Flash red to indicate damage
	flash_damage()
	
	if current_health <= 0 and not is_dead:
		print("GangMember health reached 0, calling die()")
		die()
	else:
		print("GangMember survived with", current_health, "health")

func heal(amount: int) -> void:
	"""Heal the GangMember"""
	if not is_alive:
		return
	
	current_health = min(max_health, current_health + amount)
	print("GangMember healed", amount, "HP. Current health:", current_health, "/", max_health)

func die() -> void:
	"""Handle the GangMember's death"""
	if not is_alive or is_dead:
		print("GangMember is already dead, ignoring die() call")
		return
	
	is_alive = false
	is_dead = true
	print("GangMember has died!")
	
	# Play death groan sound
	print("Calling _play_death_sound()")
	_play_death_sound()
	
	# Switch to dead state
	current_state = State.DEAD
	state_machine.set_state("dead")
	
	# Don't unregister from Entities system - dead GangMembers can still be pushed
	# But they won't take turns anymore since the dead state doesn't do anything

func _change_to_dead_sprite() -> void:
	"""Change the sprite to the dead version"""
	# Hide the main sprite
	if sprite:
		sprite.visible = false
	
	# Show the dead sprite
	var dead_sprite = get_node_or_null("Dead")
	if dead_sprite:
		dead_sprite.visible = true
		# Apply the same facing direction to the dead sprite
		_update_dead_sprite_facing()
		print("✓ GangMember switched to dead sprite")
	else:
		print("✗ ERROR: Dead sprite not found")
	
	# Switch collision shapes
	_switch_to_dead_collision()

func _switch_to_dead_collision() -> void:
	"""Switch to the dead collision shape"""
	# Disable the main base collision area
	if base_collision_area:
		base_collision_area.monitoring = false
		base_collision_area.monitorable = false
		print("✓ Disabled main collision area")
	
	# Enable the dead collision area
	var dead_collision_area = get_node_or_null("Dead/BaseCollisionArea")
	if dead_collision_area:
		dead_collision_area.monitoring = true
		dead_collision_area.monitorable = true
		# Set collision layer to 1 so golf balls can detect it
		dead_collision_area.collision_layer = 1
		# Set collision mask to 1 so it can detect golf balls on layer 1
		dead_collision_area.collision_mask = 1
		# Connect to area_entered signal for collision detection
		if not dead_collision_area.is_connected("area_entered", _on_base_area_entered):
			dead_collision_area.connect("area_entered", _on_base_area_entered)
		print("✓ Enabled dead collision area")
	else:
		print("✗ ERROR: Dead/BaseCollisionArea not found")

func flash_damage() -> void:
	"""Flash the GangMember red to indicate damage taken"""
	if not sprite:
		return
	
	var original_modulate = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 0, 0, 1), 0.1)
	tween.tween_property(sprite, "modulate", original_modulate, 0.2)

func play_death_effect() -> void:
	"""Play death animation or effect"""
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
		tween.tween_callback(queue_free)

func get_health_percentage() -> float:
	"""Get current health as a percentage"""
	return float(current_health) / float(max_health)

func is_healthy() -> bool:
	"""Check if the GangMember is at full health"""
	return current_health >= max_health

func get_is_dead() -> bool:
	"""Check if the GangMember is dead"""
	return is_dead 
