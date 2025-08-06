extends Node

# Test script to verify the progression system integration
# This can be run from any scene to test the complete integration

func _ready():
	print("=== Testing Progression System Integration ===")
	
	# Test 1: Check if FileLevelManager is accessible
	var file_level_manager = get_node("/root/Main/FileLevelManager")
	if not file_level_manager:
		print("❌ ERROR: FileLevelManager not found!")
		return
	print("✅ FileLevelManager found")
	
	# Test 2: Check if Main scene has the required methods
	var main_scene = get_node("/root/Main")
	if not main_scene:
		print("❌ ERROR: Main scene not found!")
		return
	print("✅ Main scene found")
	
	if not main_scene.has_method("show_final_score_display"):
		print("❌ ERROR: Main scene missing show_final_score_display method!")
		return
	print("✅ Main scene has show_final_score_display method")
	
	if not main_scene.has_method("complete_hole"):
		print("❌ ERROR: Main scene missing complete_hole method!")
		return
	print("✅ Main scene has complete_hole method")
	
	# Test 3: Check if UI elements exist
	var clubhouse_level_label = main_scene.get_node_or_null("UI/ClubHouseLevelLabel")
	if not clubhouse_level_label:
		print("❌ ERROR: ClubHouseLevelLabel not found!")
		return
	print("✅ ClubHouseLevelLabel found")
	
	var character_stat_banner = main_scene.get_node_or_null("CharacterStatBanner")
	if not character_stat_banner:
		print("❌ ERROR: CharacterStatBanner not found!")
		return
	print("✅ CharacterStatBanner found")
	
	var final_score_display = main_scene.get_node_or_null("FinalScoreDisplay")
	if not final_score_display:
		print("❌ ERROR: FinalScoreDisplay not found!")
		return
	print("✅ FinalScoreDisplay found")
	
	# Test 4: Check initial state
	var stats = file_level_manager.get_current_stats()
	print("Initial state:")
	print("  Character Level: ", stats.character_level)
	print("  ClubHouse Level: ", stats.clubhouse_level)
	print("  ClubHouse Level Label: ", clubhouse_level_label.text)
	
	# Test 5: Simulate hole completions
	print("\n=== Simulating Hole Completions ===")
	
	# Complete holes 1-5 (should give 10 exp each)
	for i in range(1, 6):
		file_level_manager.complete_hole(i)
		await get_tree().create_timer(0.2).timeout
		print("Completed hole ", i)
	
	# Check state after 5 holes (should still be level 1)
	stats = file_level_manager.get_current_stats()
	print("\nAfter 5 holes:")
	print("  Character Level: ", stats.character_level)
	print("  ClubHouse Level: ", stats.clubhouse_level)
	print("  ClubHouse Level Label: ", clubhouse_level_label.text)
	
	# Complete holes 6-10 (should reach level 2)
	for i in range(6, 11):
		file_level_manager.complete_hole(i)
		await get_tree().create_timer(0.2).timeout
		print("Completed hole ", i)
	
	# Check state after 10 holes (should be level 2)
	stats = file_level_manager.get_current_stats()
	print("\nAfter 10 holes:")
	print("  Character Level: ", stats.character_level)
	print("  ClubHouse Level: ", stats.clubhouse_level)
	print("  ClubHouse Level Label: ", clubhouse_level_label.text)
	
	# Test 6: Test final score display
	print("\n=== Testing Final Score Display ===")
	main_scene.show_final_score_display()
	await get_tree().create_timer(2.0).timeout
	
	# Hide the final score display
	if final_score_display:
		final_score_display.hide()
	
	print("\n=== Integration Test Complete ===")
	print("Expected results:")
	print("  - After 5 holes: Level 1 (50/100 exp)")
	print("  - After 10 holes: Level 2 (0/200 exp)")
	print("  - UI labels should update automatically")
	print("  - Final score display should show current progression")

# Function to run the test from other scripts
func run_integration_test():
	_ready() 