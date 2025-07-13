extends Node2D

func _ready():
	print("=== SUITCASE SYSTEM TEST ===")
	test_suitcase_placement_logic()
	test_suitcase_detection()

func test_suitcase_placement_logic():
	"""Test the SuitCase placement logic"""
	print("\n--- Testing SuitCase Placement Logic ---")
	
	# Test holes 1-18 to see which ones should have SuitCases
	for hole in range(18):
		var should_place = (hole + 1) % 6 == 0
		print("Hole %d: %s" % [hole + 1, "SuitCase" if should_place else "No SuitCase"])
	
	print("Expected SuitCases on holes: 6, 12, 18")

func test_suitcase_detection():
	"""Test SuitCase detection logic"""
	print("\n--- Testing SuitCase Detection ---")
	
	# Test player reaching SuitCase position
	var player_pos = Vector2i(5, 5)
	var suitcase_pos = Vector2i(5, 5)
	
	if player_pos == suitcase_pos:
		print("✓ Player reached SuitCase position")
	else:
		print("✗ Player not at SuitCase position")
	
	# Test different positions
	player_pos = Vector2i(4, 5)
	if player_pos == suitcase_pos:
		print("✗ False positive - player not at SuitCase")
	else:
		print("✓ Correctly detected player not at SuitCase")

func test_fairway_position_generation():
	"""Test fairway position generation"""
	print("\n--- Testing Fairway Position Generation ---")
	
	# Create a simple test layout with fairway tiles
	var test_layout = [
		["Base", "F", "Base"],
		["F", "F", "F"],
		["Base", "F", "Base"]
	]
	
	# Simulate the get_valid_fairway_positions logic
	var fairway_positions = []
	for y in test_layout.size():
		for x in test_layout[y].size():
			if test_layout[y][x] == "F":
				fairway_positions.append(Vector2i(x, y))
	
	print("Fairway positions found:", fairway_positions)
	print("Expected: [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(1,2)]")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				test_suitcase_placement_logic()
			KEY_2:
				test_suitcase_detection()
			KEY_3:
				test_fairway_position_generation()
			KEY_ESCAPE:
				get_tree().quit() 