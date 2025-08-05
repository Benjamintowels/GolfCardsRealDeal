extends Camera2D

@export var follow_speed: float = 2.0  # How fast the camera follows the mouse
@export var max_offset: float = 100.0  # Maximum distance the camera can move from center
@export var boundary_margin: float = 50.0  # Margin from scene edges

var target_position: Vector2
var scene_bounds: Rect2
var is_active: bool = true

func _ready():
	# Set the camera as the current camera
	make_current()
	
	# Calculate scene bounds based on the viewport size and scene content
	# You may need to adjust these values based on your actual scene size
	scene_bounds = Rect2(
		boundary_margin, 
		boundary_margin, 
		get_viewport().get_visible_rect().size.x - boundary_margin * 2,
		get_viewport().get_visible_rect().size.y - boundary_margin * 2
	)
	
	# Set initial position to center
	position = get_viewport().get_visible_rect().size / 2

func _process(delta):
	# Commented out for now
	pass
	# if not is_active:
	# 	return
	
	# # Get mouse position in world coordinates
	# var mouse_pos = get_global_mouse_position()
	
	# # Calculate the center of the viewport
	# var viewport_center = get_viewport().get_visible_rect().size / 2
	
	# # Calculate the offset from center
	# var offset = mouse_pos - viewport_center
	
	# # Clamp the offset to the maximum allowed distance
	# offset = offset.limit_length(max_offset)
	
	# # Calculate target position
	# target_position = viewport_center + offset
	
	# # Clamp to scene boundaries
	# target_position.x = clamp(target_position.x, scene_bounds.position.x, scene_bounds.end.x)
	# target_position.y = clamp(target_position.y, scene_bounds.position.y, scene_bounds.end.y)
	
	# # Smoothly move camera towards target position
	# position = position.lerp(target_position, follow_speed * delta)

func deactivate():
	"""Deactivate the camera when transitioning to other scenes"""
	is_active = false
	# Reset position to center when deactivating
	position = get_viewport().get_visible_rect().size / 2

func activate():
	"""Reactivate the camera"""
	is_active = true
