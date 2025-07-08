extends Node2D

# Test script for freeze turn skip logic
# This tests the has_active_npcs() function logic

func _ready():
	print("=== FREEZE TURN SKIP TEST ===")
	print("Testing the logic for skipping World Turn when all NPCs are frozen")
	
	# Test different scenarios
	test_scenario_1()
	test_scenario_2()
	test_scenario_3()
	test_scenario_4()

func test_scenario_1():
	"""Test: No NPCs - should skip World Turn"""
	print("\n--- Scenario 1: No NPCs ---")
	var mock_npcs = []
	var result = test_has_active_npcs(mock_npcs)
	print("Result: ", result, " (Expected: false - should skip World Turn)")

func test_scenario_2():
	"""Test: All NPCs dead - should skip World Turn"""
	print("\n--- Scenario 2: All NPCs dead ---")
	var mock_npcs = [
		{"alive": false, "frozen": false, "turns_remaining": 0},
		{"alive": false, "frozen": false, "turns_remaining": 0}
	]
	var result = test_has_active_npcs(mock_npcs)
	print("Result: ", result, " (Expected: false - should skip World Turn)")

func test_scenario_3():
	"""Test: All alive NPCs frozen and won't thaw - should skip World Turn"""
	print("\n--- Scenario 3: All alive NPCs frozen and won't thaw ---")
	var mock_npcs = [
		{"alive": true, "frozen": true, "turns_remaining": 3},
		{"alive": true, "frozen": true, "turns_remaining": 2}
	]
	var result = test_has_active_npcs(mock_npcs)
	print("Result: ", result, " (Expected: false - should skip World Turn)")

func test_scenario_4():
	"""Test: Some NPCs active - should NOT skip World Turn"""
	print("\n--- Scenario 4: Some NPCs active ---")
	var mock_npcs = [
		{"alive": true, "frozen": true, "turns_remaining": 3},  # Frozen, won't thaw
		{"alive": true, "frozen": false, "turns_remaining": 0}, # Not frozen
		{"alive": true, "frozen": true, "turns_remaining": 1}   # Frozen, will thaw
	]
	var result = test_has_active_npcs(mock_npcs)
	print("Result: ", result, " (Expected: true - should NOT skip World Turn)")

func test_has_active_npcs(mock_npcs: Array) -> bool:
	"""Test implementation of has_active_npcs logic"""
	print("Checking ", mock_npcs.size(), " NPCs...")
	
	for i in range(mock_npcs.size()):
		var npc = mock_npcs[i]
		print("  NPC ", i, ": alive=", npc.alive, ", frozen=", npc.frozen, ", turns_remaining=", npc.turns_remaining)
		
		if not npc.alive:
			print("    -> Dead, skipping")
			continue
		
		var will_thaw_this_turn = npc.frozen and npc.turns_remaining <= 1
		
		if not npc.frozen or will_thaw_this_turn:
			print("    -> Active (not frozen or will thaw this turn)")
			return true
		else:
			print("    -> Frozen and won't thaw this turn, skipping")
	
	print("  -> No active NPCs found")
	return false 