extends Node2D

# Test script for the new structured shop system
# This demonstrates how the shop now has guaranteed slots

func _ready():
	print("=== STRUCTURED SHOP SYSTEM TEST ===")
	
	# Test different turn counts and their shop configurations
	var test_turns = [1, 5, 10, 15, 20, 25, 30]
	
	for turn in test_turns:
		Global.global_turn_count = turn
		Global.update_reward_tier()
		var tier = Global.get_current_reward_tier()
		var probabilities = Global.get_tier_probabilities()
		
		print("Turn %d: Tier %d - Tier 1: %.1f%%, Tier 2: %.1f%%, Tier 3: %.1f%%" % [
			turn, tier, 
			probabilities["tier_1"] * 100, 
			probabilities["tier_2"] * 100, 
			probabilities["tier_3"] * 100
		])
	
	print("\n=== TESTING SHOP GENERATION ===")
	
	# Test shop generation at different tiers
	test_shop_generation()

func test_shop_generation():
	"""Test that the shop generates the correct structured layout"""
	print("Testing shop generation...")
	
	# Create a shop interior
	var shop_scene = preload("res://Shop/ShopInterior.tscn")
	var shop = shop_scene.instantiate()
	get_tree().current_scene.add_child(shop)
	
	# Test at different tiers
	var test_tiers = [1, 2, 3]
	
	for tier in test_tiers:
		Global.current_reward_tier = tier
		print("\n--- Testing Shop Tier %d ---" % tier)
		
		# Generate shop items
		shop.generate_shop_items()
		
		# Check the structure
		var items = shop.current_shop_items
		print("Shop items (%d):" % items.size())
		
		for i in range(items.size()):
			var item = items[i]
			var item_type = "card" if item is CardData else "equipment"
			var slot_type = get_slot_type(i)
			print("  Slot %d (%s): %s (%s)" % [i + 1, slot_type, item.name, item_type])
		
		# Verify structure
		verify_shop_structure(items, tier)
	
	# Clean up
	shop.queue_free()
	
	print("\n=== STRUCTURED SHOP SYSTEM TEST COMPLETE ===")

func get_slot_type(slot_index: int) -> String:
	"""Get the expected slot type based on position"""
	match slot_index:
		0: return "Guaranteed Club Card"
		1: return "Guaranteed Equipment"
		2: return "Random Tiered Item"
		3: return "Random Tiered Item"
		_: return "Unknown"

func verify_shop_structure(items: Array, tier: int):
	"""Verify that the shop has the correct structure"""
	print("Verifying shop structure for tier %d..." % tier)
	
	# Check that we have items
	if items.is_empty():
		print("  ❌ ERROR: No items generated!")
		return
	
	# Check slot 1: Should be a club card
	if items.size() > 0:
		var slot1_item = items[0]
		if slot1_item is CardData:
			var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
			if club_names.has(slot1_item.name):
				print("  ✅ Slot 1: Club card (%s)" % slot1_item.name)
			else:
				print("  ❌ Slot 1: Expected club card, got %s" % slot1_item.name)
		else:
			print("  ❌ Slot 1: Expected club card, got equipment")
	
	# Check slot 2: Should be equipment
	if items.size() > 1:
		var slot2_item = items[1]
		if slot2_item is EquipmentData:
			print("  ✅ Slot 2: Equipment (%s)" % slot2_item.name)
		else:
			print("  ❌ Slot 2: Expected equipment, got card")
	
	# Check slots 3-4: Should be tiered items
	for i in range(2, min(items.size(), 4)):
		var slot_item = items[i]
		var item_tier = slot_item.get_reward_tier()
		print("  ✅ Slot %d: Tiered item (%s, Tier %d)" % [i + 1, slot_item.name, item_tier])

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Test shop generation
			test_shop_generation()
		
		elif event.keycode == KEY_R:
			# Reset turn counter
			Global.reset_global_turn()
			print("Turn counter reset to: ", Global.global_turn_count)
			print("Reward tier reset to: ", Global.get_current_reward_tier())
		
		elif event.keycode == KEY_T:
			# Test specific tier
			var test_tier = 2
			Global.current_reward_tier = test_tier
			print("Testing tier %d shop generation..." % test_tier)
			test_shop_generation() 