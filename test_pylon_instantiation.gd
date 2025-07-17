extends Node2D

func _ready():
	print("=== TESTING PYLON INSTANTIATION ===")
	
	# Try to load the Pylon scene
	var pylon_scene = preload("res://Interactables/Pylon.tscn")
	if pylon_scene == null:
		print("❌ Failed to preload Pylon scene")
		return
	
	print("✓ Pylon scene preloaded successfully")
	
	# Try to instantiate the Pylon
	var pylon = pylon_scene.instantiate()
	if pylon == null:
		print("❌ Failed to instantiate Pylon")
		return
	
	print("✓ Pylon instantiated successfully")
	print("  - Pylon name:", pylon.name)
	print("  - Pylon script:", pylon.get_script())
	
	# Add to scene
	add_child(pylon)
	print("✓ Pylon added to scene")
	
	# Check if sprite exists
	var sprite = pylon.get_node_or_null("PylonSprite")
	if sprite:
		print("✓ PylonSprite found")
		print("  - Texture:", sprite.texture)
		print("  - Visible:", sprite.visible)
	else:
		print("❌ PylonSprite not found")
	
	print("=== PYLON TEST COMPLETE ===") 