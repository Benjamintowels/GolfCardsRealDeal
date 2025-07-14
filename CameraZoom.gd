extends Camera2D

@export var min_zoom: float = 0.6
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var zoom_smoothness: float = 5.0

var target_zoom: float = 1.5
var is_zooming: bool = false
var zoom_tween: Tween = null

# Dynamic zoom limits for drone equipment
var current_min_zoom: float = 0.6
var current_max_zoom: float = 3.0

func _ready():
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

func reset_zoom():
	target_zoom = 1.5
	_start_zoom_tween()

func get_current_zoom() -> float:
	return target_zoom

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
	zoom_tween.set_ease(Tween.EASE_OUT)
	
	# Tween to target zoom
	zoom_tween.tween_property(self, "zoom", Vector2(target_zoom, target_zoom), 0.3)
	
	# Mark as zooming during the tween
	is_zooming = true
	zoom_tween.finished.connect(func(): is_zooming = false) 
