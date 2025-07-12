extends Node
class_name DeckManager

signal deck_updated
signal discard_recycled(count: int)

# Separate piles for gameplay (drawing, discarding, hand)
var club_draw_pile: Array[CardData] = []
var club_discard_pile: Array[CardData] = []
var action_draw_pile: Array[CardData] = []
var action_discard_pile: Array[CardData] = []
var hand: Array[CardData] = []

# NEW: Ordered deck system for proper card tracking
var action_deck_order: Array[CardData] = []  # The actual order of cards in the action deck
var action_deck_index: int = 0  # Current position in the deck
var club_deck_order: Array[CardData] = []    # The actual order of cards in the club deck
var club_deck_index: int = 0    # Current position in the club deck

# Legacy support - keep the old system for now
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []

func _ready():
	# Connect to CurrentDeckManager signals
	var current_deck_manager = get_parent().get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.deck_updated.connect(_on_current_deck_updated)
		# Initial sync - wait a frame to ensure CurrentDeckManager is initialized
		call_deferred("sync_with_current_deck")
	else:
		print("DeckManager: CurrentDeckManager not found during _ready()")
		print("DeckManager: Parent node:", get_parent().name if get_parent() else "No parent")
		print("DeckManager: Available siblings:")
		if get_parent():
			for child in get_parent().get_children():
				print("  -", child.name)

func _on_current_deck_updated():
	"""Called when CurrentDeckManager deck is updated"""
	# Only sync if we haven't initialized separate decks yet
	# This prevents overwriting our separate pile system during gameplay
	if club_draw_pile.size() == 0 and action_draw_pile.size() == 0:
		sync_with_current_deck()
	else:
		print("DeckManager: Separate decks already initialized, skipping sync to preserve discard piles")

func sync_with_current_deck():
	"""Sync the separate deck system with CurrentDeckManager"""
	var current_deck_manager = get_parent().get_node_or_null("CurrentDeckManager")
	if not current_deck_manager:
		print("DeckManager: ERROR - CurrentDeckManager not found!")
		return
	
	var current_deck = current_deck_manager.get_current_deck()
	
	# If CurrentDeckManager has no cards, force initialization
	if current_deck.size() == 0:
		print("DeckManager: CurrentDeckManager has no cards, forcing initialization")
		current_deck_manager.initialize_starter_deck()
		current_deck = current_deck_manager.get_current_deck()
	
	# Clear existing piles
	club_draw_pile.clear()
	club_discard_pile.clear()
	action_draw_pile.clear()
	action_discard_pile.clear()
	
	# Sort cards into appropriate piles
	for card in current_deck:
		if is_club_card(card):
			club_draw_pile.append(card)
		else:
			action_draw_pile.append(card)
	
	# Initialize the ordered deck system
	action_deck_order = action_draw_pile.duplicate()
	action_deck_order.shuffle()
	action_deck_index = 0
	
	club_deck_order = club_draw_pile.duplicate()
	club_deck_order.shuffle()
	club_deck_index = 0
	
	print("DeckManager: Initialized ordered deck system")
	print("Action deck order:", action_deck_order.size(), "cards")
	print("Club deck order:", club_deck_order.size(), "cards")
	
	emit_signal("deck_updated")

func initialize_deck(cards: Array[CardData]) -> void:
	# Legacy function - now delegates to CurrentDeckManager
	if has_node("/root/CurrentDeckManager"):
		var current_deck_manager = get_node("/root/CurrentDeckManager")
		current_deck_manager.current_deck = cards.duplicate()
		current_deck_manager.emit_signal("deck_updated")
	
	discard_pile.clear()
	hand.clear()
	emit_signal("deck_updated")

func initialize_separate_decks() -> void:
	"""Initialize the separate deck system from CurrentDeckManager"""
	sync_with_current_deck()
	hand.clear()
	emit_signal("deck_updated")

func add_card_to_deck(card: CardData) -> void:
	"""Add a card to the CurrentDeckManager (single source of truth)"""
	var current_deck_manager = get_parent().get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.add_card_to_deck(card)
	else:
		print("Warning: CurrentDeckManager not found")

