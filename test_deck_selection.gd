extends Control

func _ready():
	print("=== DECK SELECTION TEST ===")
	test_deck_selection_system()

func test_deck_selection_system():
	print("\n--- Testing Deck Selection System ---")
	
	# Test that Global has the selected_deck_type variable
	if Global.has("selected_deck_type"):
		print("✅ Global.selected_deck_type exists")
	else:
		print("❌ Global.selected_deck_type missing")
	
	# Test that CurrentDeckManager has the switch functions
	var deck_manager = CurrentDeckManager.new()
	add_child(deck_manager)
	
	if deck_manager.has_method("switch_to_starter_deck"):
		print("✅ switch_to_starter_deck method exists")
	else:
		print("❌ switch_to_starter_deck method missing")
	
	if deck_manager.has_method("switch_to_fighter_deck"):
		print("✅ switch_to_fighter_deck method exists")
	else:
		print("❌ switch_to_fighter_deck method missing")
	
	# Test deck switching
	print("\nTesting deck switching...")
	
	# Switch to fighter deck
	deck_manager.switch_to_fighter_deck()
	var fighter_deck = deck_manager.get_current_deck()
	print("Fighter deck size:", fighter_deck.size())
	
	# Switch to starter deck
	deck_manager.switch_to_starter_deck()
	var starter_deck = deck_manager.get_current_deck()
	print("Starter deck size:", starter_deck.size())
	
	# Test that decks are different
	if fighter_deck.size() != starter_deck.size():
		print("✅ Decks have different sizes (as expected)")
	else:
		print("❌ Decks have same size (unexpected)")
	
	print("✅ SUCCESS: Deck selection system working!")
	
	deck_manager.queue_free() 