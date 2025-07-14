extends Node2D

# Test scene for Benny arm height visual effect
# This scene tests that the arm height controller works correctly during SetHeight phase

@onready var benny_char: Node2D
@onready var camera: Camera2D
@onready var arm_height_controller: Node2D

func _ready():
	print("=== BENNY ARM HEIGHT TEST SCENE ===")
	
	# Find the BennyChar node
	benny_char = get_node_or_null("BennyChar")
	if not benny_char:
		print("⚠ BennyChar node not found")
		return
	
	# Find the camera
	camera = get_node_or_null("Camera2D")
	if not camera:
		print("⚠ Camera2D node not found")
		return
	
	# Find the arm height controller
	arm_height_controller = benny_char.get_node_or_null("BennyArmHeightController")
	if not arm_height_controller:
		print("⚠ BennyArmHeightController not found")
		return
	
	# Set up the camera reference for the arm height controller
	if arm_height_controller.has_method("set_camera_reference"):
		arm_height_controller.set_camera_reference(camera)
		print("✓ Camera reference set for arm height controller")
	
	print("=== TEST SCENE READY ===")
	print("Move your mouse up/down to see the arm rotate")
	print("Press SPACE to toggle SetHeight phase")
	print("Press ESC to exit")

var is_set_height_phase = false

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				# Toggle SetHeight phase
				is_set_height_phase = !is_set_height_phase
				if arm_height_controller and arm_height_controller.has_method("set_set_height_phase"):
					arm_height_controller.set_set_height_phase(is_set_height_phase)
					print("SetHeight phase:", "ACTIVE" if is_set_height_phase else "INACTIVE")
			KEY_ESCAPE:
				# Exit test
				get_tree().quit() 