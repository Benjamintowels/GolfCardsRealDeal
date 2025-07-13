extends Node2D

# Test script for bonfire activation system
# This demonstrates how bonfires activate from fire tiles and lighter equipment

var cell_size: int = 48
var map_manager: Node = null
var test_ball: Node2D = null
var bonfire: Node2D = null
var player: Node2D = null
var equipment_manager: Node = null

func _ready():
	print("=== BONFIRE ACTIVATION SYSTEM TEST ===")
	
	# Create a simple map manager for testing
	_create_test_map_manager()
	
	# Create a test fire ball
	_create_test_fire_ball()
	
	# Create a test bonfire
	_create_test_bonfire()
	
	# Create a test player
	_create_test_player()
	
	# Create equipment manager
	_create_equipment_manager()
	
	print("Test setup complete.")
	print("Controls:")
	print("- SPACE: Test fire spreading near bonfire")
	print("- L: Give player Lighter equipment")
	print("- R: Remove Lighter equipment")
	print("- P: Move player near bonfire")
	print("- F: Create fire tile on bonfire's tile")

func _create_test_map_manager():
	"""Create a simple map manager for testing"""
	var MapManager = load("res://MapManager.gd")
	map_manager = MapManager.new()
	add_child(map_manager)
	
	# Create a simple 10x10 test map with grass tiles
	var test_layout = []
	for y in range(10):
		var row = []
		for x in range(10):
			row.append("F")  # All grass tiles
		test_layout.append(row)
	
	map_manager.load_map_data(test_layout)
	print("Test map created: 10x10 grid with grass tiles")

func _create_test_fire_ball():
	"""Create a test fire ball"""
	var ball_scene = preload("res://GolfBall.tscn")
	test_ball = ball_scene.instantiate()
	add_child(test_ball)
	
	# Set up the ball
	test_ball.cell_size = cell_size
	test_ball.map_manager = map_manager
	
	# Position at center of map
	test_ball.position = Vector2(5 * cell_size + cell_size / 2, 5 * cell_size + cell_size / 2)
	
	# Add fire element
	var ElementData = load("res://Elements/ElementData.gd")
	var fire_element = ElementData.new()
	fire_element.name = "Fire"
	fire_element.color = Color.RED
	test_ball.set_element(fire_element)
	
	print("Test fire ball created at center of map")

func _create_test_bonfire():
	"""Create a test bonfire"""
	var bonfire_scene = preload("res://Interactables/Bonfire.tscn")
	bonfire = bonfire_scene.instantiate()
	add_child(bonfire)
	
	# Position bonfire at a specific location
	bonfire.position = Vector2(7 * cell_size + cell_size / 2, 7 * cell_size + cell_size / 2)
	
	print("Test bonfire created at position (7, 7)")

func _create_test_player():
	"""Create a test player"""
	player = Node2D.new()
	player.name = "Player"
	add_child(player)
	
	# Position player away from bonfire initially
	player.position = Vector2(3 * cell_size + cell_size / 2, 3 * cell_size + cell_size / 2)
	
	print("Test player created at position (3, 3)")

func _create_equipment_manager():
	"""Create equipment manager for testing"""
	var EquipmentManager = load("res://EquipmentManager.gd")
	equipment_manager = EquipmentManager.new()
	equipment_manager.name = "EquipmentManager"
	add_child(equipment_manager)
	
	print("Equipment manager created")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_test_fire_spreading_near_bonfire()
		elif event.keycode == KEY_L:
			_give_player_lighter()
		elif event.keycode == KEY_R:
			_remove_player_lighter()
		elif event.keycode == KEY_P:
			_move_player_near_bonfire()
		elif event.keycode == KEY_F:
			_create_fire_on_bonfire_tile()

func _test_fire_spreading_near_bonfire():
	"""Test fire spreading near the bonfire"""
	print("\n--- Testing Fire Spreading Near Bonfire ---")
	
	# Move ball to adjacent tile to bonfire
	var bonfire_tile = bonfire.get_grid_position()
	var adjacent_tile = bonfire_tile + Vector2i(1, 0)  # Right of bonfire
	var world_pos = Vector2(adjacent_tile.x * cell_size + cell_size / 2, adjacent_tile.y * cell_size + cell_size / 2)
	test_ball.position = world_pos
	
	# Trigger fire spreading check
	test_ball._check_fire_spreading()
	
	print("Ball moved to tile", adjacent_tile, "- checking for fire spreading...")
	print("Bonfire should activate if fire tile is created!")

func _give_player_lighter():
	"""Give the player Lighter equipment"""
	print("\n--- Giving Player Lighter Equipment ---")
	
	var Lighter = load("res://Equipment/Lighter.tres")
	if Lighter:
		equipment_manager.add_equipment(Lighter)
		print("Player now has Lighter equipment!")
		print("Move player near bonfire (P key) to test lighter dialog")
	else:
		print("Failed to load Lighter equipment")

func _remove_player_lighter():
	"""Remove Lighter equipment from player"""
	print("\n--- Removing Lighter Equipment ---")
	
	var equipped_items = equipment_manager.get_equipped_equipment()
	for equipment in equipped_items:
		if equipment.name == "Lighter":
			equipment_manager.remove_equipment(equipment)
			print("Lighter equipment removed!")
			return
	
	print("No Lighter equipment found to remove")

func _move_player_near_bonfire():
	"""Move player near the bonfire to test lighter dialog"""
	print("\n--- Moving Player Near Bonfire ---")
	
	# Move player to adjacent tile to bonfire
	var bonfire_tile = bonfire.get_grid_position()
	var adjacent_tile = bonfire_tile + Vector2i(0, 1)  # Below bonfire
	var world_pos = Vector2(adjacent_tile.x * cell_size + cell_size / 2, adjacent_tile.y * cell_size + cell_size / 2)
	player.position = world_pos
	
	print("Player moved to tile", adjacent_tile, "near bonfire")
	
	# Check if player has lighter
	if equipment_manager.has_lighter():
		print("Player has Lighter - should trigger dialog!")
	else:
		print("Player doesn't have Lighter - no dialog will appear")

func _create_fire_on_bonfire_tile():
	"""Create a fire tile directly on the bonfire's tile"""
	print("\n--- Creating Fire on Bonfire Tile ---")
	
	var bonfire_tile = bonfire.get_grid_position()
	
	# Create fire tile directly
	var fire_tile_scene = preload("res://Particles/FireTile.tscn")
	var fire_tile = fire_tile_scene.instantiate()
	
	# Set the tile position
	fire_tile.set_tile_position(bonfire_tile)
	
	# Position the fire tile at the tile center
	var tile_center = Vector2(bonfire_tile.x * cell_size + cell_size / 2, bonfire_tile.y * cell_size + cell_size / 2)
	fire_tile.position = tile_center
	
	# Add to fire tiles group for easy management
	fire_tile.add_to_group("fire_tiles")
	
	# Add to scene
	add_child(fire_tile)
	
	print("Fire tile created on bonfire's tile at", bonfire_tile)
	print("Bonfire should activate immediately!")

func _exit_tree():
	print("=== BONFIRE ACTIVATION TEST EXIT ===") 