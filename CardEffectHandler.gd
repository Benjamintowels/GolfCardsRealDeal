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
	elif card.effect_type == "ModifyNext":
		handle_modify_next_card(card)
		return true
	elif card.effect_type == "ModifyNextCard":
		handle_modify_next_card_card(card)
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

func handle_modify_next_card(card: CardData):
	"""Handle cards with ModifyNext effect type"""
	print("CardEffectHandler: Handling ModifyNext card:", card.name)
	
	if card.name == "Sticky Shot":
		course.sticky_shot_active = true
		course.next_shot_modifier = "sticky_shot"
		print("StickyShot effect applied to next shot")
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("StickyShot card used from bag pile")
		
		# Remove only the specific card button, not the entire hand
		remove_specific_card_button(card)
	
	elif card.name == "Bouncey":
		course.bouncey_shot_active = true
		course.next_shot_modifier = "bouncey_shot"
		print("Bouncey effect applied to next shot")
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("Bouncey card used from bag pile")
		
		# Remove only the specific card button, not the entire hand
		remove_specific_card_button(card)
	
	elif card.name == "FireBall":
		course.fire_ball_active = true
		course.next_shot_modifier = "fire_ball"
		print("FireBall effect applied to next shot")
		
		# Play flame sound effect
		play_flame_sound()
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("FireBall card used from bag pile")
		
		# Remove only the specific card button, not the entire hand
		remove_specific_card_button(card)

func play_flame_sound():
	"""Play the flame sound effect when FireBall card is used"""
	# Find the player node to get access to the golf ball scene
	var player = course.player_node
	if player:
		# Create a temporary golf ball instance to play the sound
		var ball_scene = preload("res://GolfBall.tscn")
		var temp_ball = ball_scene.instantiate()
		course.add_child(temp_ball)
		
		# Play the flame sound
		var flame_sound = temp_ball.get_node_or_null("FlameOn")
		if flame_sound:
			flame_sound.play()
			print("Playing flame sound effect")
		else:
			print("Warning: FlameOn sound not found on golf ball")
		
		# Remove the temporary ball after a short delay
		await get_tree().create_timer(0.1).timeout
		temp_ball.queue_free()

func handle_modify_next_card_card(card: CardData):
	"""Handle cards that modify the next card played"""
	print("CardEffectHandler: Handling ModifyNextCard card:", card.name)
	
	if card.name == "Dub":
		course.next_card_doubled = true
		print("Next card effect will be doubled")
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("Dub card used from bag pile")
		
		# Remove only the specific card button, not the entire hand
		remove_specific_card_button(card)

func remove_specific_card_button(card: CardData):
	"""Remove only the specific card button from the UI without affecting other cards"""
	# Find the button that corresponds to this card and remove it
	var movement_buttons_container = course.movement_buttons_container
	if movement_buttons_container:
		for child in movement_buttons_container.get_children():
			if child is TextureButton and child.texture_normal == card.image:
				# Remove from the container and free the button
				movement_buttons_container.remove_child(child)
				child.queue_free()
				
				# Also remove from the movement_buttons array if it exists
				if course.has_method("get_movement_buttons") or "movement_buttons" in course:
					if "movement_buttons" in course and course.movement_buttons.has(child):
						course.movement_buttons.erase(child)
				
				print("Removed card button for:", card.name)
				break

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
		
		# Ball launched with deviation
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
	
	# Position the ball at the player's position (scramble balls are always tee shots)
	var player_sprite = course.player_node.get_node_or_null("Sprite2D")
	var player_size = player_sprite.texture.get_size() * player_sprite.scale if player_sprite and player_sprite.texture else Vector2(course.cell_size, course.cell_size)
	var player_center = course.player_node.global_position + player_size / 2
	
	var ball_local_position = player_center - course.camera_container.global_position
	ball.position = ball_local_position
	ball.cell_size = course.cell_size
	ball.map_manager = course.map_manager
	
	# Add to scene
	course.camera_container.add_child(ball)
	ball.add_to_group("balls")
	ball.add_to_group("scramble_balls")
	
	# Set ball properties - calculate a landing spot for proper targeting
	ball.club_info = course.club_data[course.selected_club] if course.selected_club in course.club_data else {}
	# Determine is_putting from club data, just like LaunchManager does
	var is_putting = course.club_data.get(course.selected_club, {}).get("is_putter", false)
	ball.is_putting = is_putting
	ball.time_percentage = course.charge_time / course.max_charge_time
	
	# Set landing spot - middle ball uses the actual chosen landing spot, others use estimated spots
	if ball_index == 0:
		# Middle ball (index 0) uses the actual chosen landing spot like a normal ball
		ball.chosen_landing_spot = course.chosen_landing_spot
	else:
		# Side balls use estimated landing spots based on their deviated direction
		# Calculate the landing spot in global coordinates
		var ball_global_pos = course.camera_container.global_position + ball.position
		var estimated_distance = power * 0.8  # Rough estimate of how far the ball will travel
		var landing_spot = ball_global_pos + (direction.normalized() * estimated_distance)
		ball.chosen_landing_spot = landing_spot
	
	# Connect signals
	ball.landed.connect(_on_scramble_ball_landed.bind(ball_index))
	ball.out_of_bounds.connect(_on_scramble_ball_out_of_bounds.bind(ball_index))
	
	# Set ball launch position for player collision delay system
	if course.player_node and course.player_node.has_method("set_ball_launch_position"):
		course.player_node.set_ball_launch_position(ball.global_position)
		print("Scramble ball launch position set for player collision delay:", ball.global_position)
	
	# Launch the ball with the deviated direction
	ball.launch(direction, power, height, spin, 0)  # No spin strength category for scramble balls
	
	# Add to tracking arrays
	scramble_balls.append(ball)
	scramble_landing_positions.append(Vector2.ZERO)
	scramble_landing_tiles.append(Vector2i.ZERO)
	
	# Enable camera following for the first ball (center ball)
	if ball_index == 0:
		course.camera_following_ball = true
		course.launch_manager.golf_ball = ball  # Set as the main golf ball for camera following
	
	# Scramble ball launched

