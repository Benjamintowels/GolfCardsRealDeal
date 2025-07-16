extends Control

# Test script for pause menu functionality
# This test verifies that the escape key brings up the pause menu

func _ready():
	print("=== PAUSE MENU TEST STARTED ===")
	print("Press ESC to test pause menu")
	print("Press SPACE to simulate escape key press")
	print("Press R to reset test")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			# Simulate escape key press
			print("Simulating escape key press...")
			# Create a fake escape key event
			var escape_event = InputEventKey.new()
			escape_event.keycode = KEY_ESCAPE
			escape_event.pressed = true
			# Send it to the current scene
			get_tree().current_scene._input(escape_event)
			
		elif event.keycode == KEY_R:
			# Reset test
			print("=== RESETTING PAUSE MENU TEST ===")
			# Remove any existing pause menus
			var pause_menus = get_tree().get_nodes_in_group("pause_menu")
			for menu in pause_menus:
				if menu and is_instance_valid(menu):
					menu.queue_free()
			print("Pause menus cleared")
			
		elif event.keycode == KEY_T:
			# Test pause menu function directly
			print("Testing show_pause_menu() function directly...")
			if get_tree().current_scene.has_method("show_pause_menu"):
				get_tree().current_scene.show_pause_menu()
				print("Pause menu should now be visible")
			else:
				print("ERROR: show_pause_menu() method not found!")

func _process(delta):
	# Check if pause menu is visible
	var pause_menus = get_tree().get_nodes_in_group("pause_menu")
	if pause_menus.size() > 0:
		print("✓ Pause menu is visible")
	else:
		print("✗ No pause menu visible") 