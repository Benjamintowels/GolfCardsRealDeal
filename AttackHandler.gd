extends Node
class_name AttackHandler

# Import strategy classes
const MeleeAttackStrategy = preload("res://Strategies/MeleeAttackStrategy.gd")
const RangedAttackStrategy = preload("res://Strategies/RangedAttackStrategy.gd")
const MovementAttackStrategy = preload("res://Strategies/MovementAttackStrategy.gd")

# Attack system variables
var is_attack_mode := false
var attack_range := 1
var valid_attack_tiles := []
var selected_card: CardData = null
var active_button: TextureButton = null

# References
var player_node: Node2D
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary

# Sound effects
var card_play_sound: AudioStreamPlayer2D
var kick_sound: AudioStreamPlayer2D  # Reference to KickSound from player scene
var punchb_sound: AudioStreamPlayer2D  # Reference to PunchB sound from player scene
var assassin_dash_sound: AudioStreamPlayer2D  # Reference to AssassinDash sound
var assassin_cut_sound: AudioStreamPlayer2D  # Reference to AssassinDash cut sound
var slash_sound: AudioStreamPlayer2D  # Reference to SlashSound from player scene

# UI references
var card_stack_display: Control
var deck_manager: DeckManager
var card_row: Control  # Reference to the CardRow for animation

# Card effect handling
var card_effect_handler: Node

# CardRow animation variables
var card_row_original_position: Vector2
var card_row_animation_tween: Tween
var card_row_animation_duration: float = 0.3
var card_row_animation_offset: float = 100.0  # How far down to move the CardRow

# Attack properties
var attack_damage := 25

# Ash dog attack properties - now handled by RangedAttackStrategy

# Slash attack properties - now handled by MeleeAttackStrategy

# SlashFX scene reference - now handled by MeleeAttackStrategy

# Strategy instances
var melee_strategy: MeleeAttackStrategy
var ranged_strategy: RangedAttackStrategy
var movement_strategy: MovementAttackStrategy

# Signals
signal attack_mode_entered
signal attack_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)
signal npc_attacked(npc: Node, damage: int)
signal kick_attack_performed
signal punchb_attack_performed
signal ash_dog_attack_performed
signal slash_attack_performed
signal assassin_dash_attack_performed

func _init():
	pass

