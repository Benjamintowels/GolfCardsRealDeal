extends Node3D

# Course3D - Main 3D golf course scene
# Uses optimized Course3DManager for elegant, modular game flow

# 3D Course Manager (main orchestrator)
const Course3DManager := preload("res://3D/3DManagers/Course3DManager.gd")
var course_3d_manager: Course3DManager = null

# 3D scene references
@onready var camera_3d: Camera3D = $Camera3D
@onready var world_container: Node3D = $WorldContainer
@onready var obstacle_container: Node3D = $ObstacleContainer
@onready var ui_layer: Control = $UILayer

# Camera movement for testing
var camera_speed: float = 100.0
var camera_zoom_speed: float = 0.1
var current_zoom: float = 1.2
var min_zoom: float = 0.6
var max_zoom: float = 3.0

func _ready():
	print("🎯 Course3D initializing...")
	
	# Wait one frame to ensure scene is fully ready
	await get_tree().process_frame
	
	# Setup camera with proper 3D positioning
	_setup_3d_camera()
	
	# Initialize the main 3D course manager
	_initialize_course_manager()
	
	# Setup basic UI for testing
	_setup_test_ui()
	
	print("✓ Course3D ready!")

func _setup_3d_camera():
	"""Setup the 3D camera with proper positioning and constraints"""
	
	# Position camera above and behind the center
	camera_3d.position = Vector3(0, 200, 300)
	camera_3d.rotation_degrees = Vector3(-30, 0, 0)  # Look down at the grid
	
	# Set camera properties
	camera_3d.fov = 60.0
	camera_3d.near = 1.0
	camera_3d.far = 2000.0
	
	print("✓ 3D Camera positioned with proper angle")

func _initialize_course_manager():
	"""Initialize the main 3D course manager"""
	
	# Create course manager
	course_3d_manager = Course3DManager.new()
	add_child(course_3d_manager)
	
	# Set scene references (with null checks)
	if camera_3d:
		course_3d_manager.camera_3d = camera_3d
		print("✓ Camera3D reference set")
	
	if world_container:
		course_3d_manager.world_container = world_container
		print("✓ WorldContainer reference set")
	
	if obstacle_container:
		course_3d_manager.obstacle_container = obstacle_container
		print("✓ ObstacleContainer reference set")
	else:
		print("⚠ ObstacleContainer not found in scene, creating fallback")
		obstacle_container = Node3D.new()
		obstacle_container.name = "ObstacleContainer"
		add_child(obstacle_container)
		course_3d_manager.obstacle_container = obstacle_container
		print("✓ ObstacleContainer fallback created and set")
	
	if ui_layer:
		course_3d_manager.ui_layer = ui_layer
		print("✓ UILayer reference set")
	
	# Connect to course manager signals
	course_3d_manager.course_initialized.connect(_on_course_initialized)
	course_3d_manager.game_phase_changed.connect(_on_game_phase_changed)
	course_3d_manager.player_moved.connect(_on_player_moved)
	course_3d_manager.ball_launched.connect(_on_ball_launched)
	
	print("✓ Course3DManager initialized")

func _setup_test_ui():
	"""Setup basic UI for testing the 3D system"""
	
	# Create UI container
	var ui_container = VBoxContainer.new()
	ui_container.position = Vector2(20, 20)
	ui_layer.add_child(ui_container)
	
	# Add title
	var title = Label.new()
	title.text = "3D Golf Course - Optimized System"
	title.add_theme_font_size_override("font_size", 24)
	ui_container.add_child(title)
	
	# Add instructions
	var instructions = Label.new()
	instructions.text = "Controls:\nWASD - Move camera\nMouse wheel - Zoom\nMiddle mouse - Pan\n\n3D Golf Course System\nGrid floor with billboard sprites\nModular manager architecture"
	instructions.add_theme_font_size_override("font_size", 16)
	ui_container.add_child(instructions)
	
	# Add status label
	var status_label = Label.new()
	status_label.text = "Status: Initializing..."
	status_label.add_theme_font_size_override("font_size", 14)
	ui_container.add_child(status_label)
	
	# Store reference for updates
	status_label.set_meta("status_label", true)

func _on_course_initialized():
	"""Called when course manager finishes initialization"""
	print("🎉 Course3D system fully initialized!")
	
	# Update UI status
	_update_status("Ready - 3D Golf Course Active")

func _on_game_phase_changed(new_phase: String):
	"""Handle game phase changes"""
	print("📊 Game phase changed to:", new_phase)
	_update_status("Phase: " + new_phase.capitalize())

func _on_player_moved(new_position: Vector3):
	"""Handle player movement"""
	print("👤 Player moved to:", new_position)

func _on_ball_launched(ball: Node3D):
	"""Handle ball launch"""
	print("⚽ Ball launched!")

func _update_status(message: String):
	"""Update the status label"""
	for child in ui_layer.get_children():
		if child.has_meta("status_label"):
			child.text = message
			break

func _input(event):
	"""Handle input for 3D camera control"""
	
	# Camera zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_zoom = clamp(current_zoom - camera_zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_zoom = clamp(current_zoom + camera_zoom_speed, min_zoom, max_zoom)
			_update_camera_zoom()
	
	# Camera panning with middle mouse
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			var pan_speed = 2.0
			camera_3d.position.x -= event.relative.x * pan_speed
			camera_3d.position.z -= event.relative.y * pan_speed

func _update_camera_zoom():
	"""Update camera zoom level"""
	camera_3d.fov = 60.0 / current_zoom

func _process(delta):
	"""Handle continuous input for camera movement"""
	
	# WASD camera movement
	var movement = Vector3.ZERO
	
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		movement.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		movement.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		movement.z -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		movement.z += 1
	
	if movement != Vector3.ZERO:
		movement = movement.normalized() * camera_speed * delta
		camera_3d.position += movement
		
		# Clamp camera height to stay above ground
		camera_3d.position.y = clamp(camera_3d.position.y, 50.0, 500.0)
		
		# Maintain camera angle (always looking down)
		camera_3d.rotation_degrees.x = -30.0

# Public API
func get_course_manager() -> Course3DManager:
	"""Get the course manager"""
	return course_3d_manager

func get_camera_position() -> Vector3:
	"""Get current camera position"""
	return camera_3d.position

func set_camera_position(position: Vector3):
	"""Set camera position"""
	camera_3d.position = position

func get_camera_zoom() -> float:
	"""Get current camera zoom"""
	return current_zoom

func set_camera_zoom(zoom: float):
	"""Set camera zoom"""
	current_zoom = clamp(zoom, min_zoom, max_zoom)
	_update_camera_zoom() 
