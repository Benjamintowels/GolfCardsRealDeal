extends Node2D

func _ready():
	print("=== TESTING CLOTHING REWARDS DISPLAY ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test the reward selection dialog
	test_reward_selection_dialog()

func test_reward_selection_dialog():
	"""Test that clothing items display properly in the reward selection dialog"""
	print("Testing reward selection dialog...")
	
	# Create a reward selection dialog
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	get_tree().current_scene.add_child(reward_dialog)
	
	# Show the reward selection
	reward_dialog.show_reward_selection()
	
	print("✓ Reward selection dialog created and shown")
	print("✓ Check that clothing items (Cape, Top Hat) display with proper scaling")
	print("✓ Clothing items should be larger than regular equipment (GolfShoes)")
	
	# Wait a few seconds then close
	await get_tree().create_timer(5.0).timeout
	reward_dialog.queue_free()
	
	print("=== CLOTHING REWARDS TEST COMPLETE ===") 