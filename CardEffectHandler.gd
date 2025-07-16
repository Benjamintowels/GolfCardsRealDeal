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

# RedJay ball movement tracking
var redjay_moving_ball := false
var redjay_ball_original_position: Vector2 = Vector2.ZERO
var redjay_moved_ball: Node2D = null  # Track the specific ball that was moved by RedJay

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
	elif card.effect_type == "Teleport":
		handle_teleport_effect(card)
		return true
	elif card.effect_type == "Draw":
		handle_draw_effect(card)
		return true
	elif card.effect_type == "ExtraTurn":
		handle_extra_turn_effect(card)
		return true
	elif card.effect_type == "Block":
		handle_block_effect(card)
		return true
	elif card.effect_type == "Arrange":
		handle_arrange_effect(card)
		return true
	elif card.effect_type == "AnimalHelp":
		handle_animal_help_effect(card)
		return true
	elif card.effect_type == "PlayerEffect":
		handle_player_effect(card)
		return true
	elif card.effect_type == "Vampire":
		handle_vampire_effect(card)
		return true
	elif card.effect_type == "Dodge":
		handle_dodge_effect(card)
		return true
	elif card.effect_type == "BagAdjust":
		handle_bag_adjust_effect(card)
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
	scramble_total_balls = card.get_effective_strength()
	
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
	
	elif card.name == "IceBall":
		course.ice_ball_active = true
		course.next_shot_modifier = "ice_ball"
		print("IceBall effect applied to next shot")
		
		# Play ice sound effect (using a different sound or silence for now)
		play_ice_sound()
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("IceBall card used from bag pile")
		
		# Remove only the specific card button, not the entire hand
		remove_specific_card_button(card)
	
	elif card.name == "Explosive":
		course.explosive_shot_active = true
		course.next_shot_modifier = "explosive_shot"
		print("Explosive effect applied to next shot")
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("Explosive card used from bag pile")
		
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

func play_ice_sound():
	"""Play the ice sound effect when IceBall card is used"""
	# Find the player node to get access to the golf ball scene
	var player = course.player_node
	if player:
		# Create a temporary golf ball instance to play the sound
		var ball_scene = preload("res://GolfBall.tscn")
		var temp_ball = ball_scene.instantiate()
		course.add_child(temp_ball)
		
		# Play the ice sound
		var ice_sound = temp_ball.get_node_or_null("IceOn")
		if ice_sound:
			ice_sound.play()
			print("Playing ice sound effect")
		else:
			print("Warning: IceOn sound not found on golf ball")
		
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
	
	elif card.name == "RooBoost":
		course.rooboost_active = true
		course.next_movement_card_rooboost = true
		print("RooBoost effect applied to next movement card")
		
		# Handle card discard - could be from hand or bag pile
		if course.deck_manager.hand.has(card):
			course.deck_manager.discard(card)
			course.card_stack_display.animate_card_discard(card.name)
			course.update_deck_display()
		else:
			# Card is from bag pile during club selection - just animate discard
			course.card_stack_display.animate_card_discard(card.name)
			print("RooBoost card used from bag pile")
		
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

func handle_teleport_effect(card: CardData):
	"""Handle teleport effect - move player to ball's current location"""
	print("CardEffectHandler: Handling Teleport card:", card.name)
	
	# Get the ball's current position
	var ball_position = get_ball_position()
	if ball_position == Vector2.ZERO:
		print("Warning: No ball found for teleport")
		return
	
	# Create portal effect at player's current position
	create_teleport_portal(course.player_node.global_position)
	
	# Move player to ball position
	teleport_player_to_ball(ball_position)
	
	# Handle card discard
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Teleport card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("Teleport complete - player can continue their turn")

