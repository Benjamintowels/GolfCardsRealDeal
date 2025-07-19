class_name CameraManager
extends Node

# Camera reference
var camera: Camera2D = null

# Camera tween management
var current_camera_tween: Tween = null

# Camera panning variables
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var camera_snap_back_pos: Vector2 = Vector2.ZERO

# Camera settings
var cell_size: int = 48
var follow_speed: float = 3.0

# References to other systems
var player_manager: Node = null
var grid_manager: Node = null
var background_manager: Node = null

# Pin-to-tee transition management
var pin_to_tee_tween: Tween = null

# Aiming camera tracking
var aiming_tracking_active: bool = false
var aiming_tracking_tween: Tween = null
var last_aiming_position: Vector2 = Vector2.ZERO  # Track last position for reference
var camera_stationary: bool = false  # Toggle for middle mouse button

func setup(camera_ref: Camera2D, player_mgr: Node, grid_mgr: Node, bg_mgr: Node, cell_size_param: int = 48):
	"""Initialize the camera manager with required references"""
	camera = camera_ref
	player_manager = player_mgr
	grid_manager = grid_mgr
	background_manager = bg_mgr
	cell_size = cell_size_param
	
	print("CameraManager setup complete")

func update_camera_to_player() -> void:
	"""Update camera to follow player's current position (called during movement animation)"""
	if not player_manager or not player_manager.get_player_node():
		return
	
	var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center: Vector2 = player_manager.get_player_node().global_position + player_size / 2
	
	# Update camera snap back position
	camera_snap_back_pos = player_center
	
	# Smoothly follow player during movement (small tween for smooth following)
	var current_camera_pos = camera.position
	var target_camera_pos = player_center
	
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, follow_speed * get_process_delta_time())
	camera.position = new_camera_pos

func smooth_camera_to_player() -> void:
	"""Smoothly tween camera to player's final position (called after movement animation completes)"""
	if not player_manager or not player_manager.get_player_node():
		return
	
	var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
	var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
	var player_center: Vector2 = player_manager.get_player_node().global_position + player_size / 2
	
	# Update camera snap back position
	camera_snap_back_pos = player_center
	
	# Smoothly tween camera to final position using managed tween
	create_camera_tween(player_center, 0.9)
	
	# Add smooth zoom in effect after camera position tween completes
	if camera and camera.has_method("zoom_in_after_movement"):
		# Add a small delay to let the camera position tween complete first
		var zoom_timer = get_tree().create_timer(0.4)  # Wait 0.4 seconds
		zoom_timer.timeout.connect(func(): camera.zoom_in_after_movement())

func create_camera_tween(target_position: Vector2, duration: float = 0.5, transition: Tween.TransitionType = Tween.TRANS_SINE, ease: Tween.EaseType = Tween.EASE_OUT) -> void:
	"""Create a camera tween with proper management to prevent conflicts"""
	# Don't create tweens during aiming phase to avoid interference with aiming circle
	if aiming_tracking_active:
		print("CameraManager: Skipping camera tween during aiming phase to avoid interference")
		camera.position = target_position
		return
	
	# Store current camera position before killing any existing tween
	var current_camera_position = camera.position
	
	# Kill any existing camera tween first
	kill_current_camera_tween()
	
	# Ensure camera position is maintained after killing the tween
	camera.position = current_camera_position
	
	# Reset parallax layer offsets when camera is repositioned via tween
	if background_manager:
		background_manager.reset_layer_offsets()
		print("✓ Reset parallax layer offsets before camera tween")
	
	# Create new tween
	current_camera_tween = get_tree().create_tween()
	current_camera_tween.tween_property(camera, "position", target_position, duration).set_trans(transition).set_ease(ease)
	
	# Clean up when tween completes
	current_camera_tween.finished.connect(func(): current_camera_tween = null)

func kill_current_camera_tween() -> void:
	"""Kill any currently running camera tween to prevent conflicts"""
	if current_camera_tween and current_camera_tween.is_valid():
		current_camera_tween.kill()
		current_camera_tween = null

func transition_camera_to_npc(npc: Node) -> void:
	"""Transition camera to focus on the NPC"""
	if not npc:
		print("ERROR: No NPC provided for camera transition")
		return
	
	var npc_pos = npc.global_position
	print("Transitioning camera to NPC at position: ", npc_pos)
	create_camera_tween(npc_pos, 1.0)
	await current_camera_tween.finished

