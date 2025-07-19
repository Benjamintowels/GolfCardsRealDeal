class_name GameStateManager
extends Node

# Game phase management
var game_phase := "tee_select" # Possible: tee_select, draw_cards, aiming, launch, ball_flying, move, etc.

# Hole and round management
var current_hole := 0  # 0-based hole index (0-8 for front 9, 9-17 for back 9)
var hole_score := 0
var round_scores := []  # Array to store scores for each hole
var round_complete := false  # Flag to track if front 9 is complete
var turn_count: int = 1

# Game mode constants
const NUM_HOLES := 9  # Number of holes per round (9 for front 9, 9 for back 9)
var is_back_9_mode := false  # Flag to track if we're playing back 9
var back_9_start_hole := 9  # Hole 10 (index 9)

# Game state flags
var has_started := false
var is_placing_player := true

# Gimme mechanic variables
var gimme_active := false  # Track if gimme is currently active
var gimme_ball: Node2D = null  # Reference to the ball that's in gimme range

# Ball and shot tracking
var ball_landing_tile: Vector2i = Vector2i.ZERO
var ball_landing_position: Vector2 = Vector2.ZERO
var waiting_for_player_to_reach_ball := false
var shot_start_grid_pos: Vector2i = Vector2i.ZERO  # Store where the shot was taken from (grid position)
var used_reach_ball_button: bool = false  # Track if player used ReachBallButton this turn
var drive_distance := 0.0

# Camera and aiming variables
var camera_following_ball := false
var aiming_circle: Control = null
var chosen_landing_spot: Vector2 = Vector2.ZERO
var max_shot_distance: float = 800.0  # Reduced from 2000.0 to something more on-screen
var is_aiming_phase: bool = false

# Club selection variables
var selected_club: String = ""
var temporary_club: CardData = null  # Temporary club from BagCheck card
var bag_check_active: bool = false  # Track if BagCheck effect is active

# Puzzle type system variables
var current_puzzle_type: String = "score"  # Default puzzle type
var next_puzzle_type: String = "score"     # Puzzle type for next hole

# Shop interaction variables
var shop_entrance_detected := false
var shop_grid_pos := Vector2i(2, 4)  # Position of shop from map layout
var suitcase_grid_pos := Vector2i.ZERO  # Track SuitCase position
var suitcase_node: Node2D = null  # Reference to the SuitCase node

# Fire tile damage tracking
var fire_tiles_that_damaged_player: Array[Vector2i] = []  # Track which fire tiles have already damaged player this turn

# References to other systems
var course: Node = null
var ui_manager: Node = null
var map_manager: Node = null
var build_map: Node = null
var player_manager: Node = null
var grid_manager: Node = null
var camera_manager: Node = null
var deck_manager: Node = null
var movement_controller: Node = null
var attack_handler: Node = null
var weapon_handler: Node = null
var launch_manager: Node = null

func setup(course_ref: Node, ui_mgr: Node, map_mgr: Node, build_map_ref: Node, player_mgr: Node, grid_mgr: Node, camera_mgr: Node, deck_mgr: Node, movement_ctrl: Node, attack_hdlr: Node, weapon_hdlr: Node, launch_mgr: Node):
	"""Initialize the game state manager with required references"""
	course = course_ref
	ui_manager = ui_mgr
	map_manager = map_mgr
	build_map = build_map_ref
	player_manager = player_mgr
	grid_manager = grid_mgr
	camera_manager = camera_mgr
	deck_manager = deck_mgr
	movement_controller = movement_ctrl
	attack_handler = attack_hdlr
	weapon_handler = weapon_hdlr
	launch_manager = launch_mgr
	
	print("GameStateManager setup complete")

# ===== GAME PHASE MANAGEMENT =====

func set_game_phase(new_phase: String) -> void:
	"""Set the current game phase"""
	var old_phase = game_phase
	game_phase = new_phase
	print("Game phase changed from '%s' to '%s'" % [old_phase, new_phase])

func get_game_phase() -> String:
	"""Get the current game phase"""
	return game_phase

func is_phase(phase: String) -> bool:
	"""Check if current phase matches the given phase"""
	return game_phase == phase

# ===== HOLE AND ROUND MANAGEMENT =====

func start_front_nine() -> void:
	"""Initialize front nine mode"""
	is_back_9_mode = false
	current_hole = 0  # Start at hole 1 (index 0)
	round_scores.clear()
	round_complete = false
	print("Front 9 mode initialized, starting at hole:", current_hole + 1)

