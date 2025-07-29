extends Node
class_name MovementAttackStrategy

# use for attacks that move the player such as assassindash 

# References needed for movement attacks
var card_effect_handler: Node
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary
var player_node: Node2D

# Sound effects
var assassin_dash_sound: AudioStreamPlayer2D
var assassin_cut_sound: AudioStreamPlayer2D

# Attack properties
var assassin_dash_damage := 40

# Signals
signal npc_attacked(npc: Node, damage: int)
signal assassin_dash_attack_performed
signal attack_completed

func setup(
	card_effect_handler_ref: Node,
	grid_tiles_ref: Array,
	grid_size_ref: Vector2i,
	cell_size_ref: int,
	obstacle_map_ref: Dictionary,
	player_grid_pos_ref: Vector2i,
	player_stats_ref: Dictionary,
	player_node_ref: Node2D,
	assassin_dash_sound_ref: AudioStreamPlayer2D = null,
	assassin_cut_sound_ref: AudioStreamPlayer2D = null
):
	card_effect_handler = card_effect_handler_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	player_node = player_node_ref
	assassin_dash_sound = assassin_dash_sound_ref
	assassin_cut_sound = assassin_cut_sound_ref

func perform_assassin_dash_attack(target_pos: Vector2i) -> void:
	"""Perform Assassin Dash attack at the specified position"""
	print("=== PERFORMING ASSASSIN DASH ATTACK ===")
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Play AssassinDash sound
	if assassin_dash_sound:
		assassin_dash_sound.play()
	
	# Emit assassin dash attack signal for animation
	print("🎯 EMITTING assassin_dash_attack_performed signal")
	emit_signal("assassin_dash_attack_performed")
	
	# Get NPC at target position
	var npc = get_npc_at_position(target_pos)
	if npc:
		print("Found NPC at target position:", npc.name)
		perform_assassin_dash_attack_on_npc(npc, target_pos)
	else:
		# Check for destructible object at target position
		var destructible = get_destructible_at_position(target_pos)
		if destructible:
			print("Found destructible object at target position:", destructible.name)
			perform_assassin_dash_attack_on_destructible(destructible, target_pos)
		else:
			print("No NPC or destructible found at target position:", target_pos)
			# Still perform the dash movement even if no target
			perform_assassin_dash_movement(target_pos)
			emit_signal("attack_completed")

