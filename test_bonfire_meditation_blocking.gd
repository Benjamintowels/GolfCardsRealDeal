extends Node2D

# Test scene for bonfire meditation and movement blocking
# Press L to light bonfire, M to check meditation status, B to check blocking

var bonfire: Node2D = null
var player: Node2D = null
var equipment_manager: Node = null

func _ready():
	print("=== BONFIRE MEDITATION & BLOCKING TEST SCENE ===")
	print("Press L to light bonfire")
	print("Press M to check meditation status")
	print("Press B to check movement blocking")
	print("Press P to move player near bonfire")
	print("Press R to remove lighter equipment")
	
	# Find the bonfire and player
	_find_objects()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			_light_bonfire()
		elif event.keycode == KEY_M:
			_check_meditation_status()
		elif event.keycode == KEY_B:
			_check_movement_blocking()
		elif event.keycode == KEY_P:
			_move_player_near_bonfire()
		elif event.keycode == KEY_R:
			_remove_lighter()

func _find_objects():
	"""Find the bonfire, player, and equipment manager"""
	# Find bonfire
	var bonfires = get_tree().get_nodes_in_group("interactables")
	for obj in bonfires:
		if obj.get_script() and "bonfire.gd" in str(obj.get_script().resource_path):
			bonfire = obj
			print("✓ Found bonfire:", bonfire.name)
			break
	
	# Find player
	player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		player = _find_player_recursive(get_tree().current_scene)
	if player:
		print("✓ Found player:", player.name)
	else:
		print("✗ Player not found")
	
	# Find equipment manager
	equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		print("✓ Found equipment manager:", equipment_manager.name)
	else:
		print("✗ Equipment manager not found")

func _find_player_recursive(node: Node) -> Node2D:
	"""Recursively search for a Player node in the scene tree"""
	if node.name == "Player":
		return node as Node2D
	
	for child in node.get_children():
		var result = _find_player_recursive(child)
		if result:
			return result
	
	return null

func _light_bonfire():
	"""Light the bonfire"""
	if bonfire and bonfire.has_method("set_bonfire_active"):
		bonfire.set_bonfire_active(true)
		print("✓ Bonfire lit!")
		_check_bonfire_status()
	else:
		print("✗ Cannot light bonfire - bonfire not found or missing method")

func _check_meditation_status():
	"""Check if player is meditating"""
	if player and player.has_method("is_currently_meditating"):
		var is_meditating = player.is_currently_meditating()
		print("Player meditation status:", is_meditating)
		
		# Check if player is near bonfire
		if bonfire and player.has_method("get_grid_position") and bonfire.has_method("get_grid_position"):
			var player_pos = player.get_grid_position()
			var bonfire_pos = bonfire.get_grid_position()
			var distance = abs(player_pos.x - bonfire_pos.x) + abs(player_pos.y - bonfire_pos.y)
			print("Distance to bonfire:", distance, "tiles")
			
			if distance <= 1 and distance > 0:
				print("✓ Player is adjacent to bonfire")
			else:
				print("✗ Player is not adjacent to bonfire")
	else:
		print("✗ Cannot check meditation - player not found or missing method")

func _check_movement_blocking():
	"""Check if bonfire blocks movement"""
	if bonfire and bonfire.has_method("blocks"):
		var blocks_movement = bonfire.blocks()
		print("Bonfire blocks movement:", blocks_movement)
		
		# Check if bonfire is in obstacle map
		var course = get_tree().current_scene
		if course and "obstacle_map" in course:
			var grid_pos = bonfire.get_grid_position()
			var in_obstacle_map = course.obstacle_map.has(grid_pos)
			print("Bonfire in obstacle map:", in_obstacle_map)
			
			if in_obstacle_map:
				var obstacle = course.obstacle_map[grid_pos]
				print("Obstacle at bonfire position:", obstacle.name if obstacle else "null")
		else:
			print("✗ Cannot check obstacle map - course not found")
	else:
		print("✗ Cannot check blocking - bonfire not found or missing method")

func _move_player_near_bonfire():
	"""Move player to an adjacent tile to the bonfire"""
	if not player or not bonfire:
		print("✗ Cannot move player - player or bonfire not found")
		return
	
	if not player.has_method("get_grid_position") or not bonfire.has_method("get_grid_position"):
		print("✗ Cannot move player - missing grid position methods")
		return
	
	var bonfire_pos = bonfire.get_grid_position()
	var adjacent_pos = bonfire_pos + Vector2i(1, 0)  # Move to right of bonfire
	
	if player.has_method("set_grid_position"):
		player.set_grid_position(adjacent_pos)
		print("✓ Moved player to adjacent position:", adjacent_pos)
		_check_meditation_status()
	else:
		print("✗ Cannot move player - missing set_grid_position method")

func _remove_lighter():
	"""Remove lighter equipment from player"""
	if equipment_manager and equipment_manager.has_method("remove_equipment"):
		# Find and remove lighter equipment
		var equipped = equipment_manager.get_equipped_equipment()
		for equipment in equipped:
			if equipment.name == "Lighter":
				equipment_manager.remove_equipment(equipment)
				print("✓ Removed lighter equipment")
				return
		print("✗ No lighter equipment found to remove")
	else:
		print("✗ Cannot remove lighter - equipment manager not found or missing method")

func _check_bonfire_status():
	"""Check bonfire status"""
	if bonfire and bonfire.has_method("is_bonfire_active"):
		var is_active = bonfire.is_bonfire_active()
		print("Bonfire active status:", is_active)
	else:
		print("✗ Cannot check bonfire status - bonfire not found or missing method") 