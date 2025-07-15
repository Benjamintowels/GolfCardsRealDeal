extends Control

# Test script for aiming zoom system
# This will test the camera zoom out when entering aiming phase and zoom restoration when exiting

var course: Node = null
var camera: Camera2D = null

func _ready():
	print("=== AIMING ZOOM SYSTEM TEST ===")
	
	# Find course (should be the main scene)
	course = get_tree().current_scene
	if not course or not course.has_method("enter_aiming_phase"):
		print("ERROR: Could not find course with aiming methods")
		return
	
	# Find camera
	camera = get_tree().current_scene.get_node_or_null("GameCamera")
	if not camera:
		print("ERROR: Could not find GameCamera")
		return
	
	print("✓ Found course and GameCamera")
	print("Current camera zoom:", camera.get_current_zoom())
	print("Default zoom position:", camera.get_default_zoom_position())

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Test entering aiming phase
				_test_enter_aiming()
			KEY_2:
				# Test exiting aiming phase (left click)
				_test_exit_aiming_left_click()
			KEY_3:
				# Test exiting aiming phase (right click)
				_test_exit_aiming_right_click()
			KEY_4:
				# Show current status
				_show_status()
			KEY_5:
				# Test zoom restoration
				_test_zoom_restoration()

func _test_enter_aiming():
	"""Test entering aiming phase"""
	print("\n=== TESTING ENTER AIMING PHASE ===")
	
	if not course or not camera:
		print("ERROR: Course or camera not found")
		return
	
	# Store current zoom
	var zoom_before = camera.get_current_zoom()
	print("Zoom before entering aiming:", zoom_before)
	
	# Enter aiming phase
	if course.has_method("enter_aiming_phase"):
		course.enter_aiming_phase()
		print("✓ Called enter_aiming_phase()")
		
		# Wait a moment for the zoom tween to complete
		await get_tree().create_timer(1.5).timeout
		var zoom_after = camera.get_current_zoom()
		print("Zoom after entering aiming:", zoom_after)
		print("Zoom difference:", zoom_after - zoom_before)
		
		# Check if zoomed out (should be less than before)
		if zoom_after < zoom_before:
			print("✓ SUCCESS: Camera zoomed out for aiming")
		else:
			print("✗ FAILED: Camera did not zoom out for aiming")
	else:
		print("ERROR: Course does not have enter_aiming_phase method")

func _test_exit_aiming_left_click():
	"""Test exiting aiming phase with left click (enter launch phase)"""
	print("\n=== TESTING EXIT AIMING (LEFT CLICK) ===")
	
	if not course or not camera:
		print("ERROR: Course or camera not found")
		return
	
	# Make sure we're in aiming phase first
	if not course.is_aiming_phase:
		print("Not in aiming phase, entering first...")
		course.enter_aiming_phase()
		await get_tree().create_timer(1.5).timeout
	
	# Store current zoom
	var zoom_before = camera.get_current_zoom()
	print("Zoom before exiting aiming:", zoom_before)
	
	# Simulate left click to exit aiming and enter launch phase
	if course.has_method("restore_zoom_after_aiming"):
		course.restore_zoom_after_aiming()
		print("✓ Called restore_zoom_after_aiming()")
		
		# Wait a moment for the zoom tween to complete
		await get_tree().create_timer(1.5).timeout
		var zoom_after = camera.get_current_zoom()
		print("Zoom after exiting aiming:", zoom_after)
		print("Zoom difference:", zoom_after - zoom_before)
		
		# Check if zoomed back in (should be more than before)
		if zoom_after > zoom_before:
			print("✓ SUCCESS: Camera zoomed back in after aiming")
		else:
			print("✗ FAILED: Camera did not zoom back in after aiming")
	else:
		print("ERROR: Course does not have restore_zoom_after_aiming method")

