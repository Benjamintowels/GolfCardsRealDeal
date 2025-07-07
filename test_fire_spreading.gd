extends Node2D

# Test script for fire spreading system
# This demonstrates how fire balls spread fire to grass tiles

var cell_size: int = 48
var map_manager: Node = null
var test_ball: Node2D = null

func _ready():
	print("=== FIRE SPREADING SYSTEM TEST ===")
	
	# Create a simple map manager for testing
	_create_test_map_manager()
	
	# Create a test fire ball
	_create_test_fire_ball()
	
	print("Test setup complete. Press SPACE to test fire spreading.")

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

func _create_test_fire_ball():
	"""Create a test fire ball"""
	var ball_scene = preload("res://GolfBall.tscn")
	test_ball = ball_scene.instantiate()
	add_child(test_ball)
	
	# Set up the ball
	test_ball.cell_size = cell_size
	test_ball.map_manager = map_manager
	
	# Position at center of map
	test_ball.position = Vector2(2 * cell_size + cell_size / 2, 2 * cell_size + cell_size / 2)
	
	# Add fire element
	var ElementData = load("res://Elements/ElementData.gd")
	var fire_element = ElementData.new()
	fire_element.name = "Fire"
	fire_element.color = Color.RED
	test_ball.set_element(fire_element)
	
	print("Test fire ball created at center of map")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_test_fire_spreading()
		elif event.keycode == KEY_R:
			_reset_test()
		elif event.keycode == KEY_T:
			_test_turn_advancement()

func _test_fire_spreading():
	"""Test fire spreading by making the ball roll around"""
	print("\n--- Testing Fire Spreading ---")
	
	# Simulate ball rolling to different grass tiles
	var test_positions = [
		Vector2(1, 1),  # Rough tile
		Vector2(3, 1),  # Rough tile
		Vector2(1, 3),  # Rough tile
		Vector2(3, 3),  # Rough tile
	]
	
	for pos in test_positions:
		var world_pos = Vector2(pos.x * cell_size + cell_size / 2, pos.y * cell_size + cell_size / 2)
		test_ball.position = world_pos
		
		# Trigger fire spreading check
		test_ball._check_fire_spreading()
		
		print("Ball moved to tile", pos, "- checking for fire spreading...")
		
		# Wait a moment to see the effect
		await get_tree().create_timer(0.5).timeout
	
	print("Fire spreading test complete!")

func _test_turn_advancement():
	"""Test turn advancement for fire tiles"""
	print("\n--- Testing Turn Advancement ---")
	
	# Get all fire tiles
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	print("Found", fire_tiles.size(), "fire tiles")
	
	# Advance all fire tiles
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile) and fire_tile.has_method("advance_turn"):
			fire_tile.advance_turn()
			print("Advanced fire tile at", fire_tile.get_tile_position())
	
	print("Turn advancement test complete!")

func _reset_test():
	"""Reset the test"""
	print("\n--- Resetting Test ---")
	
	# Remove all fire tiles
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	for fire_tile in fire_tiles:
		if is_instance_valid(fire_tile):
			fire_tile.queue_free()
	
	# Reset ball position
	test_ball.position = Vector2(2 * cell_size + cell_size / 2, 2 * cell_size + cell_size / 2)
	
	print("Test reset complete!")

func _exit_tree():
	print("=== FIRE SPREADING TEST EXIT ===") 