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
	
	# Shuffle the piles
	club_draw_pile.shuffle()
	action_draw_pile.shuffle()
	
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
	var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "Fire Club", "Ice Club"]
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
	"""Draw cards from the action deck"""
	# Check if we need to reshuffle to get enough cards
	var total_available_cards = action_draw_pile.size() + action_discard_pile.size()
	if action_draw_pile.size() < count and total_available_cards >= count:
		reshuffle_action_discard()
	
	var drawn_cards: Array[CardData] = []
	for i in range(count):
		# If draw pile is empty, try to reshuffle discard pile
		if action_draw_pile.is_empty():
			reshuffle_action_discard()
			# If still empty after reshuffle, we can't draw more cards
			if action_draw_pile.is_empty():
				break
		
		var index := randi() % action_draw_pile.size()
		var card := action_draw_pile[index]
		action_draw_pile.remove_at(index)
		drawn_cards.append(card)
	
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

func reshuffle_club_discard() -> void:
	"""Reshuffle club discard pile into draw pile"""
	var count := club_discard_pile.size()
	if count == 0:
		return
	
	club_draw_pile = club_discard_pile.duplicate()
	club_draw_pile.shuffle()
	club_discard_pile.clear()
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
		hand.erase(card)
	else:
		print("Warning: Tried to discard a card not in hand:", card.name)

	# Sort card into appropriate discard pile
	if is_club_card(card):
		club_discard_pile.append(card)
	else:
		action_discard_pile.append(card)
	
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
