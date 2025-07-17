extends Node2D

func _ready():
	print("=== DEBUG TEST START ===")
	print("Testing debug output...")
	
	# Test Pylon scene loading
	var pylon_scene = preload("res://Interactables/Pylon.tscn")
	if pylon_scene:
		print("✓ Pylon scene loaded successfully")
		
		var pylon = pylon_scene.instantiate()
		if pylon:
			print("✓ Pylon instantiated successfully")
			add_child(pylon)
			print("✓ Pylon added to scene")
			
			# Check if sprite is visible
			var sprite = pylon.get_node_or_null("PylonSprite")
			if sprite:
				print("✓ PylonSprite found")
				print("  - Position:", sprite.position)
				print("  - Visible:", sprite.visible)
				print("  - Texture:", sprite.texture)
			else:
				print("❌ PylonSprite not found")
		else:
			print("❌ Failed to instantiate Pylon")
	else:
		print("❌ Failed to load Pylon scene")
	
	print("=== DEBUG TEST END ===")
	
	# Quit after 2 seconds
	get_tree().create_timer(2.0).timeout.connect(func(): get_tree().quit()) 