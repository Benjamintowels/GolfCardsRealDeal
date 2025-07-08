extends Node2D

func _ready():
	print("=== TESTING CLOTHING MARKER2D POSITIONING ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test the clothing system with Marker2D positioning
	test_clothing_markers()

func test_clothing_markers():
	"""Test that clothing items are positioned correctly using Marker2D nodes"""
	print("Testing clothing Marker2D positioning...")
	
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
	
	# Test adding clothing items
	test_add_clothing(equipment_manager)
	
	# Wait a moment to see the results
	await get_tree().create_timer(3.0).timeout
	
	# Test removing clothing items
	test_remove_clothing(equipment_manager)
	
	print("=== CLOTHING MARKER2D TEST COMPLETE ===")

func test_add_clothing(equipment_manager: EquipmentManager):
	"""Test adding clothing items to see if they appear at Marker2D positions"""
	print("Testing clothing addition...")
	
	# Load clothing resources
	var cape = preload("res://Equipment/Clothes/Cape.tres")
	var top_hat = preload("res://Equipment/Clothes/TopHat.tres")
	
	if cape and top_hat:
		print("✓ Loaded clothing resources")
		
		# Add clothing items
		equipment_manager.add_equipment(cape)
		equipment_manager.add_equipment(top_hat)
		
		print("✓ Added Cape and Top Hat")
		print("✓ Check that Cape appears at NeckClothes marker")
		print("✓ Check that Top Hat appears at HeadClothes marker")
	else:
		print("✗ Failed to load clothing resources")

func test_remove_clothing(equipment_manager: EquipmentManager):
	"""Test removing clothing items"""
	print("Testing clothing removal...")
	
	# Clear all equipment
	equipment_manager.clear_all_equipment()
	
	print("✓ Cleared all equipment")
	print("✓ Check that clothing items are removed from markers") 