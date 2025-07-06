extends Node2D

# Comprehensive test script to verify the explosion system with GangMember ragdoll
# This can be run to test if the explosion effect and ragdoll animation work correctly

var gang_members_created = false

func _ready():
	print("=== EXPLOSION SYSTEM TEST WITH RAGDOLL ===")
	
	# Create some test GangMembers around the explosion point
	_create_test_gang_members()
	
	print("=== TEST READY ===")
	print("Press SPACE to trigger explosion at (200, 200)")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_trigger_explosion()

func _trigger_explosion():
	"""Trigger an explosion at the test position"""
	print("=== TRIGGERING EXPLOSION ===")
	
	# Test creating an explosion that should affect the GangMembers
	var explosion = Explosion.create_explosion_at_position(Vector2(200, 200), self)
	
	if explosion:
		print("✓ Explosion created successfully")
	else:
		print("✗ Failed to create explosion")
	
	print("=== EXPLOSION TRIGGERED ===")

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

# Import Explosion class
const Explosion = preload("res://Particles/Explosion.gd") 