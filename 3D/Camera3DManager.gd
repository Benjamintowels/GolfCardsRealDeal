extends Node
class_name Camera3DManager

# 3D Camera Manager - Extends 2D camera functionality to 3D space
# Maintains the same smooth tracking, zooming, and panning behavior

# Signals
signal camera_moved
signal camera_zoomed(zoom_level: float)
signal camera_panned
signal ball_tracking_started
signal ball_tracking_stopped

# Camera reference
var camera: Camera3D = null

# Camera tween management
var current_camera_tween: Tween = null

# Camera panning variables
var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var camera_snap_back_pos: Vector3 = Vector3.ZERO

# Camera settings
var cell_size: int = 48
var follow_speed: float = 3.0
var min_zoom: float = 0.6
var max_zoom: float = 3.0
var current_zoom: float = 1.2
var zoom_speed: float = 0.1

# Camera positioning
var camera_height: float = 200.0  # Height above ground
var camera_distance: float = 300.0  # Distance behind target
var camera_angle: float = -30.0  # Look down angle

# References to other systems
var player_manager: Node = null
var grid_manager: Node = null
var background_manager: Node = null

# Pin-to-tee transition management
var pin_to_tee_tween: Tween = null

# Aiming camera tracking
var aiming_tracking_active: bool = false
var aiming_tracking_tween: Tween = null
var last_aiming_position: Vector3 = Vector3.ZERO
var camera_stationary: bool = false

# Idle zoom effect system
var idle_zoom_timer: Timer = null
var idle_zoom_active: bool = false
var idle_zoom_tween: Tween = null
var idle_zoom_duration: float = 1.0
var idle_zoom_target: float = 3.0

func setup(camera_ref: Camera3D, player_mgr: Node, grid_mgr: Node, bg_mgr: Node, cell_size_param: int = 48):
	"""Initialize the 3D camera manager with required references"""
	camera = camera_ref
	player_manager = player_mgr
	grid_manager = grid_mgr
	background_manager = bg_mgr
	cell_size = cell_size_param
	
	# Initialize idle zoom timer
	_setup_idle_zoom_timer()
	
	print("Camera3DManager setup complete")

func update_camera_to_player() -> void:
	"""Update camera to follow player's current position"""
	if not player_manager or not player_manager.get_player_node():
		return
	
	var player_pos = player_manager.get_player_node().global_position
	var target_camera_pos = Vector3(player_pos.x, camera_height, player_pos.z + camera_distance)
	
	# Update camera snap back position
	camera_snap_back_pos = target_camera_pos
	
	# Smoothly follow player during movement
	var current_camera_pos = camera.position
	var new_camera_pos = current_camera_pos.lerp(target_camera_pos, follow_speed * get_process_delta_time())
	camera.position = new_camera_pos
	
	# Emit camera moved signal
	camera_moved.emit()

func smooth_camera_to_player() -> void:
	"""Smoothly tween camera to player's final position"""
	if not player_manager or not player_manager.get_player_node():
		return
	
	var player_pos = player_manager.get_player_node().global_position
	var target_camera_pos = Vector3(player_pos.x, camera_height, player_pos.z + camera_distance)
	
	# Update camera snap back position
	camera_snap_back_pos = target_camera_pos
	
	# Smoothly tween camera to final position
	create_camera_tween(target_camera_pos, 0.9)
	
	# Add smooth zoom in effect after camera position tween completes
	var zoom_timer = get_tree().create_timer(0.4)
	zoom_timer.timeout.connect(func(): 
		zoom_in_after_movement()
		# Start idle zoom timer after zoom in effect completes
		var idle_timer = get_tree().create_timer(0.6)
		idle_timer.timeout.connect(func(): start_idle_zoom_timer())
	)

func create_camera_tween(target_position: Vector3, duration: float = 0.5, transition: Tween.TransitionType = Tween.TRANS_SINE, ease: Tween.EaseType = Tween.EASE_OUT) -> void:
	"""Create a camera tween with proper management to prevent conflicts"""
	# Don't create tweens during aiming phase to avoid interference
	if aiming_tracking_active:
		print("Camera3DManager: Skipping camera tween during aiming phase")
		camera.position = target_position
		return
	
	# Reset idle zoom timer when camera moves
	reset_idle_zoom_timer()
	
	# Store current camera position before killing any existing tween
	var current_camera_position = camera.position
	
	# Kill any existing camera tween first
	kill_current_camera_tween()
	
	# Ensure camera position is maintained after killing the tween
	camera.position = current_camera_position
	
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
	
	# Stop idle zoom timer during NPC interaction
	stop_idle_zoom_timer()
	
	var npc_pos = npc.global_position
	var target_camera_pos = Vector3(npc_pos.x, camera_height, npc_pos.z + camera_distance)
	print("Transitioning camera to NPC at position: ", target_camera_pos)
	create_camera_tween(target_camera_pos, 1.0)
	await current_camera_tween.finished

