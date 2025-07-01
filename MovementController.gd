extends Node
class_name MovementController

# Movement system variables
var is_movement_mode := false
var movement_range := 2
var valid_movement_tiles := []
var selected_card: CardData = null
var selected_card_label: String = ""
var active_button: TextureButton = null
var movement_buttons := []
var movement_buttons_container: BoxContainer

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
var next_card_doubled := false

# Signals
signal movement_mode_entered
signal movement_mode_exited
signal card_selected(card: CardData)
signal card_discarded(card: CardData)

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
	movement_buttons_container_ref: BoxContainer,
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
	movement_buttons_container = movement_buttons_container_ref
	card_click_sound = card_click_sound_ref
	card_play_sound = card_play_sound_ref
	card_stack_display = card_stack_display_ref
	deck_manager = deck_manager_ref
	card_effect_handler = card_effect_handler_ref

func create_movement_buttons() -> void:
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()

	for i in deck_manager.hand.size():
		var card := deck_manager.hand[i]

		var btn := TextureButton.new()
		btn.name = "CardButton%d" % i
		btn.texture_normal = card.image
		btn.custom_minimum_size = Vector2(100, 140)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED

		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.focus_mode = Control.FOCUS_NONE
		btn.z_index = 10

		var overlay := ColorRect.new()
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(1, 0.84, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		btn.add_child(overlay)

		btn.mouse_entered.connect(func(): overlay.visible = true)
		btn.mouse_exited.connect(func(): overlay.visible = false)

		btn.pressed.connect(func(): _on_movement_card_pressed(card, btn))

		movement_buttons_container.add_child(btn)
		movement_buttons.append(btn)

func _on_movement_card_pressed(card: CardData, button: TextureButton) -> void:
	if selected_card == card:
		return
	card_click_sound.play()
	hide_all_movement_highlights()
	valid_movement_tiles.clear()

	# Check if this is a special effect card first
	if card_effect_handler and card_effect_handler.handle_card_effect(card):
		return  # Effect was handled by the effect handler
	
	is_movement_mode = true
	active_button = button
	selected_card = card
	selected_card_label = card.name
	movement_range = card.effect_strength

	if next_card_doubled:
		movement_range *= 2
		print("Card effect doubled! New range:", movement_range)

	print("Card selected:", card.name, "Range:", movement_range)

	player_node.start_movement_mode(card, movement_range)
	
	valid_movement_tiles = player_node.valid_movement_tiles.duplicate()
	show_movement_highlights()
	
	emit_signal("movement_mode_entered")
	emit_signal("card_selected", card)



func calculate_valid_movement_tiles() -> void:
	valid_movement_tiles.clear()

	var base_mobility = player_stats.get("base_mobility", 0)
	var total_range = movement_range + base_mobility

	for y in grid_size.y:
		for x in grid_size.x:
			var pos := Vector2i(x, y)

			if calculate_grid_distance(player_grid_pos, pos) <= total_range and pos != player_grid_pos:
				if obstacle_map.has(pos):
					var obstacle = obstacle_map[pos]

					if obstacle.has_method("blocks") and obstacle.blocks():
						continue

				valid_movement_tiles.append(pos)

func calculate_grid_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func show_movement_highlights() -> void:
	hide_all_movement_highlights()
	for pos in valid_movement_tiles:
		grid_tiles[pos.y][pos.x].get_node("MovementHighlight").visible = true

func hide_all_movement_highlights() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			grid_tiles[y][x].get_node("MovementHighlight").visible = false

func exit_movement_mode() -> void:
	is_movement_mode = false
	hide_all_movement_highlights()
	valid_movement_tiles.clear()

	if active_button and active_button.is_inside_tree():
		if selected_card:
			var card_discarded := false

			if deck_manager.hand.has(selected_card):
				deck_manager.discard(selected_card)
				card_discarded = true
				
				if next_card_doubled:
					next_card_doubled = false
			else:
				print("Card not in hand:", selected_card.name)

			card_stack_display.animate_card_discard(selected_card.name)
			emit_signal("card_discarded", selected_card)

		if movement_buttons_container and movement_buttons_container.has_node(NodePath(active_button.name)):
			movement_buttons_container.remove_child(active_button)

		active_button.queue_free()
		movement_buttons.erase(active_button)
		active_button = null

	selected_card_label = ""
	selected_card = null
	
	emit_signal("movement_mode_exited")

func handle_tile_click(x: int, y: int) -> bool:
	"""Handle tile click and return true if movement was successful"""
	var clicked := Vector2i(x, y)
	
	if is_movement_mode and clicked in valid_movement_tiles:
		player_node.move_to_grid(clicked)
		card_play_sound.play()
		return true
	else:
		print("Invalid movement tile or not in movement mode")
		return false

func handle_tile_mouse_entered(x: int, y: int, is_panning: bool) -> void:
	if not is_panning and is_movement_mode:
		var tile: Control = grid_tiles[y][x]
		var clicked := Vector2i(x, y)
		
		if not Vector2i(x, y) in valid_movement_tiles:
			tile.get_node("Highlight").visible = true

func handle_tile_mouse_exited(x: int, y: int, is_panning: bool) -> void:
	if not is_panning:
		grid_tiles[y][x].get_node("Highlight").visible = false

func clear_all_movement_ui() -> void:
	"""Clear all movement-related UI elements"""
	hide_all_movement_highlights()
	for child in movement_buttons_container.get_children():
		child.queue_free()
	movement_buttons.clear()
	selected_card_label = ""
	selected_card = null
	active_button = null
	is_movement_mode = false

func get_movement_cards_for_inventory() -> Array[CardData]:
	"""Get all movement cards from the current hand"""
	return deck_manager.hand.filter(func(card): return card.effect_type == "movement")

func update_player_position(new_grid_pos: Vector2i) -> void:
	"""Update the stored player grid position"""
	player_grid_pos = new_grid_pos

func is_in_movement_mode() -> bool:
	return is_movement_mode

func get_selected_card() -> CardData:
	return selected_card

func get_valid_movement_tiles() -> Array:
	return valid_movement_tiles.duplicate() 
