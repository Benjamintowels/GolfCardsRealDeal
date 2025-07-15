extends Node
class_name AttackHandler

# Attack system variables
var is_attack_mode := false
var attack_range := 1
var valid_attack_tiles := []
var selected_card: CardData = null
var active_button: TextureButton = null
var attack_buttons := []
var attack_buttons_container: BoxContainer

# References
var player_node: Node2D
var grid_tiles: Array
var grid_size: Vector2i
var cell_size: int
var obstacle_map: Dictionary
var player_grid_pos: Vector2i
var player_stats: Dictionary

# Sound effects
var card_click_sound: AudioStreamPlayer2D
var card_play_sound: AudioStreamPlayer2D
var kick_sound: AudioStreamPlayer2D  # Reference to KickSound from player scene
var punchb_sound: AudioStreamPlayer2D  # Reference to PunchB sound from player scene
var assassin_dash_sound: AudioStreamPlayer2D  # Reference to AssassinDash sound
var assassin_cut_sound: AudioStreamPlayer2D  # Reference to AssassinDash cut sound

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
var knockback_distance := 1

# Ash dog attack properties
var ash_dog_damage := 50

# Signals
signal attack_mode_entered
signal attack_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)
signal npc_attacked(npc: Node, damage: int)
signal kick_attack_performed
signal punchb_attack_performed
signal ash_dog_attack_performed

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
	attack_buttons_container_ref: BoxContainer,
	card_click_sound_ref: AudioStreamPlayer2D,
	card_play_sound_ref: AudioStreamPlayer2D,
	card_stack_display_ref: Control,
	deck_manager_ref: DeckManager,
	card_effect_handler_ref: Node,
	kick_sound_ref: AudioStreamPlayer2D = null,
	punchb_sound_ref: AudioStreamPlayer2D = null,
	assassin_dash_sound_ref: AudioStreamPlayer2D = null,
	assassin_cut_sound_ref: AudioStreamPlayer2D = null,
	card_row_ref: Control = null
):
	player_node = player_node_ref
	grid_tiles = grid_tiles_ref
	grid_size = grid_size_ref
	cell_size = cell_size_ref
	obstacle_map = obstacle_map_ref
	player_grid_pos = player_grid_pos_ref
	player_stats = player_stats_ref
	attack_buttons_container = attack_buttons_container_ref
	card_click_sound = card_click_sound_ref
	card_play_sound = card_play_sound_ref
	card_stack_display = card_stack_display_ref
	deck_manager = deck_manager_ref
	card_effect_handler = card_effect_handler_ref
	kick_sound = kick_sound_ref
	punchb_sound = punchb_sound_ref
	assassin_dash_sound = assassin_dash_sound_ref
	assassin_cut_sound = assassin_cut_sound_ref
	card_row = card_row_ref
	
	# Store the original position of the CardRow for animation
	if card_row:
		card_row_original_position = card_row.position

# Reference to movement controller for button cleanup
var movement_controller: Node = null

func set_movement_controller(controller: Node) -> void:
	movement_controller = controller

func create_attack_buttons() -> void:
	# Attack cards are now handled by the movement controller
	# This function is kept for compatibility but doesn't create separate buttons
	pass

func _on_attack_card_pressed(card: CardData, button: TextureButton) -> void:
	print("=== ATTACK CARD PRESSED ===")
	print("Card:", card.name, "Effect type:", card.effect_type)
	print("Card in hand:", deck_manager.hand.has(card))
	print("Attack handler setup check - card_effect_handler:", card_effect_handler != null)
	print("Attack handler setup check - deck_manager:", deck_manager != null)
	
	if selected_card == card:
		print("Card already selected, returning")
		return
	card_click_sound.play()
	hide_all_attack_highlights()
	valid_attack_tiles.clear()

	is_attack_mode = true
	active_button = button
	selected_card = card
	attack_range = card.get_effective_strength()
	print("Attack range set to:", attack_range)

	calculate_valid_attack_tiles()
	show_attack_highlights()
	
	emit_signal("attack_mode_entered")
	emit_signal("card_selected", card)
	print("=== END ATTACK CARD PRESSED ===")

