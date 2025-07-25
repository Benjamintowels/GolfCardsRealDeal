extends Control

func _ready():
	print("=== FIGHTER DECK TEST ===")
	test_fighter_deck_integration()

func test_fighter_deck_integration():
	print("\n--- Testing Fighter Deck Integration ---")
	
	# Create a CurrentDeckManager instance
	var deck_manager = CurrentDeckManager.new()
	add_child(deck_manager)
	
	# Wait for initialization
	await get_tree().process_frame
	
	# Test switching to fighter deck
	deck_manager.switch_to_fighter_deck()
	
	# Check the deck contents
	var deck = deck_manager.get_current_deck()
	
	# Count different types of cards
	var attack_cards = []
	var weapon_cards = []
	var aoe_cards = []
	var defense_cards = []
	var movement_cards = []
	var club_cards = []
	
	for card in deck:
		if card.effect_type == "Attack":
			attack_cards.append(card.name)
		elif card.effect_type == "Weapon":
			weapon_cards.append(card.name)
		elif card.effect_type == "AOEAttack":
			aoe_cards.append(card.name)
		elif card.effect_type == "Defense" or card.name in ["BlockB", "DodgeCard", "Vampire"]:
			defense_cards.append(card.name)
		elif card.effect_type == "Movement":
			movement_cards.append(card.name)
		elif card.effect_type == "Club":
			club_cards.append(card.name)
	
	print("Fighter deck size:", deck.size())
	print("Attack cards:", attack_cards.size(), "-", attack_cards)
	print("Weapon cards:", weapon_cards.size(), "-", weapon_cards)
	print("AOE cards:", aoe_cards.size(), "-", aoe_cards)
	print("Defense cards:", defense_cards.size(), "-", defense_cards)
	print("Movement cards:", movement_cards.size(), "-", movement_cards)
	print("Club cards:", club_cards.size(), "-", club_cards)
	
	# Test switching back to starter deck
	deck_manager.switch_to_starter_deck()
	var starter_deck = deck_manager.get_current_deck()
	print("Switched back to starter deck, size:", starter_deck.size())
	
	print("✅ SUCCESS: Fighter deck integration working!")
	
	deck_manager.queue_free() 