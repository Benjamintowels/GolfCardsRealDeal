extends Control
class_name Bag

signal bag_clicked

@onready var texture_rect: TextureRect = $TextureRect

var bag_level: int = 1
var character_name: String = "Benny"  # Default character
var inventory_dialog: Control = null
var is_inventory_open: bool = false

# Character-specific bag textures
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

func show_inventory():
	"""Show the inventory dialog"""
	if is_inventory_open:
		return
	
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
	
	# Movement cards section (middle - 4x4 grid)
	var movement_label = Label.new()
	movement_label.text = "Movement Cards"
	movement_label.add_theme_font_size_override("font_size", 18)
	movement_label.add_theme_color_override("font_color", Color.WHITE)
	movement_label.position = Vector2(220, 50)
	movement_label.size = Vector2(360, 30)
	main_container.add_child(movement_label)
	
	var movement_grid = GridContainer.new()
	movement_grid.columns = 4
	movement_grid.position = Vector2(220, 70)
	movement_grid.size = Vector2(360, 400)
	movement_grid.add_theme_constant_override("h_separation", 12)
	movement_grid.add_theme_constant_override("v_separation", 12)
	main_container.add_child(movement_grid)
	
	# Get movement cards and display them
	var movement_cards = get_movement_cards()
	var movement_slots = get_movement_slots()
	
	# Add movement card slots with placeholder for empty slots
	for i in range(movement_slots):
		var slot_container = create_slot_container()
		movement_grid.add_child(slot_container)
		
		# Add placeholder as background
		var placeholder = create_placeholder_slot()
		slot_container.add_child(placeholder)
		
		# Add actual card on top if available
		if i < movement_cards.size():
			var card_display = create_card_display(movement_cards[i], 1)
			slot_container.add_child(card_display)
			# Ensure card appears on top by setting z_index
			card_display.z_index = 1
	
	# Club cards section (right side - single column)
	var club_label = Label.new()
	club_label.text = "Club Cards"
	club_label.add_theme_font_size_override("font_size", 18)
	club_label.add_theme_color_override("font_color", Color.WHITE)
	club_label.position = Vector2(620, 80)
	club_label.size = Vector2(120, 30)
	main_container.add_child(club_label)
	
	var club_container = VBoxContainer.new()
	club_container.position = Vector2(620, 120)
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
			var card_display = create_card_display(club_cards[i], 1)
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

func create_card_display(card_data: CardData, count: int) -> Control:
	"""Create a display for a single card with count"""
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
	
	# Equipment description
	var desc_label = Label.new()
	desc_label.text = equipment_data.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	desc_label.position = Vector2(60, 30)
	desc_label.size = Vector2(110, 20)
	container.add_child(desc_label)
	
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
