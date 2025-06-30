extends Node
class_name DeckManager

signal deck_updated
signal discard_recycled(count: int)

var draw_pile: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []

var starter_deck: Array[CardData] = [
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move4.tres"),
	preload("res://Cards/Move5.tres"),
	preload("res://Cards/StickyShot.tres"),
	preload("res://Cards/Bouncey.tres"),
	preload("res://Cards/Dub.tres"),
	preload("res://Cards/FloridaScramble.tres"),
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move4.tres"),
	preload("res://Cards/Move5.tres"),
	preload("res://Cards/StickyShot.tres"),
	preload("res://Cards/Bouncey.tres"),
	preload("res://Cards/Dub.tres"),
	preload("res://Cards/FloridaScramble.tres"),
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move4.tres"),
	preload("res://Cards/Move5.tres"),
	preload("res://Cards/FloridaScramble.tres")
]


func initialize_deck(cards: Array[CardData]) -> void:
	draw_pile = cards.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	emit_signal("deck_updated")

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
	print("Draw Pile:", draw_pile.size())
	print("Discard Pile:", discard_pile.size())
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
