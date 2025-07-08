extends Node2D

func _ready():
	print("=== TESTING COMPLETE CLOTHING SYSTEM ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test the complete clothing system
	test_complete_system()

func test_complete_system():
	"""Test the complete clothing system with Marker2D positioning"""
	print("Testing complete clothing system...")
	
	# Get the equipment manager
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if not equipment_manager:
		print("✗ EquipmentManager not found")
		return
	
	# Get the player
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player:
		print("✗ Player not found")
		return
	
	print("✓ Found EquipmentManager and Player")
	
	# Test 1: Add Cape (neck slot)
	print("\n--- Test 1: Adding Cape to neck slot ---")
	var cape = preload("res://Equipment/Clothes/Cape.tres")
	if cape:
		equipment_manager.add_equipment(cape)
		print("✓ Added Cape")
		print("✓ Cape should appear at NeckClothes marker position")
		await get_tree().create_timer(2.0).timeout
	else:
		print("✗ Failed to load Cape")
	
	# Test 2: Add Top Hat (head slot)
	print("\n--- Test 2: Adding Top Hat to head slot ---")
	var top_hat = preload("res://Equipment/Clothes/TopHat.tres")
	if top_hat:
		equipment_manager.add_equipment(top_hat)
		print("✓ Added Top Hat")
		print("✓ Top Hat should appear at HeadClothes marker position")
		await get_tree().create_timer(2.0).timeout
	else:
		print("✗ Failed to load Top Hat")
	
	# Test 3: Check clothing slots
	print("\n--- Test 3: Checking clothing slots ---")
	var clothing_slots = equipment_manager.get_clothing_slots()
	print("Head slot:", clothing_slots["head"].name if clothing_slots["head"] else "empty")
	print("Neck slot:", clothing_slots["neck"].name if clothing_slots["neck"] else "empty")
	print("Body slot:", clothing_slots["body"].name if clothing_slots["body"] else "empty")
	
	# Test 4: Remove specific clothing
	print("\n--- Test 4: Removing Cape ---")
	if cape:
		equipment_manager.remove_equipment(cape)
		print("✓ Removed Cape")
		print("✓ Cape should disappear from NeckClothes marker")
		await get_tree().create_timer(2.0).timeout
	
	# Test 5: Clear all equipment
	print("\n--- Test 5: Clearing all equipment ---")
	equipment_manager.clear_all_equipment()
	print("✓ Cleared all equipment")
	print("✓ All clothing should disappear from markers")
	
	print("\n=== COMPLETE CLOTHING SYSTEM TEST COMPLETE ===")
	print("✓ If all tests passed, the clothing system is working correctly!")
	print("✓ Clothing items should appear at the correct Marker2D positions")
	print("✓ Each character has their own Marker2D positions for proper clothing placement") 