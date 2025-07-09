extends Node

# Test script to verify BlockB card integration

func _ready():
	print("=== TESTING BLOCKB CARD INTEGRATION ===")
	
	# Test 1: Check if BlockB is in rewards
	test_rewards_integration()
	
	# Test 2: Check if BlockB is in shop
	test_shop_integration()
	
	# Test 3: Check if BlockB is in starter deck
	test_starter_deck_integration()
	
	print("=== INTEGRATION TEST COMPLETE ===")
	
	# Quit after a short delay
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

func test_rewards_integration():
	print("\n--- Testing Rewards Integration ---")
	
	# Create a RewardSelectionDialog instance
	var reward_dialog = preload("res://RewardSelectionDialog.tscn").instantiate()
	add_child(reward_dialog)
	
	# Check if BlockB is in available_cards
	var has_blockb = false
	for card in reward_dialog.available_cards:
		if card.name == "BlockB":
			has_blockb = true
			break
	
	print("BlockB in rewards:", has_blockb)
	
	if has_blockb:
		print("✅ SUCCESS: BlockB is available in rewards!")
	else:
		print("❌ ERROR: BlockB is missing from rewards!")
	
	reward_dialog.queue_free()

func test_shop_integration():
	print("\n--- Testing Shop Integration ---")
	
	# Create a ShopInterior instance
	var shop_interior = preload("res://Shop/ShopInterior.tscn").instantiate()
	add_child(shop_interior)
	
	# Wait for shop to initialize
	await get_tree().process_frame
	
	# Check if BlockB is in available_cards
	var has_blockb = false
	for card in shop_interior.available_cards:
		if card.name == "BlockB":
			has_blockb = true
			break
	
	print("BlockB in shop:", has_blockb)
	
	if has_blockb:
		print("✅ SUCCESS: BlockB is available in shop!")
	else:
		print("❌ ERROR: BlockB is missing from shop!")
	
	shop_interior.queue_free()

func test_starter_deck_integration():
	print("\n--- Testing Starter Deck Integration ---")
	
	# Create a CurrentDeckManager instance
	var deck_manager = CurrentDeckManager.new()
	add_child(deck_manager)
	
	# Wait for initialization
	await get_tree().process_frame
	
	# Check the deck contents
	var deck = deck_manager.get_current_deck()
	var has_blockb = false
	
	for card in deck:
		if card.name == "BlockB":
			has_blockb = true
			break
	
	print("BlockB in starter deck:", has_blockb)
	print("Starter deck size:", deck.size())
	
	if has_blockb:
		print("✅ SUCCESS: BlockB is in the starter deck!")
	else:
		print("❌ ERROR: BlockB is missing from starter deck!")
	
	deck_manager.queue_free() 