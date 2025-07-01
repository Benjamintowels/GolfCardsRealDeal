extends Node

# Manages all NPCs (Entities) in the world
# Handles their turns when the player ends their turn

signal npc_turn_started(npc: Node)
signal npc_turn_ended(npc: Node)
signal all_npcs_turn_completed

var npcs: Array[Node] = []
var current_npc_index: int = -1
var is_npc_turn: bool = false

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