extends Node2D

# Test script for PutterHelp equipment system
# This test verifies that the PutterHelp equipment correctly draws a putter card
# on top of the normal club card draw

@onready var equipment_manager: EquipmentManager = $EquipmentManager
@onready var deck_manager: DeckManager = $DeckManager
@onready var current_deck_manager: CurrentDeckManager = $CurrentDeckManager

# Test equipment
var putter_help_equipment: EquipmentData

func _ready():
	print("=== PutterHelp System Test ===")
	
	# Load the PutterHelp equipment
	putter_help_equipment = preload("res://Equipment/PutterHelp.tres")
	print("Loaded PutterHelp equipment:", putter_help_equipment.name)
	print("Description:", putter_help_equipment.description)
	
	# Run the test
	run_putter_help_test()

func run_putter_help_test():
	print("\n--- Starting PutterHelp Test ---")
	
	# Test 1: Check initial state
	print("Test 1: Initial state check")
	print("Has PutterHelp equipment:", equipment_manager.has_putter_help())
	print("Hand size:", deck_manager.hand.size())
	print("Club draw pile size:", deck_manager.club_draw_pile.size())
	
	# Test 2: Add PutterHelp equipment
	print("\nTest 2: Adding PutterHelp equipment")
	equipment_manager.add_equipment(putter_help_equipment)
	print("Has PutterHelp equipment:", equipment_manager.has_putter_help())
	
	# Test 3: Draw club cards without PutterHelp effect
	print("\nTest 3: Drawing club cards (should not trigger PutterHelp yet)")
	var initial_hand_size = deck_manager.hand.size()
	deck_manager.draw_club_cards_to_hand(2)
	print("Hand size after drawing:", deck_manager.hand.size())
	print("Cards in hand:", deck_manager.hand.map(func(card): return card.name))
	
	# Test 4: Test virtual putter creation
	print("\nTest 4: Testing virtual putter creation")
	var putter_added = deck_manager.add_virtual_putter_to_hand()
	print("Virtual putter added successfully:", putter_added)
	print("Hand size after virtual putter add:", deck_manager.hand.size())
	print("Cards in hand:", deck_manager.hand.map(func(card): return card.name))
	
	# Test 5: Clear hand and test the full system
	print("\nTest 5: Testing full PutterHelp system")
	# Clear hand
	for card in deck_manager.hand.duplicate():
		deck_manager.discard(card)
	
	print("Hand cleared, size:", deck_manager.hand.size())
	
	# Simulate the course_1.gd draw_club_cards logic
	print("Simulating course_1.gd draw_club_cards logic...")
	
	# Draw normal club cards first
	deck_manager.draw_club_cards_to_hand(2)
	
	# Check for PutterHelp equipment and add virtual putter card if equipped
	var putter_help_active = false
	if equipment_manager.has_putter_help():
		print("PutterHelp equipment detected - adding virtual putter card")
		putter_help_active = deck_manager.add_virtual_putter_to_hand()
	
	print("Final hand size:", deck_manager.hand.size())
	print("Final cards in hand:", deck_manager.hand.map(func(card): return card.name))
	
	# Verify that a putter is in the hand
	var has_putter = false
	for card in deck_manager.hand:
		if card.name == "Putter":
			has_putter = true
			break
	
	print("Putter in hand:", has_putter)
	
	if has_putter:
		print("✅ PutterHelp system test PASSED!")
	else:
		print("❌ PutterHelp system test FAILED!")
	
	print("--- PutterHelp Test Complete ---")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			print("\n--- Running PutterHelp Test Again ---")
			run_putter_help_test()
		elif event.keycode == KEY_R:
			print("\n--- Resetting Test ---")
			# Remove PutterHelp equipment
			equipment_manager.remove_equipment(putter_help_equipment)
			# Clear hand
			for card in deck_manager.hand.duplicate():
				deck_manager.discard(card)
			print("Test reset complete") 