func transition_camera_to_player() -> void:
	"""Transition camera back to the player"""
	if not player_manager or not player_manager.get_player_node():
		print("ERROR: No player node found for camera transition")
		return
	
	var player_pos = player_manager.get_player_node().global_position
	var target_camera_pos = Vector3(player_pos.x, camera_height, player_pos.z + camera_distance)
	print("Transitioning camera back to player at position: ", target_camera_pos)
	create_camera_tween(target_camera_pos, 1.0)
	await current_camera_tween.finished
	
	# Start idle zoom timer after returning to player
	start_idle_zoom_timer()

func position_camera_on_pin(pin_position: Vector3, start_transition: bool = true, get_tee_center_func: Callable = Callable()) -> void:
	"""Position camera on pin immediately after map building"""
	await get_tree().process_frame
	
	if pin_position == Vector3.ZERO:
		camera.position = Vector3(0, camera_height, camera_distance)
		return
	
	# Position camera directly on pin
	var target_camera_pos = Vector3(pin_position.x, camera_height, pin_position.z + camera_distance)
	camera.position = target_camera_pos
	camera_snap_back_pos = target_camera_pos
	
	# Emit camera moved signal
	camera_moved.emit()
	
	# Only start the transition if requested
	if start_transition and get_tee_center_func.is_valid():
		start_pin_to_tee_transition(get_tee_center_func)
		# Start idle zoom timer after pin-to-tee transition completes
		var idle_timer = get_tree().create_timer(3.5)
		idle_timer.timeout.connect(func(): start_idle_zoom_timer())

func start_pin_to_tee_transition(get_tee_center_func: Callable) -> void:
	"""Start the pin-to-tee camera transition"""
	if not get_tee_center_func.is_valid():
		return
	
	# Wait before starting transition
	var wait_timer = get_tree().create_timer(1.5)
	wait_timer.timeout.connect(func():
		var tee_center = get_tee_center_func.call()
		if tee_center != Vector3.ZERO:
			var target_camera_pos = Vector3(tee_center.x, camera_height, tee_center.z + camera_distance)
			create_camera_tween(target_camera_pos, 2.0)
	)

func start_pin_to_tee_transition_for_new_hole(get_tee_center_func: Callable) -> void:
	"""Start pin-to-tee transition for new hole with zoomed-out view"""
	if not get_tee_center_func.is_valid():
		return
	
	# Wait before starting transition
	var wait_timer = get_tree().create_timer(1.0)
	wait_timer.timeout.connect(func():
		var tee_center = get_tee_center_func.call()
		if tee_center != Vector3.ZERO:
			var target_camera_pos = Vector3(tee_center.x, camera_height, tee_center.z + camera_distance)
			create_camera_tween(target_camera_pos, 2.0)
	)

func cancel_pin_to_tee_transition() -> void:
	"""Cancel any ongoing pin-to-tee transition"""
	if pin_to_tee_tween and pin_to_tee_tween.is_valid():
		pin_to_tee_tween.kill()
		pin_to_tee_tween = null

func start_aiming_camera_tracking(club_distance: float = 800.0) -> void:
	"""Start the aiming camera tracking system"""
	aiming_tracking_active = true
	
	# Stop idle zoom timer during aiming phase
	stop_idle_zoom_timer()
	
	# Cancel any existing camera tweens to prevent conflicts
	kill_current_camera_tween()
	cancel_pin_to_tee_transition()
	
	# If club has max distance of 750 or less, keep camera stationary
	if club_distance <= 750.0:
		camera_stationary = true
		print("Camera3DManager: Started aiming camera tracking (stationary mode) - club distance:", club_distance)
	else:
		camera_stationary = false
		print("Camera3DManager: Started aiming camera tracking (tracking mode) - club distance:", club_distance)

