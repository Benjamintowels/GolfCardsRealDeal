extends Node

# Simple test script to verify background layers integration
func _ready():
	print("Testing background layers integration...")
	
	# Test the BackgroundManager with existing layers
	var background_manager = BackgroundManager.new()
	add_child(background_manager)
	
	# Create a mock BackgroundLayers node with sprites
	var background_layers = Node2D.new()
	background_layers.name = "BackgroundLayers"
	add_child(background_layers)
	
	# Create test sprites
	var test_sprites = ["Sky", "Horizon", "Mountains", "Clouds", "DistantHill", "City", "Hill", "TreeLine3", "Foreground", "TreeLine2", "TreeLine1"]
	
	for sprite_name in test_sprites:
		var sprite = Sprite2D.new()
		sprite.name = sprite_name
		background_layers.add_child(sprite)
		print("Created test sprite: ", sprite_name)
	
	# Test the integration
	background_manager.set_use_existing_layers(true, background_layers)
	background_manager.set_theme("driving_range")
	
	print("✓ Background layers test completed")
	
	# Clean up after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): get_tree().quit()) 