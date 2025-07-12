extends Control

# Test script for drone zoom system
# This will test the camera zoom limits based on drone equipment

var equipment_manager: EquipmentManager = null
var camera: Camera2D = null

func _ready():
	print("=== DRONE ZOOM SYSTEM TEST ===")
	
	# Find equipment manager
	equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	if not equipment_manager:
		print("ERROR: Could not find EquipmentManager")
		return
	
	# Find camera
	camera = get_tree().current_scene.get_node_or_null("GameCamera")
	if not camera:
		print("ERROR: Could not find GameCamera")
		return
	
	print("✓ Found EquipmentManager and GameCamera")
	print("Current drone status:", equipment_manager.has_drone())
	print("Current drone zoom enabled:", equipment_manager.is_drone_zoom_enabled())
	print("Current camera zoom:", camera.get_current_zoom())

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Test adding drone
				_add_drone()
			KEY_2:
				# Test removing drone
				_remove_drone()
			KEY_3:
				# Test zoom limits
				_test_zoom_limits()
			KEY_4:
				# Show current status
				_show_status()

func _add_drone():
	"""Test adding drone equipment"""
	print("\n=== ADDING DRONE ===")
	
	# Load drone equipment data
	var drone_data = load("res://Equipment/Drone.tres")
	if not drone_data:
		print("ERROR: Could not load Drone.tres")
		return
	
	equipment_manager.add_equipment(drone_data)
	print("✓ Added drone equipment")
	_show_status()

func _remove_drone():
	"""Test removing drone equipment"""
	print("\n=== REMOVING DRONE ===")
	
	# Find drone in equipped equipment
	var drone_data = null
	for equipment in equipment_manager.get_equipped_equipment():
		if equipment.name == "Drone":
			drone_data = equipment
			break
	
	if drone_data:
		equipment_manager.remove_equipment(drone_data)
		print("✓ Removed drone equipment")
	else:
		print("No drone found to remove")
	
	_show_status()

func _test_zoom_limits():
	"""Test zoom limits"""
	print("\n=== TESTING ZOOM LIMITS ===")
	
	if not camera:
		print("ERROR: No camera found")
		return
	
	# Test zooming in and out
	print("Testing zoom in...")
	camera.set_zoom_level(0.1)  # Try to zoom beyond limits
	print("Zoom after setting to 0.1:", camera.get_current_zoom())
	
	print("Testing zoom out...")
	camera.set_zoom_level(5.0)  # Try to zoom beyond limits
	print("Zoom after setting to 5.0:", camera.get_current_zoom())
	
	print("Resetting zoom...")
	camera.reset_zoom()
	print("Zoom after reset:", camera.get_current_zoom())

func _show_status():
	"""Show current status"""
	print("\n=== CURRENT STATUS ===")
	print("Has drone:", equipment_manager.has_drone())
	print("Drone zoom enabled:", equipment_manager.is_drone_zoom_enabled())
	print("Camera zoom:", camera.get_current_zoom() if camera else "No camera")
	print("Equipped equipment count:", equipment_manager.get_equipment_count())
	
	# Show equipped equipment names
	var equipment_names = []
	for equipment in equipment_manager.get_equipped_equipment():
		equipment_names.append(equipment.name)
	print("Equipped equipment:", equipment_names) 