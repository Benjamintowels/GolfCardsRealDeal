extends Node2D

# Test script to demonstrate the GrassData system

func _ready():
	print("=== GRASS DATA SYSTEM TEST ===")
	
	# Create GrassManager
	var GrassManager = preload("res://Obstacles/GrassManager.gd")
	var grass_manager = GrassManager.new()
	add_child(grass_manager)
	
	# Wait a frame for GrassManager to load variations
	await get_tree().process_frame
	
	# Test getting all variations
	var all_variations = grass_manager.get_all_grass_variations()
	print("Loaded", all_variations.size(), "grass variations:")
	for variation in all_variations:
		print("  -", variation.name, "(rarity:", variation.rarity, ", height:", variation.height, ")")
	
	# Test random selection
	print("\nTesting random grass selection:")
	for i in range(10):
		var random_grass = grass_manager.get_random_grass_data()
		if random_grass:
			print("  Random grass", i + 1, ":", random_grass.name)
		else:
			print("  Failed to get random grass")
	
	# Test seasonal variations
	print("\nTesting seasonal grass selection:")
	var summer_grass = grass_manager.get_grass_variations_by_season("summer")
	print("Summer grass variations:", summer_grass.size())
	for grass in summer_grass:
		print("  -", grass.name)
	
	# Test specific grass by name
	print("\nTesting specific grass lookup:")
	var grass1 = grass_manager.get_grass_variation_by_name("SummerGrass1")
	if grass1:
		print("  Found SummerGrass1:", grass1.description)
	else:
		print("  SummerGrass1 not found")
	
	print("=== END GRASS DATA SYSTEM TEST ===") 