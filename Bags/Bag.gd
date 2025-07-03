extends Control
class_name Bag

signal bag_clicked

@onready var texture_rect: TextureRect = $TextureRect

var bag_level: int = 1
var character_name: String = "Benny"  # Default character
var inventory_dialog: Control = null
var is_inventory_open: bool = false
var is_replacement_mode: bool = false
var pending_reward: Resource = null
var pending_reward_type: String = ""
var replacement_confirmation_dialog: Control = null

# Character-specific bag textures (make it accessible)
var character_bag_textures = {
	"Layla": {
		1: preload("res://Bags/LaylaBag1.png"),
		2: preload("res://Bags/LaylaBag2.png"),
		3: preload("res://Bags/LaylaBag3.png"),
		4: preload("res://Bags/LaylaBag4.png")
	},
	"Benny": {
		1: preload("res://Bags/BennyBag1.png"),
		2: preload("res://Bags/BennyBag2.png"),
		3: preload("res://Bags/BennyBag3.png"),
		4: preload("res://Bags/BennyBag4.png")
	},
	"Clark": {
		1: preload("res://Bags/ClarkBag1.png"),
		2: preload("res://Bags/ClarkBag2.png"),
		3: preload("res://Bags/ClarkBag3.png"),
		4: preload("res://Bags/ClarkBag4.png")
	}
}

func _ready():
	# Set up the bag texture based on character and level
	set_bag_level(bag_level)
	
	# Make the bag clickable
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_bag_input_event)

func _input(event):
	"""Handle input for closing inventory with escape key"""
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_inventory_open:
			close_inventory()

func set_character(character: String):
	character_name = character
	set_bag_level(bag_level)  # Update texture with new character

func set_bag_level(level: int):
	bag_level = level
	if character_bag_textures.has(character_name) and character_bag_textures[character_name].has(level):
		texture_rect.texture = character_bag_textures[character_name][level]

