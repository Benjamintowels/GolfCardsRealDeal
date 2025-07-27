extends Node

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
	preload("res://Cards/BurstShot.tres"),        # BurstShot for testing Wraith
	
	# Defense cards (x2 each)
	preload("res://Cards/BlockB.tres"),
	preload("res://Cards/BlockB.tres"),
	
	# Club cards - only Wooden club
	preload("res://Cards/Wooden.tres")         # Wooden club only
]

# Fighter deck for testing all attack mechanics and NPC combat
var fighter_deck: Array[CardData] = [
	# Movement cards (x2 each for mobility)
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move1.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move2.tres"),
	preload("res://Cards/Move3.tres"),
	preload("res://Cards/Move3.tres"),
	
	# All Attack cards (x1 each for comprehensive testing)
	preload("res://Cards/PunchB.tres"),
	preload("res://Cards/SlashCard.tres"),
	preload("res://Cards/SlashCard.tres"),
	preload("res://Cards/SlashCard.tres"),
	preload("res://Cards/SlashCard.tres"),           # Basic melee attack
	preload("res://Cards/KickB.tres"),            # Basic melee attack
	preload("res://Cards/AttackDog.tres"),        # Dog attack
	preload("res://Cards/AssassinDash.tres"),     # Dash attack
	preload("res://Cards/SlashCard.tres"),        # Slash attack
	
	# All Weapon cards (x1 each for ranged combat testing)
	#preload("res://Cards/PistolCard.tres"),       # Basic pistol
	#preload("res://Cards/BurstShot.tres"),        # Burst fire weapon
	#preload("res://Cards/ShotgunCard.tres"),      # Shotgun weapon
	#preload("res://Cards/SniperCard.tres"),       # Sniper weapon
	#preload("res://Cards/GrenadeCard.tres"),      # Grenade weapon
	#preload("res://Cards/ThrowingKnife.tres"),    # Throwing knife
	#preload("res://Cards/ShurikenCard.tres"),     # Shuriken weapon
	
	# All AOE/Explosive cards (x1 each for area damage testing)
	preload("res://Cards/FireBallCard.tres"),     # Fire ball attack
	preload("res://Cards/IceBallCard.tres"),      # Ice ball attack
	preload("res://Cards/MeteorCard.tres"),       # Meteor attack
	preload("res://Cards/Explosive.tres"),        # Explosive attack
	preload("res://Cards/FiragaCard.tres"),       # Firaga fireball attack
	
	# Defense cards (x2 each for survival)
	preload("res://Cards/BlockB.tres"),
	preload("res://Cards/BlockB.tres"),
	preload("res://Cards/DodgeCard.tres"),        # Dodge ability
	preload("res://Cards/Vampire.tres"),          # Vampire healing
	
	# Club cards - 5 basic clubs in order (for golf mechanics)
	preload("res://Cards/Putter.tres"),        # Putter
	preload("res://Cards/PitchingWedge.tres"), # PitchingWedge
	preload("res://Cards/Iron.tres"),          # Iron
	preload("res://Cards/Wood.tres"),          # Wood
	preload("res://Cards/Driver.tres")         # Driver
]

func _ready():
	print("CurrentDeckManager: _ready() called")
	
	# Check if a deck type has already been selected
	if Global.selected_deck_type == "fighter":
		print("CurrentDeckManager: Fighter deck already selected, initializing fighter deck")
		initialize_fighter_deck()
	elif Global.selected_deck_type == "starter":
		print("CurrentDeckManager: Starter deck already selected, initializing starter deck")
		initialize_starter_deck()
	else:
		print("CurrentDeckManager: No deck selected yet, initializing default starter deck")
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

func initialize_fighter_deck():
	"""Initialize the deck with the fighter deck for combat testing"""
	current_deck = fighter_deck.duplicate()
	print("CurrentDeckManager: Initializing fighter deck with", current_deck.size(), "cards")
	print("CurrentDeckManager: Fighter deck contents:")
	for card in current_deck:
		print("  -", card.name)
	emit_signal("deck_updated")
	print("CurrentDeckManager: Initialized fighter deck with", current_deck.size(), "cards")

func switch_to_fighter_deck():
	"""Switch to the fighter deck for combat testing"""
	Global.selected_deck_type = "fighter"
	initialize_fighter_deck()

func switch_to_starter_deck():
	"""Switch back to the default starter deck"""
	Global.selected_deck_type = "starter"
	initialize_starter_deck()

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
