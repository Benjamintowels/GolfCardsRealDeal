extends Camera2D

# Driving Range Camera - Specialized camera for driving range minigame
signal camera_returned_to_player
signal position_changed

# Camera settings
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var default_zoom: float = 1.2
@export var zoom_speed: float = 0.1
@export var zoom_smoothness: float = 5.0

# Ball tracking settings
@export var ball_tracking_speed: float = 5.0  # Lerp speed for camera following
@export var ball_tracking_offset: Vector2 = Vector2(0, -120)  # Offset to show ball arc

# Parallax settings
@export var parallax_x_threshold: float = 1.0  # Minimum X movement to trigger parallax update

# Tween settings
@export var position_tween_duration: float = 1.5
@export var zoom_tween_duration: float = 1.0

# Internal variables
var target_zoom: float = default_zoom
var camera_following_ball: bool = false
var current_tween: Tween = null
var player_position: Vector2 = Vector2.ZERO
var camera_container: Control = null
var last_position: Vector2 = Vector2.ZERO

# Zoom state
var is_zooming: bool = false
var zoom_tween: Tween = null

func _ready():
	print("DrivingRangeCamera initialized")
	zoom = Vector2(default_zoom, default_zoom)
	target_zoom = default_zoom
	last_position = position
	limit_left = -2000.0
	limit_right = 2000.0
	limit_top = -2000.0
	limit_bottom = 2000.0

func _process(delta):
	if camera_following_ball and camera_container:
		# Try multiple ways to find the ball
		var ball = camera_container.get_node_or_null("GolfBall")
		if not ball:
			# Try to find any ball in the camera container
			for child in camera_container.get_children():
				if child.is_in_group("balls") or child.name.contains("Ball"):
					ball = child
					break
		
		if ball and is_instance_valid(ball):
			# Check if ball is still in flight
			var is_in_flight = false
			if ball.has_method("is_in_flight"):
				is_in_flight = ball.is_in_flight()
			elif "in_flight" in ball:
				is_in_flight = ball.in_flight
			elif ball.has_method("get_velocity"):
				var velocity = ball.get_velocity()
				is_in_flight = velocity.length() > 0.1
			elif "velocity" in ball:
				var velocity = ball.velocity
				is_in_flight = velocity.length() > 0.1
			if is_in_flight:
				# Lerp camera to ball position with offset
				var ball_position = ball.global_position
				var target_position = ball_position + ball_tracking_offset
				position = position.lerp(target_position, ball_tracking_speed * delta)
				check_and_emit_position_changed()
			else:
				print("DrivingRangeCamera: Ball no longer in flight, stopping tracking")
				camera_following_ball = false
		else:
			print("DrivingRangeCamera: No valid ball found, stopping tracking")
			camera_following_ball = false

func setup(player_pos: Vector2, camera_container_ref: Control):
	player_position = player_pos
	camera_container = camera_container_ref
	print("DrivingRangeCamera setup complete - Player position:", player_position)

	# Set camera limits to match the driving range map
	# Driving range is 250 tiles wide, 48 pixels per tile
	limit_left = 0
	limit_right = 250 * 48
	# Keep vertical limits as before
	limit_top = -2000.0
	limit_bottom = 2000.0

func position_on_player():
	if player_position != Vector2.ZERO:
		position = player_position
		check_and_emit_position_changed()
		print("DrivingRangeCamera positioned on player")

func check_and_emit_position_changed():
	var x_movement = abs(position.x - last_position.x)
	if x_movement >= parallax_x_threshold:
		position_changed.emit()
	last_position = position

func start_ball_tracking():
	print("DrivingRangeCamera: Starting ball tracking (frame-based)")
	camera_following_ball = true

func stop_ball_tracking():
	print("DrivingRangeCamera: Stopping ball tracking")
	camera_following_ball = false

func focus_on_ball_landing(ball_position: Vector2):
	print("DrivingRangeCamera: Focusing on ball landing position (tween)")
	if current_tween:
		current_tween.kill()
	var target_position = ball_position + ball_tracking_offset
	current_tween = create_tween()
	current_tween.tween_property(self, "position", target_position, position_tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	current_tween.tween_callback(check_and_emit_position_changed)

func return_to_player():
	if player_position == Vector2.ZERO:
		print("ERROR: Cannot return to player - player position not set")
		return
	print("DrivingRangeCamera: Returning to player (tween)")
	
	# Reset ball tracking state to ensure camera is ready for next shot
	camera_following_ball = false
	
	if current_tween:
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(self, "position", player_position, position_tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	current_tween.tween_callback(check_and_emit_position_changed)
	current_tween.tween_callback(_on_return_to_player_complete)

func _on_return_to_player_complete():
	print("DrivingRangeCamera: Returned to player")
	camera_returned_to_player.emit()

func set_zoom_level(zoom_level: float):
	target_zoom = clamp(zoom_level, min_zoom, max_zoom)
	_start_zoom_tween()

func _start_zoom_tween():
	if zoom_tween:
		zoom_tween.kill()
	zoom_tween = create_tween()
	zoom_tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), zoom_tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func get_current_zoom() -> float:
	return zoom.x

func cleanup():
	print("DrivingRangeCamera: Cleaning up")
	camera_following_ball = false
	if current_tween:
		current_tween.kill()
		current_tween = null
	if zoom_tween:
		zoom_tween.kill()
		zoom_tween = null