func perform_assassin_dash_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack on NPC with movement to behind-enemy position"""
	print("=== PERFORMING ASSASSIN DASH ATTACK ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("NPC is already dead, skipping attack")
		perform_assassin_dash_movement(target_pos)
		emit_signal("attack_completed")
		return
	
	# Calculate the position behind the enemy (opposite direction from player)
	var direction = target_pos - player_grid_pos
	# Normalize direction to get 1 tile movement
	var normalized_direction = Vector2i.ZERO
	if direction.x > 0:
		normalized_direction.x = 1
	elif direction.x < 0:
		normalized_direction.x = -1
	if direction.y > 0:
		normalized_direction.y = 1
	elif direction.y < 0:
		normalized_direction.y = -1
	
	var behind_enemy_pos = target_pos + normalized_direction
	print("Moving player to behind-enemy position:", behind_enemy_pos)
	
	# Double-check that the behind-enemy position is still valid
	if not is_position_valid_for_assassin_dash(behind_enemy_pos):
		print("✗ ERROR: Behind-enemy position is no longer valid:", behind_enemy_pos)
		print("✗ AssassinDash attack cancelled - cannot move behind enemy")
		emit_signal("attack_completed")
		return
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# Perform the dash movement to behind-enemy position
	perform_assassin_dash_movement(behind_enemy_pos)
	
	# Deal damage to the NPC after movement
	if npc.has_method("take_damage"):
		npc.take_damage(assassin_dash_damage)
		print("Dealt", assassin_dash_damage, "damage to NPC:", npc.name)
		
		# Emit signal for attack completion
		emit_signal("npc_attacked", npc, assassin_dash_damage)
	else:
		print("NPC does not have take_damage method:", npc.name)
	
	emit_signal("attack_completed")

func perform_assassin_dash_attack_on_destructible(destructible: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack on destructible object with movement to behind-enemy position"""
	print("=== PERFORMING ASSASSIN DASH ATTACK ON DESTRUCTIBLE ===")
	print("Destructible:", destructible.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Check if destructible is destroyed
	var is_destroyed = false
	if destructible.has_method("get_is_destroyed"):
		is_destroyed = destructible.get_is_destroyed()
	elif destructible.has_method("is_destroyed"):
		is_destroyed = destructible.is_destroyed()
	elif "is_destroyed" in destructible:
		is_destroyed = destructible.is_destroyed
	
	if is_destroyed:
		print("Destructible object is already destroyed, skipping attack")
		perform_assassin_dash_movement(target_pos)
		emit_signal("attack_completed")
		return
	
	# Calculate the position behind the enemy (opposite direction from player)
	var direction = target_pos - player_grid_pos
	# Normalize direction to get 1 tile movement
	var normalized_direction = Vector2i.ZERO
	if direction.x > 0:
		normalized_direction.x = 1
	elif direction.x < 0:
		normalized_direction.x = -1
	if direction.y > 0:
		normalized_direction.y = 1
	elif direction.y < 0:
		normalized_direction.y = -1
	
	var behind_enemy_pos = target_pos + normalized_direction
	print("Moving player to behind-enemy position:", behind_enemy_pos)
	
	# Double-check that the behind-enemy position is still valid
	if not is_position_valid_for_assassin_dash(behind_enemy_pos):
		print("✗ ERROR: Behind-enemy position is no longer valid:", behind_enemy_pos)
		print("✗ AssassinDash attack cancelled - cannot move behind enemy")
		emit_signal("attack_completed")
		return
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# Perform the dash movement to behind-enemy position
	perform_assassin_dash_movement(behind_enemy_pos)
	
	# Deal damage to the destructible object after movement
	if destructible.has_method("take_damage"):
		destructible.take_damage(assassin_dash_damage)
		print("Dealt", assassin_dash_damage, "damage to destructible object:", destructible.name)
		
		# Emit signal for attack completion
		emit_signal("npc_attacked", destructible, assassin_dash_damage)
	else:
		print("Destructible object does not have take_damage method:", destructible.name)
	
	# Complete the attack
	emit_signal("attack_completed")

func perform_assassin_dash_movement(target_pos: Vector2i) -> void:
	"""Perform the movement part of Assassin Dash attack"""
	print("Performing Assassin Dash movement to:", target_pos)
	
	# CRITICAL FIX: Temporarily disable animations to prevent position sync glitches
	var original_animations_enabled = false
	if player_node and "animations_enabled" in player_node:
		original_animations_enabled = player_node.animations_enabled
		print("🔍 ASSASSIN DEBUG: Temporarily disabling animations (was:", original_animations_enabled, ")")
		player_node.animations_enabled = false
	
	# CRITICAL: Update player grid_pos directly first
	if player_node and "grid_pos" in player_node:
		print("🔍 ASSASSIN DEBUG: Directly updating player_node.grid_pos to:", target_pos)
		player_node.grid_pos = target_pos
		print("✓ Updated player grid_pos directly to:", target_pos)
	
	# Update local tracking variables
	player_grid_pos = target_pos
	print("🔍 Updated movement strategy player_grid_pos to:", target_pos)
	
	# Update the course's player position reference
	if card_effect_handler and card_effect_handler.course:
		print("🔍 ASSASSIN DEBUG: About to update course.player_grid_pos")
		card_effect_handler.course.player_grid_pos = target_pos
		print("🔍 Updated course.player_grid_pos to:", target_pos)
	
	# Re-enable animations for the animate_to_position call
	if player_node and "animations_enabled" in player_node:
		print("🔍 ASSASSIN DEBUG: Re-enabling animations for animate_to_position")
		player_node.animations_enabled = original_animations_enabled
	
	# Animate player movement to target position (visual only now that position is set)
	if player_node and player_node.has_method("animate_to_position"):
		player_node.animate_to_position(target_pos, func():
			print("🔍 ASSASSIN DEBUG: Animation callback started")
			# Play cut sound when reaching the target
			if assassin_cut_sound:
				assassin_cut_sound.play()
			
			# CRITICAL: Update player Y-sorting immediately after AssassinDash movement
			if player_node and player_node.has_method("update_z_index_for_ysort"):
				player_node.update_z_index_for_ysort([], Vector2i.ZERO)
				print("✓ Updated player Y-sorting after AssassinDash movement to position:", target_pos)
			
			print("🔍 ASSASSIN DEBUG: Animation callback completed")
		)
		print("🔍 ASSASSIN DEBUG: animate_to_position call completed")
	else:
		print("Player node does not have animate_to_position method - using fallback")
		# Fallback: just update position without animation
		print("Player moved to position:", target_pos)

func is_position_valid_for_assassin_dash(pos: Vector2i) -> bool:
	"""Check if a position is valid for AssassinDash behind-enemy movement"""
	print("Checking if AssassinDash position is valid:", pos)
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		print("Position out of bounds:", pos)
		return false
	
	# Check if the position is occupied by an obstacle
	if obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			print("Position blocked by obstacle:", pos)
			return false
	
	# Check if the position is occupied by another NPC
	if card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc):
					var npc_pos = Vector2i.ZERO
					
					# Try to get grid position using different methods
					if npc.has_method("get_grid_position"):
						npc_pos = npc.get_grid_position()
					elif "grid_position" in npc:
						npc_pos = npc.grid_position
					elif "grid_pos" in npc:
						npc_pos = npc.grid_pos
					else:
						# Fallback: calculate grid position from world position
						var world_pos = npc.global_position
						var cell_size_used = cell_size if "cell_size" in npc else 48
						npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
					
					if npc_pos == pos:
						print("Position occupied by NPC:", pos, "NPC:", npc.name)
						return false
	
	# Check if the position is occupied by the player
	if pos == player_grid_pos:
		print("Position is player's current position:", pos)
		return false
	
	print("Position is valid for AssassinDash:", pos)
	return true

