extends Node2D

# Test script for Dodge card system
# This verifies that the Dodge card is properly added to all systems

func _ready():
	print("=== DODGE CARD SYSTEM TEST ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test all integrations
	test_shop_integration()
	test_rewards_integration()
	test_starter_deck_integration()
	test_card_effect_handler()
	
	print("=== DODGE SYSTEM TEST COMPLETE ===")

func test_shop_integration():
	print("\n--- Testing Shop Integration ---")
	
	# Load the shop script to check available cards
	var shop_script = load("res://Shop/ShopInterior.gd")
	if not shop_script:
		print("❌ ERROR: ShopInterior.gd not found!")
		return
	
	# Create a temporary instance to access the available_cards
	var temp_shop = shop_script.new()
	temp_shop.load_shop_items()
	
	var has_dodge = false
	for card in temp_shop.available_cards:
		if card.name == "DodgeCard":
			has_dodge = true
			print("✓ Found DodgeCard in shop")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	if has_dodge:
		print("✅ SUCCESS: DodgeCard is in the shop!")
	else:
		print("❌ ERROR: DodgeCard is missing from shop!")
	
	temp_shop.queue_free()

func test_rewards_integration():
	print("\n--- Testing Rewards Integration ---")
	
	# Load the rewards script to check available cards
	var rewards_script = load("res://RewardSelectionDialog.gd")
	if not rewards_script:
		print("❌ ERROR: RewardSelectionDialog.gd not found!")
		return
	
	# Create a temporary instance to access the base_cards
	var temp_rewards = rewards_script.new()
	
	var has_dodge = false
	for card in temp_rewards.base_cards:
		if card.name == "DodgeCard":
			has_dodge = true
			print("✓ Found DodgeCard in rewards")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	if has_dodge:
		print("✅ SUCCESS: DodgeCard is in the rewards system!")
	else:
		print("❌ ERROR: DodgeCard is missing from rewards system!")
	
	temp_rewards.queue_free()

func test_starter_deck_integration():
	print("\n--- Testing Starter Deck Integration ---")
	
	# Create a CurrentDeckManager instance
	var deck_manager = CurrentDeckManager.new()
	add_child(deck_manager)
	
	# Wait for initialization
	await get_tree().process_frame
	
	# Check the deck contents
	var deck = deck_manager.get_current_deck()
	var has_dodge = false
	
	for card in deck:
		if card.name == "DodgeCard":
			has_dodge = true
			print("✓ Found DodgeCard in starter deck")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	print("DodgeCard in starter deck:", has_dodge)
	print("Starter deck size:", deck.size())
	
	if has_dodge:
		print("✅ SUCCESS: DodgeCard is in the starter deck!")
	else:
		print("❌ ERROR: DodgeCard is missing from starter deck!")
	
	deck_manager.queue_free()

func test_card_effect_handler():
	print("\n--- Testing Card Effect Handler ---")
	
	# Test if the Dodge effect type is handled
	var effect_handler = CardEffectHandler.new()
	
	# Create a test DodgeCard
	var dodge_card = preload("res://Cards/DodgeCard.tres")
	
	# Test the effect handling
	var was_handled = effect_handler.handle_card_effect(dodge_card)
	
	if was_handled:
		print("✅ SUCCESS: Dodge effect type is handled by CardEffectHandler!")
	else:
		print("❌ ERROR: Dodge effect type is NOT handled by CardEffectHandler!")
	
	effect_handler.queue_free()

func test_dodge_card_properties():
	print("\n--- Testing DodgeCard Properties ---")
	
	# Load the DodgeCard resource
	var dodge_card = preload("res://Cards/DodgeCard.tres")
	
	if dodge_card:
		print("✓ DodgeCard resource loaded successfully")
		print("  - Name:", dodge_card.name)
		print("  - Effect Type:", dodge_card.effect_type)
		print("  - Effect Strength:", dodge_card.effect_strength)
		print("  - Level:", dodge_card.level)
		print("  - Max Level:", dodge_card.max_level)
		print("  - Price:", dodge_card.price)
		print("  - Default Tier:", dodge_card.default_tier)
		
		# Verify the card has the correct properties
		if dodge_card.name == "DodgeCard" and dodge_card.effect_type == "Dodge":
			print("✅ SUCCESS: DodgeCard has correct properties!")
		else:
			print("❌ ERROR: DodgeCard has incorrect properties!")
	else:
		print("❌ ERROR: Could not load DodgeCard resource!")

func test_benny_sprites():
	print("\n--- Testing Benny Dodge Sprites ---")
	
	# Check if the BennyChar scene has the required sprites
	var benny_scene = load("res://Characters/BennyChar.tscn")
	if benny_scene:
		var benny_instance = benny_scene.instantiate()
		add_child(benny_instance)
		
		# Check for BennyDodge sprite
		var dodge_sprite = benny_instance.get_node_or_null("BennyDodge")
		if dodge_sprite:
			print("✓ Found BennyDodge sprite")
		else:
			print("❌ ERROR: BennyDodge sprite not found!")
		
		# Check for BennyDodgeReady sprite
		var dodge_ready_sprite = benny_instance.get_node_or_null("BennyDodgeReady")
		if dodge_ready_sprite:
			print("✓ Found BennyDodgeReady sprite")
		else:
			print("❌ ERROR: BennyDodgeReady sprite not found!")
		
		benny_instance.queue_free()
	else:
		print("❌ ERROR: Could not load BennyChar scene!")

func test_player1_sound():
	print("\n--- Testing Player1 Dodge Sound ---")
	
	# Check if the Player1 scene has the Dodge sound
	var player1_scene = load("res://Characters/Player1.tscn")
	if player1_scene:
		var player1_instance = player1_scene.instantiate()
		add_child(player1_instance)
		
		# Check for Dodge AudioStreamPlayer2D
		var dodge_sound = player1_instance.get_node_or_null("Dodge")
		if dodge_sound and dodge_sound is AudioStreamPlayer2D:
			print("✓ Found Dodge AudioStreamPlayer2D")
			if dodge_sound.stream:
				print("✓ Dodge sound stream is loaded")
			else:
				print("❌ ERROR: Dodge sound stream is not loaded!")
		else:
			print("❌ ERROR: Dodge AudioStreamPlayer2D not found!")
		
		player1_instance.queue_free()
	else:
		print("❌ ERROR: Could not load Player1 scene!") 