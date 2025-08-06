extends Node

# Test script to demonstrate the FileLevelManager progression system
# This can be attached to any scene to test the functionality

func _ready():
	print("=== Progression System Test ===")
	
	# Get the FileLevelManager
	var file_level_manager = get_node("/root/Main/FileLevelManager")
	if not file_level_manager:
		print("ERROR: FileLevelManager not found!")
		return
	
	print("FileLevelManager found!")
	
	# Test initial state
	var stats = file_level_manager.get_current_stats()
	print("Initial stats:")
	print("  Character Level: ", stats.character_level)
	print("  Character Experience: ", stats.character_experience)
	print("  Character Progress: ", stats.character_exp_progress * 100, "%")
	print("  ClubHouse Level: ", stats.clubhouse_level)
	print("  ClubHouse Experience: ", stats.clubhouse_experience)
	print("  ClubHouse Progress: ", stats.clubhouse_exp_progress * 100, "%")
	
	# Test completing some holes
	print("\n=== Testing Hole Completion ===")
	
	# Complete holes 1-8 (should give 10 exp each)
	for i in range(1, 9):
		file_level_manager.complete_hole(i)
		await get_tree().create_timer(0.1).timeout  # Small delay to see progression
	
	# Complete hole 9 (should give 40 exp)
	file_level_manager.complete_hole(9)
	await get_tree().create_timer(0.1).timeout
	
	# Complete holes 10-17 (should give 10 exp each)
	for i in range(10, 18):
		file_level_manager.complete_hole(i)
		await get_tree().create_timer(0.1).timeout
	
	# Complete hole 18 (should give 100 exp)
	file_level_manager.complete_hole(18)
	await get_tree().create_timer(0.1).timeout
	
	# Show final stats
	stats = file_level_manager.get_current_stats()
	print("\nFinal stats after completing all holes:")
	print("  Character Level: ", stats.character_level)
	print("  Character Experience: ", stats.character_experience)
	print("  Character Progress: ", stats.character_exp_progress * 100, "%")
	print("  ClubHouse Level: ", stats.clubhouse_level)
	print("  ClubHouse Experience: ", stats.clubhouse_experience)
	print("  ClubHouse Progress: ", stats.clubhouse_exp_progress * 100, "%")
	
	print("\n=== Test Complete ===")
	print("Expected results:")
	print("  - 8 holes (1-8): 8 * 10 = 80 exp")
	print("  - Hole 9: 40 exp")
	print("  - 8 holes (10-17): 8 * 10 = 80 exp")
	print("  - Hole 18: 100 exp")
	print("  - Total: 300 exp")
	print("  - Level 1 requires 100 exp, Level 2 requires 200 exp")
	print("  - Should reach Level 2 with 100 exp remaining for Level 3")

# Function to manually test progression from other scripts
func test_progression():
	_ready() 