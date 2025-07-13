extends Control

func _ready():
	# Test the score-based reward system
	test_score_based_rewards()

func test_score_based_rewards():
	print("=== TESTING SCORE-BASED REWARDS ===")
	
	# Test different score scenarios
	var test_cases = [
		{"score": 1, "par": 3, "description": "Eagle (-2)"},
		{"score": 2, "par": 3, "description": "Birdie (-1)"},
		{"score": 3, "par": 3, "description": "Par (0)"},
		{"score": 4, "par": 3, "description": "Bogey (+1)"},
		{"score": 5, "par": 3, "description": "Double Bogey (+2)"},
		{"score": 6, "par": 3, "description": "Triple Bogey (+3)"},
		{"score": 1, "par": 4, "description": "Double Eagle (-3)"},
		{"score": 2, "par": 4, "description": "Eagle (-2)"},
		{"score": 3, "par": 4, "description": "Birdie (-1)"},
		{"score": 4, "par": 4, "description": "Par (0)"},
		{"score": 5, "par": 4, "description": "Bogey (+1)"},
	]
	
	for test_case in test_cases:
		var score = test_case["score"]
		var par = test_case["par"]
		var description = test_case["description"]
		
		var probabilities = Global.get_score_based_tier_probabilities(score, par)
		var score_vs_par = score - par
		
		print("\n%s (Score: %d, Par: %d, vs Par: %+d)" % [description, score, par, score_vs_par])
		print("  Tier 1: %.1f%%" % (probabilities["tier_1"] * 100))
		print("  Tier 2: %.1f%%" % (probabilities["tier_2"] * 100))
		print("  Tier 3: %.1f%%" % (probabilities["tier_3"] * 100))
	
	print("\n=== END TESTING SCORE-BASED REWARDS ===")
	
	# Test the reward selection dialog
	test_reward_dialog()

func test_reward_dialog():
	print("\n=== TESTING REWARD DIALOG ===")
	
	# Create a reward dialog instance
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	add_child(reward_dialog)
	
	# Test with different scores
	var test_scores = [
		{"score": 1, "par": 3, "description": "Eagle"},
		{"score": 3, "par": 3, "description": "Par"},
		{"score": 5, "par": 3, "description": "Double Bogey"},
	]
	
	for test_case in test_scores:
		print("\nTesting %s (Score: %d, Par: %d):" % [test_case["description"], test_case["score"], test_case["par"]])
		
		# Show the reward selection with score-based probabilities
		reward_dialog.show_score_based_reward_selection(test_case["score"], test_case["par"])
		
		# Wait a moment to see the results
		await get_tree().create_timer(0.1).timeout
	
	# Clean up
	reward_dialog.queue_free()
	print("=== END TESTING REWARD DIALOG ===") 