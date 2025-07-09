extends Node2D

func _ready():
	print("=== PUNCH ANIMATION TEST SCENE READY ===")
	
	# Connect to the test button
	var test_button = get_node_or_null("TestButton")
	if test_button:
		test_button.pressed.connect(_on_test_button_pressed)
		print("✓ Test button connected")
	else:
		print("⚠ Test button not found")

func _on_test_button_pressed() -> void:
	"""Handle when the test button is pressed"""
	print("=== PUNCH ANIMATION TEST BUTTON PRESSED ===")
	
	var player = get_node_or_null("Player")
	if player and player.has_method("start_punchb_animation"):
		print("✓ Starting punch animation...")
		player.start_punchb_animation()
	else:
		print("✗ Player or punch animation method not found")
	
	print("=== END PUNCH ANIMATION TEST ===") 