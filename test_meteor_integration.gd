extends Node2D

# Test script for Meteor integration with YSort system
# This can be run in the actual game to test meteor visibility

func _ready():
	print("=== METEOR INTEGRATION TEST ===")
	print("This test verifies that meteors are properly integrated with the YSort system")
	print("The meteor should be visible and properly depth-sorted when playing the MeteorCard")
	print("=== END METEOR INTEGRATION TEST ===")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		print("SPACE pressed - testing meteor YSort integration")
		_test_meteor_ysort_integration()

func _test_meteor_ysort_integration():
	"""Test that meteors are properly integrated with the YSort system"""
	print("=== TESTING METEOR YSORT INTEGRATION ===")
	
	# Check if Global YSort system exists
	if not Global:
		print("✗ ERROR: Global YSort system not found")
		return
	
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
	
	# Test YSort integration
	if meteor.has_method("get_y_sort_point"):
		var y_sort_value = meteor.get_y_sort_point()
		print("✓ Meteor get_y_sort_point() returns:", y_sort_value)
	else:
		print("✗ Meteor missing get_y_sort_point method")
	
	if meteor.has_method("update_ysort"):
		meteor.update_ysort()
		print("✓ Meteor update_ysort() method works")
	else:
		print("✗ Meteor missing update_ysort method")
	
	# Test groups
	if meteor.is_in_group("meteors"):
		print("✓ Meteor added to 'meteors' group")
	else:
		print("✗ Meteor not in 'meteors' group")
	
	if meteor.is_in_group("ysort_objects"):
		print("✓ Meteor added to 'ysort_objects' group")
	else:
		print("✗ Meteor not in 'ysort_objects' group")
	
	# Test Global YSort system integration
	Global.update_object_y_sort(meteor, "objects")
	print("✓ Global.update_object_y_sort() called successfully")
	
	# Test sprite visibility
	var meteor_sprite = meteor.get_node_or_null("MeteorSprite")
	if meteor_sprite:
		print("✓ Meteor sprite found, visible:", meteor_sprite.visible)
		print("✓ Meteor sprite z_index:", meteor_sprite.z_index)
	else:
		print("✗ Meteor sprite not found")
	
	# Clean up
	meteor.queue_free()
	print("✓ Meteor cleaned up successfully")
	
	print("=== METEOR YSORT INTEGRATION TEST COMPLETE ===")
	print("If all tests passed, the meteor should be visible when playing the MeteorCard") 