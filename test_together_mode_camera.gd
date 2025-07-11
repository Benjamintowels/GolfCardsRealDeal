extends Node2D

# Test script for Together Mode Camera functionality
# Verifies that the camera moves to the highest priority NPC during together mode

@onready var world_turn_manager: Node = null

func _ready():
	"""Initialize the test scene"""
	print("=== TOGETHER MODE CAMERA TEST INITIALIZED ===")
	
	# Wait a frame to ensure everything is loaded
	await get_tree().process_frame
	
	# Find the WorldTurnManager
	world_turn_manager = get_tree().current_scene.get_node_or_null("WorldTurnManager")
	
	if not world_turn_manager:
		print("ERROR: Could not find WorldTurnManager!")
		return
	
	print("✓ Found WorldTurnManager: ", world_turn_manager.name)
	
	# Test together mode status
	print("=== TESTING TOGETHER MODE STATUS ===")
	var together_mode_enabled = world_turn_manager.is_together_mode_enabled()
	print("Together mode enabled: ", together_mode_enabled)
	
	if not together_mode_enabled:
		print("Enabling together mode for testing...")
		world_turn_manager.set_together_mode(true)
	
	# Test priority groups
	print("=== TESTING PRIORITY GROUPS ===")
	world_turn_manager.debug_priority_groups()
	
	# Test turn progress
	print("=== TESTING TURN PROGRESS ===")
	var progress = world_turn_manager.get_turn_progress()
	print("Turn progress: ", progress)
	
	print("=== TOGETHER MODE CAMERA TEST READY ===")
	print("Press SPACE to start a world turn and test camera movement")
	print("Press T to toggle together mode")
	print("Press D for debug status")

func _input(event: InputEvent):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Start world turn to test camera movement
				if world_turn_manager:
					print("=== STARTING WORLD TURN FOR CAMERA TEST ===")
					world_turn_manager.manually_start_world_turn()
			KEY_T:
				# Toggle together mode
				if world_turn_manager:
					world_turn_manager.toggle_together_mode()
					print("Together mode toggled")
			KEY_D:
				# Debug status
				if world_turn_manager:
					world_turn_manager.debug_together_mode_status()
			KEY_P:
				# Debug priority groups
				if world_turn_manager:
					world_turn_manager.debug_priority_groups()
			KEY_C:
				# Check camera position
				_check_camera_position()

func _check_camera_position():
	"""Check the current camera position"""
	var camera = get_tree().current_scene.get_node_or_null("GameCamera")
	if camera:
		print("Camera position: ", camera.global_position)
		print("Camera zoom: ", camera.zoom)
	else:
		print("Could not find GameCamera") 