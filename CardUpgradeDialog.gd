extends Control

signal card_upgraded(card: CardData)
signal dialog_closed

@onready var background: ColorRect = $Background
@onready var title_label: Label = $DialogBox/TitleLabel
@onready var card_container: GridContainer = $DialogBox/CardContainer
@onready var close_button: Button = $DialogBox/CloseButton
@onready var upgrade_sound: AudioStreamPlayer2D = $UpgradeSound

var current_deck_manager: CurrentDeckManager
var selected_card: CardData = null
var card_buttons: Array[Button] = []

func _ready():
	# Connect signals
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Get reference to current deck manager
	current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	if not current_deck_manager:
		print("CardUpgradeDialog: ERROR - CurrentDeckManager not found!")
		return
	
	# Initially hide the dialog
	visible = false

func show_dialog():
	"""Show the card upgrade dialog"""
	visible = true
	load_player_deck()
	title_label.text = "Select a Card to Upgrade"

func hide_dialog():
	"""Hide the card upgrade dialog"""
	visible = false
	clear_card_buttons()
	emit_signal("dialog_closed")

func load_player_deck():
	"""Load and display the player's current deck"""
	clear_card_buttons()
	
	if not current_deck_manager:
		print("CardUpgradeDialog: ERROR - CurrentDeckManager not found!")
		return
	
	var deck = current_deck_manager.get_current_deck()
	var card_summary = current_deck_manager.get_deck_summary()
	
	print("CardUpgradeDialog: Loading deck with", deck.size(), "cards")
	
	# Create a set of unique cards to avoid duplicates
	var unique_cards: Array[CardData] = []
	var seen_cards: Dictionary = {}
	
	for card in deck:
		if not seen_cards.has(card.name):
			unique_cards.append(card)
			seen_cards[card.name] = true
	
	# Create card buttons
	for card in unique_cards:
		if card.can_upgrade():  # Only show cards that can be upgraded
			create_card_button(card, card_summary[card.name])

func create_card_button(card: CardData, count: int):
	"""Create a button for a card in the upgrade dialog"""
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 160)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create card display
	var card_display = create_card_display(card, count)
	button.add_child(card_display)
	
	# Connect button signal
	button.pressed.connect(_on_card_button_pressed.bind(card))
	
	# Add to container and tracking array
	card_container.add_child(button)
	card_buttons.append(button)

