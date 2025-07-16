extends Node2D

# Test script for Meteor coordinate conversion
# This verifies that grid coordinates are properly converted to world coordinates

var cell_size: int = 48
var test_grid_pos: Vector2i = Vector2i(10, 5)  # Example grid position

func _ready():
	print("=== METEOR COORDINATE CONVERSION TEST ===")
	
	# Test the coordinate conversion logic
	_test_coordinate_conversion()
	
	print("Test setup complete. Press SPACE to run coordinate test.")

func _test_coordinate_conversion():
	"""Test the coordinate conversion logic used in meteor positioning"""
	print("=== TESTING COORDINATE CONVERSION ===")
	
	# Simulate the meteor coordinate calculation
	var target_pos = test_grid_pos
	print("Grid target position:", target_pos)
	
	# Calculate world position for the meteor target (center of the 3x2 area)
	var world_target_x = (target_pos.x + 1.5) * cell_size  # Center of 3-tile width
	var world_target_y = (target_pos.y + 0.5) * cell_size  # Center of 2-tile height
	var world_target_pos = Vector2(world_target_x, world_target_y)
	
	print("World target position (before camera offset):", world_target_pos)
	
	# Simulate camera container offset (typical values)
	var simulated_camera_offset = Vector2(564.625, 360.0)  # Example camera container position
	world_target_pos += simulated_camera_offset
	
	print("Simulated camera container offset:", simulated_camera_offset)
	print("World target position (after camera offset):", world_target_pos)
	
	# Calculate meteor start position
	var meteor_start_pos = Vector2(world_target_x, -100)  # Start above screen
	meteor_start_pos += simulated_camera_offset
	
	print("Meteor start position (after camera offset):", meteor_start_pos)
	
	# Verify the calculation makes sense
	print("=== COORDINATE VERIFICATION ===")
	print("Grid position (10, 5) should be near the top-left area")
	print("World position should be significantly offset from (0,0)")
	print("Meteor should fall from above screen to the correct grid tile")
	
	print("=== COORDINATE CONVERSION TEST COMPLETE ===")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		print("SPACE pressed - running coordinate test")
		_test_coordinate_conversion()

func _on_test_button_pressed():
	"""Called when test button is pressed"""
	print("Test button pressed - running coordinate test")
	_test_coordinate_conversion() 