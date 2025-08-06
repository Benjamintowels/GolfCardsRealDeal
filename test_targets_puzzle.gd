extends Node

# Test script for Targets puzzle type
# This script can be run to test the Targets puzzle functionality

func _ready():
	print("🎯 TARGETS PUZZLE TEST STARTED")
	
	# Test 1: Check if FloatingTarget scene exists
	test_floating_target_scene()
	
	# Test 2: Check if TargetExplosion scene exists
	test_target_explosion_scene()
	
	# Test 3: Check if Boop sound exists
	test_boop_sound()
	
	# Test 4: Check if puzzle type is added to selection dialog
	test_puzzle_type_selection()
	
	print("🎯 TARGETS PUZZLE TEST COMPLETED")

func test_floating_target_scene():
	"""Test if FloatingTarget scene can be loaded"""
	print("=== TEST 1: FloatingTarget Scene ===")
	
	var scene = preload("res://Interactables/FloatingTarget.tscn")
	if scene:
		print("✓ FloatingTarget scene loaded successfully")
		
		# Try to instantiate it
		var instance = scene.instantiate()
		if instance:
			print("✓ FloatingTarget instantiated successfully")
			instance.queue_free()
		else:
			print("❌ FloatingTarget instantiation failed")
	else:
		print("❌ FloatingTarget scene not found")

func test_target_explosion_scene():
	"""Test if TargetExplosion scene can be loaded"""
	print("=== TEST 2: TargetExplosion Scene ===")
	
	var scene = preload("res://Interactables/TargetExplosion.tscn")
	if scene:
		print("✓ TargetExplosion scene loaded successfully")
		
		# Try to instantiate it
		var instance = scene.instantiate()
		if instance:
			print("✓ TargetExplosion instantiated successfully")
			instance.queue_free()
		else:
			print("❌ TargetExplosion instantiation failed")
	else:
		print("❌ TargetExplosion scene not found")

func test_boop_sound():
	"""Test if Boop sound exists"""
	print("=== TEST 3: Boop Sound ===")
	
	var sound = preload("res://Sounds/Boop.mp3")
	if sound:
		print("✓ Boop sound loaded successfully")
	else:
		print("❌ Boop sound not found")

func test_puzzle_type_selection():
	"""Test if targets puzzle type is available in selection dialog"""
	print("=== TEST 4: Puzzle Type Selection ===")
	
	# Check if the puzzle type is defined in the selection dialog
	var puzzle_selection = preload("res://PuzzleTypeSelectionDialog.gd")
	if puzzle_selection:
		print("✓ PuzzleTypeSelectionDialog script found")
		
		# Create an instance to check the puzzle types
		var instance = puzzle_selection.new()
		if instance and "targets" in instance.puzzle_types:
			print("✓ Targets puzzle type found in selection dialog")
			var target_info = instance.puzzle_types["targets"]
			print("  - Name:", target_info.name)
			print("  - Description:", target_info.description)
		else:
			print("❌ Targets puzzle type not found in selection dialog")
		
		instance.queue_free()
	else:
		print("❌ PuzzleTypeSelectionDialog script not found")

func test_layout_detection():
	"""Test layout detection logic"""
	print("=== TEST 5: Layout Detection ===")
	
	# Test horizontal layout detection
	var horizontal_layout = [
		["F", "F", "F", "F", "F", "F", "F", "F"],
		["F", "F", "F", "F", "F", "F", "F", "F"],
		["F", "F", "F", "F", "F", "F", "F", "F"]
	]
	
	var vertical_layout = [
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"],
		["F", "F", "F"]
	]
	
	var is_horizontal_1 = horizontal_layout[0].size() > horizontal_layout.size()
	var is_horizontal_2 = vertical_layout[0].size() > vertical_layout.size()
	
	print("✓ Horizontal layout detection:", is_horizontal_1, "(should be true)")
	print("✓ Vertical layout detection:", is_horizontal_2, "(should be false)")
	
	if is_horizontal_1 and not is_horizontal_2:
		print("✓ Layout detection logic working correctly")
	else:
		print("❌ Layout detection logic not working correctly") 