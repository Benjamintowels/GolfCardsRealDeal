extends Node2D

# Test script for Vampire card integration
# This verifies that the Vampire card is properly added to all systems

func _ready():
	print("=== VAMPIRE CARD INTEGRATION TEST ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test all integrations
	test_shop_integration()
	test_rewards_integration()
	test_starter_deck_integration()
	
	print("=== VAMPIRE INTEGRATION TEST COMPLETE ===")

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
	
	var has_vampire = false
	for card in temp_shop.available_cards:
		if card.name == "Vampire":
			has_vampire = true
			print("✓ Found Vampire card in shop")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	if has_vampire:
		print("✅ SUCCESS: Vampire is in the shop!")
	else:
		print("❌ ERROR: Vampire is missing from shop!")
	
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
	
	var has_vampire = false
	for card in temp_rewards.base_cards:
		if card.name == "Vampire":
			has_vampire = true
			print("✓ Found Vampire card in rewards")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	if has_vampire:
		print("✅ SUCCESS: Vampire is in the rewards system!")
	else:
		print("❌ ERROR: Vampire is missing from rewards system!")
	
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
	var has_vampire = false
	
	for card in deck:
		if card.name == "Vampire":
			has_vampire = true
			print("✓ Found Vampire card in starter deck")
			print("  - Price:", card.price)
			print("  - Tier:", card.default_tier)
			print("  - Effect Type:", card.effect_type)
			break
	
	print("Vampire in starter deck:", has_vampire)
	print("Starter deck size:", deck.size())
	
	if has_vampire:
		print("✅ SUCCESS: Vampire is in the starter deck!")
	else:
		print("❌ ERROR: Vampire is missing from starter deck!")
	
	deck_manager.queue_free()

func test_card_effect_handler():
	print("\n--- Testing Card Effect Handler ---")
	
	# Test if the Vampire effect type is handled
	var effect_handler = CardEffectHandler.new()
	
	# Create a test Vampire card
	var vampire_card = preload("res://Cards/Vampire.tres")
	
	# Test the effect handling
	var was_handled = effect_handler.handle_card_effect(vampire_card)
	
	if was_handled:
		print("✅ SUCCESS: Vampire effect type is handled by CardEffectHandler!")
	else:
		print("❌ ERROR: Vampire effect type is NOT handled by CardEffectHandler!")
	
	effect_handler.queue_free() 