func _on_scramble_ball_landed(tile: Vector2i, ball_index: int = -1):
	"""Handle when a scramble ball lands"""
	if not scramble_active:
		return
	
	# Find the ball index if not provided
	if ball_index == -1:
		for i in range(scramble_balls.size()):
			if scramble_balls[i] and scramble_balls[i].global_position == course.launch_manager.golf_ball.global_position:
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
			if scramble_balls[i] and scramble_balls[i].global_position == course.launch_manager.golf_ball.global_position:
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
		
		# Set as the main golf ball for the course via launch_manager
		course.launch_manager.golf_ball = closest_ball
		
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

func clear_all_scramble_balls():
	"""Immediately clear all scramble balls - used when one goes in the hole"""
	print("Clearing all scramble balls due to hole completion")
	
	# Clear all scramble balls
	for i in range(scramble_balls.size()):
		var ball = scramble_balls[i]
		if ball and is_instance_valid(ball):
			# Clear the landing highlight before removing the ball
			if ball.has_method("remove_landing_highlight"):
				ball.remove_landing_highlight()
			ball.queue_free()
	
	# Reset scramble state
	scramble_active = false
	scramble_balls.clear()
	scramble_landing_positions.clear()
	scramble_landing_tiles.clear()
	scramble_ball_landed_count = 0
	
	# Stop camera following
	course.camera_following_ball = false
	
	print("All scramble balls cleared")

func handle_scramble_ball_hole_completion(ball_that_went_in: Node2D):
	"""Handle when a scramble ball goes in the hole"""
	print("Scramble ball went in the hole! Clearing other balls immediately")
	
	# Find which ball went in the hole
	var ball_that_went_in_index = -1
	for i in range(scramble_balls.size()):
		if scramble_balls[i] == ball_that_went_in:
			ball_that_went_in_index = i
			break
	
	if ball_that_went_in_index != -1:
		print("Ball", ball_that_went_in_index, "went in the hole")
		
		# Store the position of the ball that went in the hole
		var hole_position = ball_that_went_in.global_position
		var hole_tile = Vector2i(floor(hole_position.x / course.cell_size), floor(hole_position.y / course.cell_size))
		
		# Clear all other scramble balls immediately
		clear_all_scramble_balls()
		
		# Update course state with the hole position
		course.ball_landing_tile = hole_tile
		course.ball_landing_position = hole_position
		course.waiting_for_player_to_reach_ball = false  # Ball went in hole, no need to wait
		
		# Emit signal for course to handle hole completion
		scramble_complete.emit(hole_position, hole_tile)
		
		print("Scramble hole completion handled - ball went in at:", hole_position)
	else:
		print("Error: Could not find the ball that went in the hole")
		# Fallback: clear all balls anyway
		clear_all_scramble_balls() 
