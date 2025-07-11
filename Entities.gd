extends Node

# Manages all NPCs (Entities) in the world
# Handles their turns when the player ends their turn
# Provides base collision and height functionality for all NPCs

signal npc_turn_started(npc: Node)
signal npc_turn_ended(npc: Node)
signal all_npcs_turn_completed

var npcs: Array[Node] = []
var current_npc_index: int = -1
var is_npc_turn: bool = false

# Base collision and height constants for NPCs
const DEFAULT_NPC_HEIGHT = 200.0  # Default NPC height (ball needs 88.0 to pass over GangMember)
const DEFAULT_BASE_COLLISION_WIDTH = 10.0
const DEFAULT_BASE_COLLISION_HEIGHT = 6.5

# NPC ball push constants (when NPCs are moving during their turns)
const GANGMEMBER_PUSH_VELOCITY = 400.0  # Strong push for GangMembers
const POLICE_PUSH_VELOCITY = 250.0      # Medium push for Police
const DEFAULT_PUSH_VELOCITY = 300.0     # Default push for other NPCs
const PUSH_VELOCITY_MULTIPLIER = 1.5    # Multiplier when NPC is actively moving

# Collision prevention to avoid infinite recursion
var recent_collisions: Dictionary = {}  # Track recent collisions to prevent duplicates
const COLLISION_COOLDOWN = 0.1  # 100ms cooldown between same NPC-ball collisions

func _ready():
	# Disabled automatic NPC turn triggering - now controlled manually by course_1.gd
	pass

func register_npc(npc: Node) -> void:
	"""Register an NPC to be managed by this system"""
	if npc not in npcs:
		npcs.append(npc)

func unregister_npc(npc: Node) -> void:
	"""Unregister an NPC from the system"""
	if npc in npcs:
		npcs.erase(npc)

func _on_player_end_turn() -> void:
	"""Called when the player ends their turn"""
	start_npc_turns()

func start_npc_turns() -> void:
	"""Start the NPC turn sequence"""
	if npcs.is_empty():
		all_npcs_turn_completed.emit()
		return
	
	is_npc_turn = true
	current_npc_index = 0
	_take_next_npc_turn()

func _take_next_npc_turn() -> void:
	"""Take the next NPC's turn"""
	if current_npc_index >= npcs.size():
		# All NPCs have taken their turn
		_end_npc_turns()
		return
	
	var current_npc = npcs[current_npc_index]
	if is_instance_valid(current_npc):
		npc_turn_started.emit(current_npc)
		
		# Call the NPC's take_turn method
		if current_npc.has_method("take_turn"):
			current_npc.take_turn()
		else:
			_on_npc_turn_completed()
	else:
		# NPC was destroyed, skip to next
		current_npc_index += 1
		_take_next_npc_turn()

func _on_npc_turn_completed() -> void:
	"""Called when an NPC finishes their turn"""
	if current_npc_index < npcs.size():
		var completed_npc = npcs[current_npc_index]
		npc_turn_ended.emit(completed_npc)
	
	current_npc_index += 1
	_take_next_npc_turn()

func _end_npc_turns() -> void:
	"""End the NPC turn sequence"""
	is_npc_turn = false
	current_npc_index = -1
	all_npcs_turn_completed.emit()

func get_npcs() -> Array[Node]:
	"""Get all registered NPCs"""
	return npcs

func is_npc_turn_active() -> bool:
	"""Check if NPCs are currently taking their turns"""
	return is_npc_turn

# Base collision and height functionality for NPCs
func get_npc_height(npc: Node) -> float:
	"""Get the height of an NPC for collision detection"""
	if npc.has_method("get_height"):
		return npc.get_height()
	elif "height" in npc:
		return npc.height
	else:
		return DEFAULT_NPC_HEIGHT

func get_npc_y_sort_point(npc: Node) -> float:
	"""Get the Y-sort reference point for an NPC (base of collision)"""
	if npc.has_method("get_y_sort_point"):
		return npc.get_y_sort_point()
	else:
		# Default to NPC's global position Y (base level)
		return npc.global_position.y

