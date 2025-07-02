extends Node

# Performance optimization patches for course_1.gd
# This file contains optimized versions of performance-critical functions

# Optimized Y-sort system
var optimized_ysort: Node
var last_ysort_update: float = 0.0
var ysort_update_interval: float = 0.1  # Update every 0.1 seconds instead of every frame

# Optimized tree collision system
var optimized_tree_collisions: Node
var last_tree_update: float = 0.0
var tree_update_interval: float = 0.2  # Update every 0.2 seconds

# Grid redraw optimization
var last_grid_redraw: float = 0.0
var grid_redraw_interval: float = 0.05  # Redraw every 0.05 seconds
var grid_needs_redraw: bool = false

func _ready():
	# Initialize optimization systems
	setup_optimized_ysort()
	setup_optimized_tree_collisions()
	print("Performance optimizer initialized")

func setup_optimized_ysort():
	"""Setup the optimized Y-sort system"""
	var ysort_script = load("res://OptimizedYSort.gd")
	optimized_ysort = ysort_script.new()
	add_child(optimized_ysort)

func setup_optimized_tree_collisions():
	"""Setup the optimized tree collision system"""
	var tree_script = load("res://OptimizedTree.gd")
	optimized_tree_collisions = tree_script.new()
	add_child(optimized_tree_collisions)

func optimized_process(delta: float, course_instance):
	"""Optimized _process function for course_1.gd"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update LaunchManager (keep this as is)
	course_instance.launch_manager.chosen_landing_spot = course_instance.chosen_landing_spot
	course_instance.launch_manager.selected_club = course_instance.selected_club
	course_instance.launch_manager.club_data = course_instance.club_data
	course_instance.launch_manager.player_stats = course_instance.player_stats
	
	# Camera following (keep this as is)
	if course_instance.camera_following_ball and course_instance.launch_manager.golf_ball and is_instance_valid(course_instance.launch_manager.golf_ball):
		var ball_center = course_instance.launch_manager.golf_ball.global_position
		var tween := get_tree().create_tween()
		tween.tween_property(course_instance.camera, "position", ball_center, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	# Card hand anchor check (keep this as is)
	if course_instance.card_hand_anchor and course_instance.card_hand_anchor.z_index != 100:
		course_instance.card_hand_anchor.z_index = 100
		course_instance.card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_STOP
		course_instance.set_process(false)  # stop checking after setting
	
	# Aiming circle update (keep this as is)
	if course_instance.is_aiming_phase and course_instance.aiming_circle:
		course_instance.update_aiming_circle()
	
	# OPTIMIZED: Y-sort updates with throttling
	if current_time - last_ysort_update >= ysort_update_interval:
		last_ysort_update = current_time
		optimized_ysort.update_camera_position(course_instance.camera.global_position)
		# Update Y-sort for all objects using optimized system
		optimized_ysort.update_all_objects_optimized()
	
	# OPTIMIZED: Tree collision updates with throttling
	if current_time - last_tree_update >= tree_update_interval:
		last_tree_update = current_time
		optimized_tree_collisions.update_tree_collisions(delta)

func optimized_input(event: InputEvent, course_instance):
	"""Optimized _input function for course_1.gd"""
	# Handle weapon mode input first (keep this as is)
	if course_instance.weapon_handler and course_instance.weapon_handler.handle_input(event):
		return
	
	# Game phase handling (keep this as is)
	if course_instance.game_phase == "aiming":
		# ... existing aiming phase code ...
		pass
	elif course_instance.game_phase == "launch":
		# ... existing launch phase code ...
		pass
	elif course_instance.game_phase == "ball_flying":
		# ... existing ball flying phase code ...
		pass
	
	# Mouse button handling (keep this as is)
	if event is InputEventMouseButton and event.pressed:
		# ... existing mouse button code ...
		pass
	elif event is InputEventMouseMotion and course_instance.is_panning:
		# ... existing mouse motion code ...
		pass
	
	# OPTIMIZED: Grid redraw with throttling
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_grid_redraw >= grid_redraw_interval:
		last_grid_redraw = current_time
		grid_needs_redraw = true
		
		# Redraw grid tiles
		for y in course_instance.grid_size.y:
			for x in course_instance.grid_size.x:
				course_instance.grid_tiles[y][x].get_node("TileDrawer").queue_redraw()
		
		course_instance.queue_redraw()
		grid_needs_redraw = false

func optimized_draw(course_instance):
	"""Optimized _draw function for course_1.gd"""
	# Only draw if grid needs redraw
	if grid_needs_redraw:
		course_instance.draw_flashlight_effect()

func cleanup():
	"""Cleanup optimization systems"""
	if optimized_ysort:
		optimized_ysort.clear_update_times()
	if optimized_tree_collisions:
		optimized_tree_collisions.clear_spatial_grid() 