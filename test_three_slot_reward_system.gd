extends Node2D

# Test script for three-slot reward system
# This demonstrates how the new three-slot system works with specific card types

func _ready():
	print("=== THREE-SLOT REWARD SYSTEM TEST ===")
	
	# Test different turn counts and their tier probabilities
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
	
	print("\n=== TESTING THREE-SLOT REWARD SELECTION ===")
	
	# Test three-slot reward selection dialog
	test_three_slot_reward_selection()

func test_three_slot_reward_selection():
	"""Test that the three-slot reward selection dialog works correctly"""
	print("Testing three-slot reward selection dialog...")
	
	# Create a reward selection dialog
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Test at different tiers
	var test_tiers = [1, 2, 3]
	
	for tier in test_tiers:
		Global.current_reward_tier = tier
		print("\n--- Testing Tier %d ---" % tier)
		
		# Get tiered rewards for each slot type
		var tiered_club_cards = reward_dialog.get_tiered_club_cards()
		var tiered_action_cards = reward_dialog.get_tiered_action_cards()
		var tiered_equipment = reward_dialog.get_tiered_equipment()
		
		print("Tiered club cards (%d):" % tiered_club_cards.size())
		for card in tiered_club_cards:
			var card_tier = card.get_reward_tier()
			print("  %s (Tier %d)" % [card.name, card_tier])
		
		print("Tiered action cards (%d):" % tiered_action_cards.size())
		for card in tiered_action_cards:
			var card_tier = card.get_reward_tier()
			print("  %s (Tier %d)" % [card.name, card_tier])
		
		print("Tiered equipment (%d):" % tiered_equipment.size())
		for equipment in tiered_equipment:
			var equip_tier = equipment.get_reward_tier()
			print("  %s (Tier %d)" % [equipment.name, equip_tier])
	
	# Clean up
	reward_dialog.queue_free()
	
	print("\n=== THREE-SLOT REWARD SYSTEM TEST COMPLETE ===")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Simulate turn increment
			Global.increment_global_turn()
			var tier = Global.get_current_reward_tier()
			var probabilities = Global.get_tier_probabilities()
			print("Turn %d: Tier %d - Tier 1: %.1f%%, Tier 2: %.1f%%, Tier 3: %.1f%%" % [
				Global.global_turn_count, tier, 
				probabilities["tier_1"] * 100, 
				probabilities["tier_2"] * 100, 
				probabilities["tier_3"] * 100
			])
		
		elif event.keycode == KEY_R:
			# Reset turn counter
			Global.reset_global_turn()
			print("Turn counter reset to: ", Global.global_turn_count)
			print("Reward tier reset to: ", Global.get_current_reward_tier())
		
		elif event.keycode == KEY_T:
			# Test three-slot reward generation
			test_three_slot_reward_generation()
		
		elif event.keycode == KEY_S:
			# Show the reward selection dialog
			show_reward_dialog()

func test_three_slot_reward_generation():
	"""Test actual three-slot reward generation"""
	print("\n=== TESTING THREE-SLOT REWARD GENERATION ===")
	
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Test multiple reward generations
	for i in range(5):
		var rewards = reward_dialog.generate_three_slot_rewards()
		print("Three-slot reward set %d:" % (i + 1))
		
		# Slot 1: Club Card (left)
		var club_card = rewards[0]
		var club_type = rewards[1]
		var club_tier = club_card.get_reward_tier()
		print("  Left (Club): %s (%s, Tier %d)" % [club_card.name, club_type, club_tier])
		
		# Slot 2: Equipment (middle)
		var equipment = rewards[2]
		var equipment_type = rewards[3]
		if equipment_type == "equipment":
			var equip_tier = equipment.get_reward_tier()
			print("  Middle (Equipment): %s (%s, Tier %d)" % [equipment.name, equipment_type, equip_tier])
		else:
			print("  Middle (Equipment): %s (%s)" % [equipment.name, equipment_type])
		
		# Slot 3: Action Card (right)
		var action_card = rewards[4]
		var action_type = rewards[5]
		var action_tier = action_card.get_reward_tier()
		print("  Right (Action): %s (%s, Tier %d)" % [action_card.name, action_type, action_tier])
		
		print("")  # Empty line for readability
	
	reward_dialog.queue_free()
	print("=== THREE-SLOT REWARD GENERATION TEST COMPLETE ===")

func show_reward_dialog():
	"""Show the actual reward selection dialog"""
	print("\n=== SHOWING REWARD SELECTION DIALOG ===")
	
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Connect signals
	reward_dialog.reward_selected.connect(_on_reward_selected)
	reward_dialog.advance_to_next_hole.connect(_on_advance_to_next_hole)
	
	# Show the dialog
	reward_dialog.show_reward_selection()
	
	print("Reward dialog shown. Press ESC to close.")

func _on_reward_selected(reward_data: Resource, reward_type: String):
	"""Called when a reward is selected"""
	print("Reward selected: %s (%s)" % [reward_data.name, reward_type])

func _on_advance_to_next_hole():
	"""Called when advance button is pressed"""
	print("Advance to next hole selected")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Close any open reward dialogs
			var reward_dialog = get_tree().current_scene.get_node_or_null("RewardSelectionDialog")
			if reward_dialog:
				reward_dialog.queue_free()
				print("Reward dialog closed.") 