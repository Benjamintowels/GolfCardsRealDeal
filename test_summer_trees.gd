extends Node2D

# Test script for SummerTree variations

func _ready():
	print("=== SUMMER TREE VARIATION TEST ===")
	
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
	
	# Test random selection multiple times
	print("\nTesting SummerTree random selection (10 times):")
	var summer_trees = ["SummerTree1", "SummerTree2", "SummerTree3"]
	var selection_count = {"SummerTree1": 0, "SummerTree2": 0, "SummerTree3": 0}
	
	for i in range(10):
		var random_tree = tree_manager.get_random_tree_data()
		if random_tree:
			print("  Random tree", i + 1, ":", random_tree.name)
			if random_tree.name in selection_count:
				selection_count[random_tree.name] += 1
		else:
			print("  Failed to get random tree")
	
	# Show distribution
	print("\nSelection distribution:")
	for tree_name in summer_trees:
		print("  ", tree_name, ":", selection_count[tree_name], "times")
	
	print("=== END SUMMER TREE VARIATION TEST ===") 