func get_npc_base_collision_shape(npc: Node) -> Dictionary:
	"""Get the base collision shape dimensions for an NPC"""
	if npc.has_method("get_base_collision_shape"):
		return npc.get_base_collision_shape()
	else:
		# Default collision shape
		return {
			"width": DEFAULT_BASE_COLLISION_WIDTH,
			"height": DEFAULT_BASE_COLLISION_HEIGHT,
			"offset": Vector2(0, 25)  # Offset from NPC center to base
		}

func is_npc_in_range_of_ball(npc: Node, ball_position: Vector2, ball_height: float = 0.0) -> bool:
	"""Check if an NPC is in collision range of a ball"""
	# Use enhanced height collision detection with TopHeight markers
	var npc_height = Global.get_object_height_from_marker(npc)
	var npc_y_sort_point = get_npc_y_sort_point(npc)
	
	# Check if ball is within NPC's height range
	if ball_height > npc_height:
		# Ball is above NPC entirely - no collision
		return false
	
	# Check horizontal distance (using base collision shape)
	var base_shape = get_npc_base_collision_shape(npc)
	var npc_base_pos = npc.global_position + base_shape.offset
	var horizontal_distance = abs(ball_position.x - npc_base_pos.x)
	
	# Check if ball is within the base collision width
	return horizontal_distance <= base_shape.width / 2

func handle_npc_ball_collision(npc: Node, ball: Node) -> void:
	"""Handle collision between an NPC and a ball"""
	# Create a unique collision key to prevent infinite recursion
	var collision_key = str(npc.get_instance_id()) + "_" + str(ball.get_instance_id())
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check if this collision was recently handled
	if collision_key in recent_collisions:
		var last_collision_time = recent_collisions[collision_key]
		if current_time - last_collision_time < COLLISION_COOLDOWN:
			print("=== COLLISION PREVENTED (RECENT) ===")
			print("NPC:", npc.name, "Ball:", ball.name, "Time since last collision:", current_time - last_collision_time)
			return
	
	# Record this collision
	recent_collisions[collision_key] = current_time
	
	# Clean up old collision records (older than 1 second)
	var keys_to_remove = []
	for key in recent_collisions:
		if current_time - recent_collisions[key] > 1.0:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		recent_collisions.erase(key)
	
	print("=== HANDLING NPC BALL COLLISION ===")
	print("NPC:", npc.name, "Ball:", ball.name, "Ball type:", ball.get_class())
	
	# Check if this is a grenade - grenades have their own collision handling
	if ball.has_method("is_grenade_weapon") and ball.is_grenade_weapon():
		print("=== GRENADE COLLISION - USING GRENADE'S OWN HANDLING ===")
		# Let the grenade handle its own collision
		if ball.has_method("_handle_npc_collision"):
			ball._handle_npc_collision(npc)
		return
	
	# Check if NPC is currently moving during their turn
	if _is_npc_moving_during_turn(npc):
		_handle_moving_npc_ball_collision(npc, ball)
	elif npc.has_method("handle_ball_collision"):
		npc.handle_ball_collision(ball)
	else:
		# Default collision handling with velocity-based damage
		_apply_default_velocity_damage(npc, ball)

func _is_npc_moving_during_turn(npc: Node) -> bool:
	"""Check if an NPC is currently moving during their turn"""
	# Check if NPC has movement tracking properties
	if npc.has_method("is_currently_moving"):
		return npc.is_currently_moving()
	elif "is_moving" in npc:
		return npc.is_moving
	return false

