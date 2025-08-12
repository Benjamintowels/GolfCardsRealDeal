extends Control

signal card_saved(card: CardData)
signal dialog_closed

@onready var background: ColorRect = $Background
@onready var title_label: Label = $DialogBox/TitleLabel
@onready var card_container: GridContainer = $DialogBox/CardContainer
@onready var close_button: Button = $DialogBox/CloseButton
@onready var save_sound: AudioStreamPlayer2D = $SaveSound
@onready var bag_sound: AudioStreamPlayer2D = $BagSound

var current_deck_manager
var selected_card: CardData = null
var card_buttons: Array[Button] = []
var save_file_manager

func _ready():
	# Connect signals
	close_button.pressed.connect(_on_close_button_pressed)
	
	# Get reference to current deck manager and save file manager
	current_deck_manager = get_tree().current_scene.get_node_or_null("CurrentDeckManager")
	save_file_manager = get_node("/root/SaveFileManager")
	
	if not current_deck_manager:
		print("CardSaveDialog: ERROR - CurrentDeckManager not found!")
		return
	
	if not save_file_manager:
		print("CardSaveDialog: ERROR - SaveFileManager not found!")
		return
	
	# Initially hide the dialog
	visible = false

func show_dialog():
	"""Show the card save dialog"""
	visible = true
	
	# Set high z_index to ensure dialog appears on top
	z_index = 3000
	
	# Hide any existing reward dialogs that might interfere
	hide_existing_reward_dialogs()
	
	# Hide ShopItems to prevent them from appearing on top
	hide_shop_items()
	
	load_player_deck()
	update_title()
	
	# Play sound when showing save dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()

func hide_existing_reward_dialogs():
	"""Hide any existing reward dialogs"""
	var existing_dialogs = get_tree().get_nodes_in_group("reward_dialogs")
	for dialog in existing_dialogs:
		if dialog != self and is_instance_valid(dialog):
			dialog.visible = false

func hide_shop_items():
	"""Hide shop items to prevent them from appearing on top"""
	var shop_items = get_tree().current_scene.get_node_or_null("ShopItems")
	if shop_items:
		shop_items.visible = false

func load_player_deck():
	"""Load and display the player's current deck"""
	if not current_deck_manager:
		return
	
	# Clear existing card buttons
	for button in card_buttons:
		if button and is_instance_valid(button):
			button.queue_free()
	card_buttons.clear()
	
	# Get all cards in the deck
	var deck_cards = current_deck_manager.get_current_deck()
	
	# Group cards by type and count
	var card_counts = {}
	for card in deck_cards:
		var card_path = card.resource_path
		if not card_counts.has(card_path):
			card_counts[card_path] = {"card": card, "count": 0}
		card_counts[card_path]["count"] += 1
	
	# Create card displays
	for card_path in card_counts:
		var card_data = card_counts[card_path]["card"]
		var count = card_counts[card_path]["count"]
		
		# Check if this card's gene is already unlocked
		var is_gene_unlocked = save_file_manager.get_card_genes().has(card_path)
		
		# Create card display
		var card_display = create_card_display(card_data, count, is_gene_unlocked)
		card_container.add_child(card_display)
		
		# Create button for the card
		var card_button = TextureButton.new()
		card_button.texture_normal = card_data.image
		card_button.custom_minimum_size = Vector2(100, 120)
		card_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_button.pressed.connect(_on_card_button_pressed.bind(card_data))
		
		# Disable button if gene is already unlocked
		if is_gene_unlocked:
			card_button.modulate = Color(0.5, 0.5, 0.5, 0.7)
			card_button.disabled = true
		
		card_container.add_child(card_button)
		card_buttons.append(card_button)

