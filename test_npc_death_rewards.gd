extends Node

# Test script for NPC death rewards
# Tests the $Looty reward system when killing different NPC types

func _ready():
	print("=== NPC DEATH REWARDS TEST ===")
	
	# Reset to starting balance
	Global.reset_looty_to_starting()
	var initial_balance = Global.get_looty()
	print("Initial balance:", initial_balance, "$Looty")
	
	# Test Zombie death reward (should give 10 $Looty)
	print("\n--- Testing Zombie Death Reward ---")
	var zombie_reward = Global.give_npc_death_reward("ZombieGolfer")
	var balance_after_zombie = Global.get_looty()
	print("Zombie reward:", zombie_reward, "$Looty")
	print("Balance after zombie:", balance_after_zombie, "$Looty")
	assert(zombie_reward == 10, "Zombie should give 10 $Looty")
	assert(balance_after_zombie == initial_balance + 10, "Balance should increase by 10")
	
	# Test GangMember death reward (should give 25 $Looty)
	print("\n--- Testing GangMember Death Reward ---")
	var gang_reward = Global.give_npc_death_reward("GangMember")
	var balance_after_gang = Global.get_looty()
	print("GangMember reward:", gang_reward, "$Looty")
	print("Balance after gang member:", balance_after_gang, "$Looty")
	assert(gang_reward == 25, "GangMember should give 25 $Looty")
	assert(balance_after_gang == balance_after_zombie + 25, "Balance should increase by 25")
	
	# Test Police death reward (should give 50 $Looty)
	print("\n--- Testing Police Death Reward ---")
	var police_reward = Global.give_npc_death_reward("Police")
	var balance_after_police = Global.get_looty()
	print("Police reward:", police_reward, "$Looty")
	print("Balance after police:", balance_after_police, "$Looty")
	assert(police_reward == 50, "Police should give 50 $Looty")
	assert(balance_after_police == balance_after_gang + 50, "Balance should increase by 50")
	
	# Test Squirrel death reward (should give 0 $Looty)
	print("\n--- Testing Squirrel Death Reward ---")
	var squirrel_reward = Global.give_npc_death_reward("Squirrel")
	var balance_after_squirrel = Global.get_looty()
	print("Squirrel reward:", squirrel_reward, "$Looty")
	print("Balance after squirrel:", balance_after_squirrel, "$Looty")
	assert(squirrel_reward == 0, "Squirrel should give 0 $Looty")
	assert(balance_after_squirrel == balance_after_police, "Balance should not change")
	
	# Test unknown NPC type (should give 0 $Looty)
	print("\n--- Testing Unknown NPC Type ---")
	var unknown_reward = Global.give_npc_death_reward("UnknownNPC")
	var balance_after_unknown = Global.get_looty()
	print("Unknown NPC reward:", unknown_reward, "$Looty")
	print("Balance after unknown NPC:", balance_after_unknown, "$Looty")
	assert(unknown_reward == 0, "Unknown NPC should give 0 $Looty")
	assert(balance_after_unknown == balance_after_squirrel, "Balance should not change")
	
	# Test case insensitivity
	print("\n--- Testing Case Insensitivity ---")
	var case_reward = Global.give_npc_death_reward("zombiegolfer")
	print("Lowercase zombie reward:", case_reward, "$Looty")
	assert(case_reward == 10, "Lowercase should still give 10 $Looty")
	
	print("\n=== ALL NPC DEATH REWARD TESTS PASSED! ===")
	print("Final balance:", Global.get_looty(), "$Looty")
	print("Total rewards earned:", Global.get_looty() - initial_balance, "$Looty") 