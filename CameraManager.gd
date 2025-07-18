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

func handle_camera_panning(event: InputEvent) -> bool:
	"""Handle camera panning input. Returns true if input was handled."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		is_panning = event.pressed
		if is_panning:
			pan_start_pos = event.position
		else:
			# Snap back to player position when panning ends
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

func cleanup() -> void:
	"""Clean up camera manager resources"""
	if current_camera_tween and current_camera_tween.is_valid():
		current_camera_tween.kill()
		current_camera_tween = null
	
	if pin_to_tee_tween and pin_to_tee_tween.is_valid():
		pin_to_tee_tween.kill()
		pin_to_tee_tween = null 