func create_card_display(card_data: CardData, count: int, is_gene_unlocked: bool) -> Control:
	"""Create a display for a single card with count and gene status"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(100, 120)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Allow clicks to pass through
	
	# Use CardVisual for consistent display
	var card_scene = preload("res://CardVisual.tscn")
	var card_instance = card_scene.instantiate()
	card_instance.size = Vector2(100, 120)
	card_instance.position = Vector2(0, 0)
	card_instance.scale = Vector2(1.236, 1.113)
	card_instance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set the card data
	if card_instance.has_method("set_card_data") and card_data:
		card_instance.set_card_data(card_data)
	
	# Add gene status indicator
	if is_gene_unlocked:
		var gene_indicator = ColorRect.new()
		gene_indicator.color = Color.GREEN
		gene_indicator.size = Vector2(25, 25)
		gene_indicator.position = Vector2(75, 0)
		gene_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(gene_indicator)
		
		var gene_label = Label.new()
		gene_label.text = "✓"
		gene_label.add_theme_font_size_override("font_size", 18)
		gene_label.add_theme_color_override("font_color", Color.WHITE)
		gene_label.position = Vector2(81, 3)
		gene_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(gene_label)
	
	container.add_child(card_instance)
	
	return container

func update_title():
	"""Update the dialog title"""
	if title_label:
		title_label.text = "Card Save - Unlock CardGenes for 3D Printer"

func _on_card_button_pressed(card_data: CardData):
	"""Handle card button press"""
	if not card_data:
		return
	
	# Check if gene is already unlocked
	var card_path = card_data.resource_path
	if save_file_manager.get_card_genes().has(card_path):
		print("CardSaveDialog: Card gene already unlocked for", card_data.name)
		return
	
	# Show save confirmation
	show_save_confirmation(card_data)

func show_save_confirmation(card_data: CardData):
	"""Show confirmation dialog for saving a card gene"""
	# Play sound when showing save confirmation dialog
	if bag_sound and bag_sound.stream:
		bag_sound.play()
	
	# Create confirmation dialog
	var confirmation_dialog = Control.new()
	confirmation_dialog.name = "SaveConfirmation"
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
	title.text = "Save Card Gene"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.CYAN)
	title.add_theme_constant_override("outline_size", 2)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.position = Vector2(150, 20)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(title)
	
	# Card display
	var card_display = create_card_display(card_data, 1, false)
	card_display.position = Vector2(140, 60)
	card_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(card_display)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = "Unlock " + card_data.name + " CardGene for 3D Printer?"
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	desc_label.add_theme_constant_override("outline_size", 1)
	desc_label.add_theme_color_override("font_outline_color", Color.BLACK)
	desc_label.position = Vector2(50, 180)
	desc_label.size = Vector2(300, 40)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(desc_label)
	
	# Buttons
	var button_container = HBoxContainer.new()
	button_container.position = Vector2(100, 250)
	button_container.size = Vector2(200, 40)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_box.add_child(button_container)
	
	var yes_button = Button.new()
	yes_button.text = "Save Gene"
	yes_button.size = Vector2(80, 40)
	yes_button.pressed.connect(_on_confirm_save.bind(card_data, confirmation_dialog))
	button_container.add_child(yes_button)
	
	var no_button = Button.new()
	no_button.text = "Cancel"
	no_button.size = Vector2(80, 40)
	no_button.pressed.connect(func(): 
		# Play sound when canceling save confirmation
		if bag_sound and bag_sound.stream:
			bag_sound.play()
		confirmation_dialog.queue_free()
	)
	button_container.add_child(no_button)
	
	add_child(confirmation_dialog)

func _on_confirm_save(card_data: CardData, confirmation_dialog: Control):
	"""Handle save confirmation"""
	# Play save sound
	if save_sound and save_sound.stream:
		save_sound.play()
	
	# Unlock the card gene
	var card_path = card_data.resource_path
	if save_file_manager.unlock_card_gene(card_path):
		print("CardSaveDialog: Card gene unlocked for", card_data.name)
		
		# Show success message
		show_save_message("CardGene unlocked: " + card_data.name + "!")
		
		# Emit signal
		card_saved.emit(card_data)
		
		# Refresh the dialog to show updated status
		load_player_deck()
	else:
		print("CardSaveDialog: Failed to unlock card gene for", card_data.name)
	
	# Close confirmation dialog
	confirmation_dialog.queue_free()

func show_save_message(message: String):
	"""Show a save confirmation message"""
	var message_label = Label.new()
	message_label.text = message
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color.CYAN)
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.position = Vector2(400, 200)
	message_label.z_index = 1000
	add_child(message_label)
	
	# Remove message after 2 seconds
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): 
		if message_label and is_instance_valid(message_label):
			message_label.queue_free()
	)

func _on_close_button_pressed():
	"""Handle close button press"""
	hide_dialog()
	dialog_closed.emit()

func hide_dialog():
	"""Hide the dialog and restore shop items"""
	visible = false
	
	# Restore shop items visibility
	var shop_items = get_tree().current_scene.get_node_or_null("ShopItems")
	if shop_items:
		shop_items.visible = true