func transition_camera_to_player() -> void:
	"""Transition camera back to the player"""
	if not player_manager or not player_manager.get_player_node():
		print("ERROR: No player node found for camera transition")
		return
	
	var player_center = player_manager.get_player_node().global_position
	print("Transitioning camera back to player at position: ", player_center)
	create_camera_tween(player_center, 1.0)
	await current_camera_tween.finished

func position_camera_on_pin(pin_position: Vector2, start_transition: bool = true, get_tee_center_func: Callable = Callable()) -> void:
	"""Position camera on pin immediately after map building"""
	
	# Add a small delay to ensure everything is properly added to the scene
	await get_tree().process_frame
	
	if pin_position == Vector2.ZERO:
		camera.position = Vector2(0, 0)
		return
	
	# Position camera directly on pin (no tween - immediate positioning)
	camera.position = pin_position
	camera_snap_back_pos = pin_position
	
	# Reset parallax layer offsets when camera is repositioned
	if background_manager:
		background_manager.reset_layer_offsets()
		print("✓ Reset parallax layer offsets after camera repositioning")
	
	# Only start the transition if requested
	if start_transition and get_tee_center_func.is_valid():
		start_pin_to_tee_transition(get_tee_center_func)

func start_pin_to_tee_transition(get_tee_center_func: Callable) -> void:
	"""Start the pin-to-tee transition after the fade-in"""
	
	# Store the tween reference so we can cancel it if needed
	pin_to_tee_tween = get_tree().create_tween()
	pin_to_tee_tween.set_parallel(false)  # Sequential tweens
	
	# Wait 1.5 seconds at pin (as requested)
	pin_to_tee_tween.tween_interval(1.5)
	
	# Tween to tee area
	var tee_center = get_tee_center_func.call()
	var tee_center_global = grid_manager.get_camera_container().position + tee_center
	pin_to_tee_tween.tween_property(camera, "position", tee_center_global, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# Update camera snap back position
	pin_to_tee_tween.tween_callback(func(): 
		camera_snap_back_pos = tee_center_global
	)
	
	# Clean up the tween reference when it completes
	pin_to_tee_tween.finished.connect(func():
		pin_to_tee_tween = null
	)

func cancel_pin_to_tee_transition() -> void:
	"""Cancel the ongoing pin-to-tee transition"""
	if pin_to_tee_tween and pin_to_tee_tween.is_valid():
		print("Cancelling ongoing pin-to-tee transition")
		pin_to_tee_tween.kill()
		pin_to_tee_tween = null

func start_aiming_camera_tracking(club_distance: float = 800.0) -> void:
	"""Start the aiming camera tracking system"""
	aiming_tracking_active = true
	
	# If club has max distance of 750 or less, keep camera stationary
	if club_distance <= 750.0:
		camera_stationary = true
		print("CameraManager: Started aiming camera tracking (stationary mode) - club distance:", club_distance)
	else:
		camera_stationary = false  # Reset stationary state for longer clubs
		print("CameraManager: Started aiming camera tracking (tracking mode) - club distance:", club_distance)

func stop_aiming_camera_tracking() -> void:
	"""Stop the aiming camera tracking and return to player position"""
	aiming_tracking_active = false
	camera_stationary = false  # Reset stationary state
	
	# Kill any ongoing aiming tracking tween
	if aiming_tracking_tween and aiming_tracking_tween.is_valid():
		aiming_tracking_tween.kill()
		aiming_tracking_tween = null
	
	# Return camera to player position
	if player_manager and player_manager.get_player_node():
		var sprite = player_manager.get_player_node().get_node_or_null("Sprite2D")
		var player_size = sprite.texture.get_size() * sprite.scale if sprite and sprite.texture else Vector2(cell_size, cell_size)
		var player_center: Vector2 = player_manager.get_player_node().global_position + player_size / 2
		
		create_camera_tween(player_center, 0.8, Tween.TRANS_SINE, Tween.EASE_OUT)
		print("CameraManager: Stopped aiming tracking, returning to player position")

func update_aiming_camera_tracking(aiming_circle_position: Vector2) -> void:
	"""Continuous camera following - only tween when target changes significantly"""
	if not aiming_tracking_active or not camera or camera_stationary:
		return
	
	# Apply camera limits if they exist
	var target_position = aiming_circle_position
	if camera.has_method("limit_left") and camera.has_method("limit_right") and camera.has_method("limit_top") and camera.has_method("limit_bottom"):
		target_position.x = clamp(target_position.x, camera.limit_left, camera.limit_right)
		target_position.y = clamp(target_position.y, camera.limit_top, camera.limit_bottom)
	
	# Check if camera is far enough from target to warrant a tween
	var distance_to_target = camera.position.distance_to(target_position)
	var camera_close_enough = distance_to_target < 2.0
	var camera_far_enough = distance_to_target > 6.0  # Only tween if camera is more than 6 pixels away
	
	print("Camera tracking update - target:", target_position, "camera_distance:", distance_to_target, "camera_close:", camera_close_enough, "camera_far:", camera_far_enough)
	
	# Only create a new tween if camera is far enough from target
	if camera_far_enough and not camera_close_enough:
		# Kill any existing aiming tracking tween first
		if aiming_tracking_tween and aiming_tracking_tween.is_valid():
			print("Killing existing tween")
			aiming_tracking_tween.kill()
		
		# Create a new tween to focus on the aiming circle
		aiming_tracking_tween = get_tree().create_tween()
		aiming_tracking_tween.tween_property(camera, "position", target_position, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("Created new tween to:", target_position)
		
		# Reset parallax layer offsets when camera moves
		if background_manager:
			background_manager.reset_layer_offsets()
		
		# Clean up the tween reference when it completes
		aiming_tracking_tween.finished.connect(func():
			print("Tween completed")
			aiming_tracking_tween = null
		)
	else:
		print("Skipping tween - target unchanged or camera close enough")
	
	# Store the last position for reference
	last_aiming_position = target_position



func handle_camera_panning(event: InputEvent) -> bool:
	"""Handle camera panning input. Returns true if input was handled."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			# Toggle camera stationary state during aiming
			if aiming_tracking_active:
				camera_stationary = !camera_stationary
				print("Camera stationary:", camera_stationary)
				return true
			else:
				# Normal panning when not aiming
				is_panning = true
				pan_start_pos = event.position
		else:
			# End panning - only snap back if not in aiming mode
			is_panning = false
			if not aiming_tracking_active:
				# Snap back to player position when panning ends (only when not aiming)
				var tween := get_tree().create_tween()
				tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		return true
	elif event is InputEventMouseMotion and is_panning:
		var delta: Vector2 = event.position - pan_start_pos
		var new_position = camera.position - delta
		
		# Apply camera limits to prevent panning outside bounds
		if camera.has_method("limit_left") and camera.has_method("limit_right") and camera.has_method("limit_top") and camera.has_method("limit_bottom"):
			new_position.x = clamp(new_position.x, camera.limit_left, camera.limit_right)
			new_position.y = clamp(new_position.y, camera.limit_top, camera.limit_bottom)
		
		camera.position = new_position
		pan_start_pos = event.position
		return true
	
	return false

func update_camera_snap_back_position(position: Vector2) -> void:
	"""Update the camera snap back position"""
	camera_snap_back_pos = position

func get_camera_snap_back_position() -> Vector2:
	"""Get the current camera snap back position"""
	return camera_snap_back_pos

func get_camera_container() -> Control:
	"""Get the camera container for world-to-grid conversions"""
	return grid_manager.get_camera_container() if grid_manager else null

func get_current_camera_tween() -> Tween:
	"""Get the current camera tween (for external access)"""
	return current_camera_tween

func get_current_pin_to_tee_tween() -> Tween:
	"""Get the current pin-to-tee tween (for external access)"""
	return pin_to_tee_tween

func cleanup() -> void:
	"""Clean up camera manager resources"""
	if current_camera_tween and current_camera_tween.is_valid():
		current_camera_tween.kill()
		current_camera_tween = null
	
	if pin_to_tee_tween and pin_to_tee_tween.is_valid():
		pin_to_tee_tween.kill()
		pin_to_tee_tween = null
	
	if aiming_tracking_tween and aiming_tracking_tween.is_valid():
		aiming_tracking_tween.kill()
		aiming_tracking_tween = null

# ===== ZOOM MANAGEMENT =====

func restore_zoom_after_aiming(course: Node) -> void:
	"""Restore camera zoom to the level it was at before entering aiming phase"""
	if camera and camera.has_method("set_zoom_level") and course.has_meta("pre_aiming_zoom"):
		var pre_aiming_zoom = course.get_meta("pre_aiming_zoom")
		print("Restoring zoom after aiming from", camera.get_current_zoom(), "to", pre_aiming_zoom)
		camera.set_zoom_level(pre_aiming_zoom)
		# Remove the stored zoom level
		course.remove_meta("pre_aiming_zoom") 
