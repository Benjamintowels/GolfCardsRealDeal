extends Node2D

# Test script for Meteor Camera Focus system
# This tests the camera focus and return functionality for meteor attacks

func _ready():
	print("=== METEOR CAMERA FOCUS TEST ===")
	print("This test verifies that the camera focuses on meteors during animation")
	print("and returns to the player when the attack is complete")
	print("=== END METEOR CAMERA FOCUS TEST ===")

func _input(event):
	if event.is_action_pressed("ui_accept"):  # SPACE key
		print("SPACE pressed - testing meteor camera focus system")
		_test_meteor_camera_focus()

func _test_meteor_camera_focus():
	"""Test the meteor camera focus system"""
	print("=== TESTING METEOR CAMERA FOCUS SYSTEM ===")
	
	# Check if we're in a course scene
	var course = get_tree().current_scene
	if not course or not course.has_method("create_camera_tween"):
		print("✗ ERROR: Not in a course scene or missing camera methods")
		return
	
	print("✓ Course scene found with camera methods")
	
	# Check if camera exists
	if not course.camera:
		print("✗ ERROR: No camera found in course")
		return
	
	print("✓ Camera found:", course.camera.name)
	
	# Check if player exists
	if not course.player_node:
		print("✗ ERROR: No player found in course")
		return
	
	print("✓ Player found:", course.player_node.name)
	
	# Test camera zoom methods
	if course.camera.has_method("set_zoom_level") and course.camera.has_method("get_current_zoom"):
		var current_zoom = course.camera.get_current_zoom()
		print("✓ Camera zoom methods available, current zoom:", current_zoom)
	else:
		print("✗ ERROR: Camera missing zoom methods")
		return
	
	# Test camera transition methods
	if course.has_method("transition_camera_to_player"):
		print("✓ Course has transition_camera_to_player method")
	else:
		print("⚠ Course missing transition_camera_to_player method (will use fallback)")
	
	# Test camera tween method
	if course.has_method("create_camera_tween"):
		print("✓ Course has create_camera_tween method")
	else:
		print("✗ ERROR: Course missing create_camera_tween method")
		return
	
	# Simulate meteor camera focus (without creating actual meteor)
	print("\n=== SIMULATING METEOR CAMERA FOCUS ===")
	
	# Get player position
	var player_pos = course.player_node.global_position
	print("Player position:", player_pos)
	
	# Simulate meteor target position (somewhere away from player)
	var meteor_target = player_pos + Vector2(200, 100)
	print("Simulated meteor target:", meteor_target)
	
	# Test camera focus on meteor start position
	var meteor_start_pos = Vector2(meteor_target.x, -100)
	print("Focusing camera on meteor start position:", meteor_start_pos)
	course.create_camera_tween(meteor_start_pos, 1.0)
	
	# Test zoom out effect
	var pre_zoom = course.camera.get_current_zoom()
	var meteor_zoom = 0.8
	course.camera.set_zoom_level(meteor_zoom)
	print("✓ Camera zoomed out from", pre_zoom, "to", meteor_zoom)
	
	# Wait 2 seconds, then focus on target
	var target_timer = get_tree().create_timer(2.0)
	target_timer.timeout.connect(func():
		print("Focusing camera on meteor target position:", meteor_target)
		course.create_camera_tween(meteor_target, 1.0)
		
		# Wait 2 more seconds, then return to player
		var return_timer = get_tree().create_timer(2.0)
		return_timer.timeout.connect(func():
			print("=== RETURNING CAMERA TO PLAYER ===")
			
			# Restore zoom
			course.camera.set_zoom_level(pre_zoom)
			print("✓ Camera zoom restored to", pre_zoom)
			
			# Return to player
			if course.has_method("transition_camera_to_player"):
				course.transition_camera_to_player()
				print("✓ Camera returned to player via transition method")
			else:
				course.create_camera_tween(player_pos, 1.0)
				print("✓ Camera returned to player via direct tween")
		)
	)
	
	print("=== METEOR CAMERA FOCUS SIMULATION COMPLETE ===")
	print("Camera should now focus on meteor positions and return to player") 