func setup(
	player_node_ref: Node2D,
	grid_tiles_ref: Array,
	grid_size_ref: Vector2i,
	cell_size_ref: int,
	obstacle_map_ref: Dictionary,
	player_grid_pos_ref: Vector2i,
	player_stats_ref: Dictionary,
	card_play_sound_ref: AudioStreamPlayer2D,
	card_stack_display_ref: Control,
	deck_manager_ref: DeckManager,
	card_effect_handler_ref: Node,
	kick_sound_ref: AudioStreamPlayer2D = null,
	punchb_sound_ref: AudioStreamPlayer2D = null,
	assassin_dash_sound_ref: AudioStreamPlayer2D = null,
	assassin_cut_sound_ref: AudioStreamPlayer2D = null,
	card_row_ref: Control = null,
	slash_sound_ref: AudioStreamPlayer2D = null
):
	player_node = player_node_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	card_play_sound = card_play_sound_ref
	card_stack_display = card_stack_display_ref
	deck_manager = deck_manager_ref
	card_effect_handler = card_effect_handler_ref
	kick_sound = kick_sound_ref
	punchb_sound = punchb_sound_ref
	assassin_dash_sound = assassin_dash_sound_ref
	assassin_cut_sound = assassin_cut_sound_ref
	card_row = card_row_ref
	slash_sound = slash_sound_ref
	
	# Initialize strategy instances and add them to the scene tree
	melee_strategy = MeleeAttackStrategy.new()
	ranged_strategy = RangedAttackStrategy.new()
	movement_strategy = MovementAttackStrategy.new()
	
	# Add strategies to the scene tree so they can use get_tree()
	add_child(melee_strategy)
	add_child(ranged_strategy)
	add_child(movement_strategy)
	
	# Setup strategies with references
	melee_strategy.setup(
		card_effect_handler_ref,
		grid_tiles_ref,
		grid_size_ref,
		cell_size_ref,
		obstacle_map_ref,
		player_grid_pos_ref,
		player_stats_ref,
		player_node_ref,
		kick_sound_ref,
		punchb_sound_ref,
		slash_sound_ref
	)
	
	ranged_strategy.setup(
		card_effect_handler_ref,
		grid_tiles_ref,
		grid_size_ref,
		cell_size_ref,
		obstacle_map_ref,
		player_grid_pos_ref,
		player_stats_ref,
		player_node_ref
	)
	
	movement_strategy.setup(
		card_effect_handler_ref,
		grid_tiles_ref,
		grid_size_ref,
		cell_size_ref,
		obstacle_map_ref,
		player_grid_pos_ref,
		player_stats_ref,
		player_node_ref,
		assassin_dash_sound_ref,
		assassin_cut_sound_ref
	)
	
	# Connect strategy signals to AttackHandler signals
	melee_strategy.npc_attacked.connect(_on_strategy_npc_attacked)
	melee_strategy.kick_attack_performed.connect(_on_strategy_kick_attack_performed)
	melee_strategy.punchb_attack_performed.connect(_on_strategy_punchb_attack_performed)
	melee_strategy.slash_attack_performed.connect(_on_strategy_slash_attack_performed)
	melee_strategy.attack_completed.connect(_on_strategy_attack_completed)
	
	ranged_strategy.npc_attacked.connect(_on_strategy_npc_attacked)
	ranged_strategy.ash_dog_attack_performed.connect(_on_strategy_ash_dog_attack_performed)
	ranged_strategy.attack_completed.connect(_on_strategy_attack_completed)
	
	movement_strategy.npc_attacked.connect(_on_strategy_npc_attacked)
	movement_strategy.assassin_dash_attack_performed.connect(_on_strategy_assassin_dash_attack_performed)
	movement_strategy.attack_completed.connect(_on_strategy_attack_completed)
	
	# Store the original position of the CardRow for animation
	if card_row:
		card_row_original_position = card_row.position
	
	# Connect to player's position signal to update attack highlights when player moves
	if player_node and player_node.has_signal("moved_to_tile"):
		# Disconnect any existing connection to avoid duplicates
		if player_node.moved_to_tile.is_connected(_on_player_moved_to_tile):
			player_node.moved_to_tile.disconnect(_on_player_moved_to_tile)
		# Connect to the player's moved_to_tile signal
		player_node.moved_to_tile.connect(_on_player_moved_to_tile)
		print("AttackHandler: Connected to player moved_to_tile signal")
	else:
		print("AttackHandler: Warning - player node or moved_to_tile signal not found")



func _on_attack_card_pressed(card: CardData, button: TextureButton = null) -> void:
	"""Handle when an attack card is pressed"""
	print("🔍 ATTACK_HANDLER DEBUG: _on_attack_card_pressed called with card:", card.name)
	print("🔍 ATTACK_HANDLER DEBUG: Current player_grid_pos:", player_grid_pos)
	
	selected_card = card
	active_button = button
	attack_damage = card.damage
	
	# Special handling for AssassinDash - use aoe_range for attack range
	if card.name == "AssassinDash":
		attack_range = card.aoe_range
		print("AssassinDash detected - using aoe_range for attack range:", attack_range)
	else:
		attack_range = card.damage_range
	
	# Enter attack mode
	is_attack_mode = true
	
	# Calculate valid attack tiles
	calculate_valid_attack_tiles()
	
	# Show attack highlights
	show_attack_highlights()
	
	# Animate CardRow up to get out of the way of range display
	animate_card_row_up()

func _on_aoe_attack_card_pressed(card: CardData, button: TextureButton = null) -> void:
	"""Handle when an AOE attack card is pressed"""
	selected_card = card
	active_button = button
	attack_damage = card.damage
	attack_range = card.aoe_range
	
	# Enter attack mode
	is_attack_mode = true
	
	# Calculate valid AOE attack tiles
	calculate_valid_aoe_attack_tiles()
	
	# Show attack highlights
	show_attack_highlights()
	
	# Animate CardRow up to get out of the way of range display
	animate_card_row_up()

