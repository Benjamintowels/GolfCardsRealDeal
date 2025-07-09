extends Control

func _ready():
	print("=== TESTING ROOBOOST SYSTEM ===")
	
	# Test 1: Load RooBoostCard
	var rooboost_card = preload("res://Cards/RooBoostCard.tres")
	print("✓ RooBoostCard loaded successfully")
	print("  - Name:", rooboost_card.name)
	print("  - Effect type:", rooboost_card.effect_type)
	print("  - Effect strength:", rooboost_card.effect_strength)
	
	# Test 2: Check CardEffectHandler can handle RooBoostCard
	var card_effect_handler = CardEffectHandler.new()
	card_effect_handler.set_course_reference(self)
	
	# Mock course variables
	rooboost_active = false
	next_movement_card_rooboost = false
	
	# Test handling RooBoostCard
	var can_handle = card_effect_handler.handle_card_effect(rooboost_card)
	print("✓ CardEffectHandler can handle RooBoostCard:", can_handle)
	print("  - RooBoost active:", rooboost_active)
	print("  - Next movement card RooBoost:", next_movement_card_rooboost)
	
	# Test 3: Check that the effect is applied correctly
	if next_movement_card_rooboost:
		print("✓ RooBoost effect applied successfully to next movement card")
	else:
		print("✗ RooBoost effect not applied correctly")
	
	print("=== ROOBOOST SYSTEM TEST COMPLETE ===")

# Mock variables for testing
var rooboost_active: bool = false
var next_movement_card_rooboost: bool = false 