func calculate_valid_attack_tiles() -> void:
	valid_attack_tiles.clear()
	print("Calculating valid attack tiles - Player at:", player_grid_pos, "Attack range:", attack_range)

	# Special case for Kick card - show all adjacent tiles regardless of content
	if selected_card and selected_card.name == "Kick":
		print("Kick card detected - showing all adjacent tiles")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					valid_attack_tiles.append(pos)
					print("Added adjacent tile for Kick card at:", pos)
		print("Total adjacent tiles for Kick card:", valid_attack_tiles.size())
		return

	# Special case for Punch card - show all tiles in cross pattern regardless of content
	if selected_card and selected_card.name == "Punch":
		print("Punch card detected - showing all tiles in cross pattern")
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
		
		# Add all cross positions to valid attack tiles (regardless of content)
		for pos in cross_positions:
			valid_attack_tiles.append(pos)
			print("Added cross pattern tile for Punch card at:", pos)
		
		print("Total cross pattern tiles for Punch card:", valid_attack_tiles.size())
		return

	# Special case for PunchB card - show all tiles in cross pattern regardless of content
	if selected_card and selected_card.name == "PunchB":
		print("PunchB card detected - showing all tiles in cross pattern")
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
		
		# Add all cross positions to valid attack tiles (regardless of content)
		for pos in cross_positions:
			valid_attack_tiles.append(pos)
			print("Added cross pattern tile for PunchB card at:", pos)
		
		print("Total cross pattern tiles for PunchB card:", valid_attack_tiles.size())
		return

	# Special case for AttackDog card - show all tiles within range regardless of content
	if selected_card and selected_card.name == "AttackDog":
		print("AttackDog card detected - showing all tiles within range")
		for y in grid_size.y:
			for x in grid_size.x:
				var pos := Vector2i(x, y)
				if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
					valid_attack_tiles.append(pos)
					print("Added tile for AttackDog card at:", pos)
		print("Total tiles for AttackDog card:", valid_attack_tiles.size())
		return

	# Special case for AssassinDash card - show cross pattern but only if tile behind enemy is available
	if selected_card and selected_card.name == "AssassinDash":
		print("AssassinDash card detected - showing cross pattern with behind-enemy validation")
		
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
		
		# Check each cross position for NPCs and validate behind-enemy tiles
		for pos in cross_positions:
			if has_npc_at_position(pos):
				# Calculate the position behind the enemy (opposite direction from player)
				var direction = pos - player_grid_pos
				var behind_enemy_pos = pos + direction
				
				# Check if the tile behind the enemy is available
				if is_position_valid_for_assassin_dash(behind_enemy_pos):
					valid_attack_tiles.append(pos)
					print("Added AssassinDash target at:", pos, "with valid behind-enemy tile at:", behind_enemy_pos)
				else:
					print("Skipped AssassinDash target at:", pos, "- behind-enemy tile not available at:", behind_enemy_pos)
		
		print("Total valid AssassinDash targets:", valid_attack_tiles.size())
		return

	# DEBUG: Print all oil drum grid positions
	var interactables = get_tree().get_nodes_in_group("interactables")
	print("Found", interactables.size(), "interactables in group")
	for interactable in interactables:
		if is_instance_valid(interactable) and interactable.has_method("get_grid_position") and interactable.name.begins_with("OilDrum"):
			print("OIL DRUM DEBUG: Oil drum '", interactable.name, "' at grid position:", interactable.get_grid_position())

	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)

			if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
				# Check if there's an NPC at this position
				if has_npc_at_position(pos):
					valid_attack_tiles.append(pos)
					print("Found valid attack tile at:", pos)
				# Check if there's an oil drum at this position (for KickB card)
				elif has_oil_drum_at_position(pos):
					valid_attack_tiles.append(pos)
					print("Found oil drum at attack tile:", pos)
	
	print("Total valid attack tiles found:", valid_attack_tiles.size())

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func has_npc_at_position(pos: Vector2i) -> bool:
	"""Check if there's an NPC at the given grid position"""
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found for NPC check at:", pos)
		return false
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("No Entities found for NPC check at:", pos)
		return false
	
	var npcs = entities.get_npcs()
	print("=== NPC DETECTION DEBUG ===")
	print("Checking for NPC at position:", pos)
	print("Total NPCs in Entities:", npcs.size())
	
	for npc in npcs:
		if is_instance_valid(npc):
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("NPC:", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("NPC:", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("NPC:", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("NPC:", npc.name, "at position:", npc_pos, "(calculated from world position)")
			
			if npc_pos == pos:
				print("✓ Found NPC at position:", pos, "NPC:", npc.name)
				return true
		else:
			print("✗ Invalid NPC reference:", npc)
	
	print("✗ No NPC found at position:", pos)
	print("=== END NPC DETECTION DEBUG ===")
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
	print("Showing attack highlights for", valid_attack_tiles.size(), "tiles")
	for pos in valid_attack_tiles:
		# Create orange attack highlight
		var tile = grid_tiles[pos.y][pos.x]
		var attack_highlight = tile.get_node_or_null("AttackHighlight")
		if not attack_highlight:
			attack_highlight = ColorRect.new()
			attack_highlight.name = "AttackHighlight"
			attack_highlight.size = tile.size
			attack_highlight.color = Color(1, 0.5, 0, 0.6)  # Orange with more opacity
			attack_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			attack_highlight.z_index = 200  # Much higher than movement highlights
			tile.add_child(attack_highlight)
			print("Created new attack highlight for tile at", pos)
		attack_highlight.visible = true
		print("Made attack highlight visible for tile at", pos)
	
	# Animate CardRow down to get out of the way of range display
	animate_card_row_down()

func hide_all_attack_highlights() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			var tile = grid_tiles[y][x]
			var attack_highlight = tile.get_node_or_null("AttackHighlight")
			if attack_highlight:
				attack_highlight.visible = false

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

func exit_attack_mode() -> void:
	print("=== EXITING ATTACK MODE ===")
	print("Selected card:", selected_card.name if selected_card else "None")
	print("Card in hand:", deck_manager.hand.has(selected_card) if selected_card else "N/A")
	print("Hand contents:", deck_manager.hand.map(func(c): return c.name))
	is_attack_mode = false
	hide_all_attack_highlights()
	valid_attack_tiles.clear()
	# Animate CardRow back to original position
	animate_card_row_up()
	if selected_card:
		print("AttackHandler: Exiting attack mode with card:", selected_card.name)
		print("AttackHandler: Card in hand:", deck_manager.hand.has(selected_card))
		if deck_manager.hand.has(selected_card):
			print("AttackHandler: Discarding attack card from hand:", selected_card.name)
			deck_manager.discard(selected_card)
			card_stack_display.animate_card_discard(selected_card.name)
			emit_signal("card_discarded", selected_card)
		else:
			print("AttackHandler: Card not in hand:", selected_card.name)
	print("=== END EXITING ATTACK MODE ===")
	# Clean up the button directly
	if active_button and active_button.is_inside_tree():
		if movement_controller and movement_controller.has_method("get_movement_buttons_container"):
			var container = movement_controller.get_movement_buttons_container()
			if container and container.has_node(NodePath(active_button.name)):
				container.remove_child(active_button)
		active_button.queue_free()
		# Also remove from movement controller's button list if it exists
		if movement_controller and movement_controller.has_method("remove_button_from_list"):
			movement_controller.remove_button_from_list(active_button)
	active_button = null
	selected_card = null
	emit_signal("attack_mode_exited")

func handle_tile_click(x: int, y: int) -> bool:
	"""Handle tile click and return true if attack was successful"""
	var clicked := Vector2i(x, y)
	print("Attack tile click at:", clicked, "Attack mode:", is_attack_mode, "Valid tiles:", valid_attack_tiles)
	
	if is_attack_mode and clicked in valid_attack_tiles:
		print("=== ATTACK TILE CLICK DEBUG ===")
		print("Selected card:", selected_card.name if selected_card else "None")
		print("Card name check:", selected_card.name == "Kick" if selected_card else "N/A")
		
		# Check if this is a KickB card attack on an oil drum
		if selected_card and selected_card.name == "Kick":
			print("Kick card detected - checking for oil drum at:", clicked)
			var oil_drum = get_oil_drum_at_position(clicked)
			if oil_drum:
				print("✓ Oil drum found - performing KickB attack!")
				perform_kickb_attack_on_oil_drum(oil_drum, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No oil drum found at position:", clicked)
		
		# Check if this is a PunchB card attack
		if selected_card and selected_card.name == "PunchB":
			print("PunchB card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			var oil_drum = get_oil_drum_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing PunchB attack!")
				perform_punchb_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			elif oil_drum:
				print("✓ Oil drum found - performing PunchB attack!")
				perform_punchb_attack_on_oil_drum(oil_drum, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No valid target found at position:", clicked)
				return false
		
		# Check if this is an AttackDog card attack
		if selected_card and selected_card.name == "AttackDog":
			print("AttackDog card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing AttackDog attack!")
				perform_attackdog_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No NPC found at position:", clicked)
				return false

		# Check if this is an AssassinDash card attack
		if selected_card and selected_card.name == "AssassinDash":
			print("AssassinDash card detected - checking for target at:", clicked)
			var npc = get_npc_at_position(clicked)
			
			if npc:
				print("✓ NPC found - performing AssassinDash attack!")
				perform_assassin_dash_attack_on_npc(npc, clicked)
				card_play_sound.play()
				return true
			else:
				print("✗ No NPC found at position:", clicked)
				return false
		
		# Check for normal NPC attack
		var npc = get_npc_at_position(clicked)
		if npc:
			print("Performing attack on NPC at:", clicked)
			perform_attack(npc, clicked)
			card_play_sound.play()
			return true
		else:
			print("No NPC found at attack position:", clicked)
			return false
	else:
		print("Invalid attack tile or not in attack mode - Clicked:", clicked, "Valid tiles:", valid_attack_tiles, "Attack mode:", is_attack_mode)
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
		# Don't deal damage to dead NPCs, just push them
		attack_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(attack_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, attack_damage)
	
	# Exit attack mode
	exit_attack_mode()

func apply_knockback(npc: Node, current_pos: Vector2i) -> void:
	"""Apply knockback to the NPC, pushing them 1 tile away from the player"""
	
	# Calculate direction from player to NPC
	var direction = current_pos - player_grid_pos
	# For grid-based movement, we need to handle direction differently
	var knockback_pos = current_pos
	
	# Check if this is a GangMember and if it's frozen
	var actual_knockback_distance = knockback_distance
	if npc.has_method("is_frozen_state") and npc.is_frozen_state():
		actual_knockback_distance = knockback_distance * 3
		print("GangMember is frozen - applying triple knockback distance:", actual_knockback_distance)
	
	if direction.x > 0:
		knockback_pos.x += actual_knockback_distance
	elif direction.x < 0:
		knockback_pos.x -= actual_knockback_distance
	elif direction.y > 0:
		knockback_pos.y += actual_knockback_distance
	elif direction.y < 0:
		knockback_pos.y -= actual_knockback_distance
	
	# Check if knockback position is valid
	if is_position_valid_for_knockback(knockback_pos):
		# Use animated pushback if the NPC supports it
		if npc.has_method("push_back"):
			npc.push_back(knockback_pos)
			print("Applied animated pushback to NPC (distance:", actual_knockback_distance, ")")
		else:
			# Fallback to instant position change
			npc.set_grid_position(knockback_pos)
			
			# Update Y-sorting
			if npc.has_method("update_z_index_for_ysort"):
				npc.update_z_index_for_ysort()
			print("Applied instant pushback to NPC (distance:", actual_knockback_distance, ", no animation support)")

func is_position_valid_for_assassin_dash(pos: Vector2i) -> bool:
	"""Check if a position is valid for AssassinDash behind-enemy movement"""
	var is_valid = true
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		is_valid = false
	
	# Check if the position is occupied by an obstacle
	elif obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			is_valid = false
	
	# Check if the position is occupied by another NPC
	elif card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func is_position_valid_for_knockback(pos: Vector2i) -> bool:
	"""Check if a position is valid for NPC knockback"""
	var is_valid = true
	
	# Basic bounds checking
	if pos.x < 0 or pos.y < 0 or pos.x > 100 or pos.y > 100:
		is_valid = false
	
	# Check if the position is occupied by an obstacle
	elif obstacle_map.has(pos):
		var obstacle = obstacle_map[pos]
		if obstacle.has_method("blocks") and obstacle.blocks():
			is_valid = false
	
	# Check if the position is occupied by another NPC
	elif card_effect_handler and card_effect_handler.course:
		var entities = card_effect_handler.course.get_node_or_null("Entities")
		if entities and entities.has_method("get_npcs"):
			var npcs = entities.get_npcs()
			for npc in npcs:
				if is_instance_valid(npc) and npc.has_method("get_grid_position"):
					if npc.get_grid_position() == pos:
						is_valid = false
						break
	
	# Check if the position is occupied by the player
	elif pos == player_grid_pos:
		is_valid = false
	
	return is_valid

func handle_tile_mouse_entered(x: int, y: int, is_panning: bool) -> void:
	if not is_panning and is_attack_mode:
		var tile: Control = grid_tiles[y][x]
		var clicked := Vector2i(x, y)
		
		if not Vector2i(x, y) in valid_attack_tiles:
			var highlight = tile.get_node_or_null("Highlight")
			if highlight:
				highlight.visible = true

func handle_tile_mouse_exited(x: int, y: int, is_panning: bool) -> void:
	if not is_panning:
		var tile = grid_tiles[y][x]
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

func _debug_list_all_npcs() -> void:
	"""Debug function to list all NPCs and their positions"""
	print("=== DEBUG: LISTING ALL NPCs ===")
	
	if not card_effect_handler or not card_effect_handler.course:
		print("No card_effect_handler or course found")
		return
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		print("No Entities found")
		return
	
	var npcs = entities.get_npcs()
	print("Total NPCs in Entities:", npcs.size())
	
	for i in range(npcs.size()):
		var npc = npcs[i]
		if is_instance_valid(npc):
			var npc_pos = Vector2i.ZERO
			
			# Try to get grid position using different methods
			if npc.has_method("get_grid_position"):
				npc_pos = npc.get_grid_position()
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using get_grid_position)")
			elif "grid_position" in npc:
				npc_pos = npc.grid_position
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using grid_position property)")
			elif "grid_pos" in npc:
				npc_pos = npc.grid_pos
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(using grid_pos property)")
			else:
				# Fallback: calculate grid position from world position
				var world_pos = npc.global_position
				var cell_size_used = cell_size if "cell_size" in npc else 48
				npc_pos = Vector2i(floor(world_pos.x / cell_size_used), floor(world_pos.y / cell_size_used))
				print("NPC", i, ":", npc.name, "at position:", npc_pos, "(calculated from world position)")
		else:
			print("NPC", i, ": Invalid NPC reference:", npc)
	
	print("=== END DEBUG: LISTING ALL NPCs ===")

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_grid_pos
	
	# If we're in attack mode, recalculate valid attack tiles with the new position
	if is_attack_mode:
		calculate_valid_attack_tiles()
		show_attack_highlights()

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

func perform_kickb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform KickB attack on oil drum - tips it over immediately"""
	print("=== PERFORMING KICKB ATTACK ON OIL DRUM ===")
	print("Oil drum:", oil_drum.name)
	print("Target position:", target_pos)
	print("Oil drum has take_damage method:", oil_drum.has_method("take_damage"))
	
	# Play KickSound
	if kick_sound:
		kick_sound.play()
	
	# Emit kick attack signal for animation
	emit_signal("kick_attack_performed")
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
		print("Oil drum tipped over status:", is_tipped)
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
		print("Oil drum tipped over status (property):", is_tipped)
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with KickB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			print("Calling take_damage(50) on oil drum")
			# Deal enough damage to kill it (50 damage)
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)  # Use 50 damage for signal
	
	# Exit attack mode
	exit_attack_mode()
	
	print("=== END KICKB ATTACK ON OIL DRUM ===") 

func perform_attackdog_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AttackDog attack on NPC with Ash dog animation"""
	print("=== PERFORMING ATTACKDOG ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Emit ash dog attack signal for animation
	emit_signal("ash_dog_attack_performed")
	
	# Create and animate Ash dog
	create_and_animate_ash_dog(npc, target_pos)

func create_and_animate_ash_dog(npc: Node, target_pos: Vector2i) -> void:
	"""Create Ash dog and animate it to attack the target"""
	# Load Ash scene
	var ash_scene = preload("res://NPC/Animals/Ash/Ash.tscn")
	if not ash_scene:
		print("Error: Failed to load Ash scene")
		complete_attackdog_attack(npc, target_pos)
		return
	
	var ash = ash_scene.instantiate()
	if not ash:
		print("Error: Failed to instantiate Ash")
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Add Ash as child of the player character (BennyChar, LaylaChar, etc.)
	var character_node = null
	if player_node:
		# Find the character node (BennyChar, LaylaChar, etc.)
		for child in player_node.get_children():
			if child.name.ends_with("Char"):
				character_node = child
				break
		
		if character_node:
			character_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of", character_node.name, "at position:", ash.global_position)
		else:
			# Fallback: add to player node directly
			player_node.add_child(ash)
			ash.global_position = player_node.global_position
			print("Ash dog created as child of player node at position:", ash.global_position)
	else:
		print("Error: No player node found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Play Ash bark sound
	var ash_bark = ash.get_node_or_null("AshBark")
	if ash_bark:
		ash_bark.play()
		print("Playing Ash bark sound")
	
	# Get target world position
	var target_world_pos = Vector2(target_pos.x * cell_size + cell_size/2, target_pos.y * cell_size + cell_size/2)
	if card_effect_handler and card_effect_handler.course:
		target_world_pos += card_effect_handler.course.camera_container.global_position
	
	# Calculate direction for sprite orientation
	var direction = target_world_pos - ash.global_position
	var is_horizontal = abs(direction.x) > abs(direction.y)
	var is_up = direction.y < 0
	
	# Set up Ash sprites
	var default_sprite = ash.get_node_or_null("AshDefaultSprite")
	var attack_sprite = ash.get_node_or_null("AshAttackSprite")
	
	if not default_sprite or not attack_sprite:
		print("Error: Ash sprites not found")
		ash.queue_free()
		complete_attackdog_attack(npc, target_pos)
		return
	
	# Hide default sprite, show attack sprite
	default_sprite.visible = false
	attack_sprite.visible = true
	
	# Set appropriate attack sprite based on direction
	if is_horizontal:
		# Use AshAttackLeftRight for horizontal movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackLeftRight.png")
		attack_sprite.flip_h = direction.x < 0  # Flip if moving left
	else:
		# Use AshAttackUp for vertical movement
		attack_sprite.texture = load("res://NPC/Animals/Ash/AshAttackUp.png")
		attack_sprite.flip_h = false  # No flip for vertical
	
	print("Ash dog attacking in direction:", "horizontal" if is_horizontal else "vertical", "flip_h:", attack_sprite.flip_h)
	
	# Animate Ash to target position
	var tween = create_tween()
	tween.tween_property(ash, "global_position", target_world_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		# Flash effect at target
		create_flash_effect(target_world_pos)
		
		# Switch to default sprite
		attack_sprite.visible = false
		default_sprite.visible = true
		
		# Set appropriate default sprite based on direction
		if is_horizontal:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultLeftRight.png")
			default_sprite.flip_h = direction.x < 0  # Flip if moving left
		else:
			default_sprite.texture = load("res://NPC/Animals/Ash/AshDefaultUp.png")
			default_sprite.flip_h = false  # No flip for vertical
		
		# Flip the sprite to face the opposite direction for return journey
		if is_horizontal:
			default_sprite.flip_h = direction.x >= 0  # Flip to face opposite direction
		# For vertical movement, we don't need to flip since it's the same sprite
		
		# Animate back to player
		var return_tween = create_tween()
		return_tween.tween_property(ash, "global_position", player_node.global_position, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		return_tween.tween_callback(func():
			# Remove Ash and complete attack
			ash.queue_free()
			complete_attackdog_attack(npc, target_pos)
		)
	)

func create_flash_effect(position: Vector2) -> void:
	"""Create a flash effect at the specified position"""
	# Create a simple flash effect using a ColorRect
	var flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.size = Vector2(48, 48)  # Same size as a tile
	flash.global_position = position - flash.size / 2
	flash.z_index = 1000  # Very high z-index to appear on top
	
	# Add to the scene
	if card_effect_handler and card_effect_handler.course:
		card_effect_handler.course.add_child(flash)
	else:
		add_child(flash)
	
	# Animate flash
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	flash_tween.tween_callback(flash.queue_free)

func complete_attackdog_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Complete the AttackDog attack by dealing damage"""
	print("Completing AttackDog attack on NPC:", npc.name)
	
	# Deal 50 damage to the NPC
	var damage = ash_dog_damage
	
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
		damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, damage)
	
	# Exit attack mode
	exit_attack_mode()
	
	print("=== END ATTACKDOG ATTACK ===")

func perform_punchb_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on NPC with movement animation"""
	print("=== PERFORMING PUNCHB ATTACK ON NPC ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance = calculate_grid_distance(player_grid_pos, target_pos)
	print("Distance to target:", distance)
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# If target is adjacent (distance = 1), attack immediately
	if distance == 1:
		print("Target is adjacent - attacking immediately")
		perform_punchb_attack_immediate(npc, target_pos)
	else:
		# Target is 2 tiles away - animate player movement
		print("Target is 2 tiles away - animating player movement")
		perform_punchb_attack_with_movement(npc, target_pos, original_player_pos)

func perform_punchb_attack_on_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack on oil drum with movement animation"""
	print("=== PERFORMING PUNCHB ATTACK ON OIL DRUM ===")
	print("Oil drum:", oil_drum.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	
	# Calculate distance to target
	var distance = calculate_grid_distance(player_grid_pos, target_pos)
	print("Distance to target:", distance)
	
	# Store original player position
	var original_player_pos = player_grid_pos
	
	# If target is adjacent (distance = 1), attack immediately
	if distance == 1:
		print("Target is adjacent - attacking immediately")
		perform_punchb_attack_immediate_oil_drum(oil_drum, target_pos)
	else:
		# Target is 2 tiles away - animate player movement
		print("Target is 2 tiles away - animating player movement")
		perform_punchb_attack_with_movement_oil_drum(oil_drum, target_pos, original_player_pos)

func perform_punchb_attack_immediate(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately (target is adjacent)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Emit punchb attack signal for animation
	emit_signal("punchb_attack_performed")
	
	# Deal 30 damage
	var punchb_damage = 30
	
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
		punchb_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(punchb_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, punchb_damage)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_oil_drum(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately on oil drum (target is adjacent)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Emit punchb attack signal for animation
	emit_signal("punchb_attack_performed")
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with PunchB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_no_animation(npc: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately without triggering animation (animation already playing)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Deal 30 damage
	var punchb_damage = 30
	
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
		punchb_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(punchb_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, punchb_damage)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_immediate_oil_drum_no_animation(oil_drum: Node, target_pos: Vector2i) -> void:
	"""Perform PunchB attack immediately on oil drum without triggering animation (animation already playing)"""
	# Play PunchB sound
	if punchb_sound:
		punchb_sound.play()
	
	# Check if oil drum is already tipped over
	var is_tipped = false
	if oil_drum.has_method("get_is_tipped_over"):
		is_tipped = oil_drum.get_is_tipped_over()
	elif "is_tipped_over" in oil_drum:
		is_tipped = oil_drum.is_tipped_over
	
	if is_tipped:
		print("Oil drum is already tipped over - no effect")
	else:
		print("Tipping over oil drum with PunchB attack!")
		# Force the oil drum to tip over by setting its health to 0
		if oil_drum.has_method("take_damage"):
			oil_drum.take_damage(50)
		else:
			print("Oil drum doesn't have take_damage method!")
	
	# Emit signal for attack completion
	emit_signal("npc_attacked", oil_drum, 50)
	
	# Exit attack mode
	exit_attack_mode()

func perform_punchb_attack_with_movement(npc: Node, target_pos: Vector2i, original_player_pos: Vector2i) -> void:
	"""Perform PunchB attack with player movement animation (target is 2 tiles away)"""
	# Calculate the intermediate position (1 tile closer to target)
	var direction = target_pos - original_player_pos
	var intermediate_pos = original_player_pos + Vector2i(sign(direction.x), sign(direction.y))
	
	print("Moving player from", original_player_pos, "to", intermediate_pos, "then to", target_pos)
	
	# Start punch animation immediately when movement begins
	emit_signal("punchb_attack_performed")
	
	# Animate player movement to target
	if player_node and player_node.has_method("animate_to_position"):
		# First move to intermediate position
		player_node.animate_to_position(intermediate_pos, func():
			# Then move to target position
			player_node.animate_to_position(target_pos, func():
				# Perform the attack (without animation since it's already playing)
				perform_punchb_attack_immediate_no_animation(npc, target_pos)
				# Move back to original position
				player_node.animate_to_position(original_player_pos, func():
					# Update player grid position
					player_grid_pos = original_player_pos
					# Update the course's player position reference
					if card_effect_handler and card_effect_handler.course:
						card_effect_handler.course.player_grid_pos = original_player_pos
				)
			)
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_punchb_attack_immediate(npc, target_pos)

func perform_punchb_attack_with_movement_oil_drum(oil_drum: Node, target_pos: Vector2i, original_player_pos: Vector2i) -> void:
	"""Perform PunchB attack on oil drum with player movement animation (target is 2 tiles away)"""
	# Calculate the intermediate position (1 tile closer to target)
	var direction = target_pos - original_player_pos
	var intermediate_pos = original_player_pos + Vector2i(sign(direction.x), sign(direction.y))
	
	print("Moving player from", original_player_pos, "to", intermediate_pos, "then to", target_pos)
	
	# Start punch animation immediately when movement begins
	emit_signal("punchb_attack_performed")
	
	# Animate player movement to target
	if player_node and player_node.has_method("animate_to_position"):
		# First move to intermediate position
		player_node.animate_to_position(intermediate_pos, func():
			# Then move to target position
			player_node.animate_to_position(target_pos, func():
				# Perform the attack (without animation since it's already playing)
				perform_punchb_attack_immediate_oil_drum_no_animation(oil_drum, target_pos)
				# Move back to original position
				player_node.animate_to_position(original_player_pos, func():
					# Update player grid position
					player_grid_pos = original_player_pos
					# Update the course's player position reference
					if card_effect_handler and card_effect_handler.course:
						card_effect_handler.course.player_grid_pos = original_player_pos
				)
			)
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_punchb_attack_immediate_oil_drum(oil_drum, target_pos)

func perform_assassin_dash_attack_on_npc(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack on NPC with movement to behind-enemy position"""
	print("=== PERFORMING ASSASSIN DASH ATTACK ===")
	print("NPC:", npc.name)
	print("Target position:", target_pos)
	print("Player position:", player_grid_pos)
	print("[AssassinDash] selected_card:", selected_card.name if selected_card else "None", "hand:", deck_manager.hand.map(func(c): return c.name))
	# Calculate the position behind the enemy (opposite direction from player)
	var direction = target_pos - player_grid_pos
	var behind_enemy_pos = target_pos + direction
	print("Moving player to behind-enemy position:", behind_enemy_pos)
	# Store original player position
	var original_player_pos = player_grid_pos
	# Play camera whoosh sound when card is played
	if assassin_dash_sound:
		assassin_dash_sound.play()
	# Animate player movement to behind-enemy position
	if player_node and player_node.has_method("animate_to_position"):
		player_node.animate_to_position(behind_enemy_pos, func():
			# Play cut sound when reaching the NPC
			if assassin_cut_sound:
				assassin_cut_sound.play()
			# Deal 40 damage to the NPC
			var assassin_damage = 40
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
				assassin_damage = 0
			else:
				# Deal damage to the NPC
				if npc.has_method("take_damage"):
					npc.take_damage(assassin_damage)
				else:
					print("NPC does not have take_damage method")
			# Apply knockback (works for both living and dead NPCs)
			apply_knockback(npc, target_pos)
			# Emit signal
			emit_signal("npc_attacked", npc, assassin_damage)
			
			# Update player grid position to behind-enemy position (stay there)
			player_grid_pos = behind_enemy_pos
			# Update the course's player position reference
			if card_effect_handler and card_effect_handler.course:
				card_effect_handler.course.player_grid_pos = behind_enemy_pos
			
			# Exit attack mode
			exit_attack_mode()
		)
	else:
		# Fallback if animation is not available
		print("Player animation not available - performing immediate attack")
		perform_assassin_dash_attack_immediate(npc, target_pos)

func perform_assassin_dash_attack_immediate(npc: Node, target_pos: Vector2i) -> void:
	"""Perform AssassinDash attack immediately without movement animation"""
	# Play cut sound
	if assassin_cut_sound:
		assassin_cut_sound.play()
	
	# Deal 40 damage
	var assassin_damage = 40
	
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
		assassin_damage = 0
	else:
		# Deal damage to the NPC
		if npc.has_method("take_damage"):
			npc.take_damage(assassin_damage)
		else:
			print("NPC does not have take_damage method")
	
	# Apply knockback (works for both living and dead NPCs)
	apply_knockback(npc, target_pos)
	
	# Emit signal
	emit_signal("npc_attacked", npc, assassin_damage)
	
	# Exit attack mode
	exit_attack_mode() 