func handle_draw_effect(card: CardData):
	"""Handle Draw effect cards - draw additional cards from action deck"""
	print("CardEffectHandler: Handling Draw card:", card.name)
	
	# Get the number of cards to draw from effective strength
	var cards_to_draw = card.get_effective_strength()
	print("Drawing", cards_to_draw, "cards from action deck")
	
	# Draw cards from action deck and add to hand
	course.deck_manager.draw_action_cards_to_hand(cards_to_draw)
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Draw card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	# Update the movement buttons to show the new cards in hand
	if course.has_method("create_movement_buttons"):
		course.create_movement_buttons()
	
	print("Draw effect completed - drew", cards_to_draw, "cards")

func handle_extra_turn_effect(card: CardData):
	"""Handle ExtraTurn effect - give the player extra turns based on effective strength"""
	print("CardEffectHandler: Handling ExtraTurn card:", card.name)
	
	# Get the number of extra turns from effective strength
	var extra_turns = card.get_effective_strength()
	print("Giving player", extra_turns, "extra turns")
	
	# Discard the card
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	# Give the player the extra turns
	for i in range(extra_turns):
		course.give_extra_turn()
	
	print("Player received", extra_turns, "extra turns due to ExtraTurn card.")

func get_ball_position() -> Vector2:
	"""Get the current ball's position in world coordinates"""
	# Check if there's a ball in the launch manager
	if course.launch_manager and course.launch_manager.golf_ball and is_instance_valid(course.launch_manager.golf_ball):
		var ball = course.launch_manager.golf_ball
		# Get the ball's grid position (which is calculated correctly by the ball)
		var ball_grid_pos = Vector2i(floor(ball.position.x / ball.cell_size), floor(ball.position.y / ball.cell_size))
		# Convert grid position to world coordinates
		var world_pos = Vector2(ball_grid_pos.x * course.cell_size + course.cell_size/2, ball_grid_pos.y * course.cell_size + course.cell_size/2) + course.camera_container.global_position
		return world_pos
	
	# Fallback: look for any ball in the scene
	var balls = course.get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if is_instance_valid(ball):
			var ball_grid_pos = Vector2i(floor(ball.position.x / ball.cell_size), floor(ball.position.y / ball.cell_size))
			var world_pos = Vector2(ball_grid_pos.x * course.cell_size + course.cell_size/2, ball_grid_pos.y * course.cell_size + course.cell_size/2) + course.camera_container.global_position
			return world_pos
	
	return Vector2.ZERO

