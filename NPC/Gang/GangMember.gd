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

# State Machine
enum State {PATROL, CHASE}
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
	state_machine.set_state("patrol")
	
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
	
	# Update world position
	var target_world_pos = Vector2(target_pos.x, target_pos.y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Simple movement - you could add tweening here for smooth movement
	position = target_world_pos
	
	print("GangMember moved from ", old_pos, " to ", target_pos)

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