func start_back_nine() -> void:
	"""Initialize back nine mode"""
	is_back_9_mode = true
	current_hole = back_9_start_hole  # Start at hole 10 (index 9)
	round_scores.clear()
	round_complete = false
	print("Back 9 mode initialized, starting at hole:", current_hole + 1)

func advance_to_next_hole() -> void:
	"""Advance to the next hole"""
	current_hole += 1
	hole_score = 0
	game_phase = "tee_select"
	print("=== ADVANCING TO HOLE", current_hole + 1, "===")

func increment_current_hole() -> void:
	"""Increment the current hole (alias for advance_to_next_hole)"""
	advance_to_next_hole()

func set_current_hole(hole_index: int) -> void:
	"""Set the current hole index"""
	current_hole = hole_index
	print("Current hole set to:", current_hole + 1)

func get_current_hole() -> int:
	"""Get the current hole number (1-based)"""
	return current_hole + 1

func get_current_hole_index() -> int:
	"""Get the current hole index (0-based)"""
	return current_hole

func is_last_hole() -> bool:
	"""Check if this is the last hole in the current round"""
	var round_end_hole = 0
	if is_back_9_mode:
		round_end_hole = back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		round_end_hole = NUM_HOLES - 1  # Hole 9 (index 8)
	
	return current_hole >= round_end_hole

func is_front_nine_complete() -> bool:
	"""Check if front nine is complete"""
	return current_hole == 8 and not is_back_9_mode

# ===== SCORE MANAGEMENT =====

func increment_hole_score() -> void:
	"""Increment the current hole score"""
	hole_score += 1
	print("Hole score incremented to:", hole_score)

func get_hole_score() -> int:
	"""Get the current hole score"""
	return hole_score

func reset_hole_score() -> void:
	"""Reset the current hole score"""
	hole_score = 0

func complete_hole() -> void:
	"""Complete the current hole and add score to round"""
	round_scores.append(hole_score)
	print("Hole completed with score:", hole_score)

func get_round_scores() -> Array:
	"""Get all round scores"""
	return round_scores

func get_total_round_score() -> int:
	"""Get the total score for the current round"""
	var total = 0
	for score in round_scores:
		total += score
	total += hole_score  # Include current hole score
	return total

# ===== TURN MANAGEMENT =====

func increment_turn_count() -> void:
	"""Increment the turn count"""
	turn_count += 1

func get_turn_count() -> int:
	"""Get the current turn count"""
	return turn_count

func reset_turn_count() -> void:
	"""Reset the turn count"""
	turn_count = 1

# ===== GIMME SYSTEM =====

func activate_gimme(ball: Node2D) -> void:
	"""Activate gimme mode with the given ball"""
	gimme_active = true
	gimme_ball = ball
	print("Gimme activated for ball:", ball.name)

func deactivate_gimme() -> void:
	"""Deactivate gimme mode"""
	gimme_active = false
	gimme_ball = null
	print("Gimme deactivated")

func is_gimme_active() -> bool:
	"""Check if gimme is currently active"""
	return gimme_active

func get_gimme_ball() -> Node2D:
	"""Get the gimme ball reference"""
	return gimme_ball

# ===== BALL AND SHOT TRACKING =====

func set_ball_landing_position(tile: Vector2i, position: Vector2) -> void:
	"""Set the ball landing position"""
	ball_landing_tile = tile
	ball_landing_position = position

func get_ball_landing_tile() -> Vector2i:
	"""Get the ball landing tile"""
	return ball_landing_tile

func get_ball_landing_position() -> Vector2:
	"""Get the ball landing position"""
	return ball_landing_position

func set_shot_start_position(grid_pos: Vector2i) -> void:
	"""Set the shot start position"""
	shot_start_grid_pos = grid_pos

func get_shot_start_position() -> Vector2i:
	"""Get the shot start position"""
	return shot_start_grid_pos

func set_drive_distance(distance: float) -> void:
	"""Set the drive distance"""
	drive_distance = distance

func get_drive_distance() -> float:
	"""Get the drive distance"""
	return drive_distance

# ===== CLUB SELECTION =====

func set_selected_club(club: String) -> void:
	"""Set the selected club"""
	selected_club = club

func get_selected_club() -> String:
	"""Get the selected club"""
	return selected_club

func set_temporary_club(club: CardData) -> void:
	"""Set a temporary club (from BagCheck card)"""
	temporary_club = club
	bag_check_active = true

func get_temporary_club() -> CardData:
	"""Get the temporary club"""
	return temporary_club

func clear_temporary_club() -> void:
	"""Clear the temporary club"""
	temporary_club = null
	bag_check_active = false

