extends Node2D

# Test script for BagCheck card system
# This test verifies that the BagCheck card correctly shows a dialog with 2 random club cards
# and allows the player to select one for temporary use

@onready var card_effect_handler: CardEffectHandler = $CardEffectHandler
@onready var deck_manager: DeckManager = $DeckManager
@onready var current_deck_manager: CurrentDeckManager = $CurrentDeckManager

# Test card
var bag_check_card: CardData

func _ready():
	print("=== BagCheck System Test ===")
	
	# Load the BagCheck card
	bag_check_card = preload("res://Cards/BagCheck.tres")
	print("Loaded BagCheck card:", bag_check_card.name)
	print("Effect type:", bag_check_card.effect_type)
	
	# Run the test
	run_bag_check_test()

func run_bag_check_test():
	print("\n--- Starting BagCheck Test ---")
	
	# Test 1: Check initial state
	print("Test 1: Initial state check")
	print("Hand size:", deck_manager.hand.size())
	print("Temporary club:", "None" if not card_effect_handler.course or not card_effect_handler.course.temporary_club else card_effect_handler.course.temporary_club.name)
	
	# Test 2: Add BagCheck card to hand
	print("\nTest 2: Adding BagCheck card to hand")
	deck_manager.hand.append(bag_check_card)
	print("Hand size after adding BagCheck:", deck_manager.hand.size())
	print("Cards in hand:", deck_manager.hand.map(func(card): return card.name))
	
	# Test 3: Test BagCheck effect
	print("\nTest 3: Testing BagCheck effect")
	print("Triggering BagCheck effect...")
	card_effect_handler.handle_bag_adjust_effect(bag_check_card)
	
	print("BagCheck effect triggered - check for dialog")
	print("Hand size after effect:", deck_manager.hand.size())
	print("Cards in hand:", deck_manager.hand.map(func(card): return card.name))
	
	print("--- BagCheck Test Complete ---")
	print("If a dialog appeared with 2 club cards, the test is working!")
	print("Select a club from the dialog to complete the test.")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("\n--- Running BagCheck Test Again ---")
			run_bag_check_test()
		elif event.keycode == KEY_R:
			print("\n--- Resetting Test ---")
			# Clear hand
			for card in deck_manager.hand.duplicate():
				deck_manager.discard(card)
			# Clear temporary club
			if card_effect_handler.course:
				card_effect_handler.course.clear_temporary_club()
			print("Test reset complete") 