func _handle_moving_npc_ball_collision(npc: Node, ball: Node) -> void:
	"""Handle collision between a moving NPC and a ball - apply push force"""
	print("=== MOVING NPC BALL COLLISION ===")
	print("NPC:", npc.name, "is moving and collided with ball")
	
	# Additional safety check - prevent grenade pushing
	if ball.has_method("is_grenade_weapon") and ball.is_grenade_weapon():
		print("=== GRENADE COLLISION IN MOVING NPC - SKIPPING PUSH ===")
		return
	
	# Get the NPC's movement direction
	var movement_direction = _get_npc_movement_direction(npc)
	if movement_direction == Vector2.ZERO:
		print("No movement direction found, using default collision")
		if npc.has_method("handle_ball_collision"):
			npc.handle_ball_collision(ball)
		else:
			_apply_default_velocity_damage(npc, ball)
		return
	
	print("NPC movement direction:", movement_direction)
	
	# Get the appropriate push velocity for this NPC type
	var push_velocity = _get_npc_push_velocity(npc)
	print("NPC push velocity:", push_velocity)
	
	# Calculate the push force vector
	var push_force = movement_direction * push_velocity
	print("Calculated push force:", push_force)
	
	# Apply the push force to the ball
	_apply_ball_push_force(ball, push_force)
	
	# Play collision sound if available
	_play_npc_collision_sound(npc)
	
	print("=== END MOVING NPC BALL COLLISION ===")

func _get_npc_movement_direction(npc: Node) -> Vector2:
	"""Get the current movement direction of an NPC"""
	# Try different methods to get movement direction
	if npc.has_method("get_movement_direction"):
		return npc.get_movement_direction()
	elif npc.has_method("get_last_movement_direction"):
		var last_dir = npc.get_last_movement_direction()
		return Vector2(last_dir.x, last_dir.y)
	elif "last_movement_direction" in npc:
		var last_dir = npc.last_movement_direction
		return Vector2(last_dir.x, last_dir.y)
	elif "facing_direction" in npc:
		var facing_dir = npc.facing_direction
		return Vector2(facing_dir.x, facing_dir.y)
	
	return Vector2.ZERO

func _get_npc_push_velocity(npc: Node) -> float:
	"""Get the appropriate push velocity for an NPC type"""
	# Check NPC type and return appropriate velocity
	if npc.name.contains("GangMember") or npc.get_script().resource_path.contains("GangMember"):
		return GANGMEMBER_PUSH_VELOCITY
	elif npc.name.contains("Police") or npc.get_script().resource_path.contains("Police"):
		return POLICE_PUSH_VELOCITY
	else:
		return DEFAULT_PUSH_VELOCITY

func _apply_ball_push_force(ball: Node, push_force: Vector2) -> void:
	"""Apply a push force to a ball"""
	# Get the ball's current velocity
	var ball_velocity = Vector2.ZERO
	if ball.has_method("get_velocity"):
		ball_velocity = ball.get_velocity()
	elif "velocity" in ball:
		ball_velocity = ball.velocity
	
	print("Ball original velocity:", ball_velocity)
	
	# Check if ball is in landed/stationary state
	var is_landed = false
	var is_rolling = false
	
	if ball.has_method("is_in_flight"):
		is_landed = not ball.is_in_flight()
	elif "landed_flag" in ball:
		is_landed = ball.landed_flag
	elif "is_rolling" in ball:
		is_rolling = ball.is_rolling
	
	# If ball is landed/stationary, we need to "wake it up"
	if is_landed or (ball_velocity.length() < 10.0 and not is_rolling):
		print("Ball is landed/stationary - waking it up with push force")
		
		# Set a minimum velocity to make the push visible
		var min_push_velocity = 100.0  # Minimum velocity to make push visible
		var normalized_push = push_force.normalized()
		var effective_push_force = normalized_push * max(push_force.length(), min_push_velocity)
		
		# Apply the effective push force
		var new_velocity = effective_push_force
		print("Applied effective push force:", new_velocity)
		
		# Apply the new velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(new_velocity)
		elif "velocity" in ball:
			ball.velocity = new_velocity
		
		# Re-enable rolling state if the ball supports it
		if ball.has_method("set_rolling_state"):
			ball.set_rolling_state(true)
		elif "is_rolling" in ball:
			ball.is_rolling = true
		
		# Reset landed flag if the ball supports it
		if ball.has_method("set_landed_flag"):
			ball.set_landed_flag(false)
		elif "landed_flag" in ball:
			ball.landed_flag = false
		
		print("Ball awakened with velocity:", new_velocity)
	else:
		# Ball is already moving - add push force to existing velocity
		var new_velocity = ball_velocity + push_force
		print("Ball new velocity:", new_velocity)
		
		# Apply the new velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(new_velocity)
		elif "velocity" in ball:
			ball.velocity = new_velocity