func _on_bag_input_event(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_inventory()
		bag_clicked.emit()

func toggle_inventory():
	"""Toggle the inventory dialog on/off"""
	if is_inventory_open:
		close_inventory()
	else:
		show_inventory()

func close_inventory():
	"""Close the inventory dialog"""
	if inventory_dialog and is_instance_valid(inventory_dialog):
		inventory_dialog.queue_free()
		inventory_dialog = null
	is_inventory_open = false
	is_replacement_mode = false
	pending_reward = null
	pending_reward_type = ""

func show_inventory():
	"""Show the inventory dialog"""
	if is_inventory_open:
		return
	
	show_deck_dialog()
	is_inventory_open = true

func show_inventory_replacement_mode(reward_data: Resource, reward_type: String):
	"""Show the inventory dialog in replacement mode"""
	
	if is_inventory_open:
		return
	
	pending_reward = reward_data
	pending_reward_type = reward_type
	is_replacement_mode = true
	
	show_deck_dialog()
	is_inventory_open = true

func show_deck_dialog():
	"""Show a dialog displaying all cards and equipment"""
	# Create the dialog
	var dialog = Control.new()
	dialog.name = "DeckDialog"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.z_index = 999
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.z_index = 999
	background.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_inventory()
	)
	dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(1000, 600)
	main_container.position = Vector2(-500, -300)
	main_container.z_index = 999
	dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = -1
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	if is_replacement_mode:
		title.text = "Select Card to Replace"
	else:
		title.text = "Inventory"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(960, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(450, 540)
	close_button.size = Vector2(100, 40)
	close_button.pressed.connect(close_inventory)
	main_container.add_child(close_button)
	
	# Equipment section (left side - single column)
	var equipment_label = Label.new()
	equipment_label.text = "Equipment"
	equipment_label.add_theme_font_size_override("font_size", 18)
	equipment_label.add_theme_color_override("font_color", Color.WHITE)
	equipment_label.position = Vector2(40, 80)
	equipment_label.size = Vector2(120, 30)
	main_container.add_child(equipment_label)
	
	var equipment_container = VBoxContainer.new()
	equipment_container.position = Vector2(40, 120)
	equipment_container.size = Vector2(120, 400)
	main_container.add_child(equipment_container)
	
	# Get and display equipment
	var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
	var equipped_items: Array[EquipmentData] = []
	if equipment_manager:
		equipped_items = equipment_manager.get_equipped_equipment()
	
	# Add equipment slots with placeholder for empty slots
	var equipment_slots = get_equipment_slots()
	for i in range(equipment_slots):
		var slot_container = create_slot_container()
		equipment_container.add_child(slot_container)
		
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		
		# Add actual equipment on top if available
		if i < equipped_items.size():
			var equipment_display = create_equipment_display(equipped_items[i])
			slot_container.add_child(equipment_display)
			# Ensure equipment appears on top by setting z_index
			equipment_display.z_index = 1
	
	# --- DYNAMIC MOVEMENT GRID LAYOUT ---
	# Determine columns based on bag level
	var movement_columns = 4
	match bag_level:
		1:
			movement_columns = 4
		2:
			movement_columns = 5
		3:
			movement_columns = 6
		4:
			movement_columns = 7
	var movement_slots = get_movement_slots()
	var movement_rows = int(ceil(float(movement_slots) / movement_columns))
	var slot_width = 80 + 12  # slot + h_separation
	var grid_width = movement_columns * slot_width - 12  # last column no separation
	var grid_height = movement_rows * (100 + 12) - 12
	var grid_x = 200  # left margin
	var grid_y = 70
	# Movement cards section (middle - dynamic grid)
	var movement_label = Label.new()
	movement_label.text = "Movement Cards"
	movement_label.add_theme_font_size_override("font_size", 18)
	movement_label.add_theme_color_override("font_color", Color.WHITE)
	movement_label.position = Vector2(grid_x, 50)
	movement_label.size = Vector2(grid_width, 30)
	main_container.add_child(movement_label)
	var movement_grid = GridContainer.new()
	movement_grid.columns = movement_columns
	movement_grid.position = Vector2(grid_x, grid_y)
	movement_grid.size = Vector2(grid_width, grid_height)
	movement_grid.add_theme_constant_override("h_separation", 12)
	movement_grid.add_theme_constant_override("v_separation", 12)
	main_container.add_child(movement_grid)
	# Get movement cards and display them
	var movement_cards = get_movement_cards()
	# Add movement card slots with placeholder for empty slots
	for i in range(movement_slots):
		var slot_container = create_slot_container()
		movement_grid.add_child(slot_container)
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		# Add actual card on top if available
		if i < movement_cards.size():
			var should_be_clickable = is_replacement_mode and pending_reward_type == "card" and not is_club_card(pending_reward)
			var card_display = create_card_display(movement_cards[i], 1, should_be_clickable)
			slot_container.add_child(card_display)
			card_display.z_index = 1
	# --- END DYNAMIC MOVEMENT GRID LAYOUT ---
	# Club cards section (right side - single column, dynamic position)
	var club_label = Label.new()
	club_label.text = "Club Cards"
	club_label.add_theme_font_size_override("font_size", 18)
	club_label.add_theme_color_override("font_color", Color.WHITE)
	# Place club section 40px right of movement grid, but not past dialog edge
	var club_x = min(grid_x + grid_width + 40, 1000 - 160)  # 120px wide + margin
	var club_label_y = 80
	var club_container_y = 120
	if bag_level == 4:
		club_label_y = 10
		club_container_y = 50
	club_label.position = Vector2(club_x, club_label_y)
	club_label.size = Vector2(120, 30)
	main_container.add_child(club_label)
	var club_container = VBoxContainer.new()
	club_container.position = Vector2(club_x, club_container_y)
	club_container.size = Vector2(120, 400)
	main_container.add_child(club_container)
	
	# Get club cards and display them
	var club_cards = get_club_cards()
	var club_slots = get_club_slots()
	
	# Add club card slots with placeholder for empty slots
	for i in range(club_slots):
		var slot_container = create_slot_container()
		club_container.add_child(slot_container)
		
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		
		# Add actual card on top if available
		if i < club_cards.size():
			var should_be_clickable = is_replacement_mode and pending_reward_type == "card" and is_club_card(pending_reward)
			var card_display = create_card_display(club_cards[i], 1, should_be_clickable)
			slot_container.add_child(card_display)
			# Ensure card appears on top by setting z_index
			card_display.z_index = 1
	
	# Add dialog to UI layer (parent of the bag)
	var ui_layer = get_parent()
	if ui_layer:
		ui_layer.add_child(dialog)
		inventory_dialog = dialog
	else:
		# Fallback to current scene if UI layer not found
		get_tree().current_scene.add_child(dialog)
		inventory_dialog = dialog

func create_card_display(card_data: CardData, count: int, clickable: bool = false) -> Control:
	"""Create a display for a single card with count"""
	if clickable:
		# Use TextureButton for clickable cards
		var button = TextureButton.new()
		button.name = "CardButton"
		button.custom_minimum_size = Vector2(80, 100)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.texture_normal = card_data.image
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.scale = Vector2(0.075, 0.075)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.pressed.connect(_on_card_button_pressed.bind(card_data))
		
		# Add hover effect
		var hover_overlay = ColorRect.new()
		hover_overlay.color = Color(1, 1, 0, 0.3)  # Yellow highlight
		hover_overlay.size = Vector2(80, 100)
		hover_overlay.visible = false
		hover_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(hover_overlay)
		
		button.mouse_entered.connect(func(): hover_overlay.visible = true)
		button.mouse_exited.connect(func(): hover_overlay.visible = false)
		
		return button
	else:
		# Use regular Control for non-clickable cards
		var container = Control.new()
		container.custom_minimum_size = Vector2(80, 100)
		container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Card image
		var image_rect = TextureRect.new()
		image_rect.texture = card_data.image
		image_rect.size = Vector2(80, 100)
		image_rect.position = Vector2(0, 0)
		image_rect.scale = Vector2(0.075, 0.075)
		image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		container.add_child(image_rect)
		
		return container

func _on_card_button_pressed(card_data: CardData):
	"""Handle card button press in replacement mode"""
	
	if is_replacement_mode and pending_reward:
		show_replacement_confirmation(card_data)

func _on_card_clicked(event: InputEvent, card_data: CardData):
	"""Handle card click in replacement mode (legacy function)"""
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_replacement_mode and pending_reward:
			show_replacement_confirmation(card_data)

func show_replacement_confirmation(card_to_replace: CardData):
	"""Show confirmation dialog for card replacement"""
	
	# Close any existing confirmation dialog first
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		replacement_confirmation_dialog.queue_free()
	
	replacement_confirmation_dialog = Control.new()
	replacement_confirmation_dialog.name = "ReplacementConfirmationDialog"
	replacement_confirmation_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	replacement_confirmation_dialog.z_index = 2000  # Set to 2000 for topmost
	replacement_confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.9)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.z_index = 2000
	replacement_confirmation_dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(600, 300)
	main_container.position = Vector2(-300, -150)
	main_container.z_index = 2000
	replacement_confirmation_dialog.add_child(main_container)
	
	# Panel background
	var panel = ColorRect.new()
	panel.color = Color(0.2, 0.2, 0.2, 0.95)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.z_index = 2000
	main_container.add_child(panel)
	
	# Border
	var border = ColorRect.new()
	border.color = Color(0.8, 0.8, 0.8, 0.6)
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.position = Vector2(-2, -2)
	border.size += Vector2(4, 4)
	border.z_index = 2000
	main_container.add_child(border)
	
	# Title
	var title = Label.new()
	title.text = "Replace Card"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(560, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.z_index = 2000
	main_container.add_child(title)
	
	# Message
	var message = Label.new()
	message.text = "Are you sure you want to replace '" + (card_to_replace.name if card_to_replace != null else "null") + "' with '" + (pending_reward.name if pending_reward != null else "null") + "'?"
	message.add_theme_font_size_override("font_size", 14)
	message.add_theme_color_override("font_color", Color.WHITE)
	message.position = Vector2(20, 80)
	message.size = Vector2(560, 60)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.z_index = 2000
	main_container.add_child(message)
	
	# Card comparison
	var card_comparison = HBoxContainer.new()
	card_comparison.position = Vector2(150, 160)
	card_comparison.size = Vector2(300, 80)
	card_comparison.z_index = 2000
	main_container.add_child(card_comparison)
	
	# Old card
	var old_card_label = Label.new()
	old_card_label.text = "Old: " + (card_to_replace.name if card_to_replace != null else "null")
	old_card_label.add_theme_font_size_override("font_size", 12)
	old_card_label.add_theme_color_override("font_color", Color.RED)
	old_card_label.z_index = 2000
	card_comparison.add_child(old_card_label)
	
	# Arrow
	var arrow_label = Label.new()
	arrow_label.text = " → "
	arrow_label.add_theme_font_size_override("font_size", 16)
	arrow_label.add_theme_color_override("font_color", Color.WHITE)
	arrow_label.z_index = 2000
	card_comparison.add_child(arrow_label)
	
	# New card
	var new_card_label = Label.new()
	new_card_label.text = "New: " + (pending_reward.name if pending_reward != null else "null")
	new_card_label.add_theme_font_size_override("font_size", 12)
	new_card_label.add_theme_color_override("font_color", Color.GREEN)
	new_card_label.z_index = 2000
	card_comparison.add_child(new_card_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(200, 220)
	button_container.size = Vector2(200, 40)
	button_container.z_index = 2000
	main_container.add_child(button_container)
	
	# Yes button
	var yes_button = Button.new()
	yes_button.text = "Yes"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_replacement.bind(card_to_replace))
	yes_button.z_index = 2000
	button_container.add_child(yes_button)
	
	# No button
	var no_button = Button.new()
	no_button.text = "No"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(_on_cancel_replacement_confirmation)
	no_button.z_index = 2000
	button_container.add_child(no_button)
	
	# Add dialog to UI layer as last child to ensure it's on top
	var ui_layer = get_tree().current_scene.get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(replacement_confirmation_dialog)
		ui_layer.move_child(replacement_confirmation_dialog, ui_layer.get_child_count() - 1)
		replacement_confirmation_dialog.visible = true
		# Lower the z_index of the Bag inventory dialog if it exists
		if inventory_dialog and is_instance_valid(inventory_dialog):
			inventory_dialog.z_index = 1000
	else:
		get_tree().current_scene.add_child(replacement_confirmation_dialog)
		replacement_confirmation_dialog.visible = true

func _on_confirm_replacement(card_to_replace: CardData):
	"""Confirm the card replacement"""
	if not pending_reward or not card_to_replace:
		close_replacement_confirmation()
		return
	# Remove the old card
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		current_deck_manager.remove_card_from_deck(card_to_replace)
	# Add the new card
	if pending_reward_type == "card":
		var card_data = pending_reward as CardData
		current_deck_manager.add_card_to_deck(card_data)
	elif pending_reward_type == "equipment":
		var equipment_data = pending_reward as EquipmentData
		var equipment_manager = get_tree().current_scene.get_node_or_null("EquipmentManager")
		if equipment_manager:
			equipment_manager.add_equipment(equipment_data)
	# Close dialogs
	close_replacement_confirmation()
	close_inventory()

func _on_cancel_replacement_confirmation():
	"""Cancel the replacement confirmation"""
	close_replacement_confirmation()

func close_replacement_confirmation():
	"""Close the replacement confirmation dialog"""
	if replacement_confirmation_dialog and is_instance_valid(replacement_confirmation_dialog):
		replacement_confirmation_dialog.queue_free()
		replacement_confirmation_dialog = null

func get_deck_size() -> int:
	"""Get the current deck size from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		return current_deck_manager.get_deck_size()
	return 0

func get_current_deck() -> Array[CardData]:
	"""Get the current deck from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		return current_deck_manager.get_current_deck()
	return []

func get_deck_summary() -> Dictionary:
	"""Get the deck summary from CurrentDeckManager"""
	var current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if current_deck_manager:
		return current_deck_manager.get_deck_summary()
	return {}

func get_card_by_name(card_name: String) -> CardData:
	"""Get a card by name from the current deck"""
	var current_deck = get_current_deck()
	for card in current_deck:
		if card.name == card_name:
			return card
	return null

func create_equipment_display(equipment_data: EquipmentData) -> Control:
	"""Create a display for a single piece of equipment"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(180, 60)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Equipment background
	var equip_bg = ColorRect.new()
	equip_bg.color = Color(0.3, 0.3, 0.3, 0.9)
	equip_bg.size = Vector2(180, 60)
	equip_bg.position = Vector2(0, 0)
	container.add_child(equip_bg)
	
	# Equipment image
	var image_rect = TextureRect.new()
	image_rect.texture = equipment_data.image
	image_rect.size = Vector2(40, 40)
	image_rect.position = Vector2(10, 10)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(image_rect)
	
	# Equipment name
	var name_label = Label.new()
	name_label.text = equipment_data.name
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.position = Vector2(60, 10)
	name_label.size = Vector2(110, 20)
	container.add_child(name_label)
	
	# Equipment description (hidden by default)
	var desc_label = Label.new()
	desc_label.text = equipment_data.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.position = Vector2(65, 30)
	desc_label.size = Vector2(310, 20)
	desc_label.visible = false  # Hidden by default
	
	# Add black background to description for better readability
	var desc_bg = ColorRect.new()
	desc_bg.color = Color(0, 0, 0, 0.8)
	desc_bg.size = Vector2(220, 24)
	desc_bg.position = Vector2(60, 28)
	desc_bg.visible = false  # Hidden by default
	container.add_child(desc_bg)
	container.add_child(desc_label)
	
	# Make container mouse filterable for hover detection
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect mouse enter/exit signals for hover effect
	container.mouse_entered.connect(func():
		desc_bg.visible = true
		desc_label.visible = true
		# Ensure description appears on top by setting high z_index
		desc_bg.z_index = 1000
		desc_label.z_index = 1001
	)
	
	container.mouse_exited.connect(func():
		desc_bg.visible = false
		desc_label.visible = false
	)
	
	return container

func get_movement_cards() -> Array[CardData]:
	"""Get all non-club cards from the current deck"""
	var current_deck = get_current_deck()
	var movement_cards: Array[CardData] = []
	for card in current_deck:
		if card.effect_type != "Club":
			movement_cards.append(card)
	return movement_cards

func get_club_cards() -> Array[CardData]:
	"""Get all club cards from the current deck"""
	var current_deck = get_current_deck()
	var club_cards: Array[CardData] = []
	
	for card in current_deck:
		if card.effect_type == "Club":
			club_cards.append(card)
	
	return club_cards

func _exit_tree():
	"""Clean up when the bag is removed from the scene"""
	close_inventory()
	close_replacement_confirmation()

func get_equipment_slots() -> int:
	"""Get the number of equipment slots based on bag level"""
	match bag_level:
		1: return 1
		2: return 2
		3: return 3
		4: return 4
		_: return 1

func get_movement_slots() -> int:
	"""Get the number of movement card slots based on bag level"""
	match bag_level:
		1: return 16  # 4x4 grid
		2: return 20  # 4x5 grid
		3: return 24  # 4x6 grid
		4: return 28  # 4x7 grid
		_: return 16

func get_club_slots() -> int:
	"""Get the number of club card slots based on bag level"""
	match bag_level:
		1: return 2
		2: return 3
		3: return 4
		4: return 5
		_: return 2

func create_slot_container() -> Control:
	"""Create a container for a slot that can hold both placeholder and actual item"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return container

func is_club_card(card_data: CardData) -> bool:
	"""Check if a card is a club card based on its name"""
	var club_names = ["Putter", "Wooden", "Iron", "Hybrid", "Driver", "PitchingWedge", "FireClub", "IceClub"]
	return club_names.has(card_data.name)

func create_placeholder_slot() -> Control:
	"""Create a placeholder slot using CardSlot.png"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Placeholder slot image
	var slot_image = TextureRect.new()
	slot_image.texture = preload("res://Cards/CardSlot.png")
	slot_image.size = Vector2(80, 100)
	slot_image.position = Vector2(0, 0)
	slot_image.scale = Vector2(0.75, 0.75)
	slot_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(slot_image)
	
	return container 
