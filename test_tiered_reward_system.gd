extends Node2D

# Test script for tiered reward system
# This demonstrates how the tiered reward system works at different turn milestones

func _ready():
	print("=== TIERED REWARD SYSTEM TEST ===")
	
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
	
	print("\n=== TESTING REWARD SELECTION ===")
	
	# Test reward selection dialog
	test_reward_selection_dialog()

func test_reward_selection_dialog():
	"""Test that the reward selection dialog uses tiered rewards"""
	print("Testing reward selection dialog...")
	
	# Create a reward selection dialog
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Test at different tiers
	var test_tiers = [1, 2, 3]
	
	for tier in test_tiers:
		Global.current_reward_tier = tier
		print("\n--- Testing Tier %d ---" % tier)
		
		# Get tiered cards and equipment
		var tiered_cards = reward_dialog.get_tiered_cards()
		var tiered_equipment = reward_dialog.get_tiered_equipment()
		
		print("Tiered cards (%d):" % tiered_cards.size())
		for card in tiered_cards:
			var card_tier = card.get_reward_tier()
			print("  %s (Tier %d)" % [card.name, card_tier])
		
		print("Tiered equipment (%d):" % tiered_equipment.size())
		for equipment in tiered_equipment:
			var equip_tier = equipment.get_reward_tier()
			print("  %s (Tier %d)" % [equipment.name, equip_tier])
	
	# Clean up
	reward_dialog.queue_free()
	
	print("\n=== TIERED REWARD SYSTEM TEST COMPLETE ===")

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
			# Test reward generation
			test_reward_generation()

func test_reward_generation():
	"""Test actual reward generation"""
	print("\n=== TESTING REWARD GENERATION ===")
	
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Test multiple reward generations
	for i in range(5):
		var rewards = reward_dialog.generate_random_rewards()
		print("Reward set %d:" % (i + 1))
		
		for j in range(0, rewards.size(), 2):
			var reward = rewards[j]
			var reward_type = rewards[j + 1]
			
			if reward_type == "card":
				var card_tier = reward.get_reward_tier()
				print("  %s (Card, Tier %d)" % [reward.name, card_tier])
			elif reward_type == "equipment":
				var equip_tier = reward.get_reward_tier()
				print("  %s (Equipment, Tier %d)" % [reward.name, equip_tier])
			else:
				print("  %s (%s)" % [reward.name, reward_type])
	
	reward_dialog.queue_free()
	print("=== REWARD GENERATION TEST COMPLETE ===") 