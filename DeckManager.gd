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

# Legacy support - keep the old system for now
var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []

func _ready():
	print("DeckManager: _ready() called")
	# Connect to CurrentDeckManager signals
	var current_deck_manager = get_parent().get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		print("DeckManager: Found CurrentDeckManager, connecting signals")
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
	print("DeckManager: CurrentDeckManager deck updated, syncing separate decks")
	# Only sync if we haven't initialized separate decks yet
	# This prevents overwriting our separate pile system during gameplay
	if club_draw_pile.size() == 0 and action_draw_pile.size() == 0:
		print("DeckManager: Separate decks not initialized yet, syncing from CurrentDeckManager")
		sync_with_current_deck()
	else:
		print("DeckManager: Separate decks already initialized, skipping sync to preserve discard piles")

func sync_with_current_deck():
	"""Sync the separate deck system with CurrentDeckManager"""
	print("DeckManager: sync_with_current_deck() called")
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
	
	print("DeckManager: Syncing with CurrentDeckManager. Total cards:", current_deck.size())
	print("DeckManager: CurrentDeckManager deck contents:")
	for card in current_deck:
		print("  -", card.name, "(Club card:", is_club_card(card), ")")
	
	# Clear existing piles
	club_draw_pile.clear()
	club_discard_pile.clear()
	action_draw_pile.clear()
	action_discard_pile.clear()
	
	# Sort cards into appropriate piles
	for card in current_deck:
		if is_club_card(card):
			club_draw_pile.append(card)
			print("DeckManager: Added", card.name, "to club pile")
		else:
			action_draw_pile.append(card)
			print("DeckManager: Added", card.name, "to action pile")
	
	# Shuffle the piles
	club_draw_pile.shuffle()
	action_draw_pile.shuffle()
	
	print("DeckManager: Synced with CurrentDeckManager - Club cards:", club_draw_pile.size(), "Action cards:", action_draw_pile.size())
	print("DeckManager: DEBUG - Club draw pile contents after sync:")
	for card in club_draw_pile:
		print("  -", card.name)
	print("DeckManager: DEBUG - Action draw pile contents after sync:")
	for card in action_draw_pile:
		print("  -", card.name)
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
	print("DeckManager: initialize_separate_decks() called")
	sync_with_current_deck()
	hand.clear()
	emit_signal("deck_updated")
	print("DeckManager: Separate decks initialized from CurrentDeckManager")
	print("DeckManager: Final state - Club draw:", club_draw_pile.size(), "Action draw:", action_draw_pile.size())

func add_card_to_deck(card: CardData) -> void:
	"""Add a card to the CurrentDeckManager (single source of truth)"""
	var current_deck_manager = get_parent().get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.add_card_to_deck(card)
		print("Added", card.name, "to deck via CurrentDeckManager")
	else:
		print("Warning: CurrentDeckManager not found")

func is_club_card(card: CardData) -> bool:
	"""Check if a card is a club card based on its name"""
	var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
	return club_names.has(card.name)

func draw_from_club_deck(count: int = 1) -> Array[CardData]:
	"""Draw cards from the club deck"""
	print("DeckManager: Attempting to draw", count, "club cards. Club pile size:", club_draw_pile.size())
	print("DeckManager: Club discard pile size:", club_discard_pile.size())
	
	# Check if we need to reshuffle to get enough cards
	var total_available_cards = club_draw_pile.size() + club_discard_pile.size()
	print("DeckManager: Total available club cards:", total_available_cards)
	if club_draw_pile.size() < count and total_available_cards >= count:
		print("DeckManager: Not enough cards in draw pile, reshuffling discard to get", count, "cards")
		reshuffle_club_discard()
	
	var drawn_cards: Array[CardData] = []
	for i in range(count):
		print("DeckManager: Drawing card", i + 1, "of", count)
		# If draw pile is empty, try to reshuffle discard pile
		if club_draw_pile.is_empty():
			print("DeckManager: Club pile empty, reshuffling discard")
			reshuffle_club_discard()
			# If still empty after reshuffle, we can't draw more cards
			if club_draw_pile.is_empty():
				print("DeckManager: Club pile still empty after reshuffle - no more cards available")
				break
		
		var index := randi() % club_draw_pile.size()
		var card := club_draw_pile[index]
		club_draw_pile.remove_at(index)
		drawn_cards.append(card)
		print("DeckManager: Drew club card:", card.name)
	
	print("DeckManager: Drew", drawn_cards.size(), "club cards total")
	emit_signal("deck_updated")
	return drawn_cards

