extends Node2D

# Test script for the new difficulty tier system
# This demonstrates how the system works at different turn milestones

func _ready():
	print("=== DIFFICULTY TIER SYSTEM TEST ===")
	
	# Test different turn counts
	var test_turns = [1, 5, 10, 15, 20, 25, 30, 35, 40]
	
	for turn in test_turns:
		Global.global_turn_count = turn
		var tier = Global.get_difficulty_tier()
		var npc_counts = Global.get_difficulty_tier_npc_counts()
		var hole0_counts = Global.get_difficulty_tier_npc_counts(0)
		
		print("Turn %d: Tier %d - %s (Hole 0: %s)" % [turn, tier, npc_counts, hole0_counts])
	
	print("=== END TEST ===")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Simulate turn increment
			Global.increment_global_turn()
			var tier = Global.get_difficulty_tier()
			var npc_counts = Global.get_difficulty_tier_npc_counts()
			var hole0_counts = Global.get_difficulty_tier_npc_counts(0)
			print("Turn %d: Tier %d - %s (Hole 0: %s)" % [Global.global_turn_count, tier, npc_counts, hole0_counts])
		
		elif event.keycode == KEY_R:
			# Reset turn counter
			Global.reset_global_turn()
			var tier = Global.get_difficulty_tier()
			var npc_counts = Global.get_difficulty_tier_npc_counts()
			var hole0_counts = Global.get_difficulty_tier_npc_counts(0)
			print("Turn counter reset to: %d (Tier %d - %s) (Hole 0: %s)" % [Global.global_turn_count, tier, npc_counts, hole0_counts])
		
		elif event.keycode == KEY_T:
			# Test specific turn
			var test_turn = 6  # Should be tier 1
			Global.global_turn_count = test_turn
			var tier = Global.get_difficulty_tier()
			var npc_counts = Global.get_difficulty_tier_npc_counts()
			var hole0_counts = Global.get_difficulty_tier_npc_counts(0)
			print("Test turn %d: Tier %d - %s (Hole 0: %s)" % [test_turn, tier, npc_counts, hole0_counts]) 