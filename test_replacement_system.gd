extends Node

# Test script for the replacement system
# This script will help verify the replacement system functionality
# NOTE: This test should be run within the Course1.tscn scene, not in isolation

func _ready():
	print("=== Replacement System Test ===")
	print("This test will verify the replacement system functionality")
	print("NOTE: This test should be run within Course1.tscn scene")
	
	# Wait a moment for the scene to be fully loaded
	await get_tree().process_frame
	
	# Check if we're in the right scene context
	check_scene_context()
	
	# Test the slot checking functions
	test_slot_checking()
	
	# Test the replacement system
	test_replacement_system()

func check_scene_context():
	"""Check if we're in the proper game scene context"""
	print("\n--- Checking Scene Context ---")
	
	var current_scene = get_tree().current_scene
	print("Current scene name:", current_scene.name if current_scene else "null")
	
	# Check if we're in Course1 scene
	if current_scene and "course_1" in current_scene.get_script().resource_path:
		print("✓ Running in Course1 scene - good!")
	else:
		print("⚠ WARNING: Not running in Course1 scene!")
		print("This test should be run within Course1.tscn for proper functionality")
		print("To test properly:")
		print("1. Open Course1.tscn")
		print("2. Add this test script as a child node")
		print("3. Run the scene")
		return
	
	# Check for required managers
	var managers_found = 0
	var total_managers = 0
	
	# Check for Bag
	var bag = current_scene.get_node_or_null("UILayer/Bag")
	if bag:
		print("✓ Bag found in UILayer")
		managers_found += 1
	else:
		print("✗ Bag not found in UILayer")
	total_managers += 1
	
	# Check for EquipmentManager
	var equipment_manager = current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		print("✓ EquipmentManager found")
		managers_found += 1
	else:
		print("✗ EquipmentManager not found")
	total_managers += 1
	
	# Check for CurrentDeckManager
	var current_deck_manager = current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		print("✓ CurrentDeckManager found")
		managers_found += 1
	else:
		print("✗ CurrentDeckManager not found")
	total_managers += 1
	
	# Check for DeckManager
	var deck_manager = current_scene.get_node_or_null("DeckManager")
	if deck_manager:
		print("✓ DeckManager found")
		managers_found += 1
	else:
		print("✗ DeckManager not found")
	total_managers += 1
	
	print("Managers found: %d/%d" % [managers_found, total_managers])
	
	if managers_found < total_managers:
		print("⚠ Some managers are missing - test may not work properly")

func test_slot_checking():
	"""Test the slot checking functionality"""
	print("\n--- Testing Slot Checking ---")
	
	# Get the bag
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		print("ERROR: Bag not found!")
		print("Make sure you're running this test within Course1.tscn")
		return
	
	print("Bag found:", bag.name)
	print("Bag level:", bag.bag_level)
	print("Equipment slots:", bag.get_equipment_slots())
	print("Movement slots:", bag.get_movement_slots())
	print("Club slots:", bag.get_club_slots())
	
	# Test equipment slot checking
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if equipment_manager:
		var equipped_items = equipment_manager.get_equipped_equipment()
		print("Current equipped items:", equipped_items.size())
		print("Equipment slots available:", equipped_items.size() < bag.get_equipment_slots())
	else:
		print("EquipmentManager not found - cannot test equipment slots")
	
	# Test card slot checking
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		var current_deck = current_deck_manager.get_current_deck()
		var movement_cards = bag.get_movement_cards()
		var club_cards = bag.get_club_cards()
		
		print("Total deck size:", current_deck.size())
		print("Movement cards:", movement_cards.size())
		print("Club cards:", club_cards.size())
		print("Movement slots available:", movement_cards.size() < bag.get_movement_slots())
		print("Club slots available:", club_cards.size() < bag.get_club_slots())
	else:
		print("CurrentDeckManager not found - cannot test card slots")

func test_replacement_system():
	"""Test the replacement system by filling the bag and trying to add items"""
	print("\n--- Testing Replacement System ---")
	
	# Get managers
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	
	if not bag or not equipment_manager or not current_deck_manager:
		print("ERROR: Required managers not found!")
		print("Make sure you're running this test within Course1.tscn")
		return
	
	# Test equipment replacement
	print("\nTesting Equipment Replacement:")
	var golf_shoes = preload("res://Equipment/GolfShoes.tres")
	var slots_available = check_bag_slots(golf_shoes, "equipment")
	print("Golf Shoes slots available:", slots_available)
	
	if not slots_available:
		print("Equipment bag is full - replacement system should trigger")
		print("Replacement dialog should appear")
	else:
		print("Equipment bag has available slots")
	
	# Test card replacement
	print("\nTesting Card Replacement:")
	var test_card = preload("res://Cards/Move1.tres")
	var card_slots_available = check_bag_slots(test_card, "card")
	print("Move1 card slots available:", card_slots_available)
	
	if not card_slots_available:
		print("Card bag is full - replacement system should trigger")
		print("Replacement dialog should appear")
	else:
		print("Card bag has available slots")
	
	# Test club card replacement
	print("\nTesting Club Card Replacement:")
	var club_card = preload("res://Cards/Putter.tres")
	var club_slots_available = check_bag_slots(club_card, "card")
	print("Putter card slots available:", club_slots_available)
	
	if not club_slots_available:
		print("Club card bag is full - replacement system should trigger")
		print("Replacement dialog should appear")
	else:
		print("Club card bag has available slots")
	
	print("\n=== Replacement System Test Complete ===")
	print("To test the actual replacement dialog:")
	print("1. Fill your bag with items")
	print("2. Try to add a new item through rewards or shop")
	print("3. The replacement dialog should appear")

func check_bag_slots(item: Resource, item_type: String) -> bool:
	"""Check if there are available slots in the bag for the item"""
	var bag = get_tree().current_scene.get_node_or_null("UILayer/Bag")
	if not bag:
		return true  # Allow if bag not found
	
	if item_type == "card":
		var card_data = item as CardData
		# Check if it's a club card by name
		var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
		if club_names.has(card_data.name):
			# Check club card slots
			var club_cards = bag.get_club_cards()
			var club_slots = bag.get_club_slots()
			return club_cards.size() < club_slots
		else:
			# Check movement card slots
			var movement_cards = bag.get_movement_cards()
			var movement_slots = bag.get_movement_slots()
			return movement_cards.size() < movement_slots
	elif item_type == "equipment":
		# Check equipment slots
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			var equipped_items = equipment_manager.get_equipped_equipment()
			var equipment_slots = bag.get_equipment_slots()
			return equipped_items.size() < equipment_slots
	
	return true 
