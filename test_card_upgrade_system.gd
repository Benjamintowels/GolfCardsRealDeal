extends Node

# Test script for the card upgrade system
func _ready():
	print("=== Testing Card Upgrade System ===")
	
	# Test 1: Basic card upgrade functionality
	test_basic_upgrade()
	
	# Test 2: Movement card upgrade
	test_movement_upgrade()
	
	# Test 3: Attack card upgrade
	test_attack_upgrade()
	
	# Test 4: Weapon card upgrade
	test_weapon_upgrade()
	
	# Test 5: Modify card upgrade
	test_modify_upgrade()
	
	print("=== Card Upgrade System Tests Complete ===")

func test_basic_upgrade():
	print("\n--- Test 1: Basic Card Upgrade ---")
	
	# Load a test card
	var card = preload("res://Cards/Move2.tres")
	print("Original card:", card.name, "Level:", card.level, "Strength:", card.effect_strength)
	
	# Test upgrade
	card.level = 2
	print("Upgraded card:", card.get_upgraded_name(), "Level:", card.level, "Effective Strength:", card.get_effective_strength())
	print("Can upgrade:", card.can_upgrade())
	print("Is upgraded:", card.is_upgraded())
	print("Upgrade description:", card.get_upgrade_description())

func test_movement_upgrade():
	print("\n--- Test 2: Movement Card Upgrade ---")
	
	var card = preload("res://Cards/Move2.tres")
	print("Original Move2 - Range:", card.effect_strength)
	
	card.level = 2
	print("Upgraded Move2 - Effective Range:", card.get_effective_strength())
	print("Should be 3 (2 + 1 bonus)")

func test_attack_upgrade():
	print("\n--- Test 3: Attack Card Upgrade ---")
	
	var card = preload("res://Cards/KickB.tres")
	print("Original Kick - Range:", card.effect_strength)
	
	card.level = 2
	print("Upgraded Kick - Effective Range:", card.get_effective_strength())
	print("Should be 2 (1 + 1 bonus)")

func test_weapon_upgrade():
	print("\n--- Test 4: Weapon Card Upgrade ---")
	
	var card = preload("res://Cards/BurstShot.tres")
	print("Original BurstShot - Shots:", card.effect_strength)
	
	card.level = 2
	print("Upgraded BurstShot - Effective Shots:", card.get_effective_strength())
	print("Should be 10 (5 + 5 bonus)")

func test_modify_upgrade():
	print("\n--- Test 5: Modify Card Upgrade ---")
	
	var card = preload("res://Cards/CoffeeCard.tres")
	print("Original CoffeeCard - Extra Turns:", card.effect_strength)
	
	card.level = 2
	print("Upgraded CoffeeCard - Effective Extra Turns:", card.get_effective_strength())
	print("Should be 2 (1 + 1 bonus)")
	
	var draw_card = preload("res://Cards/Draw2.tres")
	print("Original Draw2 - Cards Drawn:", draw_card.effect_strength)
	
	draw_card.level = 2
	print("Upgraded Draw2 - Effective Cards Drawn:", draw_card.get_effective_strength())
	print("Should be 3 (2 + 1 bonus)") 