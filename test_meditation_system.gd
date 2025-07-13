extends Node2D

func _ready():
	print("=== TESTING MEDITATION SYSTEM ===")
	
	# Find the Player node
	var player = get_node_or_null("Player")
	if not player:
		print("✗ Player node not found")
		return
	
	print("✓ Found Player node:", player)
	
	# Test meditation system setup
	if player.has_method("_setup_meditation_system"):
		print("✓ Player has meditation setup method")
	else:
		print("✗ Player missing meditation setup method")
	
	# Test meditation sprite finding
	if player.has_method("_find_meditate_sprite_recursive"):
		print("✓ Player has meditate sprite finder method")
	else:
		print("✗ Player missing meditate sprite finder method")
	
	# Test meditation start method
	if player.has_method("start_meditation"):
		print("✓ Player has start_meditation method")
	else:
		print("✗ Player missing start_meditation method")
	
	# Test meditation state checking
	if player.has_method("is_currently_meditating"):
		print("✓ Player has meditation state checker")
	else:
		print("✗ Player missing meditation state checker")
	
	# Test heal method
	if player.has_method("heal_player"):
		print("✓ Player has heal method")
	else:
		print("✗ Player missing heal method")
	
	# Find the Bonfire node
	var bonfire = get_node_or_null("Bonfire")
	if bonfire:
		print("✓ Found Bonfire node:", bonfire)
		
		# Test bonfire meditation check
		if bonfire.has_method("_check_for_player_meditation"):
			print("✓ Bonfire has meditation check method")
		else:
			print("✗ Bonfire missing meditation check method")
	else:
		print("⚠ Bonfire node not found")
	
	print("=== MEDITATION SYSTEM TEST COMPLETE ===")

func _on_test_meditation_button_pressed():
	"""Test the meditation system manually"""
	print("=== MANUAL MEDITATION TEST ===")
	
	var player = get_node_or_null("Player")
	if not player:
		print("✗ Player node not found for manual test")
		return
	
	# Check if player is already meditating
	if player.is_currently_meditating():
		print("Player is already meditating, stopping...")
		player.stop_meditation()
	else:
		print("Starting player meditation...")
		player.start_meditation()
	
	print("=== MANUAL TEST COMPLETE ===") 