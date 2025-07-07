extends Node2D

func _ready():
	print("=== SIMPLE SWING TEST READY ===")
	
	# Connect button signal
	var test_button = get_node_or_null("TestButton")
	if test_button:
		test_button.pressed.connect(_on_test_swing_pressed)
		print("✓ Connected test button")
	
	# Find the BennyChar node
	var benny_char = get_node_or_null("BennyChar")
	if benny_char:
		print("✓ Found BennyChar:", benny_char)
		print("BennyChar children:", benny_char.get_children())
		
		# Look for SwingAnimation node
		var swing_animation = benny_char.get_node_or_null("SwingAnimation")
		if swing_animation:
			print("✓ Found SwingAnimation:", swing_animation)
			print("SwingAnimation children:", swing_animation.get_children())
			
			# Check if it has the required methods
			if swing_animation.has_method("start_swing_animation"):
				print("✓ SwingAnimation has start_swing_animation method")
			else:
				print("✗ SwingAnimation missing start_swing_animation method")
		else:
			print("✗ SwingAnimation not found in BennyChar")
	else:
		print("✗ BennyChar not found")
	
	print("✓ Simple swing test ready")

func _on_test_swing_pressed():
	"""Test the swing animation directly"""
	print("=== TESTING SWING ANIMATION DIRECTLY ===")
	
	var benny_char = get_node_or_null("BennyChar")
	if benny_char:
		var swing_animation = benny_char.get_node_or_null("SwingAnimation")
		if swing_animation:
			print("Calling swing_animation.start_swing_animation()")
			swing_animation.start_swing_animation()
			print("✓ Direct swing animation test triggered")
		else:
			print("✗ SwingAnimation not found")
	else:
		print("✗ BennyChar not found") 