extends Node2D

# Test script to verify grass integration with build map system

func _ready():
	print("=== GRASS INTEGRATION TEST ===")
	
	# Test 1: Check if GrassManager can be created
	var GrassManager = preload("res://Obstacles/GrassManager.gd")
	var grass_manager = GrassManager.new()
	add_child(grass_manager)
	
	# Wait a frame for GrassManager to load variations
	await get_tree().process_frame
	
	# Test 2: Check if grass variations are loaded
	var all_variations = grass_manager.get_all_grass_variations()
	print("✓ Loaded", all_variations.size(), "grass variations")
	for variation in all_variations:
		print("  -", variation.name, "(rarity:", variation.rarity, ")")
	
	# Test 3: Check if grass scene can be loaded
	var grass_scene = preload("res://Obstacles/GrassVariations/SummerGrass.tscn")
	if grass_scene:
		print("✓ Grass scene loaded successfully")
		
		# Test 4: Check if grass can be instantiated
		var grass = grass_scene.instantiate()
		if grass:
			print("✓ Grass instantiated successfully")
			print("✓ Grass script attached:", grass.get_script() != null)
			
			# Test 5: Check if grass has required methods
			if grass.has_method("set_grass_data"):
				print("✓ Grass has set_grass_data method")
			else:
				print("✗ Grass missing set_grass_data method")
			
			if grass.has_method("get_height"):
				print("✓ Grass has get_height method")
			else:
				print("✗ Grass missing get_height method")
			
			# Test 6: Check if grass has required nodes
			var grass_sprite = grass.get_node_or_null("GrassSprite")
			if grass_sprite:
				print("✓ Grass has GrassSprite node")
			else:
				print("✗ Grass missing GrassSprite node")
			
			var top_height = grass.get_node_or_null("TopHeight")
			if top_height:
				print("✓ Grass has TopHeight marker")
			else:
				print("✗ Grass missing TopHeight marker")
			
			var ysort_point = grass.get_node_or_null("YsortPoint")
			if ysort_point:
				print("✓ Grass has YsortPoint marker")
			else:
				print("✗ Grass missing YsortPoint marker")
			
			# Test 7: Test grass data application
			var grass_data = grass_manager.get_random_grass_data()
			if grass_data:
				print("✓ Got random grass data:", grass_data.name)
				grass.set_grass_data(grass_data)
				print("✓ Applied grass data to grass element")
			else:
				print("✗ Failed to get random grass data")
			
			grass.queue_free()
		else:
			print("✗ Grass instantiation failed")
	else:
		print("✗ Grass scene loading failed")
	
	# Test 8: Check if grass is in object_scene_map (course_1.gd)
	print("\n=== OBJECT SCENE MAP TEST ===")
	print("Note: This test assumes course_1.gd has been updated with GRASS mapping")
	print("To verify, check that course_1.gd contains:")
	print("  'GRASS': preload('res://Obstacles/GrassVariations/SummerGrass.tscn')")
	print("  'GRASS': 'Base' in object_to_tile_mapping")
	
	print("=== END GRASS INTEGRATION TEST ===") 