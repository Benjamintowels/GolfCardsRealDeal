extends Node2D

# Test script for MeteorCard AOE attack system
# This demonstrates how the MeteorCard works as an AOE attack

var cell_size: int = 48
var grid_size: Vector2i = Vector2i(20, 20)
var player_grid_pos: Vector2i = Vector2i(10, 10)
var test_meteor_card: CardData = null

func _ready():
	print("=== METEOR CARD AOE ATTACK SYSTEM TEST ===")
	
	# Create a test MeteorCard
	_create_test_meteor_card()
	
	# Test the AOE attack system
	_test_meteor_aoe_system()
	
	print("Test setup complete. Press SPACE to test meteor placement.")

func _create_test_meteor_card():
	"""Create a test MeteorCard for testing"""
	print("=== CREATING TEST METEOR CARD ===")
	
	# Load the MeteorCard resource
	var meteor_card_resource = load("res://Cards/MeteorCard.tres")
	if meteor_card_resource:
		test_meteor_card = meteor_card_resource.duplicate()
		print("✓ MeteorCard loaded successfully")
		print("  - Name:", test_meteor_card.name)
		print("  - Effect Type:", test_meteor_card.effect_type)
		print("  - Effect Strength:", test_meteor_card.effect_strength)
		print("  - Level:", test_meteor_card.level)
		print("  - Effective Strength:", test_meteor_card.get_effective_strength())
	else:
		print("✗ ERROR: Could not load MeteorCard.tres")
		return
	
	print("=== METEOR CARD CREATED ===")

func _test_meteor_aoe_system():
	"""Test the meteor AOE attack system"""
	print("=== TESTING METEOR AOE SYSTEM ===")
	
	if not test_meteor_card:
		print("✗ ERROR: No test meteor card available")
		return
	
	# Test 1: Check if card is properly configured as AOEAttack
	print("Test 1: Card Configuration")
	if test_meteor_card.effect_type == "AOEAttack":
		print("✓ Card is properly configured as AOEAttack")
	else:
		print("✗ ERROR: Card effect_type is not AOEAttack:", test_meteor_card.effect_type)
	
	# Test 2: Check effective strength (should be 10 for range)
	print("Test 2: Effective Strength")
	var effective_strength = test_meteor_card.get_effective_strength()
	print("Effective strength:", effective_strength)
	if effective_strength >= 10:
		print("✓ Effective strength is sufficient for 10-tile range")
	else:
		print("✗ ERROR: Effective strength too low for 10-tile range")
	
	# Test 3: Test 3x2 area placement validation
	print("Test 3: 3x2 Area Placement Validation")
	_test_3x2_area_placement()
	
	print("=== METEOR AOE SYSTEM TEST COMPLETE ===")

func _test_3x2_area_placement():
	"""Test the 3x2 area placement validation"""
	print("Testing 3x2 area placement validation...")
	
	# Test valid placement positions
	var valid_positions = []
	for y in grid_size.y:
		for x in grid_size.x:
			var pos = Vector2i(x, y)
			if _can_place_3x2_area_at_position(pos):
				valid_positions.append(pos)
	
	print("Valid 3x2 placement positions found:", valid_positions.size())
	
	# Test some specific positions
	var test_positions = [
		Vector2i(0, 0),      # Top-left corner
		Vector2i(17, 0),     # Top-right edge
		Vector2i(0, 18),     # Bottom-left edge
		Vector2i(17, 18),    # Bottom-right edge
		Vector2i(10, 10),    # Center
		Vector2i(18, 0),     # Invalid (would extend beyond grid)
		Vector2i(0, 19),     # Invalid (would extend beyond grid)
	]
	
	for pos in test_positions:
		var can_place = _can_place_3x2_area_at_position(pos)
		print("Position", pos, "can place 3x2 area:", can_place)
	
	# Test range validation
	print("Testing range validation...")
	var range_positions = []
	for y in grid_size.y:
		for x in grid_size.x:
			var pos = Vector2i(x, y)
			var distance = _calculate_grid_distance(player_grid_pos, pos)
			if distance <= test_meteor_card.get_effective_strength() and pos != player_grid_pos:
				if _can_place_3x2_area_at_position(pos):
					range_positions.append(pos)
	
	print("Valid positions within range:", range_positions.size())
	print("First 10 valid positions:", range_positions.slice(0, 10))

func _can_place_3x2_area_at_position(top_left_pos: Vector2i) -> bool:
	"""Check if a 3x2 area can be placed with the given position as top-left corner"""
	# Check if all 6 tiles in the 3x2 area are within grid bounds
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var check_pos = top_left_pos + Vector2i(x_offset, y_offset)
			if check_pos.x >= grid_size.x or check_pos.y >= grid_size.y:
				return false
	return true

func _calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	"""Calculate Manhattan distance between two grid positions"""
	return abs(a.x - b.x) + abs(a.y - b.y)

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		print("SPACE pressed - running meteor placement test")
		_test_meteor_placement_simulation()

func _test_meteor_placement_simulation():
	"""Simulate meteor placement and AOE calculation"""
	print("=== METEOR PLACEMENT SIMULATION ===")
	
	if not test_meteor_card:
		print("✗ ERROR: No test meteor card available")
		return
	
	# Simulate placing meteor at a specific position
	var target_pos = Vector2i(12, 12)  # Example target position
	print("Simulating meteor placement at:", target_pos)
	
	# Calculate the 3x2 area positions
	var aoe_positions = []
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var pos = target_pos + Vector2i(x_offset, y_offset)
			aoe_positions.append(pos)
	
	print("AOE positions:", aoe_positions)
	
	# Calculate world position for meteor target (center of 3x2 area)
	var world_target_x = (target_pos.x + 1.5) * cell_size
	var world_target_y = (target_pos.y + 0.5) * cell_size
	var world_target_pos = Vector2(world_target_x, world_target_y)
	
	print("World target position (center of 3x2 area):", world_target_pos)
	print("Meteor would fall from above screen to this position")
	print("Then deal 35 damage to all NPCs in the 3x2 area")
	
	print("=== METEOR PLACEMENT SIMULATION COMPLETE ===")

func _on_test_button_pressed():
	"""Called when test button is pressed"""
	print("Test button pressed - running full meteor test")
	_test_meteor_aoe_system()
	_test_meteor_placement_simulation() 