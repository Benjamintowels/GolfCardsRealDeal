extends Node2D

# Test scene for explosion radius system
# Press SPACE to trigger an explosion and test the radius effects

var gang_members_created: bool = false
var player_created: bool = false

func _ready():
	print("=== EXPLOSION RADIUS TEST SCENE ===")
	print("Press SPACE to trigger explosion")
	print("GangMembers close to explosion will ragdoll")
	print("Player within radius will also ragdoll if they survive")
	
	# Create test entities automatically
	_create_test_gang_members()
	_create_test_player()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("=== TRIGGERING EXPLOSION ===")
		_create_explosion()

func _create_explosion():
	"""Create an explosion at the center of the scene"""
	print("Creating explosion at center of scene")
	
	# Create explosion at the center (300, 300)
	var explosion = Explosion.create_explosion_at_position(Vector2(300, 300), self)
	
	if explosion:
		print("✓ Explosion created successfully")
	else:
		print("✗ Failed to create explosion")

func _create_test_gang_members():
	"""Create test GangMembers at various distances from the explosion point"""
	print("=== CREATING TEST GANGMEMBERS ===")
	
	# Load the GangMember scene
	var gang_member_scene = load("res://NPC/Gang/GangMember.tscn")
	if not gang_member_scene:
		print("✗ ERROR: Could not load GangMember.tscn")
		return
	
	# Create GangMembers at different positions
	var test_positions = [
		Vector2(150, 150),  # Close to explosion (should be affected)
		Vector2(250, 250),  # Close to explosion (should be affected)
		Vector2(100, 100),  # Close to explosion (should be affected)
		Vector2(400, 400),  # Far from explosion (should not be affected)
		Vector2(50, 50),    # Far from explosion (should not be affected)
	]
	
	for i in range(test_positions.size()):
		var gang_member = gang_member_scene.instantiate()
		add_child(gang_member)
		gang_member.global_position = test_positions[i]
		
		# Setup the GangMember
		if gang_member.has_method("setup"):
			# Convert world position to grid position
			var cell_size = 48
			var grid_x = floor((test_positions[i].x - cell_size / 2) / cell_size)
			var grid_y = floor((test_positions[i].y - cell_size / 2) / cell_size)
			gang_member.setup("default", Vector2i(grid_x, grid_y))
		
		print("✓ Created GangMember", i + 1, "at position:", test_positions[i])
	
	gang_members_created = true
	print("=== TEST GANGMEMBERS CREATED ===")

func _create_test_player() -> void:
	"""Create a test player at a position within explosion radius"""
	print("=== CREATING TEST PLAYER ===")
	
	# Load the player scene
	var player_scene = load("res://Characters/Player1.tscn")
	if not player_scene:
		print("✗ ERROR: Could not load Player1.tscn")
		return
	
	# Create player at a position within explosion radius
	var player_pos = Vector2(200, 200)  # Within 150 pixel radius of explosion center (300, 300)
	var player = player_scene.instantiate()
	add_child(player)
	player.global_position = player_pos
	
	# Convert world position to grid position
	var cell_size = 48
	var grid_x = floor((player_pos.x - cell_size / 2) / cell_size)
	var grid_y = floor((player_pos.y - cell_size / 2) / cell_size)
	
	# Setup the player
	if player.has_method("setup"):
		player.setup(Vector2i(20, 20), cell_size, 0, {})  # grid_size, cell_size, base_mobility, obstacle_map
		player.set_grid_position(Vector2i(grid_x, grid_y))
		print("✓ Player setup complete at grid position:", Vector2i(grid_x, grid_y))
	else:
		print("✗ ERROR: Player doesn't have setup method")
	
	# Enable animations for the player
	if player.has_method("enable_animations"):
		player.enable_animations()
		print("✓ Player animations enabled")
	
	print("✓ Test player created at world position:", player_pos, "grid position:", Vector2i(grid_x, grid_y))
	print("Distance from explosion center:", player_pos.distance_to(Vector2(300, 300)), "pixels")
	player_created = true
	print("=== TEST PLAYER CREATED ===")

func _on_create_gang_members_pressed():
	"""Called when the create GangMembers button is pressed"""
	if not gang_members_created:
		_create_test_gang_members()

func _on_create_player_pressed():
	"""Called when the create player button is pressed"""
	if not player_created:
		_create_test_player()

# Import Explosion class
const Explosion = preload("res://Particles/Explosion.gd") 