func is_bag_check_active() -> bool:
	"""Check if bag check is active"""
	return bag_check_active

# ===== PUZZLE TYPE SYSTEM =====

func set_current_puzzle_type(puzzle_type: String) -> void:
	"""Set the current puzzle type"""
	current_puzzle_type = puzzle_type

func get_current_puzzle_type() -> String:
	"""Get the current puzzle type"""
	return current_puzzle_type

func set_next_puzzle_type(puzzle_type: String) -> void:
	"""Set the puzzle type for the next hole"""
	next_puzzle_type = puzzle_type

func get_next_puzzle_type() -> String:
	"""Get the puzzle type for the next hole"""
	return next_puzzle_type

# ===== SHOP AND SUITCASE SYSTEM =====

func set_shop_entrance_detected(detected: bool) -> void:
	"""Set shop entrance detection"""
	shop_entrance_detected = detected

func is_shop_entrance_detected() -> bool:
	"""Check if shop entrance is detected"""
	return shop_entrance_detected

func set_shop_grid_position(pos: Vector2i) -> void:
	"""Set the shop grid position"""
	shop_grid_pos = pos

func get_shop_grid_position() -> Vector2i:
	"""Get the shop grid position"""
	return shop_grid_pos

func set_suitcase_grid_position(pos: Vector2i) -> void:
	"""Set the suitcase grid position"""
	suitcase_grid_pos = pos

func get_suitcase_grid_position() -> Vector2i:
	"""Get the suitcase grid position"""
	return suitcase_grid_pos

func set_suitcase_node(node: Node2D) -> void:
	"""Set the suitcase node reference"""
	suitcase_node = node

func get_suitcase_node() -> Node2D:
	"""Get the suitcase node reference"""
	return suitcase_node

# ===== FIRE TILE TRACKING =====

func add_fire_tile_damaged(tile: Vector2i) -> void:
	"""Add a fire tile that has damaged the player this turn"""
	if tile not in fire_tiles_that_damaged_player:
		fire_tiles_that_damaged_player.append(tile)

func has_fire_tile_damaged(tile: Vector2i) -> bool:
	"""Check if a fire tile has already damaged the player this turn"""
	return tile in fire_tiles_that_damaged_player

func clear_fire_tile_damage_tracking() -> void:
	"""Clear the fire tile damage tracking for the next turn"""
	fire_tiles_that_damaged_player.clear()

# ===== ADDITIONAL GETTERS AND SETTERS =====

func set_used_reach_ball_button(used: bool) -> void:
	"""Set the used reach ball button flag"""
	used_reach_ball_button = used

func get_used_reach_ball_button() -> bool:
	"""Get the used reach ball button flag"""
	return used_reach_ball_button

func set_waiting_for_player_to_reach_ball(waiting: bool) -> void:
	"""Set the waiting for player to reach ball flag"""
	waiting_for_player_to_reach_ball = waiting

func get_waiting_for_player_to_reach_ball() -> bool:
	"""Get the waiting for player to reach ball flag"""
	return waiting_for_player_to_reach_ball

func set_has_started(started: bool) -> void:
	"""Set the has started flag"""
	has_started = started

func get_has_started() -> bool:
	"""Get the has started flag"""
	return has_started

func set_aiming_circle(circle: Control) -> void:
	"""Set the aiming circle reference"""
	aiming_circle = circle

func get_aiming_circle() -> Control:
	"""Get the aiming circle reference"""
	return aiming_circle

func set_chosen_landing_spot(spot: Vector2) -> void:
	"""Set the chosen landing spot"""
	chosen_landing_spot = spot

func get_chosen_landing_spot() -> Vector2:
	"""Get the chosen landing spot"""
	return chosen_landing_spot

func set_is_placing_player(placing: bool) -> void:
	"""Set the is placing player flag"""
	is_placing_player = placing

func get_is_placing_player() -> bool:
	"""Get the is placing player flag"""
	return is_placing_player

func set_camera_following_ball(following: bool) -> void:
	"""Set the camera following ball flag"""
	camera_following_ball = following

func get_camera_following_ball() -> bool:
	"""Get the camera following ball flag"""
	return camera_following_ball

func set_is_aiming_phase(aiming: bool) -> void:
	"""Set the is aiming phase flag"""
	is_aiming_phase = aiming

func get_is_aiming_phase() -> bool:
	"""Get the is aiming phase flag"""
	return is_aiming_phase

# ===== UTILITY FUNCTIONS =====

