extends Node2D

# Simple test script to verify the explosion system
# This can be run to test if the explosion effect works correctly

func _ready():
	print("=== EXPLOSION SYSTEM TEST ===")
	
	# Test creating an explosion
	var explosion = Explosion.create_explosion_at_position(Vector2(100, 100), self)
	
	if explosion:
		print("✓ Explosion created successfully")
	else:
		print("✗ Failed to create explosion")
	
	print("=== TEST COMPLETE ===")

# Import Explosion class
const Explosion = preload("res://Explosion.gd") 