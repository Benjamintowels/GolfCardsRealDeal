extends Node2D

# Test script for idle zoom system
# This script tests the idle zoom functionality by simulating various camera activities

var camera_manager: Node = null
var camera: Node = null
var test_timer: Timer = null

func _ready():
	print("=== IDLE ZOOM SYSTEM TEST ===")
	
	# Find camera manager and camera
	camera_manager = get_tree().current_scene.get_node_or_null("CameraManager")
	camera = get_tree().current_scene.get_node_or_null("GameCamera")
	
	if not camera_manager:
		print("✗ ERROR: CameraManager not found")
		return
	
	if not camera:
		print("✗ ERROR: GameCamera not found")
		return
	
	print("✓ CameraManager found:", camera_manager)
	print("✓ GameCamera found:", camera)
	
	# Start test sequence
	start_idle_zoom_test()

func start_idle_zoom_test():
	"""Start the idle zoom test sequence"""
	print("\n=== STARTING IDLE ZOOM TEST ===")
	
	# Test 1: Check if idle zoom timer starts after setup
	print("\nTest 1: Checking idle zoom timer initialization...")
	if camera_manager.has_method("start_idle_zoom_timer"):
		print("✓ CameraManager has start_idle_zoom_timer method")
		camera_manager.start_idle_zoom_timer()
		print("✓ Started idle zoom timer")
	else:
		print("✗ ERROR: CameraManager missing start_idle_zoom_timer method")
	
	# Test 2: Simulate camera movement to reset timer
	print("\nTest 2: Simulating camera movement to reset timer...")
	if camera_manager.has_method("reset_idle_zoom_timer"):
		print("✓ CameraManager has reset_idle_zoom_timer method")
		camera_manager.reset_idle_zoom_timer()
		print("✓ Reset idle zoom timer")
	else:
		print("✗ ERROR: CameraManager missing reset_idle_zoom_timer method")
	
	# Test 3: Simulate manual zoom input
	print("\nTest 3: Simulating manual zoom input...")
	if camera_manager.has_method("handle_manual_zoom_input"):
		print("✓ CameraManager has handle_manual_zoom_input method")
		camera_manager.handle_manual_zoom_input()
		print("✓ Handled manual zoom input")
	else:
		print("✗ ERROR: CameraManager missing handle_manual_zoom_input method")
	
	# Test 4: Simulate aiming phase (should stop idle zoom)
	print("\nTest 4: Simulating aiming phase...")
	if camera_manager.has_method("start_aiming_camera_tracking"):
		print("✓ CameraManager has start_aiming_camera_tracking method")
		camera_manager.start_aiming_camera_tracking(600.0)
		print("✓ Started aiming camera tracking")
		
		# Wait 2 seconds, then stop aiming
		var aim_timer = get_tree().create_timer(2.0)
		aim_timer.timeout.connect(func():
			print("Stopping aiming phase...")
			if camera_manager.has_method("stop_aiming_camera_tracking"):
				camera_manager.stop_aiming_camera_tracking()
				print("✓ Stopped aiming camera tracking")
			else:
				print("✗ ERROR: CameraManager missing stop_aiming_camera_tracking method")
		)
	else:
		print("✗ ERROR: CameraManager missing start_aiming_camera_tracking method")
	
	# Test 5: Simulate camera panning
	print("\nTest 5: Simulating camera panning...")
	if camera_manager.has_method("handle_camera_panning"):
		print("✓ CameraManager has handle_camera_panning method")
		
		# Simulate middle mouse button press
		var mouse_event = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_MIDDLE
		mouse_event.pressed = true
		mouse_event.position = Vector2(100, 100)
		
		var handled = camera_manager.handle_camera_panning(mouse_event)
		print("✓ Camera panning handled:", handled)
		
		# Simulate middle mouse button release
		mouse_event.pressed = false
		handled = camera_manager.handle_camera_panning(mouse_event)
		print("✓ Camera panning release handled:", handled)
	else:
		print("✗ ERROR: CameraManager missing handle_camera_panning method")
	
	print("\n=== IDLE ZOOM TEST COMPLETE ===")
	print("The idle zoom system should now be active and will zoom in after 1 second of inactivity.")
	print("Try moving the camera, zooming manually, or entering aiming phase to test the reset functionality.") 