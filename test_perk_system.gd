extends Node

# Test script for the perk system
# Run this to test the PerkReceiver and PerkDeployer functionality

func _ready():
	print("=== PERK SYSTEM TEST ===")
	
	# Test 1: Store a perk in PerkReceiver
	print("\nTest 1: Storing perk in PerkReceiver")
	PerkReceiver.store_perk("start_with_200_looty")
	print("Perk stored successfully")
	
	# Test 2: Check if perk is pending
	print("\nTest 2: Checking if perk is pending")
	var has_pending = PerkReceiver.has_pending_perk()
	print("Has pending perk:", has_pending)
	assert(has_pending == true, "Should have a pending perk")
	
	# Test 3: Retrieve the perk
	print("\nTest 3: Retrieving the perk")
	var perk_type = PerkReceiver.get_stored_perk()
	print("Retrieved perk:", perk_type)
	assert(perk_type == "start_with_200_looty", "Should retrieve the correct perk type")
	
	# Test 4: Check that perk is no longer pending
	print("\nTest 4: Checking that perk is no longer pending")
	has_pending = PerkReceiver.has_pending_perk()
	print("Has pending perk:", has_pending)
	assert(has_pending == false, "Should no longer have a pending perk")
	
	# Test 5: Test clearing perk
	print("\nTest 5: Testing clear perk")
	PerkReceiver.store_perk("random_club_card")
	PerkReceiver.clear_perk()
	has_pending = PerkReceiver.has_pending_perk()
	print("Has pending perk after clear:", has_pending)
	assert(has_pending == false, "Should not have pending perk after clear")
	
	print("\n=== PERK SYSTEM TEST COMPLETE ===")
	print("All tests passed! The perk system is working correctly.")
	
	# Clean up
	queue_free() 