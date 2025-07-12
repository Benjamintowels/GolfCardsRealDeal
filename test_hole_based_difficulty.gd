extends Node2D

# Test script for the new hole-based difficulty system
# This demonstrates how the system works with base difficulty per hole + tier amplification

func _ready():
	print("=== HOLE-BASED DIFFICULTY SYSTEM TEST ===")
	
	# Test all holes at different tiers
	test_hole_difficulty_progression()

func test_hole_difficulty_progression():
	"""Test the difficulty progression across all holes and tiers"""
	
	# Test holes 1-18 at different tiers
	var test_tiers = [0, 1, 2, 3, 4, 5]
	
	for tier in test_tiers:
		Global.global_turn_count = tier * 5 + 1  # Set turn count to match tier
		print("\n=== TIER %d TESTING ===" % tier)
		
		# Test front 9 holes
		for hole in range(9):
			var npc_counts = Global.get_difficulty_tier_npc_counts(hole)
			print("Hole %d: %s" % [hole + 1, npc_counts])
		
		# Test back 9 holes
		for hole in range(9, 18):
			var npc_counts = Global.get_difficulty_tier_npc_counts(hole)
			print("Hole %d: %s" % [hole + 1, npc_counts])

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Test specific hole and tier
				test_specific_hole_tier()
			
			KEY_R:
				# Reset and test base difficulty
				test_base_difficulty()
			
			KEY_T:
				# Test tier amplification
				test_tier_amplification()
			
			KEY_B:
				# Test back 9 vs front 9
				test_back_9_comparison()

func test_specific_hole_tier():
	"""Test a specific hole at current tier"""
	var test_hole = 4  # Hole 5
	var npc_counts = Global.get_difficulty_tier_npc_counts(test_hole)
	var tier = Global.get_difficulty_tier()
	print("\n=== SPECIFIC HOLE TEST ===")
	print("Hole %d at Tier %d: %s" % [test_hole + 1, tier, npc_counts])

func test_base_difficulty():
	"""Test base difficulty without tier amplification"""
	print("\n=== BASE DIFFICULTY TEST ===")
	Global.global_turn_count = 1  # Tier 0
	
	for hole in range(9):
		var npc_counts = Global.get_difficulty_tier_npc_counts(hole)
		print("Hole %d (Base): %s" % [hole + 1, npc_counts])

func test_tier_amplification():
	"""Test how tier amplification affects a specific hole"""
	print("\n=== TIER AMPLIFICATION TEST ===")
	var test_hole = 0  # Hole 1
	
	for tier in range(6):
		Global.global_turn_count = tier * 5 + 1
		var npc_counts = Global.get_difficulty_tier_npc_counts(test_hole)
		print("Hole 1 at Tier %d: %s" % [tier, npc_counts])

func test_back_9_comparison():
	"""Test back 9 vs front 9 difficulty"""
	print("\n=== BACK 9 vs FRONT 9 COMPARISON ===")
	Global.global_turn_count = 1  # Tier 0 for base comparison
	
	for i in range(9):
		var front_hole = i
		var back_hole = i + 9
		var front_counts = Global.get_difficulty_tier_npc_counts(front_hole)
		var back_counts = Global.get_difficulty_tier_npc_counts(back_hole)
		print("Hole %d vs %d: %s vs %s" % [front_hole + 1, back_hole + 1, front_counts, back_counts])

func test_hole_progression():
	"""Test the progression from hole 1 to hole 18"""
	print("\n=== HOLE PROGRESSION TEST ===")
	Global.global_turn_count = 1  # Tier 0
	
	print("Front 9 Progression:")
	for hole in range(9):
		var npc_counts = Global.get_difficulty_tier_npc_counts(hole)
		print("Hole %d: %s" % [hole + 1, npc_counts])
	
	print("\nBack 9 Progression:")
	for hole in range(9, 18):
		var npc_counts = Global.get_difficulty_tier_npc_counts(hole)
		print("Hole %d: %s" % [hole + 1, npc_counts]) 