extends Node

# Test script to verify bonfire placement logic

func _ready():
	print("=== TESTING BONFIRE PLACEMENT LOGIC ===")
	
	# Test hole numbers and expected bonfire placement
	var test_holes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
	
	for hole in test_holes:
		var hole_index = hole - 1  # Convert to 0-based index
		var should_have_bonfire = hole % 2 == 0  # Even holes should have bonfires
		print("Hole", hole, " (index", hole_index, "):", " SHOULD" if should_have_bonfire else " SHOULD NOT", " have bonfire")
	
	print("\n=== TESTING VALID POSITION LOGIC ===")
	
	# Create a simple test layout
	var test_layout = [
		["Base", "Base", "Base", "R", "Base"],
		["Base", "Base", "R", "R", "Base"],
		["Base", "R", "R", "R", "Base"],
		["Base", "Base", "R", "R", "Base"],
		["Base", "Base", "Base", "R", "Base"]
	]
	
	# Test positions that should be valid (2+ away from rough)
	var valid_positions = [
		Vector2i(0, 0),  # Top-left corner
		Vector2i(4, 0),  # Top-right corner
		Vector2i(0, 4),  # Bottom-left corner
		Vector2i(4, 4)   # Bottom-right corner
	]
	
	# Test positions that should be invalid (too close to rough)
	var invalid_positions = [
		Vector2i(1, 1),  # Close to rough
		Vector2i(2, 2),  # In rough area
		Vector2i(3, 3)   # In rough area
	]
	
	print("Testing valid positions:")
	for pos in valid_positions:
		var is_valid = is_position_valid_for_bonfire(pos, test_layout)
		print("  Position", pos, ":", "VALID" if is_valid else "INVALID")
	
	print("Testing invalid positions:")
	for pos in invalid_positions:
		var is_valid = is_position_valid_for_bonfire(pos, test_layout)
		print("  Position", pos, ":", "VALID" if is_valid else "INVALID")
	
	print("=== BONFIRE PLACEMENT TEST COMPLETE ===")

func is_position_valid_for_bonfire(pos: Vector2i, layout: Array) -> bool:
	"""Simplified version of the bonfire validation logic for testing"""
	if pos.y < 0 or pos.y >= layout.size() or pos.x < 0 or pos.x >= layout[0].size():
		return false
	var tile_type = layout[pos.y][pos.x]
	# Only allow placement on Base tiles
	if tile_type != "Base":
		return false
	
	# Check that the position is at least 2 tiles away from any rough terrain
	for dy in range(-2, 3):  # Check 2 tiles in each direction
		for dx in range(-2, 3):
			var check_x = pos.x + dx
			var check_y = pos.y + dy
			if check_x >= 0 and check_y >= 0 and check_y < layout.size() and check_x < layout[check_y].size():
				if layout[check_y][check_x] == "R":  # Rough tile
					return false
	
	return true 