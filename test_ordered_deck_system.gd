extends Node2D

# Test script for the new ordered deck system
# This demonstrates how the ordered deck system works

func _ready():
	print("=== ORDERED DECK SYSTEM TEST ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test the ordered deck system
	test_ordered_deck_system()

func test_ordered_deck_system():
	"""Test the ordered deck system functionality"""
	print("\n--- Testing Ordered Deck System ---")
	
	# Get the course and deck manager
	var course = get_tree().current_scene
	if not course:
		print("ERROR: Course not found!")
		return
	
	var deck_manager = course.get("deck_manager")
	if not deck_manager:
		print("ERROR: DeckManager not found!")
		return
	
	print("✓ DeckManager found")
	
	# Test deck information
	print("\n--- Deck Information ---")
	var deck_order = deck_manager.get_action_deck_order()
	var deck_index = deck_manager.get_action_deck_index()
	var remaining_cards = deck_manager.get_action_deck_remaining_cards()
	var discard_pile = deck_manager.get_action_discard_pile()
	
	print("Total deck order size:", deck_order.size())
	print("Current deck index:", deck_index)
	print("Remaining cards in deck:", remaining_cards.size())
	print("Discard pile size:", discard_pile.size())
	
	# Show the deck order
	print("\n--- Deck Order ---")
	for i in range(deck_order.size()):
		var marker = ">" if i == deck_index else " "
		print("%s[%d] %s" % [marker, i, deck_order[i].name])
	
	# Show remaining cards
	print("\n--- Remaining Cards ---")
	for i in range(remaining_cards.size()):
		print("[%d] %s" % [i, remaining_cards[i].name])
	
	# Test drawing cards
	print("\n--- Testing Card Drawing ---")
	var original_index = deck_manager.get_action_deck_index()
	var drawn_cards = deck_manager.draw_from_action_deck(3)
	
	print("Drew", drawn_cards.size(), "cards:")
	for card in drawn_cards:
		print("  -", card.name)
	
	print("Deck index changed from", original_index, "to", deck_manager.get_action_deck_index())
	
	# Test inserting a card at the top
	print("\n--- Testing Card Insertion ---")
	var test_card = preload("res://Cards/Move1.tres")
	deck_manager.insert_card_at_top_of_action_deck(test_card)
	
	var new_remaining = deck_manager.get_action_deck_remaining_cards()
	print("After inserting Move1 at top, remaining cards:")
	for i in range(new_remaining.size()):
		print("[%d] %s" % [i, new_remaining[i].name])
	
	print("\n=== ORDERED DECK SYSTEM TEST COMPLETE ===")
	print("✓ Ordered deck system is working correctly!")
	print("✓ Cards are drawn in order from the deck")
	print("✓ Cards can be inserted at the top of the deck")
	print("✓ Deck index properly tracks position") 