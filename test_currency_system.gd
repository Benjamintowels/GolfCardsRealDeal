extends Node2D

# Test script for the $Looty currency system

func _ready():
	print("=== $LOOTY CURRENCY SYSTEM TEST ===")
	
	# Test 1: Check starting balance
	print("Test 1: Starting balance")
	print("Expected: 50 $Looty")
	print("Actual:", Global.get_looty(), "$Looty")
	assert(Global.get_looty() == 50, "Starting balance should be 50 $Looty")
	print("✅ Test 1 PASSED")
	
	# Test 2: Add currency
	print("\nTest 2: Adding currency")
	var initial_balance = Global.get_looty()
	Global.add_looty(25)
	var new_balance = Global.get_looty()
	print("Initial:", initial_balance, "$Looty")
	print("Added: 25 $Looty")
	print("New balance:", new_balance, "$Looty")
	assert(new_balance == initial_balance + 25, "Balance should increase by 25")
	print("✅ Test 2 PASSED")
	
	# Test 3: Spend currency
	print("\nTest 3: Spending currency")
	initial_balance = Global.get_looty()
	var success = Global.spend_looty(30)
	new_balance = Global.get_looty()
	print("Initial:", initial_balance, "$Looty")
	print("Spent: 30 $Looty")
	print("Success:", success)
	print("New balance:", new_balance, "$Looty")
	assert(success == true, "Should be able to spend 30 $Looty")
	assert(new_balance == initial_balance - 30, "Balance should decrease by 30")
	print("✅ Test 3 PASSED")
	
	# Test 4: Try to spend more than available
	print("\nTest 4: Spending more than available")
	initial_balance = Global.get_looty()
	success = Global.spend_looty(100)
	new_balance = Global.get_looty()
	print("Initial:", initial_balance, "$Looty")
	print("Tried to spend: 100 $Looty")
	print("Success:", success)
	print("New balance:", new_balance, "$Looty")
	assert(success == false, "Should not be able to spend more than available")
	assert(new_balance == initial_balance, "Balance should remain unchanged")
	print("✅ Test 4 PASSED")
	
	# Test 5: Check affordability
	print("\nTest 5: Checking affordability")
	var can_afford_10 = Global.can_afford(10)
	var can_afford_100 = Global.can_afford(100)
	print("Can afford 10 $Looty:", can_afford_10)
	print("Can afford 100 $Looty:", can_afford_100)
	assert(can_afford_10 == true, "Should be able to afford 10 $Looty")
	assert(can_afford_100 == false, "Should not be able to afford 100 $Looty")
	print("✅ Test 5 PASSED")
	
	# Test 6: Hole completion reward
	print("\nTest 6: Hole completion reward")
	initial_balance = Global.get_looty()
	var reward = Global.give_hole_completion_reward()
	new_balance = Global.get_looty()
	print("Initial:", initial_balance, "$Looty")
	print("Reward:", reward, "$Looty")
	print("New balance:", new_balance, "$Looty")
	assert(reward >= 5 and reward <= 50, "Reward should be between 5-50 $Looty")
	assert(new_balance == initial_balance + reward, "Balance should increase by reward amount")
	print("✅ Test 6 PASSED")
	
	# Test 7: Reset to starting amount
	print("\nTest 7: Reset to starting amount")
	Global.reset_looty_to_starting()
	var reset_balance = Global.get_looty()
	print("Reset balance:", reset_balance, "$Looty")
	assert(reset_balance == 50, "Reset balance should be 50 $Looty")
	print("✅ Test 7 PASSED")
	
	print("\n=== ALL TESTS PASSED ===")
	print("$Looty currency system is working correctly!")
	
	# Clean up
	queue_free() 