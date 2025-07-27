extends Node2D

# Test script for deck labels functionality
# This script can be attached to a test scene to verify the deck labels work

func _ready():
	print("=== DECK LABELS TEST ===")
	
	# Wait a moment for everything to load
	await get_tree().process_frame
	
	# Test the deck labels functionality
	test_deck_labels()

func test_deck_labels():
	"""Test that the deck labels are properly updated"""
	print("\n--- Testing Deck Labels ---")
	
	# Get the course and deck manager
	var course = get_tree().current_scene
	if not course:
		print("ERROR: Course not found!")
		return
	
	var deck_manager = course.get("deck_manager")
	if not deck_manager:
		print("ERROR: DeckManager not found!")
		return
	
	var ui_manager = course.get("ui_manager")
	if not ui_manager:
		print("ERROR: UIManager not found!")
		return
	
	print("✓ Course, DeckManager, and UIManager found")
	
	# Test that the labels exist
	var draw_pile_label = course.get_node_or_null("UILayer/DeckImageDraw/DrawPileLabel")
	var discard_pile_label = course.get_node_or_null("UILayer/DeckImageDiscard/DiscardPileLabel")
	
	if not draw_pile_label:
		print("❌ ERROR: DrawPileLabel not found!")
		return
	
	if not discard_pile_label:
		print("❌ ERROR: DiscardPileLabel not found!")
		return
	
	print("✓ Deck labels found")
	
	# Test initial state
	print("\n--- Initial State ---")
	var initial_draw_count = deck_manager.get_action_deck_remaining_cards().size()
	var initial_discard_count = deck_manager.get_action_discard_pile().size()
	
	print("Initial draw pile count:", initial_draw_count)
	print("Initial discard pile count:", initial_discard_count)
	print("DrawPileLabel text:", draw_pile_label.text)
	print("DiscardPileLabel text:", discard_pile_label.text)
	
	# Verify labels match the actual counts
	if draw_pile_label.text == str(initial_draw_count):
		print("✓ DrawPileLabel correctly shows draw pile count")
	else:
		print("❌ ERROR: DrawPileLabel mismatch! Expected:", initial_draw_count, "Got:", draw_pile_label.text)
	
	if discard_pile_label.text == str(initial_discard_count):
		print("✓ DiscardPileLabel correctly shows discard pile count")
	else:
		print("❌ ERROR: DiscardPileLabel mismatch! Expected:", initial_discard_count, "Got:", discard_pile_label.text)
	
	# Test drawing cards
	print("\n--- Testing Card Drawing ---")
	var original_draw_count = deck_manager.get_action_deck_remaining_cards().size()
	var drawn_cards = deck_manager.draw_from_action_deck(2)
	
	print("Drew", drawn_cards.size(), "cards")
	print("Draw pile count after drawing:", deck_manager.get_action_deck_remaining_cards().size())
	print("DrawPileLabel text after drawing:", draw_pile_label.text)
	
	# Verify draw pile label updated
	var expected_draw_count = original_draw_count - drawn_cards.size()
	if draw_pile_label.text == str(expected_draw_count):
		print("✓ DrawPileLabel correctly updated after drawing")
	else:
		print("❌ ERROR: DrawPileLabel not updated correctly! Expected:", expected_draw_count, "Got:", draw_pile_label.text)
	
	# Test discarding cards
	print("\n--- Testing Card Discarding ---")
	var original_discard_count = deck_manager.get_action_discard_pile().size()
	
	# Add cards to hand first
	for card in drawn_cards:
		deck_manager.hand.append(card)
	
	# Discard one card
	if drawn_cards.size() > 0:
		deck_manager.discard(drawn_cards[0])
		print("Discarded card:", drawn_cards[0].name)
		print("Discard pile count after discarding:", deck_manager.get_action_discard_pile().size())
		print("DiscardPileLabel text after discarding:", discard_pile_label.text)
		
		# Verify discard pile label updated
		var expected_discard_count = original_discard_count + 1
		if discard_pile_label.text == str(expected_discard_count):
			print("✓ DiscardPileLabel correctly updated after discarding")
		else:
			print("❌ ERROR: DiscardPileLabel not updated correctly! Expected:", expected_discard_count, "Got:", discard_pile_label.text)
	
	print("\n=== DECK LABELS TEST COMPLETE ===") 