# Helper function to get NPC at position
func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	print("=== GETTING NPC AT POSITION (MovementStrategy) ===")
	print("Position:", pos)
	print("Card effect handler:", card_effect_handler != null)
	
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ No card_effect_handler or course found")
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return null
	
	print("✓ Entities found")
	var npcs = entities.get_npcs()
	print("Total NPCs found:", npcs.size())
	
	for npc in npcs:
		print("=== CHECKING NPC ===")
		print("NPC reference:", npc)
		print("Is instance valid:", is_instance_valid(npc))
		
		if is_instance_valid(npc):
			print("NPC name:", npc.name)
			print("NPC class:", npc.get_class())
			print("NPC script:", npc.get_script().resource_path if npc.get_script() else "No script")
			print("NPC global position:", npc.global_position)
			
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return npc
		else:
			print("✗ NPC is invalid - reference:", npc)
			if npc != null:
				print("  - NPC name (if available):", npc.name if "name" in npc else "No name property")
				print("  - NPC class (if available):", npc.get_class() if "get_class" in npc else "No get_class method")
		
		print("=== END CHECKING NPC ===")
	
	print("✗ No NPC found at position:", pos)
	return null

func get_destructible_at_position(pos: Vector2i) -> Node:
	"""Get destructible object at the specified grid position"""
	print("=== GETTING DESTRUCTIBLE AT POSITION (MovementStrategy) ===")
	print("Position:", pos)
	
	# Look for destructible objects in the destructible_objects group
	var destructibles = get_tree().get_nodes_in_group("destructible_objects")
	
	for destructible in destructibles:
		print("=== CHECKING DESTRUCTIBLE ===")
		print("Destructible reference:", destructible)
		print("Is instance valid:", is_instance_valid(destructible))
		
		if is_instance_valid(destructible):
			print("Destructible name:", destructible.name)
			print("Destructible class:", destructible.get_class())
			print("Destructible script:", destructible.get_script().resource_path if destructible.get_script() else "No script")
			print("Destructible global position:", destructible.global_position)
			
			var destructible_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if destructible.has_method("get_grid_position"):
				destructible_pos = destructible.get_grid_position()
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using get_grid_position)")
			elif "grid_position" in destructible:
				destructible_pos = destructible.grid_position
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using grid_position property)")
			elif "grid_pos" in destructible:
				destructible_pos = destructible.grid_pos
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = destructible.global_position
				var cell_size_used = cell_size if "cell_size" in destructible else 48
				destructible_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking destructible:", destructible.name, "at position:", destructible_pos, "(calculated from world position)")
			
			if destructible_pos == pos:
				print("✓ Found destructible at position:", pos, "Destructible:", destructible.name)
				return destructible
		else:
			print("✗ Destructible is invalid - reference:", destructible)
			if destructible != null:
				print("  - Destructible name (if available):", destructible.name if "name" in destructible else "No name property")
				print("  - Destructible class (if available):", destructible.get_class() if "get_class" in destructible else "No get_class method")
		
		print("=== END CHECKING DESTRUCTIBLE ===")
	
	print("✗ No destructible found at position:", pos)
	return null

func update_player_position(new_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_pos 