func stop_aiming_camera_tracking() -> void:
	"""Stop the aiming camera tracking and return to player position"""
	aiming_tracking_active = false
	camera_stationary = false
	
	# Kill any ongoing aiming tracking tween
	if aiming_tracking_tween and aiming_tracking_tween.is_valid():
		aiming_tracking_tween.kill()
		aiming_tracking_tween = null
	
	# Return camera to player position
	if player_manager and player_manager.get_player_node():
		var player_pos = player_manager.get_player_node().global_position
		var target_camera_pos = Vector3(player_pos.x, camera_height, player_pos.z + camera_distance)
		
		create_camera_tween(target_camera_pos, 0.8, Tween.TRANS_SINE, Tween.EASE_OUT)
		print("Camera3DManager: Stopped aiming tracking, returning to player position")
		
		# Start idle zoom timer after returning to player
		var idle_timer = get_tree().create_timer(1.0)
		idle_timer.timeout.connect(func(): start_idle_zoom_timer())

func update_aiming_camera_tracking(aiming_circle_position: Vector3) -> void:
	"""Continuous camera following - only tween when target changes significantly"""
	if not aiming_tracking_active or not camera or camera_stationary:
		return
	
	# Convert 2D aiming position to 3D camera position
	var target_position = Vector3(aiming_circle_position.x, camera_height, aiming_circle_position.z + camera_distance)
	
	# Check if camera is far enough from target to warrant a tween
	var distance_to_target = camera.position.distance_to(target_position)
	var camera_close_enough = distance_to_target < 2.0
	var camera_far_enough = distance_to_target > 6.0
	
	print("Camera tracking update - target:", target_position, "camera_distance:", distance_to_target)
	
	# Only create a new tween if camera is far enough from target
	if camera_far_enough and not camera_close_enough:
		# Kill any existing aiming tracking tween first
		if aiming_tracking_tween and aiming_tracking_tween.is_valid():
			aiming_tracking_tween.kill()
		
		# Create a new tween to focus on the aiming circle
		aiming_tracking_tween = get_tree().create_tween()
		aiming_tracking_tween.tween_property(camera, "position", target_position, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		print("Created new tween to:", target_position)
		
		# Clean up the tween reference when it completes
		aiming_tracking_tween.finished.connect(func():
			aiming_tracking_tween = null
		)
	
	# Store the last position for reference
	last_aiming_position = target_position

func handle_camera_panning(event: InputEvent) -> bool:
	"""Handle camera panning input. Returns true if input was handled."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		if event.pressed:
			# Reset idle zoom timer when user starts panning
			reset_idle_zoom_timer()
			
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
				# Snap back to player position when panning ends
				var tween := get_tree().create_tween()
				tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				# Start idle zoom timer after panning ends
				var idle_timer = get_tree().create_timer(0.8)
				idle_timer.timeout.connect(func(): start_idle_zoom_timer())
		return true
	elif event is InputEventMouseMotion and is_panning:
		# Reset idle zoom timer during panning motion
		reset_idle_zoom_timer()
		
		var delta: Vector2 = event.position - pan_start_pos
		var new_position = camera.position
		new_position.x -= delta.x * 2.0
		new_position.z -= delta.y * 2.0
		
		camera.position = new_position
		pan_start_pos = event.position
		return true
	
	return false

func update_camera_snap_back_position(position: Vector3) -> void:
	"""Update the camera snap back position"""
	camera_snap_back_pos = position

func get_camera_snap_back_position() -> Vector3:
	"""Get the current camera snap back position"""
	return camera_snap_back_pos

# ===== ZOOM SYSTEM =====

func set_zoom_level(zoom_level: float) -> void:
	"""Set the camera zoom level"""
	current_zoom = clamp(zoom_level, min_zoom, max_zoom)
	camera.fov = 60.0 / current_zoom
	
	# Emit zoom signal
	camera_zoomed.emit(current_zoom)
	print("Camera3DManager: Zoom set to", current_zoom)

func zoom_in_after_movement() -> void:
	"""Smoothly zoom in after player movement"""
	var zoom_target = 1.2  # Default zoom level
	set_zoom_level(zoom_target)

func get_current_zoom() -> float:
	"""Get the current zoom level"""
	return current_zoom

func get_current_max_zoom() -> float:
	"""Get the current maximum zoom level"""
	return max_zoom

func get_current_min_zoom() -> float:
	"""Get the current minimum zoom level"""
	return min_zoom

# ===== IDLE ZOOM SYSTEM =====

func _setup_idle_zoom_timer() -> void:
	"""Initialize the idle zoom timer"""
	idle_zoom_timer = Timer.new()
	idle_zoom_timer.wait_time = idle_zoom_duration
	idle_zoom_timer.one_shot = true
	idle_zoom_timer.timeout.connect(_on_idle_zoom_timeout)
	add_child(idle_zoom_timer)
	print("Camera3DManager: Idle zoom timer initialized")

func start_idle_zoom_timer() -> void:
	"""Start the idle zoom timer to track when camera should zoom in"""
	if not idle_zoom_timer:
		return
	
	# Don't start idle zoom during aiming phase
	if aiming_tracking_active:
		return
	
	# Don't start if already active
	if idle_zoom_active:
		return
	
	# Reset and start the timer
	idle_zoom_timer.stop()
	idle_zoom_timer.start()
	print("Camera3DManager: Started idle zoom timer")

func stop_idle_zoom_timer() -> void:
	"""Stop the idle zoom timer and cancel any active idle zoom"""
	if not idle_zoom_timer:
		return
	
	idle_zoom_timer.stop()
	
	# Cancel any active idle zoom effect
	if idle_zoom_active:
		_cancel_idle_zoom_effect()
	
	print("Camera3DManager: Stopped idle zoom timer")

func _on_idle_zoom_timeout() -> void:
	"""Called when idle zoom timer expires - start the zoom effect"""
	if not camera:
		return
	
	# Don't start idle zoom during aiming phase
	if aiming_tracking_active:
		return
	
	# Don't start if already active
	if idle_zoom_active:
		return
	
	# Start the idle zoom effect
	_start_idle_zoom_effect()
	print("Camera3DManager: Idle zoom timer expired, starting zoom effect")

func _start_idle_zoom_effect() -> void:
	"""Start the idle zoom effect - smoothly zoom to maximum zoom"""
	if not camera:
		return
	
	idle_zoom_active = true
	
	# Get current zoom and target zoom
	var current_zoom_level = get_current_zoom()
	var target_zoom = min(idle_zoom_target, get_current_max_zoom())
	
	# Create smooth zoom tween
	idle_zoom_tween = get_tree().create_tween()
	idle_zoom_tween.set_trans(Tween.TRANS_SINE)
	idle_zoom_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Tween to maximum zoom over 2 seconds
	idle_zoom_tween.tween_method(func(zoom_level: float):
		set_zoom_level(zoom_level)
	, current_zoom_level, target_zoom, 2.0)
	
	# Clean up when tween completes
	idle_zoom_tween.finished.connect(func():
		idle_zoom_tween = null
		print("Camera3DManager: Idle zoom effect completed")
	)
	
	print("Camera3DManager: Started idle zoom effect from", current_zoom_level, "to", target_zoom)

func _cancel_idle_zoom_effect() -> void:
	"""Cancel the active idle zoom effect"""
	if idle_zoom_tween and idle_zoom_tween.is_valid():
		idle_zoom_tween.kill()
		idle_zoom_tween = null
	
	idle_zoom_active = false
	print("Camera3DManager: Cancelled idle zoom effect")

func reset_idle_zoom_timer() -> void:
	"""Reset the idle zoom timer (called when camera activity is detected)"""
	if not idle_zoom_timer:
		return
	
	# Cancel any active idle zoom effect
	if idle_zoom_active:
		_cancel_idle_zoom_effect()
	
	# Restart the timer
	start_idle_zoom_timer()

func handle_manual_zoom_input() -> void:
	"""Handle manual zoom input from user"""
	reset_idle_zoom_timer()

# Methods required by Course3DManager
func start_ball_tracking(ball: Node3D) -> void:
	"""Start tracking the ball with camera"""
	if not camera or not ball:
		return
	
	aiming_tracking_active = true
	stop_idle_zoom_timer()
	
	# Create ball tracking tween
	aiming_tracking_tween = get_tree().create_tween()
	aiming_tracking_tween.set_trans(Tween.TRANS_SINE)
	aiming_tracking_tween.set_ease(Tween.EASE_OUT)
	
	# Track ball position
	aiming_tracking_tween.tween_method(func(ball_pos: Vector3):
		if ball and is_instance_valid(ball):
			var target_camera_pos = Vector3(ball_pos.x, camera_height, ball_pos.z + camera_distance)
			camera.position = target_camera_pos
			camera_moved.emit()
	, ball.global_position, ball.global_position, 0.1)
	
	ball_tracking_started.emit()
	print("Camera3DManager: Started ball tracking")

func stop_ball_tracking() -> void:
	"""Stop tracking the ball"""
	aiming_tracking_active = false
	
	if aiming_tracking_tween and aiming_tracking_tween.is_valid():
		aiming_tracking_tween.kill()
		aiming_tracking_tween = null
	
	ball_tracking_stopped.emit()
	print("Camera3DManager: Stopped ball tracking")

func update(delta: float) -> void:
	"""Update camera (called by main manager)"""
	# Any per-frame updates can go here
	pass 