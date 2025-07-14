extends Node2D

# Test scene for meditation system
# Press L to light bonfire, M to check meditation status, B to check blocking

func _ready():
	print("=== MEDITATION SYSTEM TEST SCENE ===")
	print("Press L to light bonfire")
	print("Press M to check meditation status")
	print("Press S to stop meditation")
	print("Press T to test manual meditation")
	
	# Connect button signal
	var test_button = $UI/VBoxContainer/TestButton
	if test_button:
		test_button.pressed.connect(_on_test_meditation_button_pressed)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_L:
				_light_bonfire()
			KEY_M:
				_check_meditation_status()
			KEY_S:
				_stop_meditation()
			KEY_T:
				_test_manual_meditation()
			KEY_C:
				_check_bonfire_cooldown()

func _light_bonfire():
	"""Light the bonfire to test meditation trigger"""
	var bonfire = $Bonfire
	if bonfire and bonfire.has_method("set_bonfire_active"):
		bonfire.set_bonfire_active(true)
		print("✓ Bonfire lit!")
		print("✓ Meditation cooldown reset - first meditation should trigger immediately")
		_update_status("Bonfire lit - player should start meditating")
	else:
		print("✗ Cannot light bonfire - bonfire not found or missing method")

func _check_meditation_status():
	"""Check the current meditation status"""
	var player = $Player
	if player and player.has_method("is_currently_meditating"):
		var is_meditating = player.is_currently_meditating()
		print("Player meditation status:", is_meditating)
		_update_status("Meditation: " + ("Active" if is_meditating else "Inactive"))
	else:
		print("✗ Cannot check meditation - player not found or missing method")
		_update_status("Error: Cannot check meditation")

func _stop_meditation():
	"""Stop the player's meditation"""
	var player = $Player
	if player and player.has_method("stop_meditation"):
		player.stop_meditation()
		print("✓ Meditation stopped")
		_update_status("Meditation stopped")
	else:
		print("✗ Cannot stop meditation - player not found or missing method")
		_update_status("Error: Cannot stop meditation")

func _test_manual_meditation():
	"""Test manual meditation trigger"""
	var player = $Player
	if player and player.has_method("start_meditation"):
		print("=== TESTING MANUAL MEDITATION ===")
		
		# First check if meditation sprite is found
		if player.has_method("_find_meditate_sprite_recursive"):
			var meditate_sprite = player._find_meditate_sprite_recursive(player)
			print("Meditation sprite found:", meditate_sprite != null)
			if meditate_sprite:
				print("Meditation sprite visible:", meditate_sprite.visible)
				print("Meditation sprite position:", meditate_sprite.position)
		
		print("Starting player meditation...")
		player.start_meditation()
		_update_status("Manual meditation started")
	else:
		print("✗ Cannot start meditation - player not found or missing method")
		_update_status("Error: Cannot start meditation")

func _check_bonfire_cooldown():
	"""Check the bonfire's meditation cooldown status"""
	var bonfire = $Bonfire
	if bonfire and "last_meditation_trigger_time" in bonfire and "meditation_cooldown" in bonfire:
		var current_time = Time.get_ticks_msec() / 1000.0
		var time_since_last = current_time - bonfire.last_meditation_trigger_time
		var cooldown_remaining = bonfire.meditation_cooldown - time_since_last
		
		print("=== BONFIRE COOLDOWN STATUS ===")
		print("Current time:", current_time)
		print("Last trigger time:", bonfire.last_meditation_trigger_time)
		print("Time since last trigger:", time_since_last)
		print("Cooldown duration:", bonfire.meditation_cooldown)
		print("Cooldown remaining:", max(0, cooldown_remaining))
		print("Can trigger meditation:", cooldown_remaining <= 0)
		print("=== END COOLDOWN STATUS ===")
		
		_update_status("Cooldown: " + str(max(0, cooldown_remaining)) + "s remaining")
	else:
		print("✗ Cannot check cooldown - bonfire not found or missing properties")
		_update_status("Error: Cannot check cooldown")

func _update_status(message: String):
	"""Update the status label"""
	var status_label = $UI/VBoxContainer/StatusLabel
	if status_label:
		status_label.text = "Status: " + message

func _on_test_meditation_button_pressed():
	"""Test the meditation system manually"""
	print("=== MANUAL MEDITATION TEST ===")
	
	var player = $Player
	if not player:
		print("✗ Player not found")
		return
	
	# Stop any existing meditation
	if player.has_method("stop_meditation"):
		player.stop_meditation()
	
	print("Starting player meditation...")
	player.start_meditation()
	_update_status("Button test: Meditation started") 