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
const DEFAULT_NPC_HEIGHT = 200.0  # Half of tree height (400/2)
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
		# Default collision handling
		print("Default NPC-ball collision handling for: ", npc.name)
		# You can add default collision effects here 
