extends Node2D

# Test scene for grenade fire system
# Press SPACE to launch a grenade and test the fire tile creation

var grenade_scene = preload("res://Weapons/Grenade.tscn")
var map_manager: Node = null

func _ready():
	print("=== GRENADE FIRE SYSTEM TEST SCENE ===")
	print("Press SPACE to launch a grenade")
	print("Grenade explosion should create fire tiles on Base, Green, Rough, and Fairway tiles")
	print("Fire tiles will damage entities and eventually turn to scorched earth")
	
	# Setup map manager for tile type checking
	_setup_map_manager()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("=== LAUNCHING GRENADE ===")
		_launch_test_grenade()

func _setup_map_manager():
	"""Setup a simple map manager for testing tile types"""
	# Create a simple map manager for testing
	map_manager = Node.new()
	map_manager.name = "MapManager"
	add_child(map_manager)
	
	# Add a simple get_tile_type method for testing
	map_manager.set_script(GDScript.new())
	var script_code = """
extends Node

func get_tile_type(x: int, y: int) -> String:
	# Create a simple test map with different tile types
	# Center area (around 300, 300) will be grass tiles
	var center_x = 6  # 300 / 48
	var center_y = 6  # 300 / 48
	
	# Check if within 3 tiles of center (grass area)
	if abs(x - center_x) <= 3 and abs(y - center_y) <= 3:
		# Create a pattern of different grass types
		if (x + y) % 2 == 0:
			return "F"  # Fairway
		else:
			return "R"  # Rough
	elif abs(x - center_x) <= 1 and abs(y - center_y) <= 1:
		return "G"  # Green (center)
	else:
		return "Base"  # Base grass (default)
	
func is_tile_scorched(x: int, y: int) -> bool:
	return false  # No tiles start scorched

func set_tile_scorched(x: int, y: int) -> void:
	print("Tile scorched at:", Vector2i(x, y))
"""
	
	var script = GDScript.new()
	script.source_code = script_code
	script.reload()
	map_manager.set_script(script)
	
	print("✓ Map manager setup complete")

func _launch_test_grenade():
	"""Launch a test grenade that will explode and create fire tiles"""
	print("Creating grenade at center of scene")
	
	# Create grenade
	var grenade = grenade_scene.instantiate()
	add_child(grenade)
	
	# Position grenade at center
	grenade.global_position = Vector2(300, 300)
	
	# Setup grenade with map manager
	grenade.map_manager = map_manager
	grenade.cell_size = 48
	
	# Set club info for grenade
	var club_info = {
		"max_distance": 400.0,
		"min_distance": 200.0
	}
	grenade.set_club_info(club_info)
	
	# Launch grenade with parameters that will make it explode quickly
	var direction = Vector2(1, 0)  # Launch right
	var power = 100.0  # Low power so it doesn't go far
	var height = 50.0  # Low height for quick landing
	
	print("Launching grenade with direction:", direction, "power:", power, "height:", height)
	grenade.launch(direction, power, height)
	
	# Connect to grenade signals
	grenade.grenade_exploded.connect(_on_grenade_exploded)
	grenade.grenade_landed.connect(_on_grenade_landed)
	
	print("✓ Grenade launched successfully")

func _on_grenade_landed(position: Vector2):
	"""Called when grenade lands"""
	print("✓ Grenade landed at:", position)

func _on_grenade_exploded(position: Vector2):
	"""Called when grenade explodes"""
	print("✓ Grenade exploded at:", position)
	print("Fire tiles should now be created in the explosion radius")
	
	# Check for fire tiles after a short delay
	await get_tree().create_timer(1.0).timeout
	_check_fire_tiles()

func _check_fire_tiles():
	"""Check if fire tiles were created"""
	var fire_tiles = get_tree().get_nodes_in_group("fire_tiles")
	print("=== FIRE TILE CHECK ===")
	print("Found", fire_tiles.size(), "fire tiles in scene")
	
	for i in range(fire_tiles.size()):
		var fire_tile = fire_tiles[i]
		if is_instance_valid(fire_tile) and fire_tile.has_method("get_tile_position"):
			var tile_pos = fire_tile.get_tile_position()
			var world_pos = Vector2(tile_pos.x * 48 + 24, tile_pos.y * 48 + 24)
			print("Fire tile", i + 1, "at tile position:", tile_pos, "world position:", world_pos)
	
	if fire_tiles.size() > 0:
		print("✓ Fire tiles created successfully!")
		print("Fire tiles will damage entities and turn to scorched earth after 2 turns")
	else:
		print("✗ No fire tiles found - check grenade explosion implementation")

func _on_test_fire_tiles_pressed():
	"""Button callback to test fire tile creation directly"""
	print("=== TESTING FIRE TILE CREATION DIRECTLY ===")
	
	# Create a fire tile manually at a test position
	var fire_tile_scene = preload("res://Particles/FireTile.tscn")
	var fire_tile = fire_tile_scene.instantiate()
	add_child(fire_tile)
	
	# Position at center
	fire_tile.global_position = Vector2(300, 300)
	fire_tile.set_tile_position(Vector2i(6, 6))  # Center tile
	
	print("✓ Test fire tile created at center")
	
	# Check fire tiles after creation
	await get_tree().create_timer(0.5).timeout
	_check_fire_tiles() 