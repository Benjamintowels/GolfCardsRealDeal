extends Node2D

# Test script for fire tile damage system
# This demonstrates how fire tiles deal damage to objects with health

var cell_size: int = 48
var map_manager: Node = null
var test_ball: Node2D = null
var test_player: Node2D = null
var test_npc: Node2D = null
var test_oil_drum: Node2D = null

func _ready():
	print("=== FIRE TILE DAMAGE SYSTEM TEST ===")
	
	# Create a simple map manager for testing
	_create_test_map_manager()
	
	# Create test objects with health
	_create_test_objects()
	
	print("Test setup complete. Press SPACE to test fire tile damage.")
	print("Press R to reset the test.")

func _create_test_map_manager():
	"""Create a simple map manager for testing"""
	var MapManager = load("res://MapManager.gd")
	map_manager = MapManager.new()
	add_child(map_manager)
	
	# Create a simple 5x5 test map with grass tiles
	var test_layout = [
		["F", "F", "F", "F", "F"],
		["F", "R", "R", "R", "F"],
		["F", "R", "Base", "R", "F"],
		["F", "R", "R", "R", "F"],
		["F", "F", "F", "F", "F"]
	]
	
	map_manager.load_map_data(test_layout)
	print("Test map created: 5x5 grid with grass tiles")

func _create_test_objects():
	"""Create test objects with health"""
	# Create a test player
	var player_scene = preload("res://Characters/Player1.tscn")
	test_player = player_scene.instantiate()
	add_child(test_player)
	test_player.cell_size = cell_size
	test_player.grid_pos = Vector2i(2, 2)  # Center position
	test_player.current_health = 100
	test_player.max_health = 100
	test_player.is_alive = true
	print("Test player created at position (2, 2) with 100 HP")
	
	# Create a test NPC
	var npc_scene = preload("res://NPC/Gang/GangMember.tscn")
	test_npc = npc_scene.instantiate()
	add_child(test_npc)
	test_npc.cell_size = cell_size
	test_npc.grid_position = Vector2i(3, 2)  # Adjacent to player
	test_npc.current_health = 30
	test_npc.max_health = 30
	test_npc.is_alive = true
	print("Test NPC created at position (3, 2) with 30 HP")
	
	# Create a test oil drum
	var oil_drum_scene = preload("res://Interactables/OilDrum.tscn")
	test_oil_drum = oil_drum_scene.instantiate()
	add_child(test_oil_drum)
	test_oil_drum.cell_size = cell_size
	test_oil_drum.grid_position = Vector2i(2, 3)  # Adjacent to player
	test_oil_drum.current_health = 50
	test_oil_drum.max_health = 50
	print("Test oil drum created at position (2, 3) with 50 HP")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_test_fire_tile_damage()
		elif event.keycode == KEY_R:
			_reset_test()

func _test_fire_tile_damage():
	"""Test fire tile damage by creating a fire tile at the player's position"""
	print("\n--- Testing Fire Tile Damage ---")
	
	# Create a fire tile at the player's position (2, 2)
	var fire_tile_scene = preload("res://Particles/FireTile.tscn")
	var fire_tile = fire_tile_scene.instantiate()
	add_child(fire_tile)
	
	# Set the tile position
	fire_tile.set_tile_position(Vector2i(2, 2))
	
	# Position the fire tile at the tile center
	var tile_center = Vector2(2 * cell_size + cell_size / 2, 2 * cell_size + cell_size / 2)
	fire_tile.position = tile_center
	
	# Add to fire tiles group
	fire_tile.add_to_group("fire_tiles")
	
	print("Fire tile created at position (2, 2)")
	print("Expected damage:")
	print("- Player at (2, 2): 30 damage (on fire tile)")
	print("- NPC at (3, 2): 15 damage (adjacent)")
	print("- Oil drum at (2, 3): 15 damage (adjacent)")
	
	# Wait a moment for the damage to be applied
	await get_tree().create_timer(0.1).timeout
	
	# Check the results
	print("\nDamage Results:")
	print("Player HP:", test_player.current_health, "/", test_player.max_health)
	print("NPC HP:", test_npc.current_health, "/", test_npc.max_health)
	print("Oil drum HP:", test_oil_drum.current_health, "/", test_oil_drum.max_health)
	
	# Verify the damage was applied correctly
	var player_damage_correct = test_player.current_health == 70  # 100 - 30
	var npc_damage_correct = test_npc.current_health == 15  # 30 - 15
	var oil_drum_damage_correct = test_oil_drum.current_health == 35  # 50 - 15
	
	print("\nDamage Verification:")
	print("Player damage correct:", player_damage_correct)
	print("NPC damage correct:", npc_damage_correct)
	print("Oil drum damage correct:", oil_drum_damage_correct)
	
	if player_damage_correct and npc_damage_correct and oil_drum_damage_correct:
		print("✓ All damage applied correctly!")
	else:
		print("✗ Some damage was not applied correctly")

func _reset_test():
	"""Reset the test"""
	print("\n--- Resetting Test ---")
	
	# Remove all fire tiles
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile):
			fire_tile.queue_free()
	
	# Reset object health
	test_player.current_health = 100
	test_npc.current_health = 30
	test_oil_drum.current_health = 50
	
	print("Test reset complete!")

func _exit_tree():
	print("=== FIRE TILE DAMAGE TEST EXIT ===") 