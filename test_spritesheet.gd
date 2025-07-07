extends Node2D

func _ready():
	print("=== TESTING SPRITESHEET LOADING ===")
	
	# Test loading the spritesheet
	var spritesheet = load("res://Characters/Swingserererer2.png")
	if spritesheet:
		print("✓ Successfully loaded Swingserererer2.png")
		print("Spritesheet size:", spritesheet.get_size())
		print("Spritesheet type:", spritesheet.get_class())
	else:
		print("✗ Failed to load Swingserererer2.png")
	
	# Test creating AtlasTexture
	if spritesheet:
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = spritesheet
		atlas_texture.region = Rect2(0, 0, 100, 100)  # Test region
		print("✓ Successfully created AtlasTexture")
		print("AtlasTexture region:", atlas_texture.region)
	else:
		print("✗ Cannot create AtlasTexture without spritesheet")
	
	print("=== SPRITESHEET TEST COMPLETE ===") 