func _on_slash_card_pressed(card: CardData, button: TextureButton = null) -> void:
	"""Handle when a SlashCard is pressed"""
	selected_card = card
	active_button = button
	attack_damage = card.damage
	attack_range = card.aoe_range
	
	# Enter attack mode
	is_attack_mode = true
	
	# Calculate valid slash attack tiles
	calculate_valid_slash_attack_tiles()
	
	# Show attack highlights
	show_attack_highlights()
	
	# Animate CardRow up to get out of the way of range display
	animate_card_row_up()

func calculate_valid_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("🔍 ATTACK_HANDLER DEBUG: calculate_valid_attack_tiles called with player_grid_pos:", player_grid_pos)
	
	# Get grid size from the course
	var grid_size = Vector2i(100, 100)  # Default grid size
	if card_effect_handler and card_effect_handler.course:
		if card_effect_handler.course.has_method("get_grid_size"):
			grid_size = card_effect_handler.course.get_grid_size()
		elif "grid_size" in card_effect_handler.course:
			grid_size = card_effect_handler.course.grid_size

	# Special handling for AssassinDash - use cross pattern instead of Manhattan distance
	if selected_card and selected_card.name == "AssassinDash":
		print("AssassinDash detected - using cross pattern for attack range")
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, attack_range + 1):
			# Up
			var up_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(player_grid_pos.x, player_grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(player_grid_pos.x - distance, player_grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(player_grid_pos.x + distance, player_grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Check if behind-enemy position is valid for each cross position
		for pos in cross_positions:
			if pos != player_grid_pos:
				# Calculate the position behind the enemy (opposite direction from player)
				var direction = pos - player_grid_pos
				var behind_enemy_pos = pos + direction
				
				# Only add this position if the behind-enemy position is valid
				if movement_strategy.is_position_valid_for_assassin_dash(behind_enemy_pos):
					valid_attack_tiles.append(pos)
					print("Added valid AssassinDash target at:", pos, "with behind-enemy position:", behind_enemy_pos)
				else:
					print("Skipped AssassinDash target at:", pos, "- behind-enemy position blocked:", behind_enemy_pos)
		
		print("Total valid AssassinDash targets found:", valid_attack_tiles.size())
		return

	# Special handling for FiragaCard - use cross pattern with range 5
	if selected_card and selected_card.name == "FiragaCard":
		print("FiragaCard detected - using cross pattern for attack range")
		var cross_positions = []
		
		# Add positions in cross pattern: up, down, left, right (no diagonals)
		for distance in range(1, attack_range + 1):
			# Up
			var up_pos = Vector2i(player_grid_pos.x, player_grid_pos.y - distance)
			if up_pos.y >= 0:
				cross_positions.append(up_pos)
			
			# Down
			var down_pos = Vector2i(player_grid_pos.x, player_grid_pos.y + distance)
			if down_pos.y < grid_size.y:
				cross_positions.append(down_pos)
			
			# Left
			var left_pos = Vector2i(player_grid_pos.x - distance, player_grid_pos.y)
			if left_pos.x >= 0:
				cross_positions.append(left_pos)
			
			# Right
			var right_pos = Vector2i(player_grid_pos.x + distance, player_grid_pos.y)
			if right_pos.x < grid_size.x:
				cross_positions.append(right_pos)
		
		# Add all cross positions to valid attack tiles
		for pos in cross_positions:
			if pos != player_grid_pos:
				valid_attack_tiles.append(pos)
				print("Added valid FiragaCard target at:", pos)
		
		print("Total valid FiragaCard targets found:", valid_attack_tiles.size())
		return

	# Default behavior for other attack cards - use Manhattan distance
	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)
			if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
				valid_attack_tiles.append(pos)

func calculate_valid_aoe_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("Calculating valid AOE attack tiles - Player at:", player_grid_pos, "AOE attack range:", attack_range)

	# Special case for Meteor card - show all tiles within range for 3x2 placement
	if selected_card and selected_card.name == "Meteor":
		print("Meteor card detected - showing all tiles within range for 3x2 placement")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					# Check if this position can be the top-left corner of a 3x2 area
					if can_place_3x2_area_at_position(pos):
						valid_attack_tiles.append(pos)
						print("Added valid 3x2 placement position for Meteor at:", pos)
		print("Total valid 3x2 placement positions for Meteor:", valid_attack_tiles.size())
		return

	print("Total valid AOE attack tiles found:", valid_attack_tiles.size())

func calculate_valid_slash_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("Calculating valid slash attack tiles - Player at:", player_grid_pos, "Slash attack range:", attack_range)
	
	# For SlashCard, show all tiles within range (excluding the player's own tile)
	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)
			if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
				valid_attack_tiles.append(pos)
	
	print("Total valid slash attack tiles found:", valid_attack_tiles.size())

func can_place_3x2_area_at_position(top_left_pos: Vector2i) -> bool:
	"""Check if a 3x2 area can be placed with the given position as top-left corner"""
	# Check if all 6 tiles in the 3x2 area are within grid bounds
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var check_pos = top_left_pos + Vector2i(x_offset, y_offset)
			if check_pos.x >= grid_size.x or check_pos.y >= grid_size.y:
				return false
	return true

func find_valid_3x2_target_position(clicked_pos: Vector2i) -> Vector2i:
	"""Find the top-left position of a valid 3x2 area that contains the clicked position"""
	# Check all possible 3x2 areas that could contain the clicked position
	for y_offset in range(2):  # 2 rows
		for x_offset in range(3):  # 3 columns
			var top_left_pos = clicked_pos - Vector2i(x_offset, y_offset)
			
			# Check if this top-left position is in our valid tiles list
			if top_left_pos in valid_attack_tiles:
				print("Found valid 3x2 area with top-left at:", top_left_pos, "containing clicked position:", clicked_pos)
				return top_left_pos
	
	# If no valid 3x2 area found, return invalid position
	return Vector2i(-1, -1)

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func has_npc_at_position(pos: Vector2i) -> bool:
	"""Check if there's an NPC at the given grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		return false
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		return false
	
	var npcs = entities.get_npcs()
	
	for npc in npcs:
		if is_instance_valid(npc):
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
			
			if npc_pos == pos:
				return true
	
	return false

func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	print("=== GETTING NPC AT POSITION ===")
	print("Position:", pos)
	print("Card effect handler:", card_effect_handler != null)
	
	if not card_effect_handler or not card_effect_handler.course:
		print("✗ No card_effect_handler or course found")
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("✗ No Entities node found")
		return null
	
	print("✓ Entities found")
	var npcs = entities.get_npcs()
	print("Total NPCs found:", npcs.size())
	
	for npc in npcs:
		print("=== CHECKING NPC ===")
		print("NPC reference:", npc)
		print("Is instance valid:", is_instance_valid(npc))
		
		if is_instance_valid(npc):
			print("NPC name:", npc.name)
			print("NPC class:", npc.get_class())
			print("NPC script:", npc.get_script().resource_path if npc.get_script() else "No script")
			print("NPC global position:", npc.global_position)
			
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("Checking NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return npc
		else:
			print("✗ NPC is invalid - reference:", npc)
			if npc != null:
				print("  - NPC name (if available):", npc.name if "name" in npc else "No name property")
				print("  - NPC class (if available):", npc.get_class() if "get_class" in npc else "No get_class method")
		
		print("=== END CHECKING NPC ===")
	
	print("✗ No NPC found at position:", pos)
	return null

func show_attack_highlights() -> void:
	hide_all_attack_highlights()
	for pos in valid_attack_tiles:
		if pos.y < grid_tiles.size() and pos.x < grid_tiles[pos.y].size():
			var tile = grid_tiles[pos.y][pos.x]
			var highlight = tile.get_node_or_null("AttackHighlight")
			if highlight:
				highlight.visible = true
				print("Highlighting tile at:", pos)
			else:
				print("No AttackHighlight node at:", pos)
		else:
			print("Invalid tile position:", pos)
	# Animate CardRow down to get out of the way of range display
	animate_card_row_down()
	# Camera zoom for Meteor is now handled by RangedAttackStrategy

func hide_all_attack_highlights() -> void:
	for y in grid_tiles.size():
		for x in grid_tiles[y].size():
			grid_tiles[y][x].get_node("AttackHighlight").visible = false

func animate_card_row_down() -> void:
	"""Animate the CardRow downwards to get out of the way of range display"""
	if not card_row:
		return
	
	# Stop any existing animation
	if card_row_animation_tween and card_row_animation_tween.is_valid():
		card_row_animation_tween.kill()
	
	# Create new tween for smooth animation
	card_row_animation_tween = create_tween()
	card_row_animation_tween.set_trans(Tween.TRANS_QUAD)
	card_row_animation_tween.set_ease(Tween.EASE_OUT)
	
	# Animate to the offset position
	var target_position = card_row_original_position + Vector2(0, card_row_animation_offset)
	card_row_animation_tween.tween_property(card_row, "position", target_position, card_row_animation_duration)
	
	print("AttackHandler: Animating CardRow down by", card_row_animation_offset, "pixels")

func animate_card_row_up() -> void:
	"""Animate the CardRow back to its original position"""
	if not card_row:
		return
	
	# Stop any existing animation
	if card_row_animation_tween and card_row_animation_tween.is_valid():
		card_row_animation_tween.kill()
	
	# Create new tween for smooth animation
	card_row_animation_tween = create_tween()
	card_row_animation_tween.set_trans(Tween.TRANS_QUAD)
	card_row_animation_tween.set_ease(Tween.EASE_OUT)
	
	# Animate back to the original position
	card_row_animation_tween.tween_property(card_row, "position", card_row_original_position, card_row_animation_duration)
	
	print("AttackHandler: Animating CardRow back to original position")

# These functions are now handled by RangedAttackStrategy

func exit_attack_mode() -> void:
	"""Exit attack mode and clean up"""
	is_attack_mode = false
	
	# Store the selected card before clearing it
	var card_to_discard = selected_card
	var card_discarded := false
	
	selected_card = null
	active_button = null
	valid_attack_tiles.clear()
	
	# Hide all attack highlights
	hide_all_attack_highlights()
	
	# Animate CardRow back to normal position
	animate_card_row_up()
	
	# Camera zoom restoration for Meteor is now handled by RangedAttackStrategy
	
	# Handle card discard
	if card_to_discard:
		# Don't discard club cards here - they're handled by the club card selection system
		if deck_manager.hand.has(card_to_discard) and not deck_manager.is_club_card(card_to_discard):
			deck_manager.discard(card_to_discard)
			card_discarded = true

		if card_discarded:
			card_stack_display.animate_card_discard(card_to_discard.name)
			emit_signal("card_discarded", card_to_discard)
			
			# Update the deck display to reflect the new card counts
			if card_effect_handler and card_effect_handler.course and "ui_manager" in card_effect_handler.course:
				var ui_manager = card_effect_handler.course.ui_manager
				if ui_manager and ui_manager.has_method("update_deck_display"):
					ui_manager.update_deck_display()
			
			# Update the movement buttons to show the remaining cards in hand
			if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_method("create_movement_buttons"):
				card_effect_handler.course.create_movement_buttons()
	
	# Clear the button reference (buttons are recreated by create_movement_buttons)
	active_button = null
	
	# Emit signal
	emit_signal("attack_mode_exited")

func handle_tile_click(x: int, y: int) -> bool:
	"""Handle tile click and return true if attack was successful"""
	var clicked := Vector2i(x, y)
	print("Attack tile click at:", clicked, "Attack mode:", is_attack_mode, "Valid tiles:", valid_attack_tiles)
	
	# Special handling for Meteor card - check if clicked position is within any valid 3x2 area
	if is_attack_mode and selected_card and selected_card.name == "Meteor":
		print("Meteor card detected - checking if clicked position is within valid 3x2 area")
		var target_pos = find_valid_3x2_target_position(clicked)
		if target_pos != Vector2i(-1, -1):
			print("✓ Valid 3x2 target found at:", target_pos, "for clicked position:", clicked)
			ranged_strategy.perform_meteor_attack(target_pos)
			card_play_sound.play()
			return true
		else:
			print("✗ Clicked position not within any valid 3x2 area:", clicked)
			return false
	
	if is_attack_mode and clicked in valid_attack_tiles:
		# Use MeleeAttackStrategy for Kick and PunchB attacks
		if selected_card and selected_card.name == "Kick":
			melee_strategy.perform_kickb_attack(clicked)
			card_play_sound.play()
			return true
		
		if selected_card and selected_card.name == "PunchB":
			melee_strategy.perform_punchb_attack(clicked)
			card_play_sound.play()
			return true
		
		# Use RangedAttackStrategy for AttackDog attacks
		if selected_card and selected_card.name == "AttackDog":
			ranged_strategy.perform_attackdog_attack(clicked)
			card_play_sound.play()
			return true

		# Use RangedAttackStrategy for FiragaCard attacks
		if selected_card and selected_card.name == "FiragaCard":
			ranged_strategy.perform_firaga_attack(clicked)
			card_play_sound.play()
			return true

		# Use MovementAttackStrategy for AssassinDash attacks
		if selected_card and selected_card.name == "AssassinDash":
			movement_strategy.perform_assassin_dash_attack(clicked)
			card_play_sound.play()
			return true
		
		# Use MeleeAttackStrategy for SlashCard attacks
		if selected_card and selected_card.name == "SlashCard":
			melee_strategy.perform_slash_attack(clicked)
			card_play_sound.play()
			return true
		
		# Check for normal NPC attack (fallback)
		var npc = get_npc_at_position(clicked)
		if npc:
			perform_attack(npc, clicked)
			card_play_sound.play()
			return true
		else:
			return false
	else:
		return false

func perform_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Perform the attack on the NPC"""
	
	# Play KickSound if this is a Kick attack
	if selected_card and selected_card.name == "Kick":
		if kick_sound:
			kick_sound.play()
		
		# Emit kick attack signal for animation
		emit_signal("kick_attack_performed")
	
	# Check if NPC is dead
	var is_dead = false
	if npc.has_method("get_is_dead"):
		is_dead = npc.get_is_dead()
	elif npc.has_method("is_dead"):
		is_dead = npc.is_dead()
	elif "is_dead" in npc:
		is_dead = npc.is_dead
	
	if is_dead:
		print("Attacking dead NPC - pushing corpse")
		attack_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			# Use selected_card.damage for attack cards
			if selected_card and selected_card.effect_type in ["Attack", "AOEAttack"]:
				npc.take_damage(selected_card.damage)
			else:
				npc.take_damage(attack_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	# Delegate knockback to melee strategy since it handles knockback logic
	melee_strategy.apply_knockback_to_npc(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, attack_damage)
	
	# Exit attack mode
	exit_attack_mode()



func handle_tile_mouse_entered(x: int, y: int, is_panning: bool) -> void:
	if not is_panning and is_attack_mode:
		# Get tile from grid manager for proper access
		var tile: Control = null
		if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_method("get_grid_manager"):
			var grid_manager = card_effect_handler.course.get_grid_manager()
			if grid_manager and grid_manager.has_method("get_grid_tile"):
				tile = grid_manager.get_grid_tile(x, y)
		
		# Fallback to direct array access
		if not tile and y < grid_tiles.size() and x < grid_tiles[y].size():
			tile = grid_tiles[y][x]
		
		if tile:
			var clicked := Vector2i(x, y)
			
			if not Vector2i(x, y) in valid_attack_tiles:
				var highlight = tile.get_node_or_null("Highlight")
				if highlight:
					highlight.visible = true

func handle_tile_mouse_exited(x: int, y: int, is_panning: bool) -> void:
	if not is_panning:
		# Get tile from grid manager for proper access
		var tile = null
		if card_effect_handler and card_effect_handler.course and card_effect_handler.course.has_method("get_grid_manager"):
			var grid_manager = card_effect_handler.course.get_grid_manager()
			if grid_manager and grid_manager.has_method("get_grid_tile"):
				tile = grid_manager.get_grid_tile(x, y)
		
		# Fallback to direct array access
		if not tile and y < grid_tiles.size() and x < grid_tiles[y].size():
			tile = grid_tiles[y][x]
		
		if tile:
			var highlight = tile.get_node_or_null("Highlight")
			if highlight:
				highlight.visible = false

func clear_all_attack_ui() -> void:
	"""Clear all attack-related UI elements"""
	hide_all_attack_highlights()
	selected_card = null
	active_button = null
	is_attack_mode = false

func get_attack_cards_for_inventory() -> Array[CardData]:
	"""Get all attack cards from the current hand"""
	return deck_manager.hand.filter(func(card): return card.effect_type == "Attack")

func _on_player_moved_to_tile(new_grid_pos: Vector2i) -> void:
	"""Handle player movement to update attack highlights"""
	player_grid_pos = new_grid_pos
	
	# Update strategies with new player position
	melee_strategy.update_player_position(new_grid_pos)
	ranged_strategy.update_player_position(new_grid_pos)
	movement_strategy.update_player_position(new_grid_pos)
	
	# If we're in attack mode, recalculate valid attack tiles with the new position
	if is_attack_mode:
		calculate_valid_attack_tiles()
		show_attack_highlights()

# Strategy signal handlers
func _on_strategy_npc_attacked(npc: Node, damage: int) -> void:
	"""Handle NPC attacked signal from strategies"""
	emit_signal("npc_attacked", npc, damage)

func _on_strategy_kick_attack_performed() -> void:
	"""Handle kick attack performed signal from melee strategy"""
	emit_signal("kick_attack_performed")

func _on_strategy_punchb_attack_performed() -> void:
	"""Handle punch attack performed signal from melee strategy"""
	emit_signal("punchb_attack_performed")

func _on_strategy_slash_attack_performed() -> void:
	"""Handle slash attack performed signal from melee strategy"""
	emit_signal("slash_attack_performed")

func _on_strategy_assassin_dash_attack_performed() -> void:
	"""Handle assassin dash attack performed signal from movement strategy"""
	emit_signal("assassin_dash_attack_performed")

func _on_strategy_ash_dog_attack_performed() -> void:
	"""Handle ash dog attack performed signal from ranged strategy"""
	emit_signal("ash_dog_attack_performed")

func _on_strategy_attack_completed() -> void:
	"""Handle attack completed signal from strategies"""
	exit_attack_mode()

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	print("🔍 ATTACK_HANDLER DEBUG: update_player_position called with:", new_grid_pos)
	print("🔍 Previous player_grid_pos:", player_grid_pos)
	print("🔍 Is attack mode:", is_attack_mode)
	print("🔍 Selected card:", selected_card.name if selected_card else "None")
	
	player_grid_pos = new_grid_pos
	print("🔍 ATTACK_HANDLER DEBUG: player_grid_pos updated to:", player_grid_pos)
	
	# Update strategies with new player position
	melee_strategy.update_player_position(new_grid_pos)
	ranged_strategy.update_player_position(new_grid_pos)
	movement_strategy.update_player_position(new_grid_pos)
	
	# If we're in attack mode, recalculate valid attack tiles with the new position
	if is_attack_mode:
		print("🔍 ATTACK_HANDLER DEBUG: Recalculating attack tiles for new position")
		calculate_valid_attack_tiles()
		show_attack_highlights()
		print("🔍 ATTACK_HANDLER DEBUG: Attack tiles recalculated")

func is_in_attack_mode() -> bool:
	return is_attack_mode

func get_selected_card() -> CardData:
	return selected_card

func get_valid_attack_tiles() -> Array:
	return valid_attack_tiles.duplicate()

func has_oil_drum_at_position(pos: Vector2i) -> bool:
	"""Check if there's an oil drum at the given grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found for oil drum check at:", pos)
		return false
	
	# Look for oil drums in the interactables group
	var interactables = get_tree().get_nodes_in_group("interactables")
	
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position"):
			var interactable_pos = interactable.get_grid_position()
			if interactable_pos == pos and interactable.name.begins_with("OilDrum"):
				print("Found oil drum at position:", pos, "Oil drum:", interactable.name)
				return true
	
	print("No oil drum found at position:", pos)
	return false

func get_oil_drum_at_position(pos: Vector2i) -> Node:
	"""Get the oil drum at the given grid position, or null if none"""
	# Look for oil drums in the interactables group
	var interactables = get_tree().get_nodes_in_group("interactables")
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position"):
			if interactable.get_grid_position() == pos and interactable.name.begins_with("OilDrum"):
				return interactable
	
	return null
