extends Node
class_name UI3DManager

# UI3DManager - Handles 3D user interface
# Optimized for 3D space with clean UI management

signal ui_action(action: String, data: Dictionary)

# UI references
var ui_layer: Control = null
var course_manager: Node = null

# UI elements
var main_ui: Control = null
var game_info_label: Label = null
var controls_label: Label = null
var phase_label: Label = null

# UI state
var current_ui_phase: String = "initializing"
var ui_elements: Dictionary = {}

func setup(ui_layer_param: Control, course_manager_param: Node):
	"""Initialize the 3D UI system"""
	ui_layer = ui_layer_param
	course_manager = course_manager_param
	
	_create_main_ui()
	_connect_signals()
	
	print("✓ UI3DManager setup complete")

func _create_main_ui():
	"""Create the main UI elements"""
	
	# Main UI container
	main_ui = VBoxContainer.new()
	main_ui.position = Vector2(20, 20)
	ui_layer.add_child(main_ui)
	
	# Game info label
	game_info_label = Label.new()
	game_info_label.text = "3D Golf Course"
	game_info_label.add_theme_font_size_override("font_size", 24)
	main_ui.add_child(game_info_label)
	
	# Phase label
	phase_label = Label.new()
	phase_label.text = "Phase: Initializing"
	phase_label.add_theme_font_size_override("font_size", 16)
	main_ui.add_child(phase_label)
	
	# Controls label
	controls_label = Label.new()
	controls_label.text = "Controls:\nWASD - Move camera\nMouse wheel - Zoom\nMiddle mouse - Pan\n\n3D Golf Course System\nGrid floor with billboard sprites"
	controls_label.add_theme_font_size_override("font_size", 16)
	main_ui.add_child(controls_label)
	
	# Store references
	ui_elements["main_ui"] = main_ui
	ui_elements["game_info"] = game_info_label
	ui_elements["phase"] = phase_label
	ui_elements["controls"] = controls_label

func _connect_signals():
	"""Connect UI signals"""
	# Connect to course manager signals if available
	if course_manager and course_manager.has_signal("game_phase_changed"):
		course_manager.game_phase_changed.connect(_on_game_phase_changed)

func _on_game_phase_changed(new_phase: String):
	"""Handle game phase changes"""
	current_ui_phase = new_phase
	update_ui_for_phase(new_phase)

func update_ui_for_phase(phase: String):
	"""Update UI based on current game phase"""
	
	# Update phase label
	if phase_label:
		phase_label.text = "Phase: " + phase.capitalize()
	
	# Phase-specific UI updates
	match phase:
		"ready":
			_show_ready_ui()
		"player_moving":
			_show_player_moving_ui()
		"ball_flying":
			_show_ball_flying_ui()
		"ball_landed":
			_show_ball_landed_ui()
		"hole_completed":
			_show_hole_completed_ui()
		"game_completed":
			_show_game_completed_ui()

func _show_ready_ui():
	"""Show UI for ready phase"""
	if controls_label:
		controls_label.text = "Controls:\nWASD - Move camera\nMouse wheel - Zoom\nMiddle mouse - Pan\n\nReady to play!\nClick to move player"

func _show_player_moving_ui():
	"""Show UI for player moving phase"""
	if controls_label:
		controls_label.text = "Player is moving...\nPlease wait."

func _show_ball_flying_ui():
	"""Show UI for ball flying phase"""
	if controls_label:
		controls_label.text = "Ball is in flight!\nTracking with camera..."

func _show_ball_landed_ui():
	"""Show UI for ball landed phase"""
	if controls_label:
		controls_label.text = "Ball has landed!\nCheck if it's in the hole."

func _show_hole_completed_ui():
	"""Show UI for hole completed phase"""
	if controls_label:
		controls_label.text = "Hole completed!\nLoading next hole..."

func _show_game_completed_ui():
	"""Show UI for game completed phase"""
	if controls_label:
		controls_label.text = "Game completed!\nAll holes finished!"

func show_game_ui():
	"""Show the main game UI"""
	if main_ui:
		main_ui.visible = true

func hide_game_ui():
	"""Hide the main game UI"""
	if main_ui:
		main_ui.visible = false

func show_hole_complete_ui():
	"""Show hole completion UI"""
	# Create a temporary celebration UI
	var celebration_label = Label.new()
	celebration_label.text = "HOLE COMPLETED!"
	celebration_label.add_theme_font_size_override("font_size", 32)
	celebration_label.position = Vector2(400, 300)
	ui_layer.add_child(celebration_label)
	
	# Remove after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): celebration_label.queue_free())

func show_game_complete_ui():
	"""Show game completion UI"""
	# Create game completion UI
	var completion_label = Label.new()
	completion_label.text = "GAME COMPLETED!\nAll 18 holes finished!"
	completion_label.add_theme_font_size_override("font_size", 28)
	completion_label.position = Vector2(350, 250)
	ui_layer.add_child(completion_label)

func update_game_info(info: Dictionary):
	"""Update game information display"""
	if game_info_label:
		var info_text = "3D Golf Course\n"
		info_text += "Hole: " + str(info.get("current_hole", 1)) + "/" + str(info.get("total_holes", 18)) + "\n"
		info_text += "Shots: " + str(info.get("shots_taken", 0)) + "\n"
		info_text += "Score: " + str(info.get("total_score", 0))
		game_info_label.text = info_text

func show_debug_info(info: Dictionary):
	"""Show debug information"""
	var debug_label = Label.new()
	debug_label.text = "Debug Info:\n"
	for key in info:
		debug_label.text += key + ": " + str(info[key]) + "\n"
	debug_label.position = Vector2(20, 400)
	debug_label.add_theme_font_size_override("font_size", 12)
	ui_layer.add_child(debug_label)

# Public API
func get_current_phase() -> String:
	return current_ui_phase

func get_ui_element(element_name: String) -> Control:
	"""Get a specific UI element by name"""
	return ui_elements.get(element_name, null)

func add_custom_ui_element(element: Control, name: String):
	"""Add a custom UI element"""
	ui_layer.add_child(element)
	ui_elements[name] = element

func remove_ui_element(name: String):
	"""Remove a UI element by name"""
	if name in ui_elements:
		var element = ui_elements[name]
		if element and is_instance_valid(element):
			element.queue_free()
		ui_elements.erase(name) 