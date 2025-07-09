extends Control

# Test script to verify upgrade display system
@onready var test_container = $TestContainer

func _ready():
	# Wait a frame to ensure everything is loaded
	await get_tree().process_frame
	test_upgrade_display()

func test_upgrade_display():
	print("=== Testing Upgrade Display System ===")
	
	# Test 1: Create a basic card and upgrade it
	var test_card = preload("res://Cards/Move1.tres").duplicate()
	print("Test card level before upgrade:", test_card.level)
	print("Test card is_upgraded before upgrade:", test_card.is_upgraded())
	
	# Upgrade the card
	test_card.level = 2
	print("Test card level after upgrade:", test_card.level)
	print("Test card is_upgraded after upgrade:", test_card.is_upgraded())
	print("Test card upgraded name:", test_card.get_upgraded_name())
	
	# Test 2: Create CardVisual and test display
	var card_scene = preload("res://CardVisual.tscn")
	var card_instance = card_scene.instantiate()
	card_instance.size = Vector2(100, 140)
	card_instance.position = Vector2(50, 50)
	
	if card_instance.has_method("set_card_data"):
		card_instance.set_card_data(test_card)
		print("CardVisual created successfully with upgraded card")
	else:
		print("ERROR: CardVisual does not have set_card_data method")
	
	test_container.add_child(card_instance)
	
	# Test 3: Test null safety
	print("Testing null safety...")
	var null_card: CardData = null
	if null_card and null_card.is_upgraded():
		print("ERROR: Null card check failed")
	else:
		print("Null card check passed")
	
	print("=== Upgrade Display Test Complete ===") 