func draw_from_action_deck(count: int = 3) -> Array[CardData]:
	"""Draw cards from the action deck"""
	print("DeckManager: Attempting to draw", count, "action cards. Action pile size:", action_draw_pile.size())
	
	# Check if we need to reshuffle to get enough cards
	var total_available_cards = action_draw_pile.size() + action_discard_pile.size()
	if action_draw_pile.size() < count and total_available_cards >= count:
		print("DeckManager: Not enough cards in draw pile, reshuffling discard to get", count, "cards")
		reshuffle_action_discard()
	
	var drawn_cards: Array[CardData] = []
	for i in range(count):
		# If draw pile is empty, try to reshuffle discard pile
		if action_draw_pile.is_empty():
			print("DeckManager: Action pile empty, reshuffling discard")
			reshuffle_action_discard()
			# If still empty after reshuffle, we can't draw more cards
			if action_draw_pile.is_empty():
				print("DeckManager: Action pile still empty after reshuffle - no more cards available")
				break
		
		var index := randi() % action_draw_pile.size()
		var card := action_draw_pile[index]
		action_draw_pile.remove_at(index)
		drawn_cards.append(card)
		print("DeckManager: Drew action card:", card.name)
	
	print("DeckManager: Drew", drawn_cards.size(), "action cards total")
	emit_signal("deck_updated")
	return drawn_cards

func draw_action_cards_to_hand(count: int = 3) -> void:
	"""Draw action cards and add them directly to the hand"""
	var drawn_cards = draw_from_action_deck(count)
	for card in drawn_cards:
		hand.append(card)
	emit_signal("deck_updated")
	print("Added", drawn_cards.size(), "action cards to hand. Hand size:", hand.size())

func draw_club_cards_to_hand(count: int = 1) -> void:
	"""Draw club cards and add them directly to the hand"""
	print("DeckManager: Drawing", count, "club cards to hand")
	var drawn_cards = draw_from_club_deck(count)
	for card in drawn_cards:
		hand.append(card)
		print("DeckManager: Added", card.name, "to hand")
	emit_signal("deck_updated")
	print("Added", drawn_cards.size(), "club cards to hand. Hand size:", hand.size())

func reshuffle_club_discard() -> void:
	"""Reshuffle club discard pile into draw pile"""
	var count := club_discard_pile.size()
	print("DeckManager: reshuffle_club_discard() called - discard pile size:", count)
	if count == 0:
		print("DeckManager: Club discard pile is empty, nothing to reshuffle")
		return
	
	print("DeckManager: Reshuffling", count, "club cards from discard to draw pile")
	club_draw_pile = club_discard_pile.duplicate()
	club_draw_pile.shuffle()
	club_discard_pile.clear()
	print("DeckManager: Club draw pile now has", club_draw_pile.size(), "cards")
	emit_signal("deck_updated")
	emit_signal("discard_recycled", count)

func reshuffle_action_discard() -> void:
	"""Reshuffle action discard pile into draw pile"""
	var count := action_discard_pile.size()
	if count == 0:
		return
	
	action_draw_pile = action_discard_pile.duplicate()
	action_draw_pile.shuffle()
	action_discard_pile.clear()
	emit_signal("deck_updated")
	emit_signal("discard_recycled", count)

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
		print("Discarding card from hand:", card.name)
		hand.erase(card)
	else:
		print("Warning: Tried to discard a card not in hand:", card.name)

	# Sort card into appropriate discard pile
	if is_club_card(card):
		club_discard_pile.append(card)
		print("DeckManager: Added", card.name, "to club discard pile (total club discard:", club_discard_pile.size(), ")")
	else:
		action_discard_pile.append(card)
		print("DeckManager: Added", card.name, "to action discard pile (total action discard:", action_discard_pile.size(), ")")
	
	# Also maintain legacy discard pile for compatibility
	discard_pile.append(card)
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

func debug_print_state() -> void:
	print("--- Deck State ---")
	print("Legacy Draw Pile:", draw_pile.size())
	print("Legacy Discard Pile:", discard_pile.size())
	print("Club Draw Pile:", club_draw_pile.size())
	print("Club Discard Pile:", club_discard_pile.size())
	print("Action Draw Pile:", action_draw_pile.size())
	print("Action Discard Pile:", action_discard_pile.size())
	print("Hand:", hand.size())
	print("------------------")

func get_deck_state() -> Dictionary:
	"""Get the current state of the draw pile"""
	var state := {}
	state["cards"] = []
	for card in draw_pile:
		state["cards"].append(card.resource_path)
	return state

func get_discard_state() -> Dictionary:
	"""Get the current state of the discard pile"""
	var state := {}
	state["cards"] = []
	for card in discard_pile:
		state["cards"].append(card.resource_path)
	return state

func get_hand_state() -> Dictionary:
	"""Get the current state of the hand"""
	var state := {}
	state["cards"] = []
	for card in hand:
		state["cards"].append(card.resource_path)
	return state

func restore_deck_state(state: Dictionary) -> void:
	"""Restore the draw pile from saved state"""
	draw_pile.clear()
	if state.has("cards"):
		for card_path in state["cards"]:
			var card = load(card_path)
			if card:
				draw_pile.append(card)
	emit_signal("deck_updated")

func restore_discard_state(state: Dictionary) -> void:
	"""Restore the discard pile from saved state"""
	discard_pile.clear()
	if state.has("cards"):
		for card_path in state["cards"]:
			var card = load(card_path)
			if card:
				discard_pile.append(card)
	emit_signal("deck_updated")

func restore_hand_state(state: Dictionary) -> void:
	"""Restore the hand from saved state"""
	hand.clear()
	if state.has("cards"):
		for card_path in state["cards"]:
			var card = load(card_path)
			if card:
				hand.append(card)
	emit_signal("deck_updated")
