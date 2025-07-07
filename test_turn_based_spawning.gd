extends Node2D

# Test script for turn-based spawning system
# This demonstrates how the system works at different turn milestones

func _ready():
	print("=== TURN-BASED SPAWNING TEST ===")
	
	# Test different turn counts
	var test_turns = [1, 5, 10, 15, 20, 25, 30]
	
	for turn in test_turns:
		Global.global_turn_count = turn
		var gang_count = Global.get_turn_based_gang_member_count()
		var oil_count = Global.get_turn_based_oil_drum_count()
		
		print("Turn %d: %d gang members, %d oil drums" % [turn, gang_count, oil_count])
	
	print("=== END TEST ===")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Simulate turn increment
			Global.increment_global_turn()
			var gang_count = Global.get_turn_based_gang_member_count()
			var oil_count = Global.get_turn_based_oil_drum_count()
			print("Turn %d: %d gang members, %d oil drums" % [Global.global_turn_count, gang_count, oil_count])
		
		elif event.keycode == KEY_R:
			# Reset turn counter
			Global.reset_global_turn()
			print("Turn counter reset to: ", Global.global_turn_count) 