func reset_for_new_hole() -> void:
	"""Reset state for a new hole"""
	hole_score = 0
	game_phase = "tee_select"
	is_placing_player = true
	gimme_active = false
	gimme_ball = null
	ball_landing_tile = Vector2i.ZERO
	ball_landing_position = Vector2.ZERO
	waiting_for_player_to_reach_ball = false
	shot_start_grid_pos = Vector2i.ZERO
	used_reach_ball_button = false
	drive_distance = 0.0
	camera_following_ball = false
	chosen_landing_spot = Vector2.ZERO
	is_aiming_phase = false
	selected_club = ""
	clear_temporary_club()
	clear_fire_tile_damage_tracking()
	
	# Apply the selected puzzle type for this hole
	current_puzzle_type = next_puzzle_type
	print("🎯 PUZZLE TYPE: Applying puzzle type '", current_puzzle_type, "' to hole", current_hole + 1)

func get_round_end_hole() -> int:
	"""Get the round end hole index"""
	if is_back_9_mode:
		return back_9_start_hole + NUM_HOLES - 1  # Hole 18 (index 17)
	else:
		return NUM_HOLES - 1  # Hole 9 (index 8)

func is_game_complete() -> bool:
	"""Check if the game is complete (both front and back nine)"""
	return is_back_9_mode and current_hole > get_round_end_hole()

# ===== DEATH HANDLING =====

func handle_player_death() -> void:
	"""Handle player death - fade to black and show death screen"""
	print("Handling player death...")
	
	# Disable all input to prevent further actions
	if course:
		course.set_process_input(false)
	
	# Fade to black and transition to death scene
	FadeManager.fade_to_black(func(): get_tree().change_scene_to_file("res://DeathScene.tscn"), 1.0)

# ===== ROUND MANAGEMENT =====

func start_round_after_tee_selection(course: Node, player_manager: Node, deck_manager: Node, ui_manager: Node) -> void:
	"""Start the round after player selects a tee position"""
	var instruction_label = course.get_node_or_null("UILayer/TeeInstructionLabel")
	if instruction_label:
		instruction_label.queue_free()
	
	# Clear all tile highlights
	for y in grid_manager.get_grid_size().y:
		for x in grid_manager.get_grid_size().x:
			grid_manager.get_grid_tiles()[y][x].get_node("Highlight").visible = false
	
	# Reset character health for new round
	Global.reset_character_health()
	
	# Reset global turn counter for new round
	Global.reset_global_turn()
	
	player_manager.set_player_stats(Global.CHARACTER_STATS.get(Global.selected_character, {}))
	
	deck_manager.initialize_separate_decks()
	print("Separate decks initialized - Club cards:", deck_manager.club_draw_pile.size(), "Action cards:", deck_manager.action_draw_pile.size())

	set_has_started(true)
	reset_hole_score()
	
	# Enable player movement animations after player is properly placed on tee
	if player_manager.get_player_node() and player_manager.get_player_node().has_method("enable_animations"):
		player_manager.get_player_node().enable_animations()
		print("Player movement animations enabled after tee placement")
	
	# Start with club selection phase
	ui_manager.enter_draw_cards_phase()
	
	print("Round started! Player at position:", player_manager.get_player_grid_pos())

# ===== NPC PRIORITY SYSTEM =====

func get_npc_priority(npc: Node) -> int:
	"""Get the priority rating for an NPC (higher = faster/more important)"""
	# Check the NPC's script to determine type
	var script_path = npc.get_script().resource_path if npc.get_script() else ""
	
	# Squirrels are fastest (highest priority) - they chase and push balls
	if "Squirrel.gd" in script_path:
		return 4
	# Zombies are second fastest
	elif "ZombieGolfer.gd" in script_path:
		return 3
	# GangMembers are medium priority
	elif "GangMember.gd" in script_path:
		return 2
	# Police are slowest (lowest priority)
	elif "police.gd" in script_path:
		return 1
	# Default priority for unknown NPCs
	else:
		return 0

