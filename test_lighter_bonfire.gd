extends Node2D

# Simple test to verify lighter equipment and bonfire interaction
# Press L to give player lighter, P to move player near bonfire

var player: Node2D = null
var bonfire: Node2D = null
var equipment_manager: Node = null

func _ready():
	print("=== LIGHTER BONFIRE TEST SCENE ===")
	print("Press L to give player lighter equipment")
	print("Press P to move player near bonfire")
	print("Move player to adjacent tile to test lighter dialog")
	
	# Find the player and bonfire
	_find_objects()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			_give_player_lighter()
		elif event.keycode == KEY_P:
			_move_player_near_bonfire()
		elif event.keycode == KEY_R:
			_remove_player_lighter()
		elif event.keycode == KEY_C:
			_check_equipment_status()

func _find_objects():
	"""Find the player, bonfire, and equipment manager in the scene"""
	# Find player
	player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		# Try searching recursively
		player = _find_node_recursive(get_tree().current_scene, "Player")
	
	# Find bonfire
	bonfire = _find_node_recursive(get_tree().current_scene, "Bonfire")
	
	# Find equipment manager
	equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	
	print("Found objects:")
	print("- Player:", player.name if player else "NOT FOUND")
	print("- Bonfire:", bonfire.name if bonfire else "NOT FOUND")
	print("- EquipmentManager:", equipment_manager.name if equipment_manager else "NOT FOUND")

func _find_node_recursive(node: Node, node_name: String) -> Node2D:
	"""Recursively search for a node with the given name"""
	if node.name == node_name:
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_node_recursive(child, node_name)
		if result:
			return result
	
	return null

func _give_player_lighter():
	"""Give the player Lighter equipment"""
	print("\n--- Giving Player Lighter Equipment ---")
	
	if not equipment_manager:
		print("✗ Equipment manager not found!")
		return
	
	var lighter_equipment = preload("res://Equipment/Lighter.tres")
	if lighter_equipment:
		equipment_manager.add_equipment(lighter_equipment)
		print("✓ Player now has Lighter equipment!")
		_check_equipment_status()
	else:
		print("✗ Failed to load Lighter equipment")

func _remove_player_lighter():
	"""Remove Lighter equipment from player"""
	print("\n--- Removing Lighter Equipment ---")
	
	if not equipment_manager:
		print("✗ Equipment manager not found!")
		return
	
	var equipped_items = equipment_manager.get_equipped_equipment()
	for equipment in equipped_items:
		if equipment.name == "Lighter":
			equipment_manager.remove_equipment(equipment)
			print("✓ Lighter equipment removed!")
			_check_equipment_status()
			return
	
	print("✗ No Lighter equipment found to remove")

func _move_player_near_bonfire():
	"""Move player to a tile adjacent to the bonfire"""
	print("\n--- Moving Player Near Bonfire ---")
	
	if not player or not bonfire:
		print("✗ Player or bonfire not found!")
		return
	
	# Get bonfire's grid position
	var bonfire_grid_pos = bonfire.get_grid_position()
	var adjacent_tile = bonfire_grid_pos + Vector2i(1, 0)  # Right of bonfire
	
	# Convert to world position
	var cell_size = 48
	var world_pos = Vector2(adjacent_tile.x * cell_size + cell_size / 2, adjacent_tile.y * cell_size + cell_size / 2)
	
	# Move player
	player.global_position = world_pos
	
	# Update player's grid position if it has that method
	if player.has_method("set_grid_position"):
		player.set_grid_position(adjacent_tile)
	
	print("✓ Player moved to tile", adjacent_tile, "adjacent to bonfire at", bonfire_grid_pos)
	print("Distance from bonfire:", world_pos.distance_to(bonfire.global_position), "pixels")
	
	# Check if player has lighter
	if equipment_manager and equipment_manager.has_method("has_lighter"):
		var has_lighter = equipment_manager.has_lighter()
		print("Player has lighter:", has_lighter)
		if has_lighter:
			print("✓ Player should trigger lighter dialog when entering bonfire area!")

func _check_equipment_status():
	"""Check the current equipment status"""
	print("\n--- Equipment Status Check ---")
	
	if not equipment_manager:
		print("✗ Equipment manager not found!")
		return
	
	var equipped_items = equipment_manager.get_equipped_equipment()
	print("Total equipped items:", equipped_items.size())
	
	for i in range(equipped_items.size()):
		var equipment = equipped_items[i]
		print("- Item", i + 1, ":", equipment.name, "(Type:", equipment.buff_type, ")")
	
	# Check specifically for lighter
	if equipment_manager.has_method("has_lighter"):
		var has_lighter = equipment_manager.has_lighter()
		print("Has lighter:", has_lighter)
	else:
		print("✗ Equipment manager doesn't have has_lighter() method") 