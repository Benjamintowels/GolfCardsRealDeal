extends Camera2D

@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var zoom_speed: float = 0.1
@export var zoom_smoothness: float = 5.0

var target_zoom: float = 1.0
var is_zooming: bool = false

func _ready():
	# Initialize zoom
	zoom = Vector2(target_zoom, target_zoom)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			# Zoom in (inverted from original)
			target_zoom = clamp(target_zoom - zoom_speed, min_zoom, max_zoom)
			is_zooming = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			# Zoom out (inverted from original)
			target_zoom = clamp(target_zoom + zoom_speed, min_zoom, max_zoom)
			is_zooming = true

func _process(delta):
	if is_zooming:
		# Smooth zoom interpolation
		var current_zoom_x = zoom.x
		var current_zoom_y = zoom.y
		
		var new_zoom_x = lerp(current_zoom_x, target_zoom, zoom_smoothness * delta)
		var new_zoom_y = lerp(current_zoom_y, target_zoom, zoom_smoothness * delta)
		
		zoom = Vector2(new_zoom_x, new_zoom_y)
		
		# Check if we're close enough to target to stop zooming
		if abs(new_zoom_x - target_zoom) < 0.01 and abs(new_zoom_y - target_zoom) < 0.01:
			zoom = Vector2(target_zoom, target_zoom)
			is_zooming = false

# Public methods for external control
func set_zoom_level(zoom_level: float):
	target_zoom = clamp(zoom_level, min_zoom, max_zoom)
	is_zooming = true

func reset_zoom():
	target_zoom = 1.0
	is_zooming = true

func get_current_zoom() -> float:
	return target_zoom 