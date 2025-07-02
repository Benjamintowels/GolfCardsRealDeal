extends Control
class_name Bag

signal bag_clicked

@onready var texture_rect: TextureRect = $TextureRect

var bag_level: int = 1
var character_name: String = "Benny"  # Default character

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

func set_character(character: String):
	character_name = character
	set_bag_level(bag_level)  # Update texture with new character

func set_bag_level(level: int):
	bag_level = level
	if character_bag_textures.has(character_name) and character_bag_textures[character_name].has(level):
		texture_rect.texture = character_bag_textures[character_name][level]

func _on_bag_input_event(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_deck_dialog()
		bag_clicked.emit()

func show_deck_dialog():
	"""Show a dialog displaying all cards in the current deck"""
	# Create the dialog
	var dialog = Control.new()
	dialog.name = "DeckDialog"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.z_index = 100
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.add_child(background)
	
	# Main container
	var main_container = Control.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.custom_minimum_size = Vector2(800, 600)
	main_container.position = Vector2(-400, -300)
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
	title.text = "Current Deck (" + str(get_deck_size()) + " cards)"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.position = Vector2(20, 20)
	title.size = Vector2(760, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(350, 540)
	close_button.size = Vector2(100, 40)
	close_button.pressed.connect(func(): dialog.queue_free())
	main_container.add_child(close_button)
	
	# Scroll container for cards
	var scroll_container = ScrollContainer.new()
	scroll_container.position = Vector2(20, 80)
	scroll_container.size = Vector2(760, 440)
	main_container.add_child(scroll_container)
	
	# Grid container for cards
	var grid_container = GridContainer.new()
	grid_container.columns = 8  # 8 cards per row
	grid_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(grid_container)
	
	# Get current deck and display cards
	var current_deck = get_current_deck()
	var deck_summary = get_deck_summary()
	
	for card_name in deck_summary:
		var count = deck_summary[card_name]
		var card_data = get_card_by_name(card_name)
		if card_data:
			# Create card display
			var card_display = create_card_display(card_data, count)
			grid_container.add_child(card_display)
	
	# Add dialog to scene
	get_tree().current_scene.add_child(dialog)

func create_card_display(card_data: CardData, count: int) -> Control:
	"""Create a display for a single card with count"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(90, 120)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Card background
	var card_bg = ColorRect.new()
	card_bg.color = Color(0.3, 0.3, 0.3, 0.9)
	card_bg.size = Vector2(80, 100)
	card_bg.position = Vector2(5, 5)
	container.add_child(card_bg)
	
	# Card image
	var image_rect = TextureRect.new()
	image_rect.texture = card_data.image
	image_rect.size = Vector2(60, 80)
	image_rect.position = Vector2(15, 10)
	image_rect.scale = Vector2(0.12, 0.12)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(image_rect)
	
	# Card name
	var name_label = Label.new()
	name_label.text = card_data.name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.position = Vector2(5, 95)
	name_label.size = Vector2(80, 15)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(name_label)
	
	# Count label
	var count_label = Label.new()
	count_label.text = "x" + str(count)
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.YELLOW)
	count_label.position = Vector2(65, 5)
	count_label.size = Vector2(20, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(count_label)
	
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