func _test_exit_aiming_right_click():
	"""Test exiting aiming phase with right click (return to move phase)"""
	print("\n=== TESTING EXIT AIMING (RIGHT CLICK) ===")
	
	if not course or not camera:
		print("ERROR: Course or camera not found")
		return
	
	# Make sure we're in aiming phase first
	if not course.is_aiming_phase:
		print("Not in aiming phase, entering first...")
		course.enter_aiming_phase()
		await get_tree().create_timer(1.5).timeout
	
	# Store current zoom
	var zoom_before = camera.get_current_zoom()
	print("Zoom before exiting aiming:", zoom_before)
	
	# Simulate right click to exit aiming and return to move phase
	if course.has_method("restore_zoom_after_aiming"):
		course.restore_zoom_after_aiming()
		print("✓ Called restore_zoom_after_aiming()")
		
		# Wait a moment for the zoom tween to complete
		await get_tree().create_timer(1.5).timeout
		var zoom_after = camera.get_current_zoom()
		print("Zoom after exiting aiming:", zoom_after)
		print("Zoom difference:", zoom_after - zoom_before)
		
		# Check if zoomed back in (should be more than before)
		if zoom_after > zoom_before:
			print("✓ SUCCESS: Camera zoomed back in after aiming")
		else:
			print("✗ FAILED: Camera did not zoom back in after aiming")
	else:
		print("ERROR: Course does not have restore_zoom_after_aiming method")

func _show_status():
	"""Show current status"""
	print("\n=== CURRENT STATUS ===")
	print("Is aiming phase:", course.is_aiming_phase if course else "No course")
	print("Camera zoom:", camera.get_current_zoom() if camera else "No camera")
	print("Default zoom position:", camera.get_default_zoom_position() if camera else "No camera")
	print("Has pre_aiming_zoom meta:", course.has_meta("pre_aiming_zoom") if course else "No course")
	
	if course and course.has_meta("pre_aiming_zoom"):
		print("Pre-aiming zoom value:", course.get_meta("pre_aiming_zoom"))

func _test_zoom_restoration():
	"""Test zoom restoration functionality"""
	print("\n=== TESTING ZOOM RESTORATION ===")
	
	if not course or not camera:
		print("ERROR: Course or camera not found")
		return
	
	# Set a specific zoom level
	var test_zoom = 1.0
	print("Setting zoom to", test_zoom)
	camera.set_zoom_level(test_zoom)
	await get_tree().create_timer(0.5).timeout
	
	# Enter aiming phase
	print("Entering aiming phase...")
	course.enter_aiming_phase()
	await get_tree().create_timer(1.5).timeout
	
	# Check if pre_aiming_zoom was stored
	if course.has_meta("pre_aiming_zoom"):
		var stored_zoom = course.get_meta("pre_aiming_zoom")
		print("✓ Pre-aiming zoom stored:", stored_zoom)
		print("Expected stored zoom:", test_zoom)
		
		if abs(stored_zoom - test_zoom) < 0.01:
			print("✓ SUCCESS: Pre-aiming zoom stored correctly")
		else:
			print("✗ FAILED: Pre-aiming zoom not stored correctly")
	else:
		print("✗ FAILED: Pre-aiming zoom not stored")
	
	# Restore zoom
	print("Restoring zoom...")
	course.restore_zoom_after_aiming()
	await get_tree().create_timer(1.5).timeout
	
	# Check if zoom was restored
	var final_zoom = camera.get_current_zoom()
	print("Final zoom:", final_zoom)
	print("Expected zoom:", test_zoom)
	
	if abs(final_zoom - test_zoom) < 0.01:
		print("✓ SUCCESS: Zoom restored correctly")
	else:
		print("✗ FAILED: Zoom not restored correctly")
	
	# Check if meta was removed
	if not course.has_meta("pre_aiming_zoom"):
		print("✓ SUCCESS: Pre-aiming zoom meta removed")
	else:
		print("✗ FAILED: Pre-aiming zoom meta not removed") 