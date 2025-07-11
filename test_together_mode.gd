extends Node2D

# Test script for WorldTurnManager Together Mode
# Demonstrates the cascade execution feature where all NPCs execute simultaneously

@onready var world_turn_manager: Node = null
@onready var test_ui: Control = null

func _ready():
	"""Initialize the test scene"""
	print("=== TOGETHER MODE TEST SCENE INITIALIZED ===")
	
	# Find the WorldTurnManager
	world_turn_manager = get_node_or_null("../WorldTurnManager")
	if not world_turn_manager:
		print("ERROR: Could not find WorldTurnManager!")
		return
	
	print("✓ Found WorldTurnManager: ", world_turn_manager.name)
	
	# Create test UI
	_create_test_ui()
	
	# Show initial status
	world_turn_manager.debug_together_mode_status()
	world_turn_manager.debug_priority_groups()
	
	print("=== TOGETHER MODE TEST READY ===")

func _create_test_ui():
	"""Create a simple UI for testing together mode"""
	test_ui = Control.new()
	test_ui.name = "TogetherModeTestUI"
	add_child(test_ui)
	
	# Create a panel for the UI
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(300, 400)
	panel.position = Vector2(10, 10)
	test_ui.add_child(panel)
	
	# Create a VBoxContainer for buttons
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.position = Vector2(10, 10)
	vbox.size = Vector2(280, 380)
	panel.add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.text = "Together Mode Test"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Status label
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Status: Ready"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)
	
	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# Toggle Together Mode button
	var toggle_button = Button.new()
	toggle_button.text = "Toggle Together Mode"
	toggle_button.pressed.connect(_on_toggle_together_mode)
	vbox.add_child(toggle_button)
	
	# Start World Turn button
	var start_turn_button = Button.new()
	start_turn_button.text = "Start World Turn"
	start_turn_button.pressed.connect(_on_start_world_turn)
	vbox.add_child(start_turn_button)
	
	# Force Complete button
	var force_complete_button = Button.new()
	force_complete_button.text = "Force Complete Turn"
	force_complete_button.pressed.connect(_on_force_complete)
	vbox.add_child(force_complete_button)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)
	
	# Duration slider
	var duration_label = Label.new()
	duration_label.text = "Turn Duration: 3.0s"
	vbox.add_child(duration_label)
	
	var duration_slider = HSlider.new()
	duration_slider.min_value = 1.0
	duration_slider.max_value = 10.0
	duration_slider.value = 3.0
	duration_slider.step = 0.5
	duration_slider.value_changed.connect(_on_duration_changed.bind(duration_label))
	vbox.add_child(duration_slider)
	
	# Cascade delay slider
	var delay_label = Label.new()
	delay_label.text = "Cascade Delay: 0.1s"
	vbox.add_child(delay_label)
	
	var delay_slider = HSlider.new()
	delay_slider.min_value = 0.0
	delay_slider.max_value = 1.0
	delay_slider.value = 0.1
	delay_slider.step = 0.05
	delay_slider.value_changed.connect(_on_delay_changed.bind(delay_label))
	vbox.add_child(delay_slider)
	
	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer3)
	
	# Debug buttons
	var debug_status_button = Button.new()
	debug_status_button.text = "Debug Status"
	debug_status_button.pressed.connect(_on_debug_status)
	vbox.add_child(debug_status_button)
	
	var debug_priority_button = Button.new()
	debug_priority_button.text = "Debug Priority Groups"
	debug_priority_button.pressed.connect(_on_debug_priority_groups)
	vbox.add_child(debug_priority_button)
	
	# Update status
	_update_status_label()

func _update_status_label():
	"""Update the status label with current together mode state"""
	if not test_ui or not world_turn_manager:
		return
	
	var status_label = test_ui.get_node_or_null("StatusLabel")
	if not status_label:
		return
	
	var mode_text = "ENABLED" if world_turn_manager.is_together_mode_enabled() else "DISABLED"
	var turn_text = "ACTIVE" if world_turn_manager.is_world_turn_in_progress() else "INACTIVE"
	
	status_label.text = "Together Mode: " + mode_text + "\nWorld Turn: " + turn_text

func _on_toggle_together_mode():
	"""Toggle together mode on/off"""
	if not world_turn_manager:
		return
	
	world_turn_manager.toggle_together_mode()
	_update_status_label()
	print("Together mode toggled")

func _on_start_world_turn():
	"""Start a world turn manually"""
	if not world_turn_manager:
		return
	
	if world_turn_manager.is_world_turn_in_progress():
		print("World turn already in progress!")
		return
	
	world_turn_manager.manually_start_world_turn()
	_update_status_label()
	print("World turn started manually")

func _on_force_complete():
	"""Force complete the current world turn"""
	if not world_turn_manager:
		return
	
	world_turn_manager.force_complete_world_turn()
	_update_status_label()
	print("World turn force completed")

func _on_duration_changed(value: float, label: Label):
	"""Change the together mode turn duration"""
	if not world_turn_manager:
		return
	
	world_turn_manager.set_together_mode_duration(value)
	label.text = "Turn Duration: " + str(value) + "s"
	print("Turn duration set to: ", value, " seconds")

func _on_delay_changed(value: float, label: Label):
	"""Change the cascade delay between priority groups"""
	if not world_turn_manager:
		return
	
	world_turn_manager.set_together_mode_cascade_delay(value)
	label.text = "Cascade Delay: " + str(value) + "s"
	print("Cascade delay set to: ", value, " seconds")

func _on_debug_status():
	"""Show debug status information"""
	if not world_turn_manager:
		return
	
	world_turn_manager.debug_together_mode_status()
	_update_status_label()

func _on_debug_priority_groups():
	"""Show debug priority groups information"""
	if not world_turn_manager:
		return
	
	world_turn_manager.debug_priority_groups()

func _process(delta: float):
	"""Update status label periodically"""
	_update_status_label()

func _input(event: InputEvent):
	"""Handle input for testing"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_T:
				# Toggle together mode with T key
				_on_toggle_together_mode()
			KEY_SPACE:
				# Start world turn with Space key
				_on_start_world_turn()
			KEY_ESCAPE:
				# Force complete with Escape key
				_on_force_complete()
			KEY_D:
				# Debug status with D key
				_on_debug_status()
			KEY_P:
				# Debug priority groups with P key
				_on_debug_priority_groups() 