func create_teleport_portal(start_position: Vector2):
	"""Create a portal effect at the specified position"""
	# Load the portal scene
	var portal_scene = preload("res://Interactables/Portal.tscn")
	var portal = portal_scene.instantiate()
	
	# Position the portal at the start position
	portal.global_position = start_position
	
	# Add to the course scene
	course.add_child(portal)
	
	# Play teleport sound
	var teleport_sound = portal.get_node_or_null("Teleport")
	if teleport_sound:
		teleport_sound.play()
		print("Playing teleport sound effect")
	
	# Create fade out animation
	var tween = course.create_tween()
	tween.tween_property(portal, "modulate:a", 0.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(portal.queue_free)
	
	print("Created teleport portal at:", start_position)

func teleport_player_to_ball(ball_position: Vector2):
	"""Teleport the player to the ball's position"""
	# The ball_position is already in world coordinates, so we need to convert it to grid coordinates
	# relative to the camera container
	var ball_local_pos = ball_position - course.camera_container.global_position
	var ball_grid_pos = Vector2i(floor(ball_local_pos.x / course.cell_size), floor(ball_local_pos.y / course.cell_size))
	
	# Update the course's player grid position
	course.player_grid_pos = ball_grid_pos
	
	# Update the player's position
	if course.player_node and course.player_node.has_method("set_grid_position"):
		course.player_node.set_grid_position(ball_grid_pos, course.ysort_objects)
	
	# Update the course's player position
	if course.has_method("update_player_position"):
		course.update_player_position()
	
	# Update movement and attack handlers
	if course.movement_controller and course.movement_controller.has_method("update_player_position"):
		course.movement_controller.update_player_position(ball_grid_pos)
	
	if course.attack_handler and course.attack_handler.has_method("update_player_position"):
		course.attack_handler.update_player_position(ball_grid_pos)
	
	print("Player teleported to ball position:", ball_grid_pos)

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

func is_redjay_moving_ball() -> bool:
	"""Check if RedJay is currently moving the ball"""
	return redjay_moving_ball

func was_ball_moved_by_redjay(ball: Node2D) -> bool:
	"""Check if a specific ball was moved by RedJay"""
	var was_moved = redjay_moved_ball == ball
	print("Checking if ball was moved by RedJay - ball:", ball.name if ball else "null", "redjay_moved_ball:", redjay_moved_ball.name if redjay_moved_ball else "null", "result:", was_moved)
	return was_moved

func clear_redjay_moved_ball():
	"""Clear the RedJay moved ball reference"""
	redjay_moved_ball = null
	print("Cleared RedJay moved ball reference")

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

func handle_block_effect(card: CardData):
	"""Handle Block effect - add block health bar and switch to block sprite"""
	print("CardEffectHandler: Handling Block card:", card.name)
	
	# Get the block amount from effective strength (25 HP base)
	var block_amount = 25 * card.get_effective_strength()
	print("Adding", block_amount, "block points")
	
	# Activate block on the course
	if course.has_method("activate_block"):
		course.activate_block(block_amount)
	else:
		print("Warning: Course does not have activate_block method")
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Block card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("Block effect activated -", block_amount, "block points added")

func handle_arrange_effect(card: CardData):
	"""Handle Arrange effect - show dialog to choose between two cards"""
	print("CardEffectHandler: Handling Arrange card:", card.name)
	
	# Create and show the arrange dialog
	var arrange_dialog_scene = preload("res://ArrangeDialog.tscn")
	var arrange_dialog = arrange_dialog_scene.instantiate()
	
	# Add to UI layer
	var ui_layer = course.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(arrange_dialog)
	else:
		course.add_child(arrange_dialog)
	
	# Connect signals
	arrange_dialog.card_selected.connect(_on_arrange_card_selected)
	arrange_dialog.dialog_closed.connect(_on_arrange_dialog_closed)
	
	# Show the dialog
	arrange_dialog.show_arrange_dialog()
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Arrange card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("Arrange effect activated - dialog shown")

func _on_arrange_card_selected(selected_card: CardData):
	"""Handle when a card is selected from the arrange dialog"""
	print("CardEffectHandler: Player selected card from arrange dialog:", selected_card.name)
	
	# The card has already been added to the deck by the dialog
	# Update the deck display to show the new card
	if course.has_method("update_deck_display"):
		course.update_deck_display()
	
	# Update the movement buttons to show the new cards in hand
	if course.has_method("create_movement_buttons"):
		course.create_movement_buttons()
	
	print("Arrange effect completed - card added to hand")

func handle_animal_help_effect(card: CardData):
	"""Handle AnimalHelp effect - spawn RedJay to help with ball movement"""
	print("CardEffectHandler: Handling AnimalHelp card:", card.name)
	
	if card.name == "CallofthewildCard":
		_handle_call_of_the_wild_effect(card)
	else:
		print("Unknown AnimalHelp card:", card.name)
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("AnimalHelp card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("AnimalHelp effect activated")

func handle_player_effect(card: CardData):
	"""Handle PlayerEffect cards - apply effects directly to the player"""
	print("CardEffectHandler: Handling PlayerEffect card:", card.name)
	
	if card.name == "GhostMode":
		_handle_ghost_mode_effect(card)
	elif card.name == "Vampire":
		_handle_vampire_effect(card)
	else:
		print("Unknown PlayerEffect card:", card.name)
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("PlayerEffect card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("PlayerEffect activated")

func _handle_ghost_mode_effect(card: CardData):
	"""Handle the specific GhostMode card effect"""
	print("=== GHOST MODE EFFECT ACTIVATED ===")
	print("Activating GhostMode effect!")
	
	# Play the cool sound effect
	play_ghost_mode_sound()
	
	# Activate ghost mode on the course
	if course.has_method("activate_ghost_mode"):
		course.activate_ghost_mode()
		print("GhostMode activated on course")
	else:
		print("Warning: Course does not have activate_ghost_mode method")

func play_ghost_mode_sound():
	"""Play the cool sound effect when GhostMode card is used"""
	# Create a temporary AudioStreamPlayer to play the sound
	var sound_player = AudioStreamPlayer.new()
	course.add_child(sound_player)
	
	# Load and play the sound
	var sound_file = load("res://Sounds/CoolSound.mp3")
	if sound_file:
		sound_player.stream = sound_file
		sound_player.play()
		print("Playing GhostMode sound effect")
	else:
		print("Warning: CoolSound.mp3 not found")
	
	# Remove the temporary sound player after a short delay
	await get_tree().create_timer(0.1).timeout
	sound_player.queue_free()

func _handle_vampire_effect(card: CardData):
	"""Handle the specific Vampire card effect"""
	print("=== VAMPIRE EFFECT ACTIVATED ===")
	print("Activating Vampire effect!")
	
	# Play the vampire sound effect
	play_vampire_sound()
	
	# Activate vampire mode on the course
	if course.has_method("activate_vampire_mode"):
		course.activate_vampire_mode()
		print("Vampire mode activated on course")
	else:
		print("Warning: Course does not have activate_vampire_mode method")

func play_vampire_sound():
	"""Play the vampire sound effect when Vampire card is used"""
	# Create a temporary AudioStreamPlayer to play the sound
	var sound_player = AudioStreamPlayer.new()
	course.add_child(sound_player)
	
	# Load and play the sound
	var sound_file = load("res://Sounds/Vampire.mp3")
	if sound_file:
		sound_player.stream = sound_file
		sound_player.play()
		print("Playing Vampire sound effect")
	else:
		print("Warning: Vampire.mp3 not found")
	
	# Remove the temporary sound player after a short delay
	await get_tree().create_timer(0.1).timeout
	sound_player.queue_free()

func handle_vampire_effect(card: CardData):
	"""Handle the Vampire card effect - activate vampire mode"""
	print("=== VAMPIRE EFFECT ACTIVATED ===")
	print("Activating Vampire effect!")
	
	# Play the vampire sound effect
	play_vampire_sound()
	
	# Activate vampire mode on the course
	if course.has_method("activate_vampire_mode"):
		course.activate_vampire_mode()
		print("Vampire mode activated on course")
	else:
		print("Warning: Course does not have activate_vampire_mode method")
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Vampire card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("Vampire effect activated")

func handle_dodge_effect(card: CardData):
	"""Handle the Dodge card effect - activate dodge mode"""
	print("=== DODGE EFFECT ACTIVATED ===")
	print("Activating Dodge effect!")
	
	# Play the dodge sound effect
	play_dodge_sound()
	
	# Activate dodge mode on the course
	if course.has_method("activate_dodge_mode"):
		course.activate_dodge_mode()
		print("Dodge mode activated on course")
	else:
		print("Warning: Course does not have activate_dodge_mode method")
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("Dodge card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("Dodge effect activated")

func play_dodge_sound():
	"""Play the dodge sound effect when Dodge card is used"""
	# Create a temporary AudioStreamPlayer to play the sound
	var sound_player = AudioStreamPlayer.new()
	course.add_child(sound_player)
	
	# Load and play the sound (using WhooshCut as a suitable dodge sound)
	var sound_file = load("res://Sounds/WhooshCut.mp3")
	if sound_file:
		sound_player.stream = sound_file
		sound_player.play()
		print("Playing Dodge sound effect")
	else:
		print("Warning: WhooshCut.mp3 not found")
	
	# Remove the temporary sound player after a short delay
	await get_tree().create_timer(0.1).timeout
	sound_player.queue_free()

func handle_bag_adjust_effect(card: CardData):
	"""Handle BagAdjust effect - show dialog to choose a club for this shot"""
	print("CardEffectHandler: Handling BagAdjust card:", card.name)
	
	# Create and show the bag check dialog
	var bag_check_dialog_scene = preload("res://BagCheckDialog.tscn")
	var bag_check_dialog = bag_check_dialog_scene.instantiate()
	
	# Add to UI layer
	var ui_layer = course.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(bag_check_dialog)
	else:
		course.add_child(bag_check_dialog)
	
	# Connect signals
	bag_check_dialog.club_selected.connect(_on_bag_check_club_selected)
	bag_check_dialog.dialog_closed.connect(_on_bag_check_dialog_closed)
	
	# Show the dialog
	bag_check_dialog.show_bag_check_dialog()
	
	# Handle card discard - could be from hand or bag pile
	if course.deck_manager.hand.has(card):
		course.deck_manager.discard(card)
		course.card_stack_display.animate_card_discard(card.name)
		course.update_deck_display()
	else:
		# Card is from bag pile during club selection - just animate discard
		course.card_stack_display.animate_card_discard(card.name)
		print("BagCheck card used from bag pile")
	
	# Remove only the specific card button, not the entire hand
	remove_specific_card_button(card)
	
	print("BagAdjust effect activated - dialog shown")

func _on_bag_check_club_selected(selected_club: CardData):
	"""Handle when a club is selected from the bag check dialog"""
	print("CardEffectHandler: Player selected club from bag check dialog:", selected_club.name)
	
	# Set the temporary club for the next shot
	if course.has_method("set_temporary_club"):
		course.set_temporary_club(selected_club)
		print("Temporary club set:", selected_club.name)
	else:
		print("Warning: Course does not have set_temporary_club method")
	
	# Update the deck display to show the card was used
	if course.has_method("update_deck_display"):
		course.update_deck_display()
	
	# Update the movement buttons to show the remaining cards
	if course.has_method("create_movement_buttons"):
		course.create_movement_buttons()
	
	print("BagAdjust effect completed - temporary club set, player can continue turn")

func _on_bag_check_dialog_closed():
	"""Handle when the bag check dialog is closed"""
	print("CardEffectHandler: Bag check dialog closed")

func _handle_call_of_the_wild_effect(card: CardData):
	"""Handle the specific Call of the Wild card effect"""
	print("=== CALL OF THE WILD EFFECT ACTIVATED ===")
	print("Activating Call of the Wild effect!")
	
	# Animate the card row down to get out of the way
	if course.has_method("get_movement_controller"):
		var movement_controller = course.get_movement_controller()
		if movement_controller and movement_controller.has_method("animate_card_row_down"):
			movement_controller.animate_card_row_down()
			print("Card row animated down for Call of the Wild effect")
	
	# Get the ball position
	var ball_position = get_ball_position()
	if ball_position == Vector2.ZERO:
		print("Warning: No ball found for Call of the Wild effect")
		return
	
	# Get the pin position
	var pin_position = course.find_pin_position()
	if pin_position == Vector2.ZERO:
		print("Warning: No pin found for Call of the Wild effect")
		return
	
	# Find the actual ball node
	var ball_node = _find_ball_node()
	if not ball_node:
		print("Warning: Could not find ball node for Call of the Wild effect")
		return
	
	# Set up RedJay movement tracking
	redjay_moving_ball = true
	redjay_ball_original_position = ball_node.global_position
	redjay_moved_ball = ball_node # Track the specific ball that was moved
	print("RedJay tracking set up - ball:", ball_node.name, "position:", ball_node.global_position)
	
	# Switch camera focus to the ball
	course.camera_following_ball = true
	print("Camera switched to follow ball during RedJay effect")
	
	# Create RedJay effect
	_create_red_jay_effect(ball_node, pin_position)

func _find_ball_node() -> Node2D:
	"""Find the actual ball node in the scene"""
	# Check if there's a ball in the launch manager
	if course.launch_manager and course.launch_manager.golf_ball and is_instance_valid(course.launch_manager.golf_ball):
		return course.launch_manager.golf_ball
	
	# Fallback: look for any ball in the scene
	var balls = course.get_tree().get_nodes_in_group("balls")
	for ball in balls:
		if is_instance_valid(ball):
			return ball
	
	return null

func _create_red_jay_effect(ball_node: Node2D, pin_position: Vector2):
	"""Create and start the RedJay effect"""
	# Load RedJay scene
	var red_jay_scene = load("res://NPC/Animals/RedJay.tscn")
	if not red_jay_scene:
		print("Error: Failed to load RedJay scene")
		return
	
	var red_jay = red_jay_scene.instantiate()
	if not red_jay:
		print("Error: Failed to instantiate RedJay")
		return
	
	# Position RedJay at a random position off screen
	var spawn_position = _get_random_off_screen_position(ball_node.global_position)
	red_jay.global_position = spawn_position
	
	# Add to scene
	course.add_child(red_jay)
	
	# Connect to RedJay completion signal if it exists
	if red_jay.has_signal("effect_completed"):
		red_jay.effect_completed.connect(_on_redjay_effect_completed)
	
	# Start the RedJay effect
	if red_jay.has_method("start_red_jay_effect"):
		red_jay.start_red_jay_effect(ball_node, pin_position)
		print("RedJay effect created at position:", spawn_position)
	else:
		print("Error: RedJay does not have start_red_jay_effect method")
		red_jay.queue_free()

func _get_random_off_screen_position(ball_position: Vector2) -> Vector2:
	"""Get a random position off screen for RedJay to spawn"""
	var screen_size = get_viewport().get_visible_rect().size
	var margin = 100.0  # Distance off screen
	
	# Choose a random side (0=top, 1=right, 2=bottom, 3=left)
	var side = randi() % 4
	
	match side:
		0:  # Top
			return Vector2(randf_range(-margin, screen_size.x + margin), -margin)
		1:  # Right
			return Vector2(screen_size.x + margin, randf_range(-margin, screen_size.y + margin))
		2:  # Bottom
			return Vector2(randf_range(-margin, screen_size.x + margin), screen_size.y + margin)
		3:  # Left
			return Vector2(-margin, randf_range(-margin, screen_size.y + margin))
	
	return Vector2.ZERO

func _on_redjay_effect_completed():
	"""Handle when RedJay effect is completed"""
	print("RedJay effect completed - switching camera back to player")
	
	# Reset RedJay movement tracking
	redjay_moving_ball = false
	redjay_moved_ball = null # Clear the tracked ball
	
	# Switch camera focus back to player
	course.camera_following_ball = false
	if course.has_method("smooth_camera_to_player"):
		course.smooth_camera_to_player()
		print("Camera switched back to player after RedJay effect")
	
	# Animate the card row back up
	if course.has_method("get_movement_controller"):
		var movement_controller = course.get_movement_controller()
		if movement_controller and movement_controller.has_method("animate_card_row_up"):
			movement_controller.animate_card_row_up()
			print("Card row animated back up after Call of the Wild effect")
	
	# The ball will land naturally and trigger the normal landing logic
	# but we need to prevent the drive distance dialog from showing
	# This will be handled in the course's _on_golf_ball_landed function

func _on_arrange_dialog_closed():
	"""Handle when the arrange dialog is closed"""
	print("CardEffectHandler: Arrange dialog closed")
	# No additional cleanup needed - the dialog handles its own cleanup
