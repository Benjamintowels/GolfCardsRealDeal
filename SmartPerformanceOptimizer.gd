extends Node

# Smart Performance Optimizer
# Only runs expensive operations when they're actually needed

# Game state tracking
var current_game_phase: String = ""
var ball_is_active: bool = false
var ball_is_moving: bool = false
var aiming_phase_active: bool = false
var launch_phase_active: bool = false

# Object movement tracking
var last_ball_position: Vector2 = Vector2.ZERO
var ball_movement_threshold: float = 5.0  # Only update Y-sort if ball moves more than this
var last_camera_position: Vector2 = Vector2.ZERO
var camera_movement_threshold: float = 10.0

# Collision detection optimization
var collision_detection_active: bool = false
var nearby_collision_objects: Array = []
var collision_detection_radius: float = 300.0  # Only check objects within this radius

# Y-sort optimization
var ysort_update_cooldown: float = 0.016  # ~60 FPS for moving objects
var last_ysort_update: float = 0.0
var objects_need_ysort_update: Array = []

# Tree collision optimization
var tree_collision_active: bool = false
var last_tree_update: float = 0.0
var tree_update_interval: float = 0.1  # Only when ball is near trees

func _ready():
	pass

func update_game_state(game_phase: String, ball_active: bool = false, aiming: bool = false, launching: bool = false):
	"""Update the current game state to determine what optimizations to apply"""
	current_game_phase = game_phase
	ball_is_active = ball_active
	aiming_phase_active = aiming
	launch_phase_active = launching
	
	# Determine if collision detection should be active
	collision_detection_active = (aiming_phase_active or launch_phase_active or ball_is_active)
	
	# Determine if tree collision should be active
	tree_collision_active = (ball_is_active and has_nearby_trees())

func update_ball_state(ball_pos: Vector2, ball_velocity: Vector2) -> void:
	"""Update ball state for performance optimization"""
	# Update ball position and velocity
	last_ball_position = ball_pos
	ball_is_moving = ball_velocity.length() > 10.0  # Ball is moving if velocity > 10

func update_projectile_ysort():
	"""Update Y-sort for any knives or grenades in flight"""
	var knives = get_tree().get_nodes_in_group("knives")
	for knife in knives:
		if is_instance_valid(knife) and knife.has_method("is_in_flight") and knife.is_in_flight():
			# Use the knife's own update_y_sort method
			knife.update_y_sort()
	
	var grenades = get_tree().get_nodes_in_group("grenades")
	for grenade in grenades:
		if is_instance_valid(grenade) and grenade.has_method("is_in_flight") and grenade.is_in_flight():
			# Use the grenade's own update_y_sort method
			grenade.update_y_sort()

func update_camera_state(camera_position: Vector2):
	"""Update camera state to determine if Y-sort updates are needed"""
	var camera_moved = camera_position.distance_to(last_camera_position) > camera_movement_threshold
	if camera_moved:
		last_camera_position = camera_position
		# Mark all static objects for Y-sort update when camera moves
		add_object_for_ysort_update("camera_moved")
		
		# Also update explosions and meteors when camera moves
		var explosions = get_tree().get_nodes_in_group("explosions")
		for explosion in explosions:
			if is_instance_valid(explosion):
				Global.update_object_y_sort(explosion, "objects")
		
		var meteors = get_tree().get_nodes_in_group("meteors")
		for meteor in meteors:
			if is_instance_valid(meteor):
				Global.update_object_y_sort(meteor, "objects")
		
		var craters = get_tree().get_nodes_in_group("craters")
		for crater in craters:
			if is_instance_valid(crater):
				Global.update_object_y_sort(crater, "objects")

