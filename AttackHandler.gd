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

# UI references
var card_stack_display: Control
var deck_manager: DeckManager

# Card effect handling
var card_effect_handler: Node

# Attack properties
var attack_damage := 25
var knockback_distance := 1

# Signals
signal attack_mode_entered
signal attack_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)
signal npc_attacked(npc: Node, damage: int)

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
	card_effect_handler_ref: Node
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

# Reference to movement controller for button cleanup
var movement_controller: Node = null

func set_movement_controller(controller: Node) -> void:
	movement_controller = controller

func create_attack_buttons() -> void:
	# Attack cards are now handled by the movement controller
	# This function is kept for compatibility but doesn't create separate buttons
	pass

func _on_attack_card_pressed(card: CardData, button: TextureButton) -> void:
	if selected_card == card:
		return
	card_click_sound.play()
	hide_all_attack_highlights()
	valid_attack_tiles.clear()

	is_attack_mode = true
	active_button = button
	selected_card = card
	attack_range = card.effect_strength

	calculate_valid_attack_tiles()
	show_attack_highlights()
	
	emit_signal("attack_mode_entered")
	emit_signal("card_selected", card)

func calculate_valid_attack_tiles() -> void:
	valid_attack_tiles.clear()

	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)

			if calculate_grid_distance(player_grid_pos, pos) <= attack_range and pos != player_grid_pos:
				# Check if there's an NPC at this position
				if has_npc_at_position(pos):
					valid_attack_tiles.append(pos)

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
		if is_instance_valid(npc) and npc.has_method("get_grid_position"):
			if npc.get_grid_position() == pos:
				return true
	
	return false

func get_npc_at_position(pos: Vector2i) -> Node:
	"""Get the NPC at the given grid position, or null if none"""
	if not card_effect_handler or not card_effect_handler.course:
		return null
	
	var entities = card_effect_handler.course.get_node_or_null("Entities")
	if not entities:
		return null
	
	var npcs = entities.get_npcs()
	for npc in npcs:
		if is_instance_valid(npc) and npc.has_method("get_grid_position"):
			if npc.get_grid_position() == pos:
				return npc
	
	return null

func show_attack_highlights() -> void:
	hide_all_attack_highlights()
	for pos in valid_attack_tiles:
		# Create orange attack highlight
		var tile = grid_tiles[pos.y][pos.x]
		var attack_highlight = tile.get_node_or_null("AttackHighlight")
		if not attack_highlight:
			attack_highlight = ColorRect.new()
			attack_highlight.name = "AttackHighlight"
			attack_highlight.size = tile.size
			attack_highlight.color = Color(1, 0.5, 0, 0.4)  # Orange with transparency
			attack_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
			attack_highlight.z_index = 101  # Higher than movement highlights
			tile.add_child(attack_highlight)
		attack_highlight.visible = true

func hide_all_attack_highlights() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			var tile = grid_tiles[y][x]
			var attack_highlight = tile.get_node_or_null("AttackHighlight")
			if attack_highlight:
				attack_highlight.visible = false

func exit_attack_mode() -> void:
	is_attack_mode = false
	hide_all_attack_highlights()
	valid_attack_tiles.clear()

	if selected_card:
		if deck_manager.hand.has(selected_card):
			deck_manager.discard(selected_card)
			card_stack_display.animate_card_discard(selected_card.name)
			emit_signal("card_discarded", selected_card)
		else:
			print("Card not in hand:", selected_card.name)

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
	
	if is_attack_mode and clicked in valid_attack_tiles:
		var npc = get_npc_at_position(clicked)
		if npc:
			perform_attack(npc, clicked)
			card_play_sound.play()
			return true
		else:
			print("No NPC found at attack position")
			return false
	else:
		print("Invalid attack tile or not in attack mode")
		return false

func perform_attack(npc: Node, target_pos: Vector2i) -> void:
	"""Perform the attack on the NPC"""
	
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
	
	if direction.x > 0:
		knockback_pos.x += knockback_distance
	elif direction.x < 0:
		knockback_pos.x -= knockback_distance
	elif direction.y > 0:
		knockback_pos.y += knockback_distance
	elif direction.y < 0:
		knockback_pos.y -= knockback_distance
	
	# Check if knockback position is valid
	if is_position_valid_for_knockback(knockback_pos):
		npc.set_grid_position(knockback_pos)
		
		# Update Y-sorting
		if npc.has_method("update_z_index_for_ysort"):
			npc.update_z_index_for_ysort()

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

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_grid_pos

func is_in_attack_mode() -> bool:
	return is_attack_mode

func get_selected_card() -> CardData:
	return selected_card

func get_valid_attack_tiles() -> Array:
	return valid_attack_tiles.duplicate() 
