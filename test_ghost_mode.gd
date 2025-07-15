extends Node2D

# Test script for GhostMode card functionality

func _ready():
	print("=== GHOST MODE CARD TEST ===")
	test_ghost_mode_card()

func test_ghost_mode_card():
	"""Test the GhostMode card functionality"""
	print("Testing GhostMode card...")
	
	# Test 1: Check if card resource exists
	var ghost_mode_card = preload("res://Cards/GhostMode.tres")
	if ghost_mode_card:
		print("✓ GhostMode card resource loaded successfully")
		print("  - Name:", ghost_mode_card.name)
		print("  - Effect Type:", ghost_mode_card.effect_type)
		print("  - Effect Strength:", ghost_mode_card.effect_strength)
		print("  - Level:", ghost_mode_card.level)
		print("  - Max Level:", ghost_mode_card.max_level)
		print("  - Upgrade Cost:", ghost_mode_card.upgrade_cost)
		print("  - Price:", ghost_mode_card.price)
		print("  - Default Tier:", ghost_mode_card.default_tier)
	else:
		print("✗ Failed to load GhostMode card resource")
		return
	
	# Test 2: Check if sound file exists
	var sound_file = load("res://Sounds/CoolSound.mp3")
	if sound_file:
		print("✓ CoolSound.mp3 found")
	else:
		print("✗ CoolSound.mp3 not found - please add this sound file")
	
	# Test 3: Check if card image exists
	if ghost_mode_card.image:
		print("✓ GhostMode card image loaded")
	else:
		print("✗ GhostMode card image not found - please add GhostMode.png")
	
	print("=== GHOST MODE CARD TEST COMPLETE ===")
	print("Note: To test full functionality, run the game and use the GhostMode card in a real game scenario") 