func has_alive_npcs() -> bool:
	"""Check if there are any alive NPCs on the map"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found!")
		return false
	
	var npcs = entities.get_npcs()
	print("Checking for alive NPCs among ", npcs.size(), " total NPCs")
	
	for npc in npcs:
		if is_instance_valid(npc):
			# Check if NPC is alive
			var is_alive = true
			if npc.has_method("get_is_dead"):
				is_alive = not npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_alive = not npc.is_dead()
			elif "is_dead" in npc:
				is_alive = not npc.is_dead
			
			if is_alive:
				print("Found alive NPC: ", npc.name)
				return true
		else:
			print("Invalid NPC found, skipping")
	
	print("No alive NPCs found on the map")
	return false

func has_active_npcs() -> bool:
	"""Check if there are any alive NPCs that are not frozen and will thaw this turn"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found!")
		return false
	
	var npcs = entities.get_npcs()
	print("Checking for active NPCs among ", npcs.size(), " total NPCs")
	
	for npc in npcs:
		if is_instance_valid(npc):
			# Check if NPC is alive
			var is_alive = true
			if npc.has_method("get_is_dead"):
				is_alive = not npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_alive = not npc.is_dead()
			elif "is_dead" in npc:
				is_alive = not npc.is_dead
			
			if is_alive:
				# Check if NPC is frozen
				var is_frozen = false
				if npc.has_method("is_frozen_state"):
					is_frozen = npc.is_frozen_state()
				elif "is_frozen" in npc:
					is_frozen = npc.is_frozen
				
				# Check if NPC will thaw this turn
				var will_thaw_this_turn = false
				if is_frozen and npc.has_method("get_freeze_turns_remaining"):
					var turns_remaining = npc.get_freeze_turns_remaining()
					will_thaw_this_turn = turns_remaining <= 1
				elif is_frozen and "freeze_turns_remaining" in npc:
					var turns_remaining = npc.freeze_turns_remaining
					will_thaw_this_turn = turns_remaining <= 1
				
				# NPC is active if not frozen, or if frozen but will thaw this turn
				if not is_frozen or will_thaw_this_turn:
					print("Found active NPC: ", npc.name, " (frozen: ", is_frozen, ", will thaw: ", will_thaw_this_turn, ")")
					return true
				else:
					print("Found frozen NPC that won't thaw this turn: ", npc.name)
		else:
			print("Invalid NPC found, skipping")
	
	print("No active NPCs found on the map")
	return false

func find_nearest_visible_npc(player_manager: Node) -> Node:
	"""Find the nearest NPC that is visible to the player, alive, and active (not frozen or will thaw this turn)"""
	var entities = get_node_or_null("Entities")
	if not entities:
		print("ERROR: No Entities node found!")
		return null
	
	var npcs = entities.get_npcs()
	print("Found ", npcs.size(), " NPCs in Entities system")
	
	var nearest_npc = null
	var nearest_distance = INF
	
	for npc in npcs:
		if is_instance_valid(npc) and npc.has_method("get_grid_position"):
			# Check if NPC is alive
			var is_alive = true
			if npc.has_method("get_is_dead"):
				is_alive = not npc.get_is_dead()
			elif npc.has_method("is_dead"):
				is_alive = not npc.is_dead()
			elif "is_dead" in npc:
				is_alive = not npc.is_dead
			
			if not is_alive:
				print("NPC ", npc.name, " is dead, skipping")
				continue
			
			# Check if NPC is frozen and won't thaw this turn
			var is_frozen = false
			if npc.has_method("is_frozen_state"):
				is_frozen = npc.is_frozen_state()
			elif "is_frozen" in npc:
				is_frozen = npc.is_frozen
			
			var will_thaw_this_turn = false
			if is_frozen and npc.has_method("get_freeze_turns_remaining"):
				var turns_remaining = npc.get_freeze_turns_remaining()
				will_thaw_this_turn = turns_remaining <= 1
			elif is_frozen and "freeze_turns_remaining" in npc:
				var turns_remaining = npc.freeze_turns_remaining
				will_thaw_this_turn = turns_remaining <= 1
			
			# Skip NPCs that are frozen and won't thaw this turn
			if is_frozen and not will_thaw_this_turn:
				print("NPC ", npc.name, " is frozen and won't thaw this turn, skipping")
				continue
			
			var npc_pos = npc.get_grid_position()
			var distance = player_manager.get_player_grid_pos().distance_to(npc_pos)
			
			print("NPC ", npc.name, " at distance ", distance, " from player (frozen: ", is_frozen, ", will thaw: ", will_thaw_this_turn, ")")
			
			# Check if NPC is within vision range (12 tiles)
			if distance <= 12 and distance < nearest_distance:
				nearest_distance = distance
				nearest_npc = npc
				print("New nearest NPC: ", npc.name, " at distance ", distance)
		else:
			print("Invalid NPC or missing get_grid_position method: ", npc.name if npc else "None")
	
	print("Final nearest NPC: ", nearest_npc.name if nearest_npc else "None")
	return nearest_npc

func start_shot_sequence(course: Node) -> void:
	"""Start the shot sequence by entering aiming phase"""
	course.enter_aiming_phase() 
