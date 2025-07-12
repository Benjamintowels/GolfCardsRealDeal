extends Node2D

# Test script to demonstrate the tree variation system

func _ready():
	print("=== TREE VARIATION SYSTEM TEST ===")
	
	# Create TreeManager
	var TreeManager = preload("res://Obstacles/TreeManager.gd")
	var tree_manager = TreeManager.new()
	add_child(tree_manager)
	
	# Wait a frame for TreeManager to load variations
	await get_tree().process_frame
	
	# Test getting all variations
	var all_variations = tree_manager.get_all_tree_variations()
	print("Loaded", all_variations.size(), "tree variations:")
	for variation in all_variations:
		print("  -", variation.name, "(rarity:", variation.rarity, ")")
	
	# Test random selection
	print("\nTesting random tree selection:")
	for i in range(10):
		var random_tree = tree_manager.get_random_tree_data()
		if random_tree:
			print("  Random tree", i + 1, ":", random_tree.name)
		else:
			print("  Failed to get random tree")
	
	print("=== END TREE VARIATION SYSTEM TEST ===") 