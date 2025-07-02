# ApplyOptimizations.gd
# This script shows exactly how to apply performance optimizations to course_1.gd

# STEP 1: Add these variables to the top of course_1.gd (after existing variables)
"""
var performance_optimizer: Node
var original_process_enabled: bool = true  # Toggle for testing
"""

# STEP 2: Add this to the _ready() function in course_1.gd (at the end)
"""
# Initialize performance optimizer
var optimizer_script = load("res://PerformanceOptimizer.gd")
performance_optimizer = optimizer_script.new()
add_child(performance_optimizer)
print("Performance optimizer added to course")
"""

# STEP 3: Replace the _process function in course_1.gd
"""
func _process(delta):
	if performance_optimizer and not original_process_enabled:
		performance_optimizer.optimized_process(delta, self)
	else:
		# Original _process code (keep this as backup)
		original_process(delta)
"""

# STEP 4: Replace the _input function in course_1.gd
"""
func _input(event: InputEvent) -> void:
	if performance_optimizer and not original_process_enabled:
		performance_optimizer.optimized_input(event, self)
	else:
		# Original _input code (keep this as backup)
		original_input(event)
"""

# STEP 5: Add this function to course_1.gd (for backup of original functions)
"""
func original_process(delta):
	# Copy your original _process code here
	# Update LaunchManager
	launch_manager.chosen_landing_spot = chosen_landing_spot
	launch_manager.selected_club = selected_club
	launch_manager.club_data = club_data
	launch_manager.player_stats = player_stats
	
	if camera_following_ball and launch_manager.golf_ball and is_instance_valid(launch_manager.golf_ball):
		var ball_center = launch_manager.golf_ball.global_position
		var tween := get_tree().create_tween()
		tween.tween_property(camera, "position", ball_center, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	if card_hand_anchor and card_hand_anchor.z_index != 100:
		card_hand_anchor.z_index = 100
		card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
		set_process(false)  # stop checking after setting
	
	if is_aiming_phase and aiming_circle:
		update_aiming_circle()
	
	# Update global Y-sort for all objects (trees, pins, etc.)
	update_all_ysort_z_indices()

func original_input(event: InputEvent) -> void:
	# Copy your original _input code here
	# Handle weapon mode input first
	if weapon_handler and weapon_handler.handle_input(event):
		return
	
	if game_phase == "aiming":
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				enter_launch_phase()
			elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				is_aiming_phase = false
				hide_aiming_circle()
				hide_aiming_instruction()
				game_phase = "move"  # Return to move phase
				_update_player_mouse_facing_state()
	elif game_phase == "launch":
		# Handle launch input through LaunchManager
		print("[DEBUG] In launch phase, handling input through LaunchManager")
		if launch_manager.handle_input(event):
			return
	elif game_phase == "ball_flying":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
			is_panning = event.pressed
			if is_panning:
				pan_start_pos = event.position
			else:
				var tween := get_tree().create_tween()
				tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		elif event is InputEventMouseMotion and is_panning:
			var delta: Vector2 = event.position - pan_start_pos
			camera.position -= delta
			pan_start_pos = event.position
		return  # Don't process other input during ball flight

	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		var node = get_viewport().gui_get_hovered_control()

	
		is_panning = event.pressed
		if is_panning:
			pan_start_pos = event.position
		else:
			var tween := get_tree().create_tween()
			tween.tween_property(camera, "position", camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	elif event is InputEventMouseMotion and is_panning:
		var delta: Vector2 = event.position - pan_start_pos
		camera.position -= delta
		pan_start_pos = event.position

	if player_node:
		player_flashlight_center = get_flashlight_center()

	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("TileDrawer").queue_redraw()

	queue_redraw()
"""

# STEP 6: Add trees to the "trees" group in your tree creation code
"""
# In your tree creation code (where trees are instantiated), add:
tree.add_to_group("trees")
"""

# STEP 7: Add performance monitoring (optional)
"""
func _process(delta):
	# Add this at the beginning of _process for performance monitoring
	if Engine.get_process_frames() % 60 == 0:  # Every 60 frames
		var fps = 1.0 / delta
		print("FPS: ", fps)
	
	# Rest of your _process code...
"""

# STEP 8: Toggle between optimized and original (for testing)
"""
# Add this function to toggle between optimized and original
func toggle_optimization():
	original_process_enabled = !original_process_enabled
	print("Optimization ", "disabled" if original_process_enabled else "enabled")
"""

# USAGE INSTRUCTIONS:
# 1. Copy the code blocks above into your course_1.gd file
# 2. Replace the existing _process and _input functions
# 3. Add the performance_optimizer variable and initialization
# 4. Add trees to the "trees" group
# 5. Test with toggle_optimization() function

# TESTING:
# - Set original_process_enabled = false to use optimizations
# - Set original_process_enabled = true to use original code
# - Compare performance between the two modes 