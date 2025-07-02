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

func _ready():
	# Disabled automatic NPC turn triggering - now controlled manually by course_1.gd
	pass

func register_npc(npc: Node) -> void:
	"""Register an NPC to be managed by this system"""
	if npc not in npcs:
		npcs.append(npc)
		print("Registered NPC: ", npc.name)

func unregister_npc(npc: Node) -> void:
	"""Unregister an NPC from the system"""
	if npc in npcs:
		npcs.erase(npc)
		print("Unregistered NPC: ", npc.name)

func _on_player_end_turn() -> void:
	"""Called when the player ends their turn"""
	print("Player ended turn, starting NPC turns...")
	start_npc_turns()

func start_npc_turns() -> void:
	"""Start the NPC turn sequence"""
	if npcs.is_empty():
		print("No NPCs to take turns")
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
		print("NPC taking turn: ", current_npc.name)
		npc_turn_started.emit(current_npc)
		
		# Call the NPC's take_turn method
		if current_npc.has_method("take_turn"):
			current_npc.take_turn()
		else:
			print("Warning: NPC ", current_npc.name, " doesn't have take_turn method")
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
	print("All NPC turns completed")
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
	var npc_height = get_npc_height(npc)
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
	if npc.has_method("handle_ball_collision"):
		npc.handle_ball_collision(ball)
	else:
		# Default collision handling with velocity-based damage
		print("Default NPC-ball collision handling for: ", npc.name)
		_apply_default_velocity_damage(npc, ball)

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
		print("Ghost ball detected - no damage dealt, just reflection")
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
	print("Default NPC collision damage calculated:", damage)
	
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
		print("Damage will kill NPC! Overkill damage:", overkill_damage)
		
		# Apply damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC ", npc.name, " does not have take_damage method")
		
		# Apply velocity dampening based on overkill damage
		var dampened_velocity = _calculate_default_kill_dampening(ball_velocity, overkill_damage)
		print("Ball passed through with dampened velocity:", dampened_velocity)
		
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
	
	# Debug output
	print("=== DEFAULT VELOCITY DAMAGE CALCULATION ===")
	print("Raw velocity magnitude:", velocity_magnitude)
	print("Clamped velocity:", clamped_velocity)
	print("Damage percentage:", damage_percentage)
	print("Calculated damage:", damage)
	print("Final damage (int):", final_damage)
	print("=== END DEFAULT VELOCITY DAMAGE CALCULATION ===")
	
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
	
	# Debug output
	print("=== DEFAULT KILL DAMPENING CALCULATION ===")
	print("Overkill damage:", overkill_damage)
	print("Clamped overkill:", clamped_overkill)
	print("Dampening percentage:", dampening_percentage)
	print("Dampening factor:", dampening_factor)
	print("Original velocity magnitude:", ball_velocity.length())
	print("Dampened velocity magnitude:", dampened_velocity.length())
	print("=== END DEFAULT KILL DAMPENING CALCULATION ===")
	
	return dampened_velocity 