func _play_npc_collision_sound(npc: Node) -> void:
	"""Play collision sound for NPC collision"""
	# Try to play collision sound if NPC has one
	if npc.has_method("_play_collision_sound"):
		npc._play_collision_sound()
	elif npc.has_method("play_collision_sound"):
		npc.play_collision_sound()

func _apply_default_velocity_damage(npc: Node, ball: Node) -> void:
	"""Apply default velocity-based damage to an NPC"""
	# Check if this is a ghost ball (shouldn't deal damage)
	var is_ghost_ball = false
	if ball.has_method("is_ghost"):
		is_ghost_ball = ball.is_ghost
	elif "is_ghost" in ball:
		is_ghost_ball = ball.is_ghost
	elif ball.name == "GhostBall":
		is_ghost_ball = true
	
	if is_ghost_ball:
		# Ghost balls only reflect, no damage
		var ball_velocity = Vector2.ZERO
		if ball.has_method("get_velocity"):
			ball_velocity = ball.get_velocity()
		elif "velocity" in ball:
			ball_velocity = ball.velocity
		
		var ball_pos = ball.global_position
		var npc_center = npc.global_position
		
		# Calculate the direction from NPC center to ball
		var to_ball_direction = (ball_pos - npc_center).normalized()
		
		# Simple reflection
		var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		reflected_velocity *= 0.8  # Reduce speed slightly
		
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
	
	# Calculate damage based on ball velocity
	var damage = _calculate_default_velocity_damage(ball_velocity.length())
	
	# Check if this damage will kill the NPC
	var current_health = 30  # Default health for NPCs
	if npc.has_method("get_current_health"):
		current_health = npc.get_current_health()
	elif "current_health" in npc:
		current_health = npc.current_health
	
	var will_kill = damage >= current_health
	var overkill_damage = 0
	
	if will_kill:
		# Calculate overkill damage
		overkill_damage = damage - current_health
		
		# Apply damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC ", npc.name, " does not have take_damage method")
		
		# Apply velocity dampening based on overkill damage
		var dampened_velocity = _calculate_default_kill_dampening(ball_velocity, overkill_damage)
		
		# Apply the dampened velocity to the ball (no reflection)
		if ball.has_method("set_velocity"):
			ball.set_velocity(dampened_velocity)
		elif "velocity" in ball:
			ball.velocity = dampened_velocity
	else:
		# Normal collision - apply damage and reflect (default behavior)
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC ", npc.name, " does not have take_damage method")
		
		# For default NPCs, we'll do a simple reflection
		var ball_pos = ball.global_position
		var npc_center = npc.global_position
		
		# Calculate the direction from NPC center to ball
		var to_ball_direction = (ball_pos - npc_center).normalized()
		
		# Simple reflection
		var reflected_velocity = ball_velocity - 2 * ball_velocity.dot(to_ball_direction) * to_ball_direction
		reflected_velocity *= 0.8  # Reduce speed slightly
		
		# Apply the reflected velocity to the ball
		if ball.has_method("set_velocity"):
			ball.set_velocity(reflected_velocity)
		elif "velocity" in ball:
			ball.velocity = reflected_velocity

func _calculate_default_velocity_damage(velocity_magnitude: float) -> int:
	"""Calculate default damage based on ball velocity magnitude"""
	# Define velocity ranges for damage scaling (same as GangMember)
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

func _calculate_default_kill_dampening(ball_velocity: Vector2, overkill_damage: int) -> Vector2:
	"""Calculate default velocity dampening when ball kills an NPC"""
	# Define dampening ranges (same as GangMember)
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
	
	return dampened_velocity 
