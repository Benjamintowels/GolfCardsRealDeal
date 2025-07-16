extends Node
class_name CurrentDeckManager

signal deck_updated

# Current deck state - this is our source of truth
var current_deck: Array[CardData] = []

# Default starter deck as specified - only wooden stick and putter for clubs
var starter_deck: Array[CardData] = [
	# Movement cards (x2 each)
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move3.tres"),
	
	# Attack cards (x2 each)
	preload("res://Cards/PunchB.tres"),
	preload("res://Cards/PunchB.tres"),
	preload("res://Cards/KickB.tres"),
	preload("res://Cards/KickB.tres"),
	
	# Defense cards (x2 each)
	preload("res://Cards/BlockB.tres"),
	preload("res://Cards/BlockB.tres"),
	
	# Club cards
	preload("res://Cards/Putter.tres"),        # Putter
	preload("res://Cards/Wooden.tres")         # Wooden club
]

func _ready():
	print("CurrentDeckManager: _ready() called")
	initialize_starter_deck()

func initialize_starter_deck():
	"""Initialize the deck with the default starter deck"""
	current_deck = starter_deck.duplicate()
	print("CurrentDeckManager: Initializing starter deck with", current_deck.size(), "cards")
	print("CurrentDeckManager: Starter deck contents:")
	for card in current_deck:
		print("  -", card.name)
	emit_signal("deck_updated")
	print("CurrentDeckManager: Initialized starter deck with", current_deck.size(), "cards")

func add_card_to_deck(card: CardData):
	"""Add a card to the current deck"""
	current_deck.append(card)
	emit_signal("deck_updated")
	print("CurrentDeckManager: Added", card.name, "to deck. Total cards:", current_deck.size())

func remove_card_from_deck(card: CardData):
	"""Remove a card from the current deck"""
	if current_deck.has(card):
		current_deck.erase(card)
		emit_signal("deck_updated")
		print("CurrentDeckManager: Removed", card.name, "from deck. Total cards:", current_deck.size())
	else:
		print("CurrentDeckManager: Warning - tried to remove", card.name, "but it's not in the deck")

func get_current_deck() -> Array[CardData]:
	"""Get the current deck as an array"""
	return current_deck.duplicate()

func get_deck_size() -> int:
	"""Get the current deck size"""
	return current_deck.size()

func has_card(card: CardData) -> bool:
	"""Check if a specific card is in the deck"""
	return current_deck.has(card)

func get_card_count(card_name: String) -> int:
	"""Get the count of a specific card by name"""
	var count = 0
	for card in current_deck:
		if card.name == card_name:
			count += 1
	return count

func get_deck_summary() -> Dictionary:
	"""Get a summary of the deck with card counts"""
	var summary = {}
	for card in current_deck:
		if summary.has(card.name):
			summary[card.name] += 1
		else:
			summary[card.name] = 1
	return summary

func print_deck_summary():
	"""Print a summary of the current deck"""
	var summary = get_deck_summary()
	print("=== Current Deck Summary ===")
	for card_name in summary:
		print(card_name + ": " + str(summary[card_name]))
	print("Total cards:", current_deck.size())
	print("==========================")

func save_deck_state() -> Dictionary:
	"""Save the current deck state for persistence"""
	var state = {}
	state["cards"] = []
	for card in current_deck:
		state["cards"].append(card.resource_path)
	return state

func load_deck_state(state: Dictionary):
	"""Load deck state from saved data"""
	current_deck.clear()
	if state.has("cards"):
		for card_path in state["cards"]:
			var card = load(card_path)
			if card:
				current_deck.append(card)
	emit_signal("deck_updated")
	print("CurrentDeckManager: Loaded deck state with", current_deck.size(), "cards") 