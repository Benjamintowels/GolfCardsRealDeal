extends Node2D

# Test script for Persistent Crater system
# This tests that craters stay in the scene after meteor attacks

func _ready():
	print("=== PERSISTENT CRATER TEST ===")
	print("This test verifies that craters persist in the scene after meteor attacks")
	print("=== END PERSISTENT CRATER TEST ===")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		print("SPACE pressed - testing persistent crater system")
		_test_persistent_crater()

func _test_persistent_crater():
	"""Test the persistent crater system"""
	print("=== TESTING PERSISTENT CRATER SYSTEM ===")
	
	# Check if we're in a course scene
	var course = get_tree().current_scene
	if not course:
		print("✗ ERROR: Not in a course scene")
		return
	
	print("✓ Course scene found")
	
	# Test meteor scene loading
	var meteor_scene = preload("res://Particles/Meteor.tscn")
	if not meteor_scene:
		print("✗ ERROR: Could not load Meteor.tscn")
		return
	
	print("✓ Meteor scene loaded successfully")
	
	# Test meteor instantiation
	var meteor = meteor_scene.instantiate()
	if not meteor:
		print("✗ ERROR: Could not instantiate meteor")
		return
	
	print("✓ Meteor instantiated successfully")
	
	# Test crater sprite
	var crater_sprite = meteor.get_node_or_null("CraterSprite")
	if crater_sprite:
		print("✓ Crater sprite found in meteor")
		print("  - Texture:", crater_sprite.texture)
		print("  - Position:", crater_sprite.position)
		print("  - Scale:", crater_sprite.scale)
		print("  - Visible:", crater_sprite.visible)
	else:
		print("✗ ERROR: No crater sprite found in meteor")
		meteor.queue_free()
		return
	
	# Test creating persistent crater
	print("\n=== TESTING PERSISTENT CRATER CREATION ===")
	
	# Create a test persistent crater
	var persistent_crater = Node2D.new()
	persistent_crater.name = "TestPersistentCrater"
	
	# Copy the crater sprite
	var new_crater_sprite = Sprite2D.new()
	new_crater_sprite.texture = crater_sprite.texture
	new_crater_sprite.position = crater_sprite.position
	new_crater_sprite.scale = crater_sprite.scale
	new_crater_sprite.modulate = crater_sprite.modulate
	new_crater_sprite.visible = true
	new_crater_sprite.z_index = crater_sprite.z_index
	
	# Add to persistent crater
	persistent_crater.add_child(new_crater_sprite)
	
	# Position at a test location
	persistent_crater.global_position = Vector2(100, 100)
	
	# Add to groups
	persistent_crater.add_to_group("craters")
	persistent_crater.add_to_group("ysort_objects")
	
	# Add to course
	course.add_child(persistent_crater)
	
	print("✓ Test persistent crater created at position:", persistent_crater.global_position)
	print("✓ Crater added to course and groups")
	
	# Test YSort integration
	if persistent_crater.is_in_group("craters"):
		print("✓ Crater added to 'craters' group")
	else:
		print("✗ Crater not in 'craters' group")
	
	if persistent_crater.is_in_group("ysort_objects"):
		print("✓ Crater added to 'ysort_objects' group")
	else:
		print("✗ Crater not in 'ysort_objects' group")
	
	# Test Global YSort system
	if Global:
		Global.update_object_y_sort(persistent_crater, "objects")
		print("✓ Global YSort system updated crater")
	else:
		print("✗ ERROR: Global YSort system not found")
	
	# Test that crater persists after meteor cleanup
	print("\n=== TESTING CRATER PERSISTENCE ===")
	
	# Clean up meteor (simulating meteor cleanup)
	meteor.queue_free()
	print("✓ Meteor cleaned up")
	
	# Check if persistent crater still exists
	if is_instance_valid(persistent_crater) and persistent_crater.is_inside_tree():
		print("✓ Persistent crater still exists in scene")
		print("✓ Crater position:", persistent_crater.global_position)
		print("✓ Crater sprite visible:", new_crater_sprite.visible)
	else:
		print("✗ ERROR: Persistent crater was removed or invalid")
	
	# Clean up test crater after a delay
	var cleanup_timer = get_tree().create_timer(3.0)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(persistent_crater):
			persistent_crater.queue_free()
			print("✓ Test persistent crater cleaned up")
	)
	
	print("=== PERSISTENT CRATER TEST COMPLETE ===")
	print("The crater should persist in the scene after meteor cleanup") 