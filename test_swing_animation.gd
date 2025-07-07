extends Node2D

func _ready():
	# Connect button signals
	var test_button = get_node_or_null("TestButton")
	var test_button2 = get_node_or_null("TestButton2")
	
	if test_button:
		test_button.pressed.connect(_on_test_swing_pressed)
		# print("✓ Connected test button")
	if test_button2:
		test_button2.pressed.connect(_on_stop_swing_pressed)
		# print("✓ Connected stop button")
	
	# Check if player exists
	var player = get_node_or_null("Player")
	if player:
		# print("✓ Player found:", player)
		# print("Player children:", player.get_children())
		# Check if player has swing animation methods
		if player.has_method("start_swing_animation"):
			# print("✓ Player has start_swing_animation method")
			pass
		else:
			# print("✗ Player missing start_swing_animation method")
			pass
		if player.has_method("is_swinging"):
			# print("✓ Player has is_swinging method")
			pass
		else:
			# print("✗ Player missing is_swinging method")
			pass
	else:
		# print("✗ Player not found")
		pass
	# print("✓ Test scene ready")

func _on_test_swing_pressed():
	"""Test the swing animation"""
	# print("=== TESTING SWING ANIMATION ===")
	var player = get_node_or_null("Player")
	if player:
		# print("Calling player.start_swing_animation()")
		player.start_swing_animation()
		# print("✓ Swing animation test triggered")
		# Check if swinging
		if player.has_method("is_swinging"):
			# print("Is swinging:", player.is_swinging())
			pass
	else:
		# print("✗ Player not found")
		pass

func _on_stop_swing_pressed():
	"""Stop the swing animation"""
	# print("=== STOPPING SWING ANIMATION ===")
	var player = get_node_or_null("Player")
	if player:
		# print("Calling player.stop_swing_animation()")
		player.stop_swing_animation()
		# print("✓ Swing animation stop triggered")
	else:
		# print("✗ Player not found")
		pass 
