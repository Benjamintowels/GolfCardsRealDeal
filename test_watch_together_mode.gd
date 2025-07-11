extends Node2D

# Test script for Watch equipment together mode functionality
# Verifies that the Watch equipment properly toggles together mode

@onready var world_turn_manager: Node = null
@onready var equipment_manager: Node = null

func _ready():
	"""Initialize the test scene"""
	print("=== WATCH TOGETHER MODE TEST INITIALIZED ===")
	
	# Wait a frame to ensure everything is loaded
	await get_tree().process_frame
	
	# Find the WorldTurnManager and EquipmentManager
	world_turn_manager = get_tree().current_scene.get_node_or_null("WorldTurnManager")
	equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	
	if not world_turn_manager:
		print("ERROR: Could not find WorldTurnManager!")
		return
	
	if not equipment_manager:
		print("ERROR: Could not find EquipmentManager!")
		return
	
	print("✓ Found WorldTurnManager: ", world_turn_manager.name)
	print("✓ Found EquipmentManager: ", equipment_manager.name)
	
	# Test initial state
	print("=== TESTING INITIAL STATE ===")
	var initial_together_mode = world_turn_manager.is_together_mode_enabled()
	print("Initial together mode state: ", "ENABLED" if initial_together_mode else "DISABLED")
	
	# Check if Watch equipment is equipped
	var has_watch = equipment_manager.has_equipment("Watch")
	print("Watch equipment equipped: ", has_watch)
	
	if has_watch:
		print("✓ Watch equipment is equipped - together mode should be enabled")
		if initial_together_mode:
			print("✓ Together mode is correctly enabled by Watch equipment")
		else:
			print("✗ Together mode is not enabled despite Watch equipment")
	else:
		print("✗ Watch equipment is not equipped")
	
	# Test manual together mode toggle
	print("=== TESTING MANUAL TOGGLE ===")
	world_turn_manager.toggle_together_mode()
	var toggled_state = world_turn_manager.is_together_mode_enabled()
	print("After manual toggle: ", "ENABLED" if toggled_state else "DISABLED")
	
	# Test setting specific state
	print("=== TESTING SPECIFIC STATE SETTING ===")
	world_turn_manager.set_together_mode(true)
	var set_true_state = world_turn_manager.is_together_mode_enabled()
	print("After setting to true: ", "ENABLED" if set_true_state else "DISABLED")
	
	world_turn_manager.set_together_mode(false)
	var set_false_state = world_turn_manager.is_together_mode_enabled()
	print("After setting to false: ", "ENABLED" if set_false_state else "DISABLED")
	
	# Test equipment removal and re-addition
	print("=== TESTING EQUIPMENT REMOVAL/ADDITION ===")
	var watch_equipment = preload("res://Equipment/Watch.tres")
	
	# Remove Watch if it exists
	if has_watch:
		equipment_manager.remove_equipment(watch_equipment)
		print("Removed Watch equipment")
		await get_tree().process_frame
		var after_removal_state = world_turn_manager.is_together_mode_enabled()
		print("After removal: ", "ENABLED" if after_removal_state else "DISABLED")
	
	# Add Watch back
	equipment_manager.add_equipment(watch_equipment)
	print("Added Watch equipment back")
	await get_tree().process_frame
	var after_addition_state = world_turn_manager.is_together_mode_enabled()
	print("After addition: ", "ENABLED" if after_addition_state else "DISABLED")
	
	# Show debug information
	print("=== DEBUG INFORMATION ===")
	world_turn_manager.debug_together_mode_status()
	world_turn_manager.debug_priority_groups()
	
	print("=== WATCH TOGETHER MODE TEST COMPLETE ===")

func _input(event: InputEvent):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				# Toggle together mode
				if world_turn_manager:
					world_turn_manager.toggle_together_mode()
					print("Together mode toggled via T key")
			KEY_D:
				# Debug status
				if world_turn_manager:
					world_turn_manager.debug_together_mode_status()
			KEY_P:
				# Debug priority groups
				if world_turn_manager:
					world_turn_manager.debug_priority_groups()
			KEY_SPACE:
				# Start world turn
				if world_turn_manager:
					world_turn_manager.manually_start_world_turn()
					print("World turn started via Space key") 