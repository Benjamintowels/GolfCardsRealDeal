extends Node
class_name CardEffectHandler

# Reference to the main course script
var course: Node = null

# Florida Scramble variables
var scramble_active := false
var scramble_balls: Array[Node2D] = []
var scramble_landing_positions: Array[Vector2] = []
var scramble_landing_tiles: Array[Vector2i] = []
var scramble_ball_landed_count := 0
var scramble_total_balls := 3

# Signals
signal scramble_complete(closest_ball_position: Vector2, closest_ball_tile: Vector2i)

func _ready():
	# This will be set by the course script
	pass

func set_course_reference(course_node: Node):
	course = course_node

func handle_card_effect(card: CardData) -> bool:
	"""Handle special card effects. Returns true if effect was handled."""
	
	if card.effect_type == "Scramble":
		handle_scramble_effect(card)
		return true
	
	return false

func handle_scramble_effect(card: CardData):
	"""Handle Florida Scramble effect"""
	print("Activating Florida Scramble effect!")
	scramble_active = true
	scramble_balls.clear()
	scramble_landing_positions.clear()
	scramble_landing_tiles.clear()
	scramble_ball_landed_count = 0
	scramble_total_balls = card.effect_strength
	
	# Discard the card
	if course.deck_manager and course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
		course.create_movement_buttons()

func launch_scramble_balls(launch_direction: Vector2, power: float, height: float, spin: float):
	"""Launch multiple balls for Florida Scramble"""
	if not scramble_active:
		return
	
	print("Launching", scramble_total_balls, "scramble balls")
	
	# Calculate deviation angles (in radians) - create a V-shape spread
	var deviation_angles = []
	var base_deviation = 0.1  # ~23 degrees for V-shape spread (much more reasonable than 8!)
	
	for i in range(scramble_total_balls):
		var angle_offset = 0.0
		if i == 0:
			angle_offset = 0.0  # Center ball - straight ahead
		elif i == 1:
			angle_offset = base_deviation  # Right ball - spreads right
		else:
			angle_offset = -base_deviation  # Left ball - spreads left
		
		deviation_angles.append(angle_offset)
		print("Ball", i, "deviation angle:", rad_to_deg(angle_offset), "degrees")
	
	# Launch each ball with slight deviation
	for i in range(scramble_total_balls):
		var ball_direction = launch_direction.rotated(deviation_angles[i])
		var ball_power = power * (0.95 + randf_range(-0.05, 0.05))  # Slight power variation
		var ball_height = height * (0.95 + randf_range(-0.05, 0.05))  # Slight height variation
		
		print("Ball", i, "original direction:", launch_direction, "final direction:", ball_direction)
		launch_single_scramble_ball(ball_direction, ball_power, ball_height, spin, i)

func launch_single_scramble_ball(direction: Vector2, power: float, height: float, spin: float, ball_index: int):
	"""Launch a single scramble ball"""
	
	# Create the ball
	var ball_scene = preload("res://GolfBall.tscn")
	var ball = ball_scene.instantiate()
	ball.name = "ScrambleBall_" + str(ball_index)
	
	# Set up ball properties
	var ball_area = ball.get_node_or_null("Area2D")
	if ball_area:
		ball_area.collision_layer = 1
		ball_area.collision_mask = 1
	
	# Position the ball
	var player_sprite = course.player_node.get_node_or_null("Sprite2D")
	var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(course.cell_size, course.cell_size)
	var player_center = course.player_node.global_position + player_size / 2
	var ball_position_offset = Vector2(0, -course.cell_size * 0.5)
	player_center += ball_position_offset
	
	var ball_local_position = player_center - course.camera_container.global_position
	ball.position = ball_local_position
	ball.cell_size = course.cell_size
	ball.map_manager = course.map_manager
	
	# Add to scene
	course.camera_container.add_child(ball)
	ball.add_to_group("balls")
	ball.add_to_group("scramble_balls")
	
	# Set ball properties - DON'T override with chosen_landing_spot for scramble balls
	# ball.chosen_landing_spot = course.chosen_landing_spot  # This was causing the override!
	ball.club_info = course.club_data[course.selected_club] if course.selected_club in course.club_data else {}
	ball.is_putting = course.is_putting
	ball.time_percentage = course.charge_time / course.max_charge_time
	
	# Connect signals
	ball.landed.connect(_on_scramble_ball_landed.bind(ball_index))
	ball.out_of_bounds.connect(_on_scramble_ball_out_of_bounds.bind(ball_index))
	
	# Launch the ball with the deviated direction
	ball.launch(direction, power, height, spin, 0)  # No spin strength category for scramble balls
	
	# Add to tracking arrays
	scramble_balls.append(ball)
	scramble_landing_positions.append(Vector2.ZERO)
	scramble_landing_tiles.append(Vector2i.ZERO)
	
	# Enable camera following for the first ball (center ball)
	if ball_index == 0:
		course.camera_following_ball = true
		course.golf_ball = ball  # Set as the main golf ball for camera following
	
	print("Launched scramble ball", ball_index, "with direction:", direction, "power:", power)

