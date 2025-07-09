extends Control

# Test script for the parallax background system
# This demonstrates how to use the background manager and parallax system

@onready var background_manager: Node = $BackgroundManager
@onready var camera: Camera2D = $Camera2D

# Test camera movement
var camera_speed: float = 100.0
var camera_direction: Vector2 = Vector2.RIGHT

func _ready():
	# Set up camera
	camera.add_to_group("camera")
	
	# Set camera reference for background manager
	background_manager.set_camera_reference(camera)
	
	# Set initial theme
	background_manager.set_theme("course1")
	
	print("✓ Test parallax background initialized")
	print("✓ Available themes: ", background_manager.get_available_themes())
	print("✓ Current theme: ", background_manager.get_current_theme())

func _process(delta):
	# Move camera for testing
	move_camera(delta)
	
	# Handle input for theme switching
	handle_theme_input()

func move_camera(delta: float) -> void:
	"""Move camera for testing parallax effect"""
	var movement = camera_direction * camera_speed * delta
	camera.position += movement
	
	# Reverse direction when camera moves too far
	if camera.position.x > 1000:
		camera_direction = Vector2.LEFT
	elif camera.position.x < -1000:
		camera_direction = Vector2.RIGHT

func handle_theme_input() -> void:
	"""Handle keyboard input for theme switching"""
	if Input.is_action_just_pressed("ui_accept"):  # Spacebar
		cycle_theme()
	elif Input.is_action_just_pressed("ui_left"):  # Left arrow
		background_manager.set_theme("forest")
	elif Input.is_action_just_pressed("ui_right"):  # Right arrow
		background_manager.set_theme("desert")
	elif Input.is_action_just_pressed("ui_up"):  # Up arrow
		background_manager.set_theme("ocean")
	elif Input.is_action_just_pressed("ui_down"):  # Down arrow
		background_manager.set_theme("course1")

func cycle_theme() -> void:
	"""Cycle through available themes"""
	var themes = background_manager.get_available_themes()
	var current_theme = background_manager.get_current_theme()
	var current_index = themes.find(current_theme)
	
	var next_index = (current_index + 1) % themes.size()
	var next_theme = themes[next_index]
	
	background_manager.set_theme(next_theme)
	print("✓ Switched to theme: ", next_theme)

func _input(event):
	# Handle mouse wheel for camera zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom *= 0.9
		
		# Clamp zoom
		camera.zoom = camera.zoom.clamp(Vector2(0.1, 3.0), Vector2(0.1, 3.0))
	
	# Handle middle mouse for camera panning
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
			camera.position -= event.relative

func _on_theme_changed(theme_name: String):
	"""Called when background theme changes"""
	print("✓ Theme changed to: ", theme_name)
	
	# Display theme info
	var info = background_manager.get_background_info()
	print("✓ Background info: ", info) 