func smart_process(delta: float, course_instance):
	"""Smart _process function that only runs expensive operations when needed"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Always run essential updates
	update_essential_systems(course_instance)
	
	# Only run Y-sort updates when needed
	if should_update_ysort(current_time):
		update_ysort_systems(course_instance, current_time)
	
	# Only run collision detection when relevant
	if collision_detection_active:
		update_collision_systems(course_instance, current_time)
	
	# Tree collision is now handled by the ball itself during launch mode
	# No need to run tree collision checks here anymore
	pass

func update_essential_systems(course_instance):
	"""Update systems that always need to run"""
	# Update LaunchManager (essential for gameplay)
	# Don't overwrite chosen_landing_spot, selected_club, or club_data if we're in knife mode, grenade mode, or spear mode
	if not course_instance.launch_manager.is_knife_mode and not course_instance.launch_manager.is_grenade_mode and not course_instance.launch_manager.is_spear_mode and not course_instance.launch_manager.is_shuriken_mode:
		course_instance.launch_manager.chosen_landing_spot = course_instance.chosen_landing_spot
		course_instance.launch_manager.selected_club = course_instance.selected_club
		course_instance.launch_manager.club_data = course_instance.club_data
	
	course_instance.launch_manager.player_stats = course_instance.player_stats
	
	# Update ball state for Y-sorting (including knives)
	if course_instance.launch_manager.golf_ball and is_instance_valid(course_instance.launch_manager.golf_ball):
		var ball_pos = course_instance.launch_manager.golf_ball.global_position
		var ball_velocity = course_instance.launch_manager.golf_ball.velocity if "velocity" in course_instance.launch_manager.golf_ball else Vector2.ZERO
		update_ball_state(ball_pos, ball_velocity)
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife):
		# Update knife state for Y-sorting
		var knife_pos = course_instance.launch_manager.throwing_knife.global_position
		var knife_velocity = course_instance.launch_manager.throwing_knife.velocity if "velocity" in course_instance.launch_manager.throwing_knife else Vector2.ZERO
		update_ball_state(knife_pos, knife_velocity)
	elif course_instance.launch_manager.grenade and is_instance_valid(course_instance.launch_manager.grenade):
		# Update grenade state for Y-sorting
		var grenade_pos = course_instance.launch_manager.grenade.global_position
		var grenade_velocity = course_instance.launch_manager.grenade.velocity if "velocity" in course_instance.launch_manager.grenade else Vector2.ZERO
		update_ball_state(grenade_pos, grenade_velocity)
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_spear_mode:
		# Update spear state for Y-sorting (reuses throwing_knife variable)
		var spear_pos = course_instance.launch_manager.throwing_knife.global_position
		var spear_velocity = course_instance.launch_manager.throwing_knife.velocity if "velocity" in course_instance.launch_manager.throwing_knife else Vector2.ZERO
		update_ball_state(spear_pos, spear_velocity)
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_shuriken_mode:
		# Update shuriken state for Y-sorting (reuses throwing_knife variable)
		var shuriken_pos = course_instance.launch_manager.throwing_knife.global_position
		var shuriken_velocity = course_instance.launch_manager.throwing_knife.velocity if "velocity" in course_instance.launch_manager.throwing_knife else Vector2.ZERO
		update_ball_state(shuriken_pos, shuriken_velocity)
	
	# Camera following (when ball or knife is active)
	if course_instance.camera_following_ball:
		var target_position = Vector2.ZERO
		var has_target = false

		# Prioritize knife if it exists and is in flight
		if course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife):
			if course_instance.launch_manager.throwing_knife.is_in_flight():
				target_position = course_instance.launch_manager.throwing_knife.global_position
				has_target = true
		# Check for grenade if it exists and is in flight
		elif course_instance.launch_manager.grenade and is_instance_valid(course_instance.launch_manager.grenade):
			if course_instance.launch_manager.grenade.is_in_flight():
				target_position = course_instance.launch_manager.grenade.global_position
				has_target = true
		# Check for spear if it exists and is in flight
		elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_spear_mode:
			if course_instance.launch_manager.throwing_knife.is_in_flight():
				target_position = course_instance.launch_manager.throwing_knife.global_position
				has_target = true
		# Check for shuriken if it exists and is in flight
		elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_shuriken_mode:
			if course_instance.launch_manager.throwing_knife.is_in_flight():
				target_position = course_instance.launch_manager.throwing_knife.global_position
				has_target = true
		# Otherwise, follow golf ball
		elif course_instance.launch_manager.golf_ball and is_instance_valid(course_instance.launch_manager.golf_ball):
			target_position = course_instance.launch_manager.golf_ball.global_position
			has_target = true

		if has_target:
			# Apply the same vertical offset as aiming mode to show player near bottom of screen and better see arc apex
			target_position.y -= 120
			var tween := get_tree().create_tween()
			tween.tween_property(course_instance.camera, "position", target_position, 0.1).set_trans(Tween.TRANS_LINEAR)
	
	# Card hand anchor check (one-time setup)
	if course_instance.card_hand_anchor and course_instance.card_hand_anchor.z_index != 100:
		course_instance.card_hand_anchor.z_index = 100
		course_instance.card_hand_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through to prevent blocking tile clicks
		# Don't disable the course's process function as it's needed for the game loop
	
	# Aiming circle update (only during aiming)
	if course_instance.is_aiming_phase and course_instance.aiming_circle:
		course_instance.update_aiming_circle()

func should_update_ysort(current_time: float) -> bool:
	"""Determine if Y-sort updates are needed"""
	# Always update if we have objects queued for update
	if not objects_need_ysort_update.is_empty():
		return true
	
	# Update at regular intervals for moving objects
	if current_time - last_ysort_update >= ysort_update_cooldown:
		return ball_is_moving or aiming_phase_active or launch_phase_active
	
	return false

func update_ysort_systems(course_instance, current_time: float):
	"""Update Y-sort systems only when needed"""
	last_ysort_update = current_time
	
	# Update Y-sort for objects that need it
	for object_info in objects_need_ysort_update:
		if object_info.has("node") and is_instance_valid(object_info.node):
			Global.update_object_y_sort(object_info.node, object_info.type)
	
	# Clear the update queue
	objects_need_ysort_update.clear()
	
	# Update grass elements Y-sort when camera moves or ball is active
	if ball_is_active or aiming_phase_active or launch_phase_active:
		var grass_elements = get_tree().get_nodes_in_group("grass_elements")
		for grass in grass_elements:
			if is_instance_valid(grass) and grass.has_method("_update_ysort"):
				grass._update_ysort()
	
	# Update explosions Y-sort when they exist
	var explosions = get_tree().get_nodes_in_group("explosions")
	for explosion in explosions:
		if is_instance_valid(explosion):
			Global.update_object_y_sort(explosion, "objects")
	
	# Update meteors Y-sort when they exist
	var meteors = get_tree().get_nodes_in_group("meteors")
	for meteor in meteors:
		if is_instance_valid(meteor):
			Global.update_object_y_sort(meteor, "objects")
	
	# Update craters Y-sort when they exist
	var craters = get_tree().get_nodes_in_group("craters")
	for crater in craters:
		if is_instance_valid(crater):
			Global.update_object_y_sort(crater, "objects")
	
	# Update camera position for spatial calculations
	update_camera_state(course_instance.camera.global_position)

func update_collision_systems(course_instance, current_time: float):
	"""Update collision detection systems only when relevant"""
	# Only check for nearby collision objects
	update_nearby_collision_objects(course_instance)
	
	# Update collision detection for nearby objects only
	for obj in nearby_collision_objects:
		if is_instance_valid(obj):
			# Update collision detection for this object
			update_object_collision(obj)

func update_nearby_collision_objects(course_instance):
	"""Find collision objects near the ball or aiming area"""
	nearby_collision_objects.clear()
	
	var check_position: Vector2
	if course_instance.launch_manager.golf_ball and is_instance_valid(course_instance.launch_manager.golf_ball):
		check_position = course_instance.launch_manager.golf_ball.global_position
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife):
		check_position = course_instance.launch_manager.throwing_knife.global_position
	elif course_instance.launch_manager.grenade and is_instance_valid(course_instance.launch_manager.grenade):
		check_position = course_instance.launch_manager.grenade.global_position
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_spear_mode:
		check_position = course_instance.launch_manager.throwing_knife.global_position
	elif course_instance.launch_manager.throwing_knife and is_instance_valid(course_instance.launch_manager.throwing_knife) and course_instance.launch_manager.is_shuriken_mode:
		check_position = course_instance.launch_manager.throwing_knife.global_position
	else:
		check_position = course_instance.player_node.global_position if course_instance.player_node else Vector2.ZERO
	
	# Get all collision objects
	var collision_objects = get_tree().get_nodes_in_group("collision_objects")
	
	for obj in collision_objects:
		if is_instance_valid(obj):
			var distance = obj.global_position.distance_to(check_position)
			if distance <= collision_detection_radius:
				nearby_collision_objects.append(obj)

func update_object_collision(obj: Node2D):
	"""Update collision detection for a specific object"""
	# This would contain the specific collision logic for each object type
	# For now, just mark it for Y-sort update if it's moving
	if obj.has_method("is_moving") and obj.is_moving():
		add_object_for_ysort_update(obj)

func update_tree_collisions(course_instance):
	"""Update tree collisions only when ball is near trees"""
	if not course_instance.launch_manager.golf_ball or not is_instance_valid(course_instance.launch_manager.golf_ball):
		return
	
	var ball_position = course_instance.launch_manager.golf_ball.global_position
	var nearby_trees = get_nearby_trees(ball_position)
	
	for tree in nearby_trees:
		if is_instance_valid(tree):
			check_tree_collision(tree, course_instance.launch_manager.golf_ball)

func get_nearby_trees(ball_position: Vector2) -> Array:
	"""Get trees near the ball position"""
	var nearby_trees = []
	var trees = get_tree().get_nodes_in_group("trees")
	
	for tree in trees:
		if is_instance_valid(tree):
			var distance = tree.global_position.distance_to(ball_position)
			if distance <= 200.0:  # Check trees within 200 pixels
				nearby_trees.append(tree)
	
	return nearby_trees

func has_nearby_trees() -> bool:
	"""Check if there are trees near the current ball position"""
	if not get_tree().get_first_node_in_group("balls"):
		return false
	
	var ball = get_tree().get_first_node_in_group("balls")
	if not ball or not is_instance_valid(ball):
		return false
	
	var nearby_trees = get_nearby_trees(ball.global_position)
	return not nearby_trees.is_empty()

func check_tree_collision(tree: Node2D, ball: Node2D):
	"""Check collision between a tree and ball"""
	# This would contain the specific tree collision logic
	# For now, just mark the tree for Y-sort update
	add_object_for_ysort_update(tree)

func add_object_for_ysort_update(obj, object_type: String = "objects"):
	"""Add an object to the Y-sort update queue"""
	# Avoid duplicates
	for existing in objects_need_ysort_update:
		if existing.has("node") and existing.node == obj:
			return
	
	objects_need_ysort_update.append({
		"node": obj,
		"type": object_type
	})

func smart_input(event: InputEvent, course_instance):
	"""Smart _input function that only redraws when necessary"""
	# Handle weapon mode input first
	if course_instance.weapon_handler and course_instance.weapon_handler.handle_input(event):
		return
	
	# Game phase handling (keep existing logic)
	if course_instance.game_phase == "aiming":
		handle_aiming_input(event, course_instance)
	elif course_instance.game_phase == "launch":
		handle_launch_input(event, course_instance)
	elif course_instance.game_phase == "ball_flying":
		handle_ball_flying_input(event, course_instance)
	
	# Mouse handling (keep existing logic)
	handle_mouse_input(event, course_instance)
	
	# OPTIMIZED: Only redraw grid when necessary
	if should_redraw_grid(event):
		redraw_grid(course_instance)

func handle_aiming_input(event: InputEvent, course_instance):
	"""Handle input during aiming phase"""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			course_instance.is_aiming_phase = false
			course_instance.hide_aiming_circle()
			course_instance.hide_aiming_instruction()
			if course_instance.has_method("restore_zoom_after_aiming"):
				course_instance.restore_zoom_after_aiming()
			course_instance.enter_launch_phase()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			course_instance.is_aiming_phase = false
			course_instance.hide_aiming_circle()
			course_instance.hide_aiming_instruction()
			if course_instance.has_method("restore_zoom_after_aiming"):
				course_instance.restore_zoom_after_aiming()
			course_instance.game_phase = "move"
			course_instance._update_player_mouse_facing_state()

func handle_launch_input(event: InputEvent, course_instance):
	"""Handle input during launch phase"""
	if course_instance.launch_manager.handle_input(event):
		return

func handle_ball_flying_input(event: InputEvent, course_instance):
	"""Handle input during ball flying phase"""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		course_instance.is_panning = event.pressed
		if course_instance.is_panning:
			course_instance.pan_start_pos = event.position
		else:
			var tween := get_tree().create_tween()
			tween.tween_property(course_instance.camera, "position", course_instance.camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif event is InputEventMouseMotion and course_instance.is_panning:
		var delta: Vector2 = event.position - course_instance.pan_start_pos
		var new_position = course_instance.camera.position - delta
		
		# Apply camera limits to prevent panning outside bounds
		if course_instance.camera.has_method("limit_left") and course_instance.camera.has_method("limit_right") and course_instance.camera.has_method("limit_top") and course_instance.camera.has_method("limit_bottom"):
			new_position.x = clamp(new_position.x, course_instance.camera.limit_left, course_instance.camera.limit_right)
			new_position.y = clamp(new_position.y, course_instance.camera.limit_top, course_instance.camera.limit_bottom)
		
		course_instance.camera.position = new_position
		course_instance.pan_start_pos = event.position

func handle_mouse_input(event: InputEvent, course_instance):
	"""Handle general mouse input"""
	if event is InputEventMouseButton and event.pressed:
		course_instance.is_panning = event.pressed
		if course_instance.is_panning:
			course_instance.pan_start_pos = event.position
		else:
			var tween := get_tree().create_tween()
			tween.tween_property(course_instance.camera, "position", course_instance.camera_snap_back_pos, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif event is InputEventMouseMotion and course_instance.is_panning:
		var delta: Vector2 = event.position - course_instance.pan_start_pos
		var new_position = course_instance.camera.position - delta
		
		# Apply camera limits to prevent panning outside bounds
		if course_instance.camera.has_method("limit_left") and course_instance.camera.has_method("limit_right") and course_instance.camera.has_method("limit_top") and course_instance.camera.has_method("limit_bottom"):
			new_position.x = clamp(new_position.x, course_instance.camera.limit_left, course_instance.camera.limit_right)
			new_position.y = clamp(new_position.y, course_instance.camera.limit_top, course_instance.camera.limit_bottom)
		
		course_instance.camera.position = new_position
		course_instance.pan_start_pos = event.position

func should_redraw_grid(event: InputEvent) -> bool:
	"""Determine if grid redraw is necessary"""
	# Only redraw on mouse movement or when flashlight effect changes
	return (event is InputEventMouseMotion or 
			(event is InputEventMouseButton and event.pressed) or
			aiming_phase_active or
			ball_is_active)

func redraw_grid(course_instance):
	"""Redraw the grid when necessary"""
	# Update flashlight center
	if course_instance.player_node:
		course_instance.player_flashlight_center = course_instance.get_flashlight_center()
	
	# Redraw grid tiles
	for y in course_instance.grid_size.y:
		for x in course_instance.grid_size.x:
			course_instance.grid_tiles[y][x].get_node("TileDrawer").queue_redraw()
	
	course_instance.queue_redraw()

func cleanup():
	"""Cleanup optimization systems"""
	objects_need_ysort_update.clear()
	nearby_collision_objects.clear() 
