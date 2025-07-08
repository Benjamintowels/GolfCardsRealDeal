extends Node2D

# Test script for Police NPC system

var cell_size: int = 48
var test_police: Node
var test_player: Node

func _ready():
	print("=== POLICE SYSTEM TEST ===")
	_create_test_environment()
	_create_test_police()
	_create_test_player()

func _create_test_environment():
	"""Create a basic test environment"""
	print("Creating test environment...")
	
	# Create a simple ground tile
	var ground = ColorRect.new()
	ground.color = Color.GREEN
	ground.size = Vector2(500, 500)
	ground.position = Vector2(-250, -250)
	add_child(ground)

func _create_test_police():
	"""Create a test Police NPC"""
	print("Creating test Police...")
	
	var police_scene = preload("res://NPC/Police/Police.tscn")
	test_police = police_scene.instantiate()
	add_child(test_police)
	
	# Setup the Police
	test_police.setup(Vector2i(5, 5), cell_size)
	test_police.current_health = 100
	test_police.max_health = 100
	test_police.is_alive = true
	
	print("✓ Test Police created at position (5, 5) with 100 HP")

func _create_test_player():
	"""Create a test player"""
	print("Creating test player...")
	
	# Create a simple player representation
	test_player = Node2D.new()
	test_player.name = "TestPlayer"
	add_child(test_player)
	
	# Add required methods
	test_player.set_script(GDScript.new())
	test_player.get_script().source_code = """
extends Node2D

var grid_pos: Vector2i = Vector2i(3, 3)
var current_health: int = 100
var max_health: int = 100

func get_grid_pos() -> Vector2i:
	return grid_pos

func take_damage(amount: int) -> void:
	current_health -= amount
	print("Player took", amount, "damage. Health:", current_health)
"""
	test_player.get_script().reload()
	
	# Create visual representation
	var player_sprite = ColorRect.new()
	player_sprite.color = Color.BLUE
	player_sprite.size = Vector2(30, 30)
	player_sprite.position = Vector2(-15, -15)
	test_player.add_child(player_sprite)
	
	# Position the player
	test_player.position = Vector2(3, 3) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	print("✓ Test player created at position (3, 3) with 100 HP")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_test_police_patrol()
			KEY_2:
				_test_police_chase()
			KEY_3:
				_test_police_attack()
			KEY_4:
				_test_police_damage()
			KEY_5:
				_test_police_death()
			KEY_R:
				_reset_test()

func _test_police_patrol():
	"""Test Police patrol behavior"""
	print("=== TESTING POLICE PATROL ===")
	
	# Move player away from Police
	test_player.grid_pos = Vector2i(10, 10)
	test_player.position = Vector2(10, 10) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Trigger Police turn
	test_police.take_turn()
	
	print("✓ Police patrol test completed")

func _test_police_chase():
	"""Test Police chase behavior"""
	print("=== TESTING POLICE CHASE ===")
	
	# Move player within vision range but outside attack range
	test_player.grid_pos = Vector2i(7, 5)
	test_player.position = Vector2(7, 5) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Trigger Police turn
	test_police.take_turn()
	
	print("✓ Police chase test completed")

func _test_police_attack():
	"""Test Police attack behavior"""
	print("=== TESTING POLICE ATTACK ===")
	
	# Move player within attack range
	test_player.grid_pos = Vector2i(6, 5)
	test_player.position = Vector2(6, 5) * cell_size + Vector2(cell_size / 2, cell_size / 2)
	
	# Trigger Police turn
	test_police.take_turn()
	
	print("✓ Police attack test completed")

func _test_police_damage():
	"""Test Police taking damage"""
	print("=== TESTING POLICE DAMAGE ===")
	
	var initial_health = test_police.current_health
	test_police.take_damage(30)
	
	if test_police.current_health == initial_health - 30:
		print("✓ Police damage test passed")
	else:
		print("✗ Police damage test failed")

func _test_police_death():
	"""Test Police death"""
	print("=== TESTING POLICE DEATH ===")
	
	test_police.take_damage(100)
	
	if test_police.is_dead:
		print("✓ Police death test passed")
	else:
		print("✗ Police death test failed")

func _reset_test():
	"""Reset the test"""
	print("=== RESETTING TEST ===")
	
	# Remove existing objects
	if test_police:
		test_police.queue_free()
	if test_player:
		test_player.queue_free()
	
	# Recreate objects
	_create_test_police()
	_create_test_player()
	
	print("✓ Test reset completed")

func _on_gui_input(event):
	"""Handle GUI input for testing"""
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Move player to mouse position
			var mouse_pos = get_global_mouse_position()
			var grid_x = int(mouse_pos.x / cell_size)
			var grid_y = int(mouse_pos.y / cell_size)
			
			test_player.grid_pos = Vector2i(grid_x, grid_y)
			test_player.position = Vector2(grid_x, grid_y) * cell_size + Vector2(cell_size / 2, cell_size / 2)
			
			print("Player moved to grid position:", test_player.grid_pos)
			
			# Trigger Police turn
			test_police.take_turn() 