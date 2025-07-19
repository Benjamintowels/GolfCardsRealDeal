extends Camera2D

@export var min_zoom: float = 0.6
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var zoom_smoothness: float = 5.0

var target_zoom: float = 1.2  # Will be set to default_zoom_position in _ready()
var is_zooming: bool = false
var zoom_tween: Tween = null

# Dynamic zoom limits for drone equipment
var current_min_zoom: float = 0.1
var current_max_zoom: float = 3.0

# Default zoom position for the "zoom in" effect after movement
var default_zoom_position: float = 1.5

func _ready():
	# Initialize target_zoom with default position
	target_zoom = default_zoom_position
	
	# Initialize zoom
	zoom = Vector2(target_zoom, target_zoom)
	
	# Initialize dynamic zoom limits
	current_min_zoom = min_zoom
	current_max_zoom = max_zoom
	
	# Set camera limits to prevent excessive panning (ignoring far-out parallax layers)
	limit_left = -2000.0  # Prevent panning too far left
	limit_right = 2000.0  # Prevent panning too far right
	limit_top = -2000.0   # Prevent panning too far up
	limit_bottom = 2000.0 # Prevent panning too far down

func _input(event):
	if event is InputEventMouseButton:
		# Check if we're in aiming phase - if so, don't handle zoom
		var game_state_manager = get_tree().current_scene.get_node_or_null("GameStateManager")
		if game_state_manager and game_state_manager.get_is_aiming_phase():
			# In aiming phase, let the course handle mouse wheel for club cycling
			return
		
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Zoom in (inverted from original)
			set_zoom_level(target_zoom - zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Zoom out (inverted from original)
			set_zoom_level(target_zoom + zoom_speed)

# Public methods for external control
func set_zoom_level(zoom_level: float):
	target_zoom = clamp(zoom_level, current_min_zoom, current_max_zoom)
	_start_zoom_tween()

func zoom_in_after_movement():
	"""Smoothly zoom in to the default zoom position after player movement"""
	# Always zoom to the default zoom position, regardless of current zoom
	var zoom_target = clamp(default_zoom_position, current_min_zoom, current_max_zoom)
	
	# Only zoom if we're not already at the default position
	if abs(target_zoom - zoom_target) > 0.01:  # Small threshold to avoid unnecessary tweens
		print("CameraZoom: Zooming in after movement from", target_zoom, "to default position", zoom_target)
		target_zoom = zoom_target
		_start_zoom_tween()
	else:
		print("CameraZoom: Already at default zoom position, skipping zoom in")

func reset_zoom():
	target_zoom = default_zoom_position
	_start_zoom_tween()

func get_current_zoom() -> float:
	return target_zoom

func set_default_zoom_position(zoom_level: float):
	"""Set the default zoom position for the zoom in effect"""
	default_zoom_position = clamp(zoom_level, current_min_zoom, current_max_zoom)
	print("CameraZoom: Set default zoom position to", default_zoom_position)

func get_default_zoom_position() -> float:
	"""Get the current default zoom position"""
	return default_zoom_position

func get_current_max_zoom() -> float:
	"""Get the current maximum zoom level"""
	return current_max_zoom

func get_current_min_zoom() -> float:
	"""Get the current minimum zoom level"""
	return current_min_zoom

func set_camera_limits(left: float, right: float, top: float, bottom: float):
	"""Set camera limits dynamically"""
	limit_left = left
	limit_right = right
	limit_top = top
	limit_bottom = bottom

func set_zoom_limits(min_zoom_level: float, max_zoom_level: float):
	"""Set zoom limits dynamically (for drone equipment)"""
	current_min_zoom = min_zoom_level
	current_max_zoom = max_zoom_level
	
	# Clamp current zoom to new limits
	if target_zoom < current_min_zoom:
		target_zoom = current_min_zoom
	elif target_zoom > current_max_zoom:
		target_zoom = current_max_zoom
	
	# Apply the new zoom immediately
	_start_zoom_tween()
	print("CameraZoom: Set zoom limits to", current_min_zoom, "-", current_max_zoom)

func _start_zoom_tween():
	"""Start a smooth zoom tween to the target zoom level"""
	# Kill any existing tween
	if zoom_tween:
		zoom_tween.kill()
	
	# Create new tween
	zoom_tween = create_tween()
	zoom_tween.set_trans(Tween.TRANS_SINE)
	zoom_tween.set_ease(Tween.EASE_IN_OUT)
	
	# Tween to target zoom (slower and smoother)
	zoom_tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 1.2)
	
	# Mark as zooming during the tween
	is_zooming = true
	zoom_tween.finished.connect(func(): is_zooming = false) 