func _on_scramble_ball_landed(tile: Vector2i, ball_index: int = -1):
	"""Handle when a scramble ball lands"""
	if not scramble_active:
		return
	
	# Find the ball index if not provided
	if ball_index == -1:
		for i in range(scramble_balls.size()):
			if scramble_balls[i] and scramble_balls[i].global_position == course.golf_ball.global_position:
				ball_index = i
				break
	
	if ball_index == -1 or ball_index >= scramble_balls.size():
		print("Error: Could not find scramble ball index")
		return
	
	print("Scramble ball", ball_index, "landed at tile:", tile)
	
	# Store landing position
	scramble_landing_positions[ball_index] = scramble_balls[ball_index].global_position
	scramble_landing_tiles[ball_index] = tile
	scramble_ball_landed_count += 1
	
	# Check if all balls have landed
	if scramble_ball_landed_count >= scramble_total_balls:
		determine_closest_ball_to_pin()

func _on_scramble_ball_out_of_bounds(ball_index: int = -1):
	"""Handle when a scramble ball goes out of bounds"""
	if not scramble_active:
		return
	
	# Find the ball index if not provided
	if ball_index == -1:
		for i in range(scramble_balls.size()):
			if scramble_balls[i] and scramble_balls[i].global_position == course.golf_ball.global_position:
				ball_index = i
				break
	
	if ball_index == -1 or ball_index >= scramble_balls.size():
		print("Error: Could not find scramble ball index for out of bounds")
		return
	
	print("Scramble ball", ball_index, "went out of bounds")
	
	# Mark as landed at starting position (penalty)
	scramble_landing_positions[ball_index] = course.player_node.global_position
	scramble_landing_tiles[ball_index] = course.player_grid_pos
	scramble_ball_landed_count += 1
	
	# Check if all balls have landed
	if scramble_ball_landed_count >= scramble_total_balls:
		determine_closest_ball_to_pin()

func determine_closest_ball_to_pin():
	"""Determine which ball landed closest to the pin"""
	print("All scramble balls landed, determining closest to pin...")
	
	# Find pin position
	var pin_position = course.find_pin_position()
	if pin_position == Vector2.ZERO:
		print("Warning: No pin found, using first ball as default")
		complete_scramble_with_ball(0)
		return
	
	# Calculate distances to pin
	var closest_ball_index = 0
	var closest_distance = INF
	
	for i in range(scramble_landing_positions.size()):
		var ball_position = scramble_landing_positions[i]
		var distance_to_pin = ball_position.distance_to(pin_position)
		
		print("Ball", i, "distance to pin:", distance_to_pin)
		
		if distance_to_pin < closest_distance:
			closest_distance = distance_to_pin
			closest_ball_index = i
	
	print("Closest ball to pin is ball", closest_ball_index, "at distance", closest_distance)
	
	# Complete the scramble with the closest ball
	complete_scramble_with_ball(closest_ball_index)

func complete_scramble_with_ball(ball_index: int):
	"""Complete the scramble effect using the specified ball"""
	print("Completing scramble with ball", ball_index)
	
	# Get the closest ball's position
	var closest_position = scramble_landing_positions[ball_index]
	var closest_tile = scramble_landing_tiles[ball_index]
	var closest_ball = scramble_balls[ball_index]
	
	# Clear all scramble balls EXCEPT the closest one
	for i in range(scramble_balls.size()):
		var ball = scramble_balls[i]
		if ball and is_instance_valid(ball) and i != ball_index:
			# Clear the landing highlight before removing the ball
			if ball.has_method("remove_landing_highlight"):
				ball.remove_landing_highlight()
			ball.queue_free()
	
	# Set the closest ball as the main golf ball for the course
	if closest_ball and is_instance_valid(closest_ball):
		# Remove from scramble groups and add to normal ball group
		closest_ball.remove_from_group("scramble_balls")
		closest_ball.add_to_group("balls")
		
		# Set as the main golf ball for the course
		course.golf_ball = closest_ball
		
		# Connect the ball to normal course signals
		closest_ball.landed.disconnect(_on_scramble_ball_landed)
		closest_ball.out_of_bounds.disconnect(_on_scramble_ball_out_of_bounds)
		
		# The ball should already have the normal course signals connected
		# since it was created as a normal golf ball
	
	# Reset scramble state
	scramble_active = false
	scramble_balls.clear()
	scramble_landing_positions.clear()
	scramble_landing_tiles.clear()
	scramble_ball_landed_count = 0
	
	# Update course state with the closest ball's position
	course.ball_landing_tile = closest_tile
	course.ball_landing_position = closest_position
	course.waiting_for_player_to_reach_ball = true
	
	# Stop camera following
	course.camera_following_ball = false
	
	# Emit signal for course to handle
	scramble_complete.emit(closest_position, closest_tile)
	
	print("Scramble effect completed. Ball landed at:", closest_position, "tile:", closest_tile)
	print("Closest ball kept as active ball for next shot")

func is_scramble_active() -> bool:
	return scramble_active

func get_scramble_ball_count() -> int:
	return scramble_balls.size() 