func is_club_card(card: CardData) -> bool:
	"""Check if a card is a club card based on its name"""
	var club_names = ["Putter", "Wood", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club", "GrenadeLauncherClubCard"]
	return club_names.has(card.name)

func draw_from_club_deck(count: int = 1) -> Array[CardData]:
	"""Draw cards from the club deck"""
	# Check if we need to reshuffle to get enough cards
	var total_available_cards = club_draw_pile.size() + club_discard_pile.size()
	if club_draw_pile.size() < count and total_available_cards >= count:
		reshuffle_club_discard()
	
	var drawn_cards: Array[CardData] = []
	for i in range(count):
		# If draw pile is empty, try to reshuffle discard pile
		if club_draw_pile.is_empty():
			reshuffle_club_discard()
			# If still empty after reshuffle, we can't draw more cards
			if club_draw_pile.is_empty():
				break
		
		var index := randi() % club_draw_pile.size()
		var card := club_draw_pile[index]
		club_draw_pile.remove_at(index)
		drawn_cards.append(card)
	
	emit_signal("deck_updated")
	return drawn_cards

func draw_from_action_deck(count: int = 3) -> Array[CardData]:
	# Show remaining cards in deck
	var remaining = get_action_deck_remaining_cards()

	
	var drawn_cards: Array[CardData] = []
	for i in range(count):
		# Check if we need to reshuffle
		if action_deck_index >= action_deck_order.size():
			reshuffle_action_discard()
			# If still no cards after reshuffle, we can't draw more
			if action_deck_order.size() == 0:
				break
		
		# Draw the next card in order
		var card := action_deck_order[action_deck_index]
		action_deck_index += 1
		drawn_cards.append(card)

	
	# Validate deck state after drawing
	validate_deck_state()
	

	
	emit_signal("deck_updated")
	return drawn_cards

func draw_action_cards_to_hand(count: int = 3) -> void:
	"""Draw action cards and add them directly to the hand"""

	
	var drawn_cards = draw_from_action_deck(count)
	for card in drawn_cards:
		hand.append(card)

	

	emit_signal("deck_updated")

func draw_club_cards_to_hand(count: int = 1) -> void:
	"""Draw club cards and add them directly to the hand"""
	var drawn_cards = draw_from_club_deck(count)
	for card in drawn_cards:
		hand.append(card)
	emit_signal("deck_updated")

func create_virtual_putter_card() -> CardData:
	"""Create a virtual putter card that doesn't come from the deck. Returns the created card."""
	var virtual_putter = preload("res://Cards/Putter.tres").duplicate()
	virtual_putter.name = "Putter"  # Ensure the name is set correctly
	print("DeckManager: Created virtual putter card for PutterHelp equipment")
	return virtual_putter

func add_virtual_putter_to_hand() -> bool:
	"""Add a virtual putter card to the hand. Returns true if successful."""
	var virtual_putter = create_virtual_putter_card()
	hand.append(virtual_putter)
	emit_signal("deck_updated")
	print("DeckManager: Added virtual putter card to hand via PutterHelp equipment")
	return true

func reshuffle_club_discard() -> void:
	"""Reshuffle club discard pile into draw pile"""
	var count := club_discard_pile.size()
	if count == 0:
		return
	
	# Add discard pile to draw pile instead of replacing it
	club_draw_pile.append_array(club_discard_pile)
	club_draw_pile.shuffle()
	club_discard_pile.clear()
	emit_signal("deck_updated")
	emit_signal("discard_recycled", count)

func reshuffle_action_discard() -> void:
	"""Reshuffle action discard pile into deck order"""
	var count := action_discard_pile.size()
	if count == 0:
		return
	
	print("DeckManager: Reshuffling action discard pile")
	print("Discard pile size:", action_discard_pile.size())
	print("Deck order size before reshuffle:", action_deck_order.size())
	print("Deck index before reshuffle:", action_deck_index)
	
	# Validate state before reshuffle
	validate_deck_state()
	
	# Show what cards are in the discard pile
	print("Cards in discard pile:")
	for i in range(min(5, action_discard_pile.size())):
		print("  ", i, ":", action_discard_pile[i].name)
	
	# Get the remaining cards that haven't been drawn yet
	var remaining_cards = get_action_deck_remaining_cards()
	print("Remaining undrawn cards:", remaining_cards.size())
	
	# Create a new deck order with remaining cards + discard pile
	var new_deck_order: Array[CardData] = []
	
	# Add remaining undrawn cards
	new_deck_order.append_array(remaining_cards)
	
	# Add all cards from discard pile (no duplicates since we're starting fresh)
	new_deck_order.append_array(action_discard_pile)
	
	# Shuffle the new deck order
	new_deck_order.shuffle()
	
	# Store the discard pile size before clearing it
	var discard_pile_size = action_discard_pile.size()
	
	# Replace the old deck order with the new one
	action_deck_order = new_deck_order
	action_deck_index = 0  # Reset to beginning of deck
	action_discard_pile.clear()
	
	print("DeckManager: Reshuffled action discard pile into deck order")
	print("New deck order size:", action_deck_order.size())
	print("Added", discard_pile_size, "cards from discard pile")
	
	# Show first few cards in new deck order
	print("First 5 cards in new deck order:")
	for i in range(min(5, action_deck_order.size())):
		print("  ", i, ":", action_deck_order[i].name)
	
	# Validate state after reshuffle
	validate_deck_state()
	
	emit_signal("deck_updated")
	emit_signal("discard_recycled", count)

func insert_card_at_top_of_action_deck(card: CardData) -> void:
	"""Insert a card at the top of the action deck (next to be drawn)"""
	action_deck_order.insert(action_deck_index, card)
	print("DeckManager: Inserted", card.name, "at top of action deck (index:", action_deck_index, ")")
	emit_signal("deck_updated")

func get_action_deck_order() -> Array[CardData]:
	"""Get the current action deck order"""
	return action_deck_order.duplicate()

func get_action_deck_index() -> int:
	"""Get the current action deck index"""
	return action_deck_index

func get_action_deck_remaining_cards() -> Array[CardData]:
	"""Get the remaining cards in the action deck (from current index to end)"""
	if action_deck_index >= action_deck_order.size():
		return []
	return action_deck_order.slice(action_deck_index)

func get_action_deck_available_cards() -> Array[CardData]:
	"""Get the cards that are actually available to draw (excluding already drawn cards)"""
	var available_cards: Array[CardData] = []
	for i in range(action_deck_index, action_deck_order.size()):
		available_cards.append(action_deck_order[i])
	return available_cards

func get_action_discard_pile() -> Array[CardData]:
	"""Get the action discard pile"""
	return action_discard_pile.duplicate()

func validate_deck_state() -> void:
	"""Validate that the deck state is consistent"""
	var action_cards_in_hand = 0
	for card in hand:
		if not is_club_card(card):
			action_cards_in_hand += 1
	
	var available_cards = get_action_deck_remaining_cards()
	var total_action_cards_in_system = available_cards.size() + action_discard_pile.size() + action_cards_in_hand
	
	# Check for duplicates in deck order
	var seen_cards = {}
	for card in action_deck_order:
		if seen_cards.has(card.name):
			seen_cards[card.name] += 1
		else:
			seen_cards[card.name] = 1
	
	print("Card counts in deck order:")
	for card_name in seen_cards:
		if seen_cards[card_name] > 1:
			print("  WARNING:", card_name, "appears", seen_cards[card_name], "times in deck order!")
		else:
			print("  ", card_name, ":", seen_cards[card_name])
	
	print("=== END VALIDATION ===")

func draw_cards(count: int = 3) -> void:
	for i in range(count):
		if draw_pile.is_empty():
			reshuffle_discard_into_draw()
		if draw_pile.is_empty():
			break

		var index := randi() % draw_pile.size()
		var card := draw_pile[index]
		draw_pile.remove_at(index)
		hand.append(card)

	emit_signal("deck_updated")

func discard(card: CardData) -> void:
	if hand.has(card):
		hand.erase(card)
	else:
		print("Warning: Tried to discard a card not in hand:", card.name)

	# Sort card into appropriate discard pile
	if is_club_card(card):
		club_discard_pile.append(card)
	else:
		action_discard_pile.append(card)
		print("DeckManager: Discarded", card.name, "to action discard pile (size:", action_discard_pile.size(), ")")
	
	# Also maintain legacy discard pile for compatibility
	discard_pile.append(card)
	
	# Validate deck state after discarding
	validate_deck_state()
	
	emit_signal("deck_updated")

func reshuffle_discard_into_draw() -> void:
	var count := discard_pile.size()
	if count == 0:
		return

	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	emit_signal("deck_updated")
	emit_signal("discard_recycled", count)