func create_card_display(card: CardData, count: int) -> Control:
	"""Create a visual display for a card"""
	var container = Control.new()
	container.size = Vector2(120, 160)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Background
	var background = ColorRect.new()
	background.color = Color(0.2, 0.2, 0.2, 0.9)
	background.size = container.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(background)
	
	# Border - orange for upgraded cards, normal for base cards
	var border = ColorRect.new()
	if card.is_upgraded():
		border.color = Color(1.0, 0.5, 0.0, 0.8)  # Orange border for upgraded
	else:
		border.color = Color(0.8, 0.8, 0.8, 0.6)  # Normal border
	border.size = Vector2(container.size.x + 4, container.size.y + 4)
	border.position = Vector2(-2, -2)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(border)
	border.z_index = -1
	
	# Card image
	var image_rect = TextureRect.new()
	image_rect.texture = card.image
	image_rect.size = Vector2(80, 120)
	image_rect.position = Vector2(20, 10)
	image_rect.scale = Vector2(0.1, 0.1)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(image_rect)
	
	# Card name
	var name_label = Label.new()
	name_label.text = card.get_upgraded_name()
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.position = Vector2(5, 135)
	name_label.size = Vector2(110, 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(name_label)
	
	# Level indicator for upgraded cards
	if card.is_upgraded():
		var level_label = Label.new()
		level_label.text = "Lvl " + str(card.level)
		level_label.add_theme_font_size_override("font_size", 12)
		level_label.add_theme_color_override("font_color", Color.GREEN)
		level_label.add_theme_constant_override("outline_size", 2)
		level_label.add_theme_color_override("font_outline_color", Color.BLACK)
		level_label.position = Vector2(85, 5)
		level_label.size = Vector2(30, 20)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(level_label)
	
	# Count indicator
	var count_label = Label.new()
	count_label.text = "x" + str(count)
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", Color.YELLOW)
	count_label.add_theme_constant_override("outline_size", 1)
	count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	count_label.position = Vector2(5, 5)
	count_label.size = Vector2(30, 20)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(count_label)
	
	return container

func clear_card_buttons():
	"""Clear all card buttons"""
	for button in card_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	card_buttons.clear()

func _on_card_button_pressed(card: CardData):
	"""Handle card button press - show upgrade confirmation"""
	selected_card = card
	show_upgrade_confirmation(card)

func show_upgrade_confirmation(card: CardData):
	"""Show confirmation dialog for upgrading a card"""
	# Create confirmation dialog
	var confirmation_dialog = Control.new()
	confirmation_dialog.name = "UpgradeConfirmation"
	confirmation_dialog.size = get_viewport_rect().size
	confirmation_dialog.z_index = 2000
	confirmation_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var dialog_bg = ColorRect.new()
	dialog_bg.color = Color(0, 0, 0, 0.8)
	dialog_bg.size = confirmation_dialog.size
	dialog_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	confirmation_dialog.add_child(dialog_bg)
	
	var dialog_box = ColorRect.new()
	dialog_box.color = Color(0.2, 0.2, 0.2, 0.95)
	dialog_box.size = Vector2(400, 300)
	dialog_box.position = (confirmation_dialog.size - dialog_box.size) / 2
	dialog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirmation_dialog.add_child(dialog_box)
	
	# Title
	var title = Label.new()
	title.text = "Upgrade Card"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(150, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title)
	
	# Card display
	var card_display = create_card_display(card, 1)
	card_display.position = Vector2(140, 60)
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(card_display)
	
	# Upgrade description
	var desc_label = Label.new()
	desc_label.text = card.get_upgrade_description()
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.position = Vector2(50, 180)
	desc_label.size = Vector2(300, 40)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(desc_label)
	
	# Cost
	var cost_label = Label.new()
	cost_label.text = "Cost: " + str(card.upgrade_cost) + " coins"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color.GOLD)
	cost_label.add_theme_constant_override("outline_size", 1)
	cost_label.add_theme_color_override("font_outline_color", Color.BLACK)
	cost_label.position = Vector2(150, 220)
	cost_label.size = Vector2(200, 30)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(cost_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 250)
	button_container.size = Vector2(200, 40)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(button_container)
	
	var yes_button = Button.new()
	yes_button.text = "Upgrade"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_upgrade.bind(card, confirmation_dialog))
	button_container.add_child(yes_button)
	
	var no_button = Button.new()
	no_button.text = "Cancel"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(func(): confirmation_dialog.queue_free())
	button_container.add_child(no_button)
	
	add_child(confirmation_dialog)

func _on_confirm_upgrade(card: CardData, confirmation_dialog: Control):
	"""Confirm and perform the card upgrade"""
	# Remove confirmation dialog
	confirmation_dialog.queue_free()
	
	# Perform upgrade
	upgrade_card(card)
	
	# Play upgrade sound from shop if available
	var shop_interior = get_tree().current_scene.get_node_or_null("ShopInterior")
	if shop_interior:
		var shop_upgrade_sound = shop_interior.get_node_or_null("UpgradeSound")
		if shop_upgrade_sound and shop_upgrade_sound.stream:
			shop_upgrade_sound.play()
	
	# Show success message
	show_upgrade_success(card)
	
	# Reload the deck display
	load_player_deck()

func upgrade_card(card: CardData):
	"""Upgrade a card by increasing its level"""
	card.level += 1
	print("CardUpgradeDialog: Upgraded", card.name, "to level", card.level)
	
	# Emit signal for other systems to handle
	emit_signal("card_upgraded", card)

func show_upgrade_success(card: CardData):
	"""Show a success message for the upgrade"""
	var success_dialog = Control.new()
	success_dialog.name = "UpgradeSuccess"
	success_dialog.size = get_viewport_rect().size
	success_dialog.z_index = 2000
	success_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = success_dialog.size
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	success_dialog.add_child(bg)
	
	var message = Label.new()
	message.text = card.name + " upgraded to Level " + str(card.level) + "!"
	message.add_theme_font_size_override("font_size", 20)
	message.add_theme_color_override("font_color", Color.GREEN)
	message.add_theme_constant_override("outline_size", 2)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.position = (success_dialog.size - Vector2(400, 50)) / 2
	message.size = Vector2(400, 50)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	success_dialog.add_child(message)
	
	add_child(success_dialog)
	
	# Remove after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if success_dialog and is_instance_valid(success_dialog):
			success_dialog.queue_free()
	)

func _on_close_button_pressed():
	"""Handle close